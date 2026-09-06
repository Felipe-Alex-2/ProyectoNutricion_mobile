import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Configuración de URL para desarrollo en Localhost
  // Android Emulator: 10.0.2.2 redirige al localhost de la máquina anfitriona
  static const String _androidLocalUrl = 'http://10.0.2.2:8000/api/v1';
  // iOS Simulator, Web, Desktop (Windows/macOS/Linux)
  static const String _defaultLocalUrl = 'http://localhost:8000/api/v1';

  static String get baseUrl {
    if (!kIsWeb && Platform.isAndroid) {
      return _androidLocalUrl;
    }
    return _defaultLocalUrl;
  }
}


