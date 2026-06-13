// api_config.dart
// Centralized API configuration for KHABAR.
// Automatically selects the correct backend URL based on the platform.

import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Backend URL — selected automatically by platform:
  ///   Web (Chrome)        → http://127.0.0.1:8000  (same machine)
  ///   Android Emulator    → http://10.0.2.2:8000   (emulator host alias)
  ///   Physical Device     → change to your PC's local IP, e.g. http://192.168.1.x:8000
  static String get baseUrl {
    if (kIsWeb) {
      // Chrome / Web build — backend is on same machine
      return 'http://127.0.0.1:8000';
    }
    // Android emulator uses 10.0.2.2 to reach the host machine's localhost
    return 'http://10.0.2.2:8000';
  }
}
