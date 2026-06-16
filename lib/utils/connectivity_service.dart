import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:khabar/api_config.dart';
import 'package:khabar/utils/web_helper.dart';


class ConnectivityService extends ValueNotifier<bool> {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  Timer? _timer;
  bool _isChecking = false;

  // Real-time states to distinguish internet from backend connectivity
  bool hasInternet = true;
  bool isBackendOnline = true;

  int _failedBackendChecks = 0;
  int _failedInternetChecks = 0;

  ConnectivityService._internal() : super(true) {
    _startMonitoring();
  }

  void _startMonitoring() {
    // Check connection immediately on startup
    checkConnection();
    // Then poll every 4 seconds to maintain real-time status in UI
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      checkConnection();
    });
  }

  Future<bool> checkConnection() async {
    if (_isChecking) return value;
    _isChecking = true;

    // ── Step 1: Check internet/browser access ──
    bool netOk = false;
    if (!kIsWeb) {
      try {
        final netResponse = await http
            .get(Uri.parse('https://www.google.com'))
            .timeout(const Duration(milliseconds: 3000));
        netOk = netResponse.statusCode == 200;
      } catch (_) {
        netOk = false;
      }
    } else {
      netOk = checkBrowserOnline();
    }

    // ── Step 2: Check backend server reachability ──
    bool backendOk = false;
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.baseUrl))
          .timeout(const Duration(milliseconds: 3500));
      backendOk = response.statusCode == 200;
    } catch (_) {
      backendOk = false;
    }

    // ── Step 3: Self-healing fallback / status assignment ──
    if (backendOk) {
      if (kIsWeb) {
        // On web, verify backend also has internet.
        bool backendHasInternet = false;
        try {
          final healthResponse = await http
              .get(Uri.parse('${ApiConfig.baseUrl}/health'))
              .timeout(const Duration(milliseconds: 2000));
          if (healthResponse.statusCode == 200) {
            final data = jsonDecode(healthResponse.body);
            backendHasInternet = data['internet'] == true;
          }
        } catch (_) {
          backendHasInternet = netOk; // Fallback to browser's own connectivity status
        }
        netOk = netOk && backendHasInternet;
      } else {
        // On Mobile, if we failed the direct ping to google but the backend is online,
        // we ask the backend if IT has internet.
        if (!netOk) {
          try {
            final healthResponse = await http
                .get(Uri.parse('${ApiConfig.baseUrl}/health'))
                .timeout(const Duration(milliseconds: 2000));
            if (healthResponse.statusCode == 200) {
              final data = jsonDecode(healthResponse.body);
              if (data['internet'] == true) {
                netOk = true;
              }
            }
          } catch (_) {}
        }
      }
    }

    // Apply consecutive checks logic to prevent flickering
    if (netOk) {
      _failedInternetChecks = 0;
    } else {
      _failedInternetChecks++;
      // Require 2 consecutive failures to mark as offline
      if (_failedInternetChecks < 2) {
        netOk = hasInternet;
      }
    }

    if (backendOk) {
      _failedBackendChecks = 0;
    } else {
      _failedBackendChecks++;
      // Require 2 consecutive failures to mark as offline
      if (_failedBackendChecks < 2) {
        backendOk = isBackendOnline;
      }
    }

    hasInternet = netOk;
    isBackendOnline = backendOk;

    // The app is fully online only if both internet and backend are active
    bool isFullyOnline = netOk && backendOk;

    if (value != isFullyOnline) {
      value = isFullyOnline;
      debugPrint('[Connectivity] Status updated: isFullyOnline=$isFullyOnline (Internet=$netOk, Backend=$backendOk)');
    }
    _isChecking = false;
    return isFullyOnline;
  }

  void disposeService() {
    _timer?.cancel();
  }
}

