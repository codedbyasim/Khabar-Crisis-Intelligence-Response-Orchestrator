import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:khabar/api_config.dart';
import 'package:khabar/theme/app_colors.dart';
import 'package:khabar/theme/language_provider.dart';
import 'package:khabar/utils/connectivity_service.dart';
import 'package:khabar/utils/local_llm_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isOffline;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isOffline = false,
  });
}

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isSending = false;

  String _getWelcomeMessage() {
    final String currentLang = LanguageProvider().language;
    if (currentLang == 'اردو') {
      return "السلام علیکم! میں خبر چیٹ بوٹ ہوں، آپ کا مددگار بحرانی معاون۔ میں آپ کو اسلام آباد اور راولپنڈی میں سیلاب، بارش، آگ اور دیگر حادثات کی معلومات اور حفاظتی رہنما خطوط فراہم کر سکتا ہوں۔ میں آپ کی کیا مدد کروں؟";
    } else if (currentLang == 'Roman Urdu') {
      return "Assalam-o-Alaikum! Main Khabar Chatbot hoon, aapka dynamic crisis assistant. Main aapko Islamabad aur Rawalpindi mein live incidents, weather updates aur emergency guidelines faraham kar sakta hoon. Main aapki kya madad karoon?";
    } else {
      return "Hello! I am Khabar Chatbot, your crisis intelligence assistant. I can provide real-time incident reports, weather updates, and emergency safety guidelines for Islamabad and Rawalpindi. How can I help you today?";
    }
  }

  List<String> _getSuggestedPrompts() {
    final String currentLang = LanguageProvider().language;
    if (currentLang == 'اردو') {
      return [
        "سیلاب سے بچاؤ کی تدابیر بتائیں؟",
        "واسا کی ٹیم کب تک پہنچے گی؟",
        "اسلام آباد کے ہنگامی نمبرز؟",
        "راولپنڈی کے موسم کی اپ ڈیٹ؟"
      ];
    } else if (currentLang == 'Roman Urdu') {
      return [
        "Flood safety tips batayein?",
        "WASA dewatering team kab tak pahuchegi?",
        "Islamabad key emergency numbers?",
        "Rawalpindi weather update?"
      ];
    } else {
      return [
        "What are the flood safety tips?",
        "When will WASA response team arrive?",
        "Emergency contact numbers for Islamabad?",
        "Weather update for Rawalpindi?"
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    // Welcome message
    _messages.add(ChatMessage(
      text: _getWelcomeMessage(),
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }


  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isSending = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // ── Check Connectivity for Offline Mode ──
    bool isOnline = ConnectivityService().value;
    if (!isOnline) {
      try {
        final localReply = await LocalLlmService().getOfflineResponse(
          text,
          LanguageProvider().language,
          LanguageProvider().region,
        );
        if (mounted) {
          setState(() {
            _messages.add(ChatMessage(
              text: localReply,
              isUser: false,
              timestamp: DateTime.now(),
              isOffline: true,
            ));
          });
        }
      } catch (e) {
        _showError("Offline model error: ${e.toString()}");
      } finally {
        if (mounted) {
          setState(() {
            _isSending = false;
          });
        }
        _scrollToBottom();
      }
      return;
    }

    try {
      // Build history for conversational memory
      final history = _messages
          .where((m) => m.text != _messages.first.text) // Skip welcome
          .map((m) => {
                "role": m.isUser ? "user" : "model",
                "content": m.text,
              })
          .toList();

      // We remove the last added message from history since we send it separately as current query
      if (history.isNotEmpty) {
        history.removeLast();
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chat'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "message": text,
          "history": history,
          "language": LanguageProvider().language,
          "user_location": LanguageProvider().region,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _messages.add(ChatMessage(
              text: data['response'],
              isUser: false,
              timestamp: DateTime.now(),
              isOffline: false,
            ));
          });
        } else {
          _showError(data['response'] ?? "Error connecting to AI.");
        }
      } else {
        _showError("Server connected but failed with status: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Connection failed. Please ensure the backend is running.");
    } finally {
      setState(() {
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  void _showError(String err) {
    setState(() {
      _messages.add(ChatMessage(
        text: "⚠️ Sorry, main connection nahi bana saka. Error: $err. Please check if api_server.py is running on http://127.0.0.1:8000.",
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: kPrimaryTeal.withValues(alpha: 0.15),
              child: const Icon(Icons.psychology, color: kPrimaryTeal),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Khabar Chatbot",
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "Islamabad & Rawalpindi Expert",
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: kTextDark,
      ),
      body: Container(
        color: kBackgroundLight,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildChatBubble(msg);
                },
              ),
            ),
            if (_messages.length <= 1) _buildSuggestedPromptsSection(),
            if (_isSending)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(kPrimaryTeal),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      LanguageProvider().language == 'اردو'
                          ? "چیٹ بوٹ سوچ رہا ہے..."
                          : LanguageProvider().language == 'Roman Urdu'
                              ? "Khabar Chatbot soch raha hai..."
                              : "Khabar Chatbot is thinking...",
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: kTextLight,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: msg.isUser ? kPrimaryTeal : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: msg.isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: msg.isUser ? Radius.zero : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: GoogleFonts.nunito(
                color: msg.isUser ? Colors.white : kTextDark,
                fontSize: 14.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!msg.isUser && msg.isOffline)
                  Row(
                    children: [
                      const Icon(Icons.offline_bolt_outlined, color: Colors.orange, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        "Local AI Mode",
                        style: GoogleFonts.nunito(
                          color: Colors.orange.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox.shrink(),
                Text(
                  "${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}",
                  style: GoogleFonts.nunito(
                    color: msg.isUser ? Colors.white70 : kTextLight,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedPromptsSection() {
    final prompts = _getSuggestedPrompts();
    return Container(
      height: 45,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: prompts.length,
        itemBuilder: (context, index) {
          final prompt = prompts[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                prompt,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: kPrimaryTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: kPrimaryTeal.withValues(alpha: 0.08),
              side: const BorderSide(color: Colors.transparent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () => _sendMessage(prompt),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    final String currentLang = LanguageProvider().language;
    String hintText = "Type message in English...";
    if (currentLang == 'اردو') {
      hintText = "اپنا پیغام یہاں لکھیں...";
    } else if (currentLang == 'Roman Urdu') {
      hintText = "Message Roman Urdu ya English mein likhein...";
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: GoogleFonts.nunito(fontSize: 14, color: kTextLight),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    fillColor: kBackgroundLight,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (val) => _sendMessage(val),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: kPrimaryTeal,
                radius: 22,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: () => _sendMessage(_messageController.text),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
