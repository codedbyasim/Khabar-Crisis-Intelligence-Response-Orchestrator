import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:khabar/api_config.dart';

/// LocalLlmService — Offline AI responses powered by the backend's local Gemma GGUF model.
///
/// Strategy:
///   1. Try calling `POST /local-chat` on the backend (uses Gemma GGUF model, no internet needed).
///   2. If backend is also unreachable, fall back to hardcoded keyword responses.
class LocalLlmService {
  static final LocalLlmService _instance = LocalLlmService._internal();
  factory LocalLlmService() => _instance;
  LocalLlmService._internal();

  Future<String> getOfflineResponse(
    String query,
    String language,
    String sector,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/local-chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': query,
              'language': language,
              'sector': sector,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['response'] != null) {
          final mode = data['mode'] ?? 'local_qwen';
          final modelTag = mode.contains('local') ? ' 🤖 Local AI' : ' ⚠️ Loading/Offline';
          debugPrint('[LocalLlm] Response via $mode');
          return '${data['response']}\n\n_[$modelTag Mode — No Internet]_';
        }
      }
    } on TimeoutException {
      debugPrint('[LocalLlm] /local-chat timeout');
    } catch (e) {
      debugPrint('[LocalLlm] /local-chat unreachable ($e)');
    }

    final bool isUrdu = language == 'Urdu' || language == 'اردو';
    final bool isRoman = language == 'Roman Urdu';
    if (isUrdu) {
      return '⚠️ آف لائن لوکل ماڈل اس وقت دستیاب نہیں ہے (لوڈ ہو رہا ہے یا غیر فعال ہے)۔ براہِ مہربانی ہنگامی مدد کے لیے Rescue 1122 پر کال کریں۔';
    } else if (isRoman) {
      return '⚠️ Offline Local AI Model abhi available nahi hai (Loading or Offline). Please call Rescue 1122 immediately for emergency support.';
    }
    return '⚠️ Local AI Model is currently unavailable (Loading or Offline). Please call Rescue 1122 directly for immediate assistance.';
  }
}
