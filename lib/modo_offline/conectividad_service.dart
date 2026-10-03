import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class ConectividadService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _estaConectado = true;
  bool _estaVerificando = false;

  bool get estaConectado => _estaConectado;
  bool get estaVerificando => _estaVerificando;

  ConectividadService() {
    _iniciarMonitoreo();
  }

  void _iniciarMonitoreo() {
    // Verificación inicial
    verificarConexionReal();

    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      final tieneInterfaz = results.any((r) => r != ConnectivityResult.none);
      if (!tieneInterfaz) {
        _actualizarEstado(false);
      } else {
        // Confirmar acceso real al servidor o internet
        await verificarConexionReal();
      }
    });
  }

  Future<bool> verificarConexionReal() async {
    _estaVerificando = true;
    notifyListeners();

    bool conectado = false;
    try {
      // 1. Intento rápido de resolución de host
      final host = Uri.parse(ApiConfig.baseUrl).host;
      if (host.isNotEmpty && host != 'localhost' && host != '10.0.2.2') {
        final result = await InternetAddress.lookup(host).timeout(const Duration(seconds: 4));
        conectado = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } else {
        // Si es emulador o localhost, probar lookup a google/cloudflare con timeout corto
        final result = await InternetAddress.lookup('one.one.one.one').timeout(const Duration(seconds: 3));
        conectado = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      }
    } catch (_) {
      conectado = false;
    }

    _estaVerificando = false;
    _actualizarEstado(conectado);
    return conectado;
  }

  void marcarDesconectadoPorErrorHttp() {
    if (_estaConectado) {
      _actualizarEstado(false);
    }
  }

  void _actualizarEstado(bool nuevoEstado) {
    if (_estaConectado != nuevoEstado) {
      _estaConectado = nuevoEstado;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
