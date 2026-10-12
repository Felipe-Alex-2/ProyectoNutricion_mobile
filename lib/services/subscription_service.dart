import 'dart:async';

import '../models/subscription_receipt.dart';

import 'package:flutter/foundation.dart';

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
  String? _ownerId;
  int _generation = 0;
  Future<void>? _refreshing;
  bool _isRefreshing = false;
  bool _hasResolvedSubscription = false;
  bool get isRefreshing => _isRefreshing;
  bool get hasResolvedSubscription => _hasResolvedSubscription;
  List<SubscriptionReceipt> _receipts = [];
  List<SubscriptionReceipt> get receipts => List.unmodifiable(_receipts);
  bool _receiptsLoading = false;
  bool get receiptsLoading => _receiptsLoading;
  String? _receiptsError;
  String? get receiptsError => _receiptsError;
  bool _hasMoreReceipts = false;
  bool get hasMoreReceipts => _hasMoreReceipts;
  int _receiptVersion = 0;

  Subscription? get currentSubscription => _currentSubscription;
  List<SubscriptionPlan> get plans => _plans;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isPremium => _currentSubscription?.isPremium ?? false;

  SubscriptionService(this._apiService, this._storageService);

  void reset() {
    _generation++;
    _receiptVersion++;
    _ownerId = null;
    _refreshing = null;
    _isRefreshing = false;
    _hasResolvedSubscription = false;
    _receipts = [];
    _receiptsLoading = false;
    _receiptsError = null;
    _hasMoreReceipts = false;
    _currentSubscription = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchCurrentSubscription({String? userId}) {
    if (userId == null || userId.isEmpty) {
      reset();
      return Future.value();
    }
    if (_ownerId != userId) {
      reset();
      _ownerId = userId;
    }
    if (_refreshing != null) return _refreshing!;
    final pending = _refreshSubscription(userId, _generation);
    _refreshing = pending;
    return pending.whenComplete(() {
      if (identical(_refreshing, pending)) _refreshing = null;
    });
  }

  bool _isCurrent(String userId, int generation) =>
      generation == _generation &&
      _ownerId == userId &&
      _apiService.currentUserId == userId;

  Future<void> _refreshSubscription(String userId, int generation) async {
    _isRefreshing = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _apiService.get('/subscriptions/current');
      if (!_isCurrent(userId, generation)) return;
      final sub = response is Map<String, dynamic>
          ? Subscription.fromJson(response)
          : null;
      if (sub != null && sub.userId == userId && sub.isPremium) {
        _currentSubscription = sub;
        await _storageService.saveLocalSubscription(
          status: sub.status,
          expiresAt: sub.expiresAt!.toIso8601String(),
          orderId: sub.paypalOrderId ?? '',
          userId: userId,
        );
      } else {
        _currentSubscription = null;
        await _storageService.clearLocalSubscription(userId: userId);
      }
      if (_isCurrent(userId, generation)) _hasResolvedSubscription = true;
    } on ApiException catch (error) {
      if (!_isCurrent(userId, generation)) return;
      if (error.statusCode == 0) {
        if (!isPremium) await _checkLocalSubscriptionFallback(userId);
        if (!_isCurrent(userId, generation)) return;
        if (isPremium) _hasResolvedSubscription = true;
      } else if (error.statusCode == 401 || error.statusCode == 403) {
        _currentSubscription = null;
        _hasResolvedSubscription = false;
        await _storageService.clearLocalSubscription(userId: userId);
      }
      if (_isCurrent(userId, generation)) _errorMessage = error.message;
    } catch (_) {
      if (_isCurrent(userId, generation)) {
        _errorMessage =
            'No se pudo comprobar la suscripción. Intenta de nuevo.';
      }
    } finally {
      if (_isCurrent(userId, generation)) {
        _isRefreshing = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchReceipts({bool loadMore = false}) async {
    final owner = _apiService.currentUserId;
    if (owner == null) return;
    if (_ownerId != owner) {
      reset();
      _ownerId = owner;
    }
    if (loadMore && (_receiptsLoading || !_hasMoreReceipts)) return;
    final version = ++_receiptVersion;
    final offset = loadMore ? _receipts.length : 0;
    _receiptsLoading = true;
    _receiptsError = null;
    notifyListeners();
    try {
      final response = await _apiService.get(
        '/subscriptions/receipts?limit=20&offset=$offset',
      );
      if (version != _receiptVersion || _apiService.currentUserId != owner) {
        return;
      }
      final page = (response as List)
          .map(
            (row) => SubscriptionReceipt.fromJson(row as Map<String, dynamic>),
          )
          .toList();
      _receipts = loadMore
          ? [
              ..._receipts,
              ...page.where(
                (item) => !_receipts.any((old) => old.id == item.id),
              ),
            ]
          : page;
      _hasMoreReceipts = page.length == 20;
    } catch (_) {
      if (version == _receiptVersion && _apiService.currentUserId == owner) {
        _receiptsError =
            'No se pudieron cargar tus comprobantes. Intenta de nuevo.';
      }
    } finally {
      if (version == _receiptVersion && _apiService.currentUserId == owner) {
        _receiptsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<Uint8List> downloadReceipt(SubscriptionReceipt receipt) async {
    final data = await _apiService.getBytes(
      '/subscriptions/receipts/${Uri.encodeComponent(receipt.id)}/pdf',
    );
    if (data.length < 5 || String.fromCharCodes(data.take(5)) != '%PDF-') {
      throw ApiException('El comprobante recibido no es un PDF válido.');
    }
    return data;
  }

  Future<void> _checkLocalSubscriptionFallback(String? userId) async {
    final generation = _generation;
    if (userId == null || userId.isEmpty) {
      _currentSubscription = null;
      return;
    }
    try {
      final local = await _storageService.getLocalSubscription(userId: userId);
      if (!_isCurrent(userId, generation)) return;
      final status = local['status'];
      final expiresStr = local['expires'];
      final order = local['order'];

      if (status == 'ACTIVE' && expiresStr != null && expiresStr.isNotEmpty) {
        final expires = DateTime.tryParse(expiresStr);
        if (expires != null && expires.isAfter(DateTime.now())) {
          _currentSubscription = Subscription(
            id: order ?? 'SUB_LOCAL',
            userId: userId,
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

  Future<CreateOrderResponse?> createPayPalOrder(String planName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _apiService.post(
        '/subscriptions/create-order',
        body: {'plan_name': planName},
      );
      return CreateOrderResponse.fromJson(data as Map<String, dynamic>);
    } catch (error) {
      _errorMessage = error.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PaymentVerificationResult> verifyAndActivateSubscription(
    String orderId, {
    String? userId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    final generation = _generation;
    try {
      final data = await _apiService.post(
        '/subscriptions/verify-order',
        body: {'order_id': orderId},
      ) as Map<String, dynamic>;
      if (userId == null ||
          _apiService.currentUserId != userId ||
          generation != _generation) {
        throw ApiException(
          'La cuenta cambió durante la verificación.',
          statusCode: 401,
        );
      }
      final subscription = data['subscription'];
      if (data['paid'] == true && subscription is Map<String, dynamic>) {
        final verified = Subscription.fromJson(subscription);
        if (verified.userId != userId || !verified.isPremium) {
          throw ApiException('La suscripción no pertenece al usuario actual.');
        }
        // Invalidate any older refresh started before checkout completed.
        _generation++;
        _ownerId = userId;
        _refreshing = null;
        _isRefreshing = false;
        _hasResolvedSubscription = true;
        _currentSubscription = verified;
        notifyListeners();
        await _storageService.saveLocalSubscription(
          status: verified.status,
          expiresAt: verified.expiresAt!.toIso8601String(),
          orderId: orderId,
          userId: userId,
        );
        unawaited(fetchReceipts());
      }
      return PaymentVerificationResult(
        isPaid:
            data['paid'] == true &&
            _currentSubscription?.paypalOrderId == orderId,
        message: data['message']?.toString() ?? 'Verifica el pago.',
        status: data['status']?.toString(),
      );
    } catch (error) {
      _errorMessage = error.toString();
      return PaymentVerificationResult(
        isPaid: false,
        message: _errorMessage!,
        status: 'ERROR',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> captureOrActivateSubscription(
    String orderId, {
    String? userId,
  }) async =>
      (await verifyAndActivateSubscription(orderId, userId: userId)).isPaid;

  Future<bool> cancelSubscription({String? userId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _apiService.post('/subscriptions/cancel');
      await _storageService.clearLocalSubscription(userId: userId);
      _generation++;
      _refreshing = null;
      _isRefreshing = false;
      _hasResolvedSubscription = true;
      _currentSubscription = null;
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
