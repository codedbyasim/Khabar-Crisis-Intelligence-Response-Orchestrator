// api_config.dart
// Centralized API configuration for KHABAR.
// Automatically selects the correct backend URL based on the platform.

import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Backend URL — Render Cloud Deployment
  static String get baseUrl {
    return 'https://khabar-api-xjc4.onrender.com';
  }
}
