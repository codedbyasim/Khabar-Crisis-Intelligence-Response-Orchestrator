import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

/// LocalLlmService — 100% On-device client-side Emergency Assistant.
/// Orchestrates dynamic Qwen2.5-0.5B-Instruct local GGUF execution via llama_cpp_dart.
/// Falls back gracefully to rule-based keyword matchers if model is not yet downloaded.
class LocalLlmService {
  static final LocalLlmService _instance = LocalLlmService._internal();
  factory LocalLlmService() => _instance;
  LocalLlmService._internal();

  static const String modelFileName = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const String modelDownloadUrl = 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const int _minimumModelBytes = 50 * 1024 * 1024;

  LlamaParent? _llamaParent;
  bool _isInitializing = false;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Check if the model has already been downloaded onto device memory
  Future<bool> isModelDownloaded() async {
    final file = await _getModelFile();
    if (!await file.exists()) return false;

    final size = await file.length();
    return size >= _minimumModelBytes;
  }

  Future<File> _getModelFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$modelFileName');
  }

  Future<void> _deleteModelFile() async {
    final file = await _getModelFile();
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  /// Downloads the 350MB Qwen GGUF model file chunk-by-chunk.
  /// Supports HTTP Range-based resume: if a partial file exists, continues from where it left off.
  /// Retries up to 5 times with exponential backoff on connection failures.
  Stream<double> downloadModel() async* {
    final file = await _getModelFile();
    await file.parent.create(recursive: true);

    const int maxRetries = 5;
    int attempt = 0;

    while (attempt < maxRetries) {
      attempt++;
      int downloadedBytes = 0;
      if (await file.exists()) {
        downloadedBytes = await file.length();
        if (downloadedBytes >= _minimumModelBytes) {
          yield 1.0;
          return;
        }
      }

      debugPrint("[LocalLlm] Download attempt $attempt/$maxRetries (offset: $downloadedBytes bytes)");
      final client = http.Client();
      try {
        int totalBytes = 360000000;
        try {
          final headResp = await client.head(Uri.parse(modelDownloadUrl))
              .timeout(const Duration(seconds: 15));
          final cl = headResp.headers['content-length'];
          if (cl != null) totalBytes = int.parse(cl);
        } catch (_) {}

        final request = http.Request('GET', Uri.parse(modelDownloadUrl));
        if (downloadedBytes > 0) {
          request.headers['Range'] = 'bytes=$downloadedBytes-';
        }

        final response = await client.send(request)
            .timeout(const Duration(seconds: 30));

        if (response.statusCode != 200 && response.statusCode != 206) {
          throw Exception('Server returned status: ${response.statusCode}');
        }

        final sink = file.openWrite(
          mode: downloadedBytes > 0 ? FileMode.append : FileMode.write,
        );

        try {
          await for (final chunk in response.stream) {
            sink.add(chunk);
            downloadedBytes += chunk.length;
            double progress = downloadedBytes / totalBytes;
            if (progress > 1.0) progress = 1.0;
            yield progress;
          }
          await sink.flush();
        } finally {
          await sink.close();
        }

        final finalSize = await file.length();
        if (finalSize >= _minimumModelBytes) {
          debugPrint("[LocalLlm] Download complete! Total: $finalSize bytes");
          yield 1.0;
          return;
        } else {
          throw Exception('File incomplete after download ($finalSize bytes).');
        }
      } catch (e) {
        client.close();
        debugPrint("[LocalLlm] Attempt $attempt failed: $e");
        if (attempt >= maxRetries) {
          await _deleteModelFile();
          throw Exception(
            'Download failed after $maxRetries attempts. '
            'Please check your internet connection and try again.',
          );
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      } finally {
        client.close();
      }
    }
  }

  /// Initializes the Llama engine with model offloaded to a background isolate thread
  Future<void> initModel() async {
    if (_isInitialized) return;
    if (_isInitializing) return;
    _isInitializing = true;

    try {
      final file = await _getModelFile();
      if (!await file.exists()) {
        throw Exception("Model file not found. Download it first.");
      }

      final size = await file.length();
      if (size < _minimumModelBytes) {
        await _deleteModelFile();
        throw Exception("Stored model file is incomplete. Please download it again.");
      }

      debugPrint("[LocalLlm] Initializing Llama Engine isolate with path: ${file.path}");
      
      // ✅ Explicitly load native library based on platform
      if (Platform.isAndroid) {
        debugPrint("[LocalLlm] Android detected - loading libllama.so");
        try {
          // Try to explicitly load the native library
          // llama_cpp_dart will automatically resolve from APK's lib/arm64-v8a/ or lib/armeabi-v7a/
          Llama.libraryPath = "libllama";  // Without .so - system will auto-append
        } catch (e) {
          debugPrint("[LocalLlm] Failed to set libraryPath: $e");
        }
      } else if (Platform.isIOS) {
        debugPrint("[LocalLlm] iOS detected - loading llama.framework");
        try {
          Llama.libraryPath = "llama.framework/llama";
        } catch (e) {
          debugPrint("[LocalLlm] Failed to set iOS libraryPath: $e");
        }
      }

      // Create optimized model parameters for mobile
      final modelParams = ModelParams();
      final contextParams = ContextParams();
      final samplingParams = SamplerParams();

      debugPrint("[LocalLlm] Creating LlamaLoad with model: ${file.path}");
      final loadCommand = LlamaLoad(
        path: file.path,
        modelParams: modelParams,
        contextParams: contextParams,
        samplingParams: samplingParams,
      );

      debugPrint("[LocalLlm] Initializing LlamaParent...");
      _llamaParent = LlamaParent(loadCommand);
      await _llamaParent!.init();
      
      _isInitialized = true;
      debugPrint("[LocalLlm] ✅ Llama Engine successfully initialized!");
    } catch (e) {
      debugPrint("[LocalLlm] ❌ Initialization error: $e");
      final errStr = e.toString().toLowerCase();
      
      // Check if this is a native library loading error
      final isLibraryError = errStr.contains('libllama') ||
          errStr.contains('dlopen') ||
          errStr.contains('cannot find') ||
          errStr.contains('library') ||
          errStr.contains('llamaexception') ||
          errStr.contains('failed to load');

      if (isLibraryError) {
        debugPrint("[LocalLlm] ⚠️  Native library not found - will use regex fallback");
        // Don't delete file - library issue, not file issue
      } else {
        debugPrint("[LocalLlm] File corruption detected - will re-download");
        await _deleteModelFile();
      }

      _isInitialized = false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Streams generated response tokens from the on-device model isolate
  Stream<String> getOfflineResponseStream(String query) {
    if (!_isInitialized || _llamaParent == null) {
      return Stream.error(Exception("Local AI engine is not initialized. Using regex fallback."));
    }

    return _generateTokenStream(query);
  }

  Stream<String> _generateTokenStream(String query) async* {
    try {
      // ChatML prompt structure for Qwen2.5-Instruct
      final prompt = "<|im_start|>system\n"
          "You are Khabar Offline AI, a helpful emergency response assistant for Islamabad and Rawalpindi. "
          "Keep responses extremely concise (2-3 sentences max), comforting, reassuring, and actionable. "
          "Provide specific safety tips, emergency helplines, or instructions in the user's language.\n"
          "<|im_end|>\n"
          "<|im_start|>user\n"
          "$query\n"
          "<|im_end|>\n"
          "<|im_start|>assistant\n";

      debugPrint("[LocalLlm] Sending prompt to isolate...");

      // Send prompt and wait for stream to start generating tokens
      final tokenStream = _llamaParent!.stream;
      _llamaParent!.sendPrompt(prompt);

      var generationActive = false;
      final maxWaitTime = Duration(seconds: 10);
      final startTime = DateTime.now();

      await for (final token in tokenStream) {
        // Check if we've exceeded max wait time
        if (DateTime.now().difference(startTime) > maxWaitTime) {
          debugPrint("[LocalLlm] Inference timeout exceeded");
          break;
        }

        generationActive = true;

        // Stop on end-of-sequence markers
        if (token.contains("<|im_end|>") || token.contains("<|im_start|>")) {
          debugPrint("[LocalLlm] End-of-sequence marker detected, stopping generation");
          break;
        }

        // Skip empty tokens and control characters
        if (token.isEmpty || token.codeUnits.every((code) => code < 32)) {
          continue;
        }

        debugPrint("[LocalLlm] Token: '$token'");
        yield token;
      }

      if (!generationActive) {
        debugPrint("[LocalLlm] No tokens generated from model");
      }
    } catch (e) {
      debugPrint("[LocalLlm] Stream generation error: $e");
      throw Exception("Model inference failed: $e");
    }
  }

  /// Synchronous fallback helper for backward compatibility and regex rule matchers
  Future<String> getOfflineResponse(
    String query,
    String selectedLanguage,
    String sector,
  ) async {
    // If the local GGUF model is downloaded and initialized, use it
    if (_isInitialized) {
      try {
        final buffer = StringBuffer();
        await for (final token in getOfflineResponseStream(query)
            .timeout(const Duration(seconds: 8))) {
          buffer.write(token);
        }

        final response = buffer.toString().trim();
        if (response.isNotEmpty) {
          return response;
        }
      } catch (e) {
        debugPrint("[LocalLlm] Fallback to regex due to inference error: $e");
      }
    }

    // Default simulation/regex logic if model is not loaded
    await Future.delayed(const Duration(milliseconds: 500));
    final String cleanQuery = query.toLowerCase().trim();
    String lang = detectLanguage(query);
    
    if (selectedLanguage == 'اردو' || selectedLanguage == 'Urdu') {
      final RegExp urduRegExp = RegExp(r'[\u0600-\u06FF]');
      if (!urduRegExp.hasMatch(query) && cleanQuery.length > 2) {
        lang = 'Roman Urdu';
      } else {
        lang = 'Urdu';
      }
    } else if (selectedLanguage == 'Roman Urdu') {
      lang = 'Roman Urdu';
    } else {
      final RegExp urduRegExp = RegExp(r'[\u0600-\u06FF]');
      if (urduRegExp.hasMatch(query)) {
        lang = 'Urdu';
      }
    }

    if (lang == 'Urdu') {
      return _getUrduResponse(cleanQuery, sector);
    } else if (lang == 'Roman Urdu') {
      return _getRomanUrduResponse(cleanQuery, sector);
    } else {
      return _getEnglishResponse(cleanQuery, sector);
    }
  }

  /// Auto-detects whether the query is written in Urdu, Roman Urdu, or English.
  String detectLanguage(String query) {
    final RegExp urduRegExp = RegExp(r'[\u0600-\u06FF]');
    if (urduRegExp.hasMatch(query)) {
      return 'Urdu';
    }

    final List<String> romanUrduKeywords = [
      'kya', 'hai', 'hain', 'mein', 'batao', 'karo', 'se', 'ki', 'ko', 'pay', 'pe', 'bachein', 
      'shuru', 'miley', 'ke', 'aur', 'ka', 'he', 'ye', 'yeh', 'kar', 'karen', 'karein', 'toh',
      'raha', 'rahi', 'rahe', 'hoga', 'hogi', 'ap', 'aap', 'koe', 'koi', 'mujhe', 'mjhe', 'bhi',
      'kuch', 'humein', 'hum', 'tha', 'thi', 'the', 'bhai', 'gari', 'gaadi', 'pani', 'paani',
      'barish', 'baarish', 'nazar', 'chal', 'kr', 'rha', 'ha', 'rhy'
    ];

    final List<String> words = query.toLowerCase().split(RegExp(r'[\s\p{P}]+', unicode: true));
    int romanScore = 0;
    for (var word in words) {
      if (romanUrduKeywords.contains(word)) {
        romanScore++;
      }
    }

    if (romanScore >= 1) {
      return 'Roman Urdu';
    }
    return 'English';
  }

  // ════════════════════════════════════════════
  // ENGLISH OFF-LINE ADVISORIES
  // ════════════════════════════════════════════
  String _getEnglishResponse(String query, String sector) {
    if (_matches(query, ['hello', 'hi', 'salam', 'khabar', 'who are you', 'status', 'start'])) {
      return '👋 **Hello! I am KHABAR Client-Side Offline AI.**\n\n'
          'I am running 100% locally on your phone without requiring any internet or backend server connection.\n\n'
          'I can assist you with emergency numbers, flood safety, rain precautions, electrical safety, first aid, and gas leak guidelines for Islamabad & Rawalpindi.\n\n'
          '*How can I help you in this emergency?*';
    }

    if (_matches(query, ['number', 'contact', 'phone', 'call', 'rescue', 'police', 'wasa', 'cda', 'helpline', 'ambulance', 'fire'])) {
      return '🚨 **Islamabad & Rawalpindi Emergency Helplines (Offline Database):**\n\n'
          '* **Rescue 1122** (Ambulance, Fire, Rescue): 📞 `1122` (Immediate emergency response)\n'
          '* **Police Emergency**: 📞 `15` (Call for security/law enforcement)\n'
          '* **Fire Brigade (Islamabad)**: 📞 `16` (Direct line for fires)\n'
          '* **WASA Islamabad & Rawalpindi**: 📞 `1334` (Water drainage, dewatering, and sewage emergencies)\n'
          '* **CDA Disaster Management (Islamabad)**: 📞 `051-9252036`\n\n'
          '_Keep these numbers saved on your phone. They do not require internet._';
    }

    if (_matches(query, ['rain', 'storm', 'weather', 'monsoon', 'barish', 'mosam', 'cloudburst'])) {
      return '🌧️ **Monsoon & Heavy Rain Safety Advisory:**\n\n'
          '* **Stay Indoors**: Avoid non-essential outdoor travel during heavy downpours.\n'
          '* **Nullah Lai Alert**: WASA monitors Nullah Lai water levels. If it exceeds **18 feet**, an alert is issued. Stay away from Nullah Lai banks.\n'
          '* **Travel Restrictions**: Avoid low-lying underpasses like Faizabad underpass, I-8 underpass, and waterlogged roads in G-11/G-10.\n'
          '* **Utility Outages**: Power cuts are common during rainstorms. Keep a flash light handy and charge your phone beforehand.';
    }

    if (_matches(query, ['flood', 'lai', 'nullah', 'nala', 'water', 'sailab', 'pani', 'drowning', 'submerge', 'inundat'])) {
      return '🌊 **Flood Emergency Action Plan:**\n\n'
          '* **Nullah Lai Danger**: Avoid traveling near Nullah Lai (Rawalpindi/Islamabad) when the water level rises past **18 feet**.\n'
          '* **Water Entering House**: If water enters your building:\n'
          '  1. **Unplug all electrical appliances** immediately to prevent electrocution.\n'
          '  2. Turn off your main breaker switch.\n'
          '  3. Move valuable goods and family members to a higher floor or elevated ground.\n'
          '* **Stranded Outdoors**: Never walk or drive through flowing water. Just 6 inches of moving water can sweep you off your feet, and 2 feet can carry away most cars.\n'
          '* **Emergency Dispatch**: Call Rescue **1122** for evacuation assistance.';
    }

    if (_matches(query, ['safety', 'protect', 'rules', 'precaution', 'hifazat', 'tadabeer', 'prevent'])) {
      return '🛡️ **Top 4 Emergency Safety Rules:**\n\n'
          '1. **Stay Indoors**: Avoid roads during lightning and heavy rainfall.\n'
          '2. **Electrical Hazard**: Never touch electric utility poles, transformers, or downed wires. They carry lethal currents.\n'
          '3. **Reroute**: Plan alternative routes away from underpasses and low-lying sectors.\n'
          '4. **Clean Drinking Water**: Floodwaters contaminate local supplies. Drink only boiled or clean bottled water to prevent cholera and other waterborne diseases.';
    }

    if (_matches(query, ['electricity', 'shock', 'wire', 'pole', 'current', 'transformer', 'power', 'wapda', 'iesco', 'khamba'])) {
      return '⚡ **Electrical Shock & Power Grid Safety:**\n\n'
          '* **Downed Wires**: Treat all fallen wires as live and dangerous. Keep at least a 30-foot distance.\n'
          '* **Water Hazard**: Do not touch switches or electronic devices with wet hands, or while standing in standing water.\n'
          '* **First Aid for Shock**:\n'
          '  1. **Do NOT touch the victim** directly if they are still in contact with the electrical source.\n'
          '  2. Switch off the main power source immediately.\n'
          '  3. If you cannot turn off power, use a dry, non-conductive object (like a wooden stick or broom handle) to push the victim away from the wire.\n'
          '  4. Call **1122** immediately for medical assistance.';
    }

    if (_matches(query, ['gas', 'leak', 'sui gas', 'cylinder', 'explosion', 'fire', 'aag'])) {
      return '🔥 **Gas Leak & Fire Safety Guide:**\n\n'
          '* **Gas Leak Detected**: If you smell gas inside your house:\n'
          '  1. Open all doors and windows immediately for ventilation.\n'
          '  2. **Do NOT switch on/off any electrical lights or appliances** (this causes sparks).\n'
          '  3. Do NOT light matches or lighters.\n'
          '  4. Turn off the main gas valve/cylinder valve.\n'
          '  5. Go outside and call the Sui Northern Gas pipeline helpline: 📞 `1199`.\n'
          '* **Active Fire**: Evacuate immediately. Call Fire Brigade: 📞 `16` or Rescue: 📞 `1122`.';
    }

    if (_matches(query, ['first aid', 'medical', 'hospital', 'zakhmi', 'hurt', 'injury', 'pims', 'shifa', 'holy family', 'doctor'])) {
      return '🚑 **First Aid & Emergency Medical Guide:**\n\n'
          '* **Severe Bleeding**: Apply firm, direct pressure to the wound with a clean cloth. Elevate the injured area above heart level if possible.\n'
          '* **Fractures**: Do not try to move the broken bone. Keep the limb still and wait for help.\n'
          '* **Emergency Ambulance**: Dial **1122** immediately.\n'
          '* **Key Regional Hospitals (Offline Reference)**:\n'
          '  * **PIMS Hospital**: Sector G-8, Islamabad (📞 `051-9261170`)\n'
          '  * **Shifa International**: Sector H-8, Islamabad (📞 `051-8440000`)\n'
          '  * **Holy Family Hospital**: Satellite Town, Rawalpindi (📞 `051-9290321`)\n'
          '  * **Benazir Bhutto Hospital**: Murree Road, Rawalpindi (📞 `051-9290301`)';
    }

    return 'ℹ️ **KHABAR Offline Intelligence Core (No Match):**\n\n'
        'I am running offline without server connection. I detected your query, but do not have an exact matching response in my local database.\n\n'
        '🚨 **Quick Help Contact Numbers:**\n'
        '* Emergency Ambulance, Rescue & Fire: Dial **1122**\n'
        '* Police Emergency: Dial **15**\n'
        '* Water Supply/Drainage: Dial WASA **1334**\n\n'
        '_Please stay safe, stay indoors during heavy storms, and avoid low roads._';
  }

  // ════════════════════════════════════════════
  // URDU OFF-LINE ADVISORIES
  // ════════════════════════════════════════════
  String _getUrduResponse(String query, String sector) {
    if (_matches(query, ['ہیلو', 'سلام', 'اسلام', 'کون', 'خبر', 'سٹارٹ', 'شروع'])) {
      return '👋 **السلام علیکم! میں خبر آف لائن اے آئی اسسٹنٹ ہوں۔**\n\n'
          'میں آپ کے فون پر بغیر انٹرنیٹ اور بغیر بیک اینڈ سرور کے 100% مقامی طور پر کام کر رہا ہوں۔\n\n'
          'میں آپ کو ہنگامی نمبرز، سیلاب سے بچاؤ، بارش کی حفاظتی تدابیر، بجلی کی حفاظت، فرسٹ ایڈ اور گیس لیکج کے بارے میں معلومات فراہم کر سکتا ہوں۔\n\n'
          '*اس ہنگامی صورتحال میں، میں آپ کی کیا مدد کر سکتا ہوں؟*';
    }

    if (_matches(query, ['نمبر', 'رابطہ', 'فون', 'کال', 'ریسکیو', 'پولیس', 'واسا', 'ہیلپ لائن', 'ایمبولینس', 'آگ'])) {
      return '🚨 **اسلام آباد اور راولپنڈی کے ہنگامی ہیلپ لائن نمبرز (آف لائن ڈیٹا بیس):**\n\n'
          '* **ریسکیو 1122** (ایمبولینس، فائر، ریسکیو): 📞 `1122` (فوری ہنگامی امداد)\n'
          '* **پولیس ایمرجنسی**: 📞 `15` (سیکیورٹی اور قانون نافذ کرنے والے ادارے)\n'
          '* **فائر بریگیڈ (اسلام آباد)**: 📞 `16` (آگ لگنے کے واقعات کے لیے)\n'
          '* **واسا راولپنڈی/اسلام آباد**: 📞 `1334` (پانی کی نکاسی اور سیوریج کے ہنگامی مسائل)\n'
          '* **سی ڈی اے ڈیزاسٹر مینجمنٹ (اسلام آباد)**: 📞 `051-9252036`\n\n'
          '_یہ ہنگامی نمبر اپنے پاس محفوظ رکھیں۔ ان کے لیے انٹرنیٹ یا نیٹ ورک ڈیٹا کی ضرورت نہیں ہے۔_';
    }

    if (_matches(query, ['بارش', 'طوفان', 'موسم', 'گرج', 'بادل', 'کلاؤڈ'])) {
      return '🌧️ **شدید بارش اور مون سون کی حفاظتی ہدایات:**\n\n'
          '* **گھر پر رہیں**: شدید بارش اور گرج چمک کے دوران غیر ضروری سفر سے گریز کریں۔\n'
          '* **نالہ لئی وارننگ**: نالہ لئی میں پانی کی سطح **18 فٹ** سے تجاوز کرنے پر واسا الرٹ جاری کرتا ہے۔ نالہ لئی کے کناروں سے دور رہیں۔\n'
          '* **سفر میں احتیاط**: پانی سے بھری سڑکوں اور انڈر پاسز (جیسے فیض آباد، آئی ایٹ انڈر پاس) سے گزرنے سے بچیں۔\n'
          '* **موبائل چارجنگ**: بارش کے دوران بجلی کی فراہمی معطل ہو سکتی ہے، اس لیے اپنے فونز اور ہنگامی لائٹس پہلے سے چارج رکھیں۔';
    }

    if (_matches(query, ['سیلاب', 'پانی', 'ڈوبنا', 'نالہ', 'لئی', 'نالہ لئی', 'سیلابی', 'ڈوب'])) {
      return '🌊 **سیلاب کی صورتحال میں ہنگامی اقدامات:**\n\n'
          '* **نالہ لئی کا خطرہ**: راولپنڈی اور اسلام آباد میں نالہ لئی کے قریب جانے سے گریز کریں جب پانی کی سطح **18 فٹ** سے اوپر چلی جائے۔\n'
          '* **اگر گھر میں پانی داخل ہو جائے**:\n'
          '  1. **بجلی کے تمام آلات فوری بند کر دیں** اور ان پلگ کریں تاکہ کرنٹ لگنے کا خطرہ نہ ہو۔\n'
          '  2. گھر کا مین سوئچ (بریکر) بند کر دیں۔\n'
          '  3. گھر کے افراد اور قیمتی سامان کو فوراً بالائی منزل یا اونچی جگہ منتقل کریں۔\n'
          '* **باہر پھنس جانے کی صورت میں**: بہتے ہوئے پانی میں پیدل چلنے یا گاڑی چلانے کی کوشش نہ کریں۔ صرف 6 انچ بہتا پانی آپ کو گرا سکتا ہے اور 2 فٹ پانی گاڑی کو بہا سکتا ہے۔\n'
          '* **ریسکیو ٹیم کے لیے**: فوری طور پر **1122** پر کال کریں۔';
    }

    if (_matches(query, ['حفاظت', 'بچاؤ', 'تدابیر', 'اصول', 'حفاظتی'])) {
      return '🛡️ **ہنگامی صورتحال کے 4 اہم حفاظتی اصول:**\n\n'
          '1. **اندر رہیں**: طوفان اور اسموگ/بارش کے دوران گھروں میں رہیں۔\n'
          '2. **بجلی سے دوری**: زمین پر گرے تاروں، کھمبوں اور ٹرانسفارمرز سے دور رہیں۔ ان میں جان لیوا کرنٹ ہو سکتا ہے۔\n'
          '3. **راستے کی تبدیلی**: سیلاب زدہ انڈر پاسز اور نشیبی سڑکوں کے بجائے متبادل اور محفوظ راستے چنیں۔\n'
          '4. **صاف پانی**: سیلاب کے دوران پینے کا پانی آلودہ ہو جاتا ہے۔ بیماریوں سے بچنے کے لیے صرف ابلا ہوا پانی استعمال کریں۔';
    }

    if (_matches(query, ['بجلی', 'کرنٹ', 'جھٹکا', 'تار', 'کھمبا', 'ٹرانسفارمر', 'واپڈا', 'آئیسکو'])) {
      return '⚡ **بجلی کے خطرات اور حادثات سے بچاؤ:**\n\n'
          '* **ٹوٹے ہوئے تار**: سڑک پر گرے ہوئے تاروں کو چالو سمجھیں اور ان سے کم از کم 30 فٹ کا فاعدہ رکھیں۔\n'
          '* **گیلے ہاتھ**: گیلے ہاتھوں سے بجلی کے بورڈ، سوئچ یا آلات کو ہاتھ نہ لگائیں اور نہ ہی پانی میں کھڑے ہو کر ایسا کریں۔\n'
          '* **کرنٹ لگنے کی صورت میں فرسٹ ایڈ**:\n'
          '  1. **متاثرہ شخص کو براہ راست نہ چھوئیں۔**\n'
          '  2. فوری طور پر مین سوئچ یا بریکر بند کر دیں۔\n'
          '  3. اگر بجلی بند کرنا ممکن نہ ہو تو کسی خشک لکڑی یا پلاسٹک کی لاٹھی سے متاثرہ شخص کو تار سے دور دھکیلیں۔\n'
          '  4. فوری طبی امداد کے لیے **1122** پر کال کریں۔';
    }

    if (_matches(query, ['گیس', 'لیک', 'سلنڈر', 'آگ', 'دھواں', 'دھماکہ', 'فائر'])) {
      return '🔥 **گیس لیکج اور آگ لگنے کی حفاظتی تدابیر:**\n\n'
          '* **گیس کی بو آنے پر**:\n'
          '  1. گھر کی کھڑکیاں اور دروازے فوری کھول دیں تاکہ گیس باہر نکل سکے۔\n'
          '  2. **بجلی کا کوئی سوئچ آن یا آف نہ کریں** (اس سے چنگاری پیدا ہو سکتی ہے)۔\n'
          '  3. ماچس، لکڑی یا سگریٹ ہرگز نہ جلائیں۔\n'
          '  4. گیس کا مین والو یا سلنڈر والو بند کریں۔\n'
          '  5. گھر سے باہر جا کر سوئی گیس ہیلپ لائن 📞 `1199` پر کال کریں۔\n'
          '* **آگ لگنے پر**: عمارت سے فوراً باہر نکلیں۔ لفٹ کا استعمال نہ کریں۔ اسلام آباد فائر بریگیڈ 📞 `16` یا ریسکیو 📞 `1122` پر کال کریں۔';
    }

    if (_matches(query, ['زخمی', 'فرسٹ ایڈ', 'طبی', 'ہسبتال', 'چوٹ', 'پمز', 'شفا', 'ڈاکٹر'])) {
      return '🚑 **فرسٹ ایڈ اور ہنگامی طبی معلومات:**\n\n'
          '* **خون بہنا**: زخم پر صاف کپڑے سے مضبوطی سے دباؤ ڈالیں۔ اگر ممکن ہو تو زخم والے حصے کو دل کی سطح سے اونچا رکھیں۔\n'
          '* **ہڈی ٹوٹنا**: ٹوٹی ہوئی ہڈی کو ہلانے کی کوشش نہ کریں اور متاثرہ حصے کو ساکت رکھ کر مدد کا انتظار کریں۔\n'
          '* **ہنگامی ایمبولینس**: فوری طور پر **1122** ڈائل کریں۔\n'
          '* **ہسپتالوں کے فون نمبر (آف لائن حوالہ)**:\n'
          '  * **پمز ہسپتال**: سیکٹر G-8، اسلام آباد (📞 `051-9261170`)\n'
          '  * **شفا انٹرنیشنل**: سیکٹر H-8، اسلام آباد (📞 `051-8440000`)\n'
          '  * **ہولی فیملی ہسپتال**: سیٹلائٹ ٹاؤن، راولپنڈی (📞 `051-9290321`)\n'
          '  * **بینظیر بھٹو ہسپتال**: مری روڈ، راولپنڈی (📞 `051-9290301`)';
    }

    return 'ℹ️ **خبر آف لائن انٹیلی جنس کور (کوئی میچ نہیں ملا):**\n\n'
        'میں بیک اینڈ سرور سے منسلک ہوئے بغیر آف لائن کام کر رہا ہوں۔ مجھے آپ کا سوال موصول ہوا ہے، لیکن میرے آف لائن ڈیٹا بیس میں اس کا براہ راست جواب موجود نہیں۔\n\n'
        '🚨 **ہنگامی رابطے کے نمبرز:**\n'
        '* ایمبولینس، ریسکیو اور آگ بجھانے والا عملہ: **1122**\n'
        '* پولیس ہیلپ لائن: **15**\n'
        '* واسا (پانی کی نکاسی): **1334**\n\n'
        '_براہ کرم محفوظ رہیں، طوفان کے دوران گھروں میں رہیں اور سیلابی راستوں سے بچیں۔_';
  }

  // ════════════════════════════════════════════
  // ROMAN URDU OFF-LINE ADVISORIES
  // ════════════════════════════════════════════
  String _getRomanUrduResponse(String query, String sector) {
    if (_matches(query, ['hello', 'hi', 'salam', 'assalam', 'kon', 'khabar', 'start', 'shuru'])) {
      return '👋 **Assalam-o-Alaikum! Main KHABAR Offline AI Assistant hoon.**\n\n'
          'Main aapke phone pe bina internet aur bina server ke 100% locally chal raha hoon.\n\n'
          'Main aapko emergency numbers, flood safety, rain safety, electricity rules, first aid aur gas leaks ke baray mein bata sakta hoon.\n\n'
          '*Main is emergency mein aapki kya madad karoon?*';
    }

    if (_matches(query, ['number', 'contact', 'phone', 'call', 'rescue', 'police', 'wasa', 'cda', 'helpline', 'ambulance', 'fire', 'aag'])) {
      return '🚨 **Islamabad aur Rawalpindi Emergency Helplines (Offline Database):**\n\n'
          '* **Rescue 1122** (Ambulance, Fire, Rescue): 📞 `1122` (Fori emergency madad)\n'
          '* **Police Emergency**: 📞 `15` (Security ya police help ke liye)\n'
          '* **Fire Brigade (Islamabad)**: 📞 `16` (Aag bujhane ke liye)\n'
          '* **WASA Islamabad & Rawalpindi**: 📞 `1334` (Pani nikalne ya sewage emergencies ke liye)\n'
          '* **CDA Disaster Management (Islamabad)**: 📞 `051-9252036`\n\n'
          '_Yeh emergency numbers apne phone mein save rakhein. Inke liye internet ki zaroorat nahi hai._';
    }

    if (_matches(query, ['rain', 'storm', 'weather', 'monsoon', 'barish', 'mosam', 'cloudburst', 'toofan'])) {
      return '🌧️ **Barish aur Monsoon key safety rules:**\n\n'
          '* **Ghar pe rahein**: Tez barish aur bijli chamakne ke dauran bahar janay se parhez karein.\n'
          '* **Nullah Lai Alert**: WASA constantly monitor karta hai. Agar pani ka level **18 feet** se barhay to warning alert jari hota hai. Nullah Lai ke qareeb na jayein.\n'
          '* **Road blockages**: Waterlogged roads aur underpasses (jaise Faizabad, I-8 underpass) se guzarne se bachein.\n'
          '* **Power cuts**: Barish mein bijli ja sakti hai, is liye lights aur phones pehle se charge rakhein.';
    }

    if (_matches(query, ['flood', 'lai', 'nullah', 'nala', 'water', 'sailab', 'pani', 'drowning', 'doobna', 'flooding'])) {
      return '🌊 **Flood Emergency Action Plan (Roman Urdu):**\n\n'
          '* **Nullah Lai Danger**: Rawalpindi aur Islamabad mein Nullah Lai ke qareeb na jayein agar pani ka level **18 feet** se oopar chala jaye.\n'
          '* **Agar Ghar mein Pani aa jaye**:\n'
          '  1. **Bijli ke appliances foran unplug karein** taake current lagne ka khatra na ho.\n'
          '  2. Main switch (breaker) band kar dein.\n'
          '  3. Ghar ke logon aur qeemti saman ko foran doosri floor ya oonchi jagah shift karein.\n'
          '* **Bahar phans janay ki soorat mein**: Behtay pani mein paidal chalne ya gari chalane ki koshish na karein. Sirf 6 inches behta pani aap ko gira sakta hai aur 2 feet pani gari ko baha sakta hai.\n'
          '* **Madad ke liye**: Foran **1122** par call karein.';
    }

    if (_matches(query, ['safety', 'protect', 'rules', 'precaution', 'hifazat', 'tadabeer', 'prevent', 'bachao'])) {
      return '🛡️ **Emergency ke 4 aham Hifazati Rules:**\n\n'
          '1. **Bahar na niklein**: Barish aur toofan ke dauran ghar pe rahein.\n'
          '2. **Bijli ke khambay**: Gire hue taar, transformers aur wet poles se door rahein. In mein lethal current ho sakta hai.\n'
          '3. **Reroute**: Flooded areas aur low roads ke bajaye alternative safe rasta chunain.\n'
          '4. **Saaf pani**: Floods ke dauran pani ganda ho jata hai. Bimarion se bachne ke liye sirf ubla hua ya filtered pani piyein.';
    }

    if (_matches(query, ['electricity', 'shock', 'wire', 'pole', 'current', 'transformer', 'power', 'wapda', 'iesco', 'khamba', 'bijli'])) {
      return '⚡ **Bijli ke current aur shock se hifazat:**\n\n'
          '* **Gire hue taar**: Downed wires ko hamesha live aur dangerous samjhein, kam se kam 30 feet door rahein.\n'
          '* **Giley haath**: Giley hathon se ya pani mein khare ho kar electrical switches ya appliances ko haath na lagayein.\n'
          '* **Shock First Aid**:\n'
          '  1. **Zakhmi shaks ko direct touch na karein** agar wo current source se touch hai.\n'
          '  2. Foran main electrical switch/breaker band karein.\n'
          '  3. Agar power band karna mumkin na ho to dry wood (khushk lakri) ya plastic stick se zakhmi ko taar se door karein.\n'
          '  4. Ambulance ke liye foran **1122** call karein.';
    }

    if (_matches(query, ['gas', 'leak', 'sui gas', 'cylinder', 'explosion', 'fire', 'aag', 'dhuman'])) {
      return '🔥 **Gas Leakage aur Fire Emergency guidelines:**\n\n'
          '* **Gas Leak smell aye to**:\n'
          '  1. Ghar ki khirkiyan aur darwaze foran khol dein taake gas bahar nikal sakay.\n'
          '  2. **Bijli ka koi light ya switch ON/OFF na karein** (is se spark peda hota hai).\n'
          '  3. Matchstick ya lighter na jalayein.\n'
          '  4. Main gas valve/cylinder valve band karein.\n'
          '  5. Ghar se bahar ja kar Sui Gas helpline 📞 `1199` par call karein.\n'
          '* **Aag lagne par**: Building se foran bahar niklein. Lift use na karein. Islamabad Fire Brigade 📞 `16` ya Rescue 📞 `1122` call karein.';
    }

    if (_matches(query, ['first aid', 'medical', 'hospital', 'zakhmi', 'hurt', 'injury', 'pims', 'shifa', 'holy family', 'doctor', 'chot'])) {
      return '🚑 **First Aid aur Emergency Medical Guide:**\n\n'
          '* **Khoon behna (Bleeding)**: Zakham par clean cloth se pressure dein. Zakhmi hissay ko dil ki level se oopar rakhein taake bleeding kam ho.\n'
          '* **Hadi tootna (Fracture)**: Hadi ko seedha karne ya hilane ki koshish na karein, usay stable rakh kar ambulance ka wait karein.\n'
          '* **Emergency Ambulance**: Dial **1122** immediately.\n'
          '* **Emergency Hospitals (Offline Database Reference)**:\n'
          '  * **PIMS Hospital**: Sector G-8, Islamabad (📞 `051-9261170`)\n'
          '  * **Shifa International**: Sector H-8, Islamabad (📞 `051-8440000`)\n'
          '  * **Holy Family Hospital**: Satellite Town, Rawalpindi (📞 `051-9290321`)\n'
          '  * **Benazir Bhutto Hospital**: Murree Road, Rawalpindi (📞 `051-9290301`)';
    }

    return 'ℹ️ **KHABAR Offline Intelligence Core (No Match):**\n\n'
        'Main server ke bina offline mode mein chal raha hoon. Mujhe aapka query mila hai par iska exact matching response offline database mein nahi hai.\n\n'
        '🚨 **Emergency Numbers:**\n'
        '* Ambulance, Rescue & Fire: Dial **1122**\n'
        '* Police Emergency: Dial **15**\n'
        '* WASA (Water drainage): Dial **1334**\n\n'
        '_Salamat rahein, barish ke dauran ghar pe rahein aur flooded areas se door rahein._';
  }

  // Helper method to clear/dispose the LlamaParent instance manually
  void dispose() {
    if (_llamaParent != null) {
      _llamaParent = null;
      _isInitialized = false;
    }
  }

  bool _matches(String text, List<String> keywords) {
    final normalizedText = text.toLowerCase();
    for (var keyword in keywords) {
      if (normalizedText.contains(keyword.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
}
