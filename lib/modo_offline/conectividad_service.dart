import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import '../config/api_config.dart';

class ConectividadService extends ChangeNotifier with WidgetsBindingObserver {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _estaConectado = true;
  bool _estaVerificando = false;
  bool _estaEnPrimerPlano = true;

  Timer? _timerInactividadFueraApp;

  // Tiempo de inactividad fuera de la app antes de pasar a modo offline: 1 minuto
  static const Duration duracionInactividadFueraApp = Duration(minutes: 1);

  bool get estaConectado => _estaConectado;
  bool get estaVerificando => _estaVerificando;
  bool get estaEnPrimerPlano => _estaEnPrimerPlano;

  ConectividadService() {
    WidgetsBinding.instance.addObserver(this);
    _iniciarMonitoreo();
  }

  void _iniciarMonitoreo() {
    // Verificacion inicial al arrancar
    verificarConexionReal();

    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      final tieneInterfaz = results.any((r) => r != ConnectivityResult.none);
      if (!tieneInterfaz) {
        // Desconexion fisica real de red: Pasar a modo offline de inmediato
        _timerInactividadFueraApp?.cancel();
        _actualizarEstado(false);
      } else {
        // Interfaz activa: verificar conexion real
        if (_estaEnPrimerPlano) {
          await verificarConexionReal();
        } else if (_estaConectado) {
          await verificarConexionReal();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _alSalirDeLaApp();
        break;
      case AppLifecycleState.resumed:
        _alRegresarALaApp();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  void _alSalirDeLaApp() {
    if (!_estaEnPrimerPlano) return;
    _estaEnPrimerPlano = false;

    // Iniciar temporizador de 1 minuto de inactividad fuera de la aplicacion
    _timerInactividadFueraApp?.cancel();
    _timerInactividadFueraApp = Timer(duracionInactividadFueraApp, () {
      if (!_estaEnPrimerPlano) {
        debugPrint('[ConectividadService] 1 minuto de inactividad fuera de la app. Activando modo offline.');
        _actualizarEstado(false);
      }
    });
  }

  void _alRegresarALaApp() {
    _estaEnPrimerPlano = true;
    _timerInactividadFueraApp?.cancel();
    _timerInactividadFueraApp = null;

    // Al volver al primer plano, re-verificar de inmediato si hay conexion real
    verificarConexionReal();
  }

  Future<bool> verificarConexionReal() async {
    _estaVerificando = true;
    notifyListeners();

    bool conectado = false;
    try {
      final host = Uri.parse(ApiConfig.baseUrl).host;
      if (host.isNotEmpty && host != 'localhost' && host != '10.0.2.2') {
        try {
          final result = await InternetAddress.lookup(host).timeout(const Duration(seconds: 4));
          conectado = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        } catch (_) {
          // Si el host especifico de Railway se demoro, probar con DNS publico
          final fallback = await InternetAddress.lookup('one.one.one.one').timeout(const Duration(seconds: 3));
          conectado = fallback.isNotEmpty && fallback[0].rawAddress.isNotEmpty;
        }
      } else {
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
    // Si la aplicacion esta en segundo plano, respetar el minuto de inactividad antes de cambiar a offline
    if (!_estaEnPrimerPlano) {
      return;
    }

    // Si esta en primer plano y ocurrio un error HTTP, re-verificar conexion real
    verificarConexionReal();
  }

  void _actualizarEstado(bool nuevoEstado) {
    if (_estaConectado != nuevoEstado) {
      _estaConectado = nuevoEstado;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerInactividadFueraApp?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
