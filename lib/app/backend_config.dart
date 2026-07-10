import 'package:flutter/foundation.dart';

class BackendConfig {
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: kIsWeb
        ? 'http://localhost:8081'
        : 'http://192.168.45.156:8081',
  );

  static const Map<String, String> jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };
}
