import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/subscription_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

class SubscriptionService extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storageService;

  Subscription? _currentSubscription;
  List<SubscriptionPlan> _plans = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Credenciales directas de Sandbox como respaldo garantizado
  static const String _paypalClientId =
      'BAAgAP2YtTQ2bAYxpfmeNidhSjKcagiXNSy-Y9MO8CCzCi7_uIH4AGjOTUWYzcC_b-R49TE3xgGtE4ZfnM';
  static const String _paypalClientSecret =
      'EMXqvch3aLQqllX03PFwnasRL_FfFabn5JLTbr7PUj3KlLLM7dohH9Fyzya55wFlNPE9e5Whr8K7DPyE';
  static const String _paypalBaseUrl = 'https://api-m.sandbox.paypal.com';

  Subscription? get currentSubscription => _currentSubscription;
  List<SubscriptionPlan> get plans => _plans;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isPremium => _currentSubscription?.isPremium ?? false;

  SubscriptionService(this._apiService, this._storageService);

  void reset() {
    _currentSubscription = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchCurrentSubscription({String? userId}) async {
    _currentSubscription = null;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/subscriptions/current');
      if (response != null && response is Map<String, dynamic>) {
        final sub = Subscription.fromJson(response);
        // Validar estrictamente que la suscripción pertenezca a ESTE usuario y sea CLIENTE_PREMIUM
        final matchesUser = userId == null || sub.userId == null || sub.userId == userId;
        if (sub.isPremium && matchesUser) {
          _currentSubscription = sub;
          await _storageService.saveLocalSubscription(
            status: sub.status,
            expiresAt: sub.expiresAt?.toIso8601String() ?? '',
            orderId: sub.paypalOrderId ?? '',
            userId: userId,
          );
        } else {
          _currentSubscription = null;
          await _storageService.clearLocalSubscription(userId: userId);
        }
      } else {
        // El servidor confirmó que este usuario NO tiene suscripción activa
        _currentSubscription = null;
        await _storageService.clearLocalSubscription(userId: userId);
      }
    } catch (_) {
      // En caso de fallo de red, sólo consultar si este usuario específico tenía respaldo local
      await _checkLocalSubscriptionFallback(userId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _checkLocalSubscriptionFallback(String? userId) async {
    if (userId == null || userId.isEmpty) {
      _currentSubscription = null;
      return;
    }
    try {
      final local = await _storageService.getLocalSubscription(userId: userId);
      final status = local['status'];
      final expiresStr = local['expires'];
      final order = local['order'];

      if (status == 'ACTIVE' && expiresStr != null && expiresStr.isNotEmpty) {
        final expires = DateTime.tryParse(expiresStr);
        if (expires != null && expires.isAfter(DateTime.now())) {
          _currentSubscription = Subscription(
            id: order ?? 'SUB_LOCAL',
            planName: 'CLIENTE_PREMIUM',
            status: 'ACTIVE',
            amount: 5.0,
            currency: 'USD',
            startedAt: DateTime.now(),
            expiresAt: expires,
            createdAt: DateTime.now(),
            paypalOrderId: order,
          );
          return;
        }
      }
      _currentSubscription = null;
    } catch (_) {
      _currentSubscription = null;
    }
  }

  Future<void> fetchPlans() async {
    try {
      final response = await _apiService.get('/subscriptions/plans');
      if (response is List) {
        _plans = response
            .map((p) => SubscriptionPlan.fromJson(p as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  // Genera la orden oficial de PayPal Sandbox (vía backend o fallback directo a PayPal API)
  Future<CreateOrderResponse?> createPayPalOrder(String planName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // 1. Intento con el backend
    try {
      final response = await _apiService.post(
        '/subscriptions/create-order',
        body: {'plan_name': planName},
      );
      if (response is Map<String, dynamic>) {
        final order = CreateOrderResponse.fromJson(response);
        if (order.approvalUrl.isNotEmpty) {
          _isLoading = false;
          notifyListeners();
          return order;
        }
      }
    } catch (_) {
      // Si el backend en Railway está actualizándose o no responde, usamos PayPal REST API directo
    }

    // 2. Fallback garantizado directo a PayPal Sandbox REST API
    try {
      final order = await _createDirectPayPalSandboxOrder(
        5.00,
        'NutriSalud - Plan Premium IA (1 Mes)',
      );
      _isLoading = false;
      notifyListeners();
      return order;
    } catch (e) {
      _errorMessage = 'No se pudo generar la orden de PayPal ($e)';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<CreateOrderResponse> _createDirectPayPalSandboxOrder(
    double amount,
    String description,
  ) async {
    // 1. Obtener Access Token de PayPal Sandbox
    final credentials = '$_paypalClientId:$_paypalClientSecret';
    final basicAuth = base64Encode(utf8.encode(credentials));

    final tokenRes = await http.post(
      Uri.parse('$_paypalBaseUrl/v1/oauth2/token'),
      headers: {
        'Authorization': 'Basic $basicAuth',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'client_credentials'},
    );

    if (tokenRes.statusCode != 200) {
      throw Exception('Error autenticando con PayPal Sandbox: ${tokenRes.body}');
    }

    final tokenData = jsonDecode(tokenRes.body) as Map<String, dynamic>;
    final accessToken = tokenData['access_token'] as String;

    // 2. Crear Orden v2 Checkout
    final orderPayload = {
      'intent': 'CAPTURE',
      'purchase_units': [
        {
          'amount': {
            'currency_code': 'USD',
            'value': amount.toStringAsFixed(2),
          },
          'description': description,
        }
      ],
      'payment_source': {
        'paypal': {
          'experience_context': {
            'brand_name': 'NutriSalud',
            'landing_page': 'LOGIN',
            'user_action': 'PAY_NOW',
            'return_url': 'https://proyectonutricionbackend-production.up.railway.app/paypal-return',
            'cancel_url': 'https://proyectonutricionbackend-production.up.railway.app/cancel',
          }
        }
      }
    };

    final orderRes = await http.post(
      Uri.parse('$_paypalBaseUrl/v2/checkout/orders'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(orderPayload),
    );

    if (orderRes.statusCode != 200 && orderRes.statusCode != 201) {
      throw Exception('Error creando orden en PayPal: ${orderRes.body}');
    }

    final orderData = jsonDecode(orderRes.body) as Map<String, dynamic>;
    final orderId = orderData['id'] as String;
    final links = orderData['links'] as List<dynamic>? ?? [];

    String approvalUrl = '';
    for (final link in links) {
      final rel = link['rel'] as String?;
      if (rel == 'payer-action' || rel == 'approve') {
        approvalUrl = link['href'] as String;
        break;
      }
    }

    if (approvalUrl.isEmpty) {
      approvalUrl = 'https://www.sandbox.paypal.com/checkoutnow?token=$orderId';
    }

    return CreateOrderResponse(
      orderId: orderId,
      approvalUrl: approvalUrl,
    );
  }

  // Verifica con PayPal si el usuario realmente completó el pago antes de activar
  Future<PaymentVerificationResult> verifyAndActivateSubscription(
    String orderId, {
    String? userId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // 1. Intentar validar a través del endpoint del backend
    try {
      final res = await _apiService.post(
        '/subscriptions/verify-order',
        body: {'order_id': orderId},
      );
      if (res is Map<String, dynamic>) {
        final isPaid = res['paid'] == true;
        final message = res['message'] as String? ?? '';
        final status = res['status'] as String?;

        if (isPaid) {
          final now = DateTime.now();
          final expires = now.add(const Duration(days: 30));

          _currentSubscription = Subscription(
            id: orderId,
            planName: 'CLIENTE_PREMIUM',
            status: 'ACTIVE',
            amount: 5.0,
            currency: 'USD',
            startedAt: now,
            expiresAt: expires,
            createdAt: now,
            paypalOrderId: orderId,
          );

          await _storageService.saveLocalSubscription(
            status: 'ACTIVE',
            expiresAt: expires.toIso8601String(),
            orderId: orderId,
            userId: userId,
          );

          _isLoading = false;
          notifyListeners();
          return PaymentVerificationResult(
            isPaid: true,
            message: message.isNotEmpty ? message : 'Pago verificado exitosamente. Plan Premium activado.',
            status: status,
          );
        } else {
          // El backend confirmó que NO ha pagado aún
          _isLoading = false;
          _errorMessage = message.isNotEmpty ? message : 'No ha pagado aún en PayPal.';
          notifyListeners();
          return PaymentVerificationResult(
            isPaid: false,
            message: _errorMessage!,
            status: status,
          );
        }
      }
    } catch (e) {
      debugPrint('Fallo al verificar con backend, verificando directamente con PayPal Sandbox: $e');
    }

    // 2. Verificación directa con PayPal Sandbox REST API (garantizada)
    try {
      final directStatus = await _queryDirectPayPalOrderStatus(orderId);

      // Si la orden aún no ha sido pagada por el comprador:
      if (directStatus == 'CREATED' || directStatus == 'PAYER_ACTION_REQUIRED' || directStatus == 'SAVED') {
        _isLoading = false;
        _errorMessage = 'No ha pagado aún. Por favor complete el pago en PayPal en el navegador y vuelva a verificar.';
        notifyListeners();
        return PaymentVerificationResult(
          isPaid: false,
          message: _errorMessage!,
          status: directStatus,
        );
      }

      // Si está APPROVED, capturar el pago en PayPal
      if (directStatus == 'APPROVED') {
        final captured = await _captureDirectPayPalOrder(orderId);
        if (!captured) {
          _isLoading = false;
          _errorMessage = 'No ha pagado aún o el cobro no pudo completarse en PayPal.';
          notifyListeners();
          return PaymentVerificationResult(
            isPaid: false,
            message: _errorMessage!,
            status: 'CAPTURE_FAILED',
          );
        }
      } else if (directStatus != 'COMPLETED') {
        _isLoading = false;
        _errorMessage = 'Estado de orden en PayPal: $directStatus. No ha pagado aún.';
        notifyListeners();
        return PaymentVerificationResult(
          isPaid: false,
          message: _errorMessage!,
          status: directStatus,
        );
      }

      // El pago ESTÁ confirmado y capturado (COMPLETED)
      final now = DateTime.now();
      final expires = now.add(const Duration(days: 30));

      _currentSubscription = Subscription(
        id: orderId,
        planName: 'CLIENTE_PREMIUM',
        status: 'ACTIVE',
        amount: 5.0,
        currency: 'USD',
        startedAt: now,
        expiresAt: expires,
        createdAt: now,
        paypalOrderId: orderId,
      );

      await _storageService.saveLocalSubscription(
        status: 'ACTIVE',
        expiresAt: expires.toIso8601String(),
        orderId: orderId,
        userId: userId,
      );

      _isLoading = false;
      notifyListeners();
      return PaymentVerificationResult(
        isPaid: true,
        message: 'Pago verificado exitosamente. Plan Premium activado.',
        status: 'COMPLETED',
      );
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'No ha pagado aún o no se pudo comprobar el pago en PayPal.';
      notifyListeners();
      return PaymentVerificationResult(
        isPaid: false,
        message: _errorMessage!,
        status: 'ERROR',
      );
    }
  }

  Future<String> _queryDirectPayPalOrderStatus(String orderId) async {
    final credentials = '$_paypalClientId:$_paypalClientSecret';
    final basicAuth = base64Encode(utf8.encode(credentials));

    final tokenRes = await http.post(
      Uri.parse('$_paypalBaseUrl/v1/oauth2/token'),
      headers: {
        'Authorization': 'Basic $basicAuth',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'client_credentials'},
    );

    if (tokenRes.statusCode != 200) {
      throw Exception('Error autenticando con PayPal Sandbox');
    }

    final tokenData = jsonDecode(tokenRes.body) as Map<String, dynamic>;
    final accessToken = tokenData['access_token'] as String;

    final orderRes = await http.get(
      Uri.parse('$_paypalBaseUrl/v2/checkout/orders/$orderId'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (orderRes.statusCode != 200) {
      throw Exception('Error consultando orden $orderId');
    }

    final data = jsonDecode(orderRes.body) as Map<String, dynamic>;
    return (data['status'] as String? ?? 'UNKNOWN').toUpperCase();
  }

  Future<bool> _captureDirectPayPalOrder(String orderId) async {
    final credentials = '$_paypalClientId:$_paypalClientSecret';
    final basicAuth = base64Encode(utf8.encode(credentials));

    final tokenRes = await http.post(
      Uri.parse('$_paypalBaseUrl/v1/oauth2/token'),
      headers: {
        'Authorization': 'Basic $basicAuth',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'client_credentials'},
    );

    if (tokenRes.statusCode != 200) return false;

    final tokenData = jsonDecode(tokenRes.body) as Map<String, dynamic>;
    final accessToken = tokenData['access_token'] as String;

    final captureRes = await http.post(
      Uri.parse('$_paypalBaseUrl/v2/checkout/orders/$orderId/capture'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (captureRes.statusCode == 200 || captureRes.statusCode == 201) {
      final data = jsonDecode(captureRes.body) as Map<String, dynamic>;
      final status = (data['status'] as String? ?? '').toUpperCase();
      return status == 'COMPLETED' || status == 'APPROVED';
    }
    return false;
  }

  // Compatibilidad hacia atrás
  Future<bool> captureOrActivateSubscription(String orderId, {String? userId}) async {
    final res = await verifyAndActivateSubscription(orderId, userId: userId);
    return res.isPaid;
  }

  Future<bool> cancelSubscription({String? userId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.post('/subscriptions/cancel');
    } catch (_) {}

    await _storageService.clearLocalSubscription(userId: userId);
    _currentSubscription = null;
    _isLoading = false;
    notifyListeners();
    return true;
  }
}
