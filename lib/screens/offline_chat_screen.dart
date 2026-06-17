import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:khabar/utils/local_llm_service.dart';

class OfflineChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  OfflineChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class OfflineChatScreen extends StatefulWidget {
  const OfflineChatScreen({super.key});

  @override
  State<OfflineChatScreen> createState() => _OfflineChatScreenState();
}

class _OfflineChatScreenState extends State<OfflineChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<OfflineChatMessage> _messages = [];
  bool _isTyping = false;
  String _selectedLang = 'English'; // Toggle between 'English', 'اردو', 'Roman Urdu'

  // Model download & initialization states
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isInitializingModel = false;
  bool _isModelReady = false;
  String _downloadError = '';

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
    _loadWelcomeMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    LocalLlmService().dispose();
    super.dispose();
  }

  Future<void> _checkModelStatus() async {
    final downloaded = await LocalLlmService().isModelDownloaded();
    if (downloaded) {
      _initializeModel();
    }
  }

  Future<void> _initializeModel() async {
    if (mounted) {
      setState(() {
        _isInitializingModel = true;
        _downloadError = '';
      });
    }
    try {
      await LocalLlmService().initModel();
      if (mounted) {
        setState(() {
          _isModelReady = true;
          _isInitializingModel = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadError = 'Failed to load AI engine: $e';
          _isInitializingModel = false;
        });
      }
    }
  }

  void _startDownload() {
    if (mounted) {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
        _downloadError = '';
      });
    }

    LocalLlmService().downloadModel().listen(
      (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _downloadError = error.toString().replaceAll('Exception: ', '');
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isDownloading = false;
          });
        }
        _initializeModel();
      },
      cancelOnError: true,
    );
  }

  void _loadWelcomeMessage() {
    _messages.clear();
    String welcome = "";
    if (_selectedLang == 'English') {
      welcome = "👋 **Hello! I am KHABAR Client-Side Offline AI.**\n\n"
          "I am running 100% locally on your phone without requiring any internet or backend server connection.\n\n"
          "I can assist you with emergency numbers, flood safety, rain precautions, electrical safety, first aid, and gas leak guidelines for Islamabad & Rawalpindi.\n\n"
          "*How can I help you in this emergency?*";
    } else if (_selectedLang == 'اردو') {
      welcome = "👋 **السلام علیکم! میں خبر آف لائن اے آئی اسسٹنٹ ہوں۔**\n\n"
          "میں آپ کے فون پر بغیر انٹرنیٹ اور بغیر بیک اینڈ سرور کے 100% مقامی طور پر کام کر رہا ہوں۔\n\n"
          "میں آپ کو ہنگامی نمبرز، سیلاب سے بچاؤ، بارش کی حفاظتی تدابیر، بجلی کی حفاظت، فرسٹ ایڈ اور گیس لیکج کے بارے میں معلومات فراہم کر سکتا ہوں۔\n\n"
          "*میں اس ہنگامی صورتحال میں آپ کی کیا مدد کر سکتا ہوں؟*";
    } else {
      welcome = "👋 **Assalam-o-Alaikum! Main KHABAR Offline AI Assistant hoon.**\n\n"
          "Main aapke phone pe bina internet aur bina server ke 100% locally chal raha hoon.\n\n"
          "Main aapko emergency numbers, flood safety, rain safety, electricity rules, first aid aur gas leaks ke baray mein bata sakta hoon.\n\n"
          "*Main is emergency mein aapki kya madad karoon?*";
    }
    setState(() {
      _messages.add(OfflineChatMessage(
        text: welcome,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = OfflineChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await LocalLlmService().getOfflineResponse(
        text,
        _selectedLang,
        "Islamabad",
      );

      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(OfflineChatMessage(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(OfflineChatMessage(
            text: "Local AI Error: Failed to generate response ($error).",
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<Map<String, String>> _getSuggestionChips() {
    if (_selectedLang == 'English') {
      return [
        {'label': '🚨 Helplines', 'query': 'Emergency helpline numbers'},
        {'label': '🌧️ Rain Precautions', 'query': 'Monsoon rain safety precautions'},
        {'label': '🌊 Flood Actions', 'query': 'Flood emergency safety rules'},
        {'label': '⚡ Electric Safety', 'query': 'Electrical shock safety rules'},
        {'label': '🚑 First Aid Care', 'query': 'First aid and hospital references'},
      ];
    } else if (_selectedLang == 'اردو') {
      return [
        {'label': '🚨 ہنگامی نمبرز', 'query': 'ہنگامی نمبرز بتائیں'},
        {'label': '🌧️ بارش کی تدابیر', 'query': 'بارش کی حفاظتی تدابیر'},
        {'label': '🌊 سیلاب سے بچاؤ', 'query': 'سیلاب سے بچاؤ کے اقدامات'},
        {'label': '⚡ بجلی کی حفاظت', 'query': 'بجلی کے جھٹکے اور کرنٹ سے بچنا'},
        {'label': '🚑 فرسٹ ایڈ گائیڈ', 'query': 'زخمیوں کا علاج اور ہسپتال'},
      ];
    } else {
      return [
        {'label': '🚨 Helplines', 'query': 'Emergency numbers details'},
        {'label': '🌧️ Barish ki Safety', 'query': 'Barish safety precautions'},
        {'label': '🌊 Flood Rules', 'query': 'Flood safety rules'},
        {'label': '⚡ Bijli se Bachao', 'query': 'Bijli current shock guidance'},
        {'label': '🚑 First Aid Help', 'query': 'First aid medical hospital list'},
      ];
    }
  }

  // Custom rich text parser to display **bold** and * bullet points cleanly
  Widget _buildMessageContent(String text, bool isUser) {
    final List<String> lines = text.split('\n');
    final textColor = isUser ? Colors.white : Colors.white.withValues(alpha: 0.95);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.trim().startsWith('* ')) {
          // Bullet point line
          final String cleanLine = line.trim().substring(2);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0, left: 6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "• ",
                  style: TextStyle(
                    color: isUser ? Colors.white70 : const Color(0xFF14C3B4),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.nunito(
                        color: textColor,
                        fontSize: 14,
                        height: 1.45,
                      ),
                      children: _parseBoldSpans(cleanLine, isUser),
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // Regular line
          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.nunito(
                  color: textColor,
                  fontSize: 14.2,
                  height: 1.45,
                ),
                children: _parseBoldSpans(line, isUser),
              ),
            ),
          );
        }
      }).toList(),
    );
  }

  List<TextSpan> _parseBoldSpans(String text, bool isUser) {
    final List<TextSpan> spans = [];
    final RegExp exp = RegExp(r'\*\*(.*?)\*\*');
    int start = 0;

    for (final Match match in exp.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isUser ? Colors.white : const Color(0xFF14C3B4),
        ),
      ));
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
  }

  Widget _buildDownloadSection(bool isUrdu) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF091E1D).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF14C3B4).withValues(alpha: 0.2),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14C3B4).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                color: Color(0xFF14C3B4),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isUrdu ? "ایڈوانسڈ آف لائن اے آئی اپ گریڈ" : "Advanced Offline AI Upgrade",
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isUrdu
                ? "کیا آپ 350MB کا ایڈوانسڈ آف لائن Qwen-2.5 ماڈل ڈاؤن لوڈ کرنا چاہتے ہیں؟ یہ آپ کے 4GB RAM فون پر بغیر انٹرنیٹ مکمل ہنگامی معلومات فراہم کرے گا۔"
                : "Download the 350MB advanced Qwen-2.5 local model to enable rich on-device emergency reasoning without internet.",
            style: GoogleFonts.nunito(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (_downloadError.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _downloadError,
              style: const TextStyle(color: Color(0xFFFF5252), fontSize: 11),
            ),
          ],
          const SizedBox(height: 12),
          if (_isDownloading) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF14C3B4)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "${(_downloadProgress * 100).toStringAsFixed(0)}%",
                  style: GoogleFonts.nunito(
                    color: const Color(0xFF14C3B4),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isUrdu ? "ڈاؤن لوڈ ہو رہا ہے، براہِ کرم انتظار کریں..." : "Downloading model file, please wait...",
              style: GoogleFonts.nunito(
                color: Colors.white38,
                fontSize: 10,
              ),
            ),
          ] else if (_isInitializingModel) ...[
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Color(0xFF14C3B4),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isUrdu ? "آف لائن اے آئی ماڈل شروع ہو رہا ہے..." : "Initializing offline AI model...",
                  style: GoogleFonts.nunito(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ] else ...[
            GestureDetector(
              onTap: _startDownload,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2EA39B), Color(0xFF165E59)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF14C3B4).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    isUrdu ? "آف لائن ماڈل ڈاؤن لوڈ کریں (350MB)" : "Download Offline Model (350MB)",
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isUrdu = _selectedLang == 'اردو';

    return Scaffold(
      backgroundColor: const Color(0xFF071413),
      appBar: AppBar(
        backgroundColor: const Color(0xFF091E1D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF14C3B4).withValues(alpha: 0.15),
              child: const Icon(Icons.wifi_off_rounded, color: Color(0xFF14C3B4)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isUrdu ? "آف لائن ایمرجنسی گائیڈ" : "Offline Emergency AI",
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isModelReady ? const Color(0xFF14C3B4) : Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isModelReady 
                            ? (isUrdu ? "لوکل Qwen AI: فعال" : "On-Device Qwen AI: ACTIVE")
                            : (isUrdu ? "لوکل میچر: فعال" : "On-Device Matcher: ACTIVE"),
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          color: _isModelReady ? const Color(0xFF14C3B4) : Colors.amber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Language Switcher inside Chat
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLang,
                    dropdownColor: const Color(0xFF0B1E1C),
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF14C3B4), size: 16),
                    items: const [
                      DropdownMenuItem(value: 'English', child: Text('EN')),
                      DropdownMenuItem(value: 'اردو', child: Text('اردو')),
                      DropdownMenuItem(value: 'Roman Urdu', child: Text('ROM')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedLang = val;
                          _loadWelcomeMessage();
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF071413),
              Color(0xFF040B0A),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Offline Banner Warning
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F).withValues(alpha: 0.15),
                  border: const Border(
                    bottom: BorderSide(color: Color(0x33D32F2F), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFFF5252), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isUrdu
                            ? "یہ موڈ 100% آف لائن ہے۔ ہنگامی کال کے لیے براہِ راست 1122 ڈائل کریں۔"
                            : "Offline Mode. In critical danger, dial 1122 directly on phone.",
                        style: GoogleFonts.nunito(
                          color: const Color(0xFFFF8A8A),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Glassmorphic Download Section
              if (!_isModelReady)
                _buildDownloadSection(isUrdu),

              // Chat Messages Area
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _buildMessageBubble(msg);
                  },
                ),
              ),

              // Typing Indicator
              if (_isTyping)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xDF0A1D1C),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isUrdu ? "لوکل ماڈل سوچ رہا ہے..." : "Local AI is thinking...",
                              style: GoogleFonts.nunito(
                                color: Colors.white70,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Color(0xFF14C3B4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Suggested prompt chips
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _getSuggestionChips().map((chip) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        backgroundColor: const Color(0xFF091E1D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: const Color(0xFF14C3B4).withValues(alpha: 0.3),
                            width: 1.0,
                          ),
                        ),
                        label: Text(
                          chip['label']!,
                          style: GoogleFonts.nunito(
                            color: const Color(0xFF14C3B4),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => _sendMessage(chip['query']!),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Chat Input Field
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xDF0A1D1C),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                style: GoogleFonts.nunito(color: Colors.white, fontSize: 14.5),
                                decoration: InputDecoration(
                                  hintText: isUrdu ? "یہاں آف لائن سوال پوچھیں..." : "Ask offline helper here...",
                                  hintStyle: GoogleFonts.nunito(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onSubmitted: _sendMessage,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 48,
                      width: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF2EA39B),
                            Color(0xFF165E59),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 18),
                        onPressed: () => _sendMessage(_messageController.text),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(OfflineChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: msg.isUser 
              ? const Color(0xFF1C635E)
              : const Color(0xDF0A1D1C),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 16),
          ),
          border: Border.all(
            color: msg.isUser 
                ? const Color(0xFF14C3B4).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMessageContent(msg.text, msg.isUser),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                "${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}",
                style: GoogleFonts.nunito(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
