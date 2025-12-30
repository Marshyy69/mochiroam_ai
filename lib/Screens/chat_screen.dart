import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

import '../services/preferences_service.dart';
import '../services/recommendation_rules.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final List<ChatMessage> _messages = [];

  final ChatUser _currentUser =
      ChatUser(id: "user-1", firstName: "You");

  final ChatUser _aiUser =
      ChatUser(id: "ai-1", firstName: "Mochi AI");

  bool _isTyping = false;

  late AnimationController _typingController;

  @override
  void initState() {
    super.initState();

    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _messages.insert(
      0,
      ChatMessage(
        user: _aiUser,
        text:
            "Hi! I’m Mochi AI 🍡✈️\nTell me where you want to go and I’ll plan your trip!",
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _typingController.dispose();
    super.dispose();
  }

  void _handleSendPressed(ChatMessage message) {
    setState(() {
      _messages.insert(0, message);
      _isTyping = true;
    });

    _getAIResponse(message.text);
  }

  Future<void> _getAIResponse(String userText) async {
    try {
      final prefs = await PreferencesService.fetch();
      final rules = RecommendationRules.build(prefs);

      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null) throw Exception("Missing API key");

      final response = await http.post(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {
              "role": "system",
              "content":
                  "You are Mochi AI, a friendly travel assistant that creates clear, realistic travel itineraries."
            },
            {
              "role": "user",
              "content": """
Preferences:
- Pax: ${prefs.pax}
- Children: ${prefs.hasChildren}
- Elderly: ${prefs.hasElderly}

Rules:
$rules

Request:
$userText
"""
            }
          ],
          "temperature": 0.7,
        }),
      );

      final data = jsonDecode(response.body);
      final aiText =
          data["choices"][0]["message"]["content"];

      if (!mounted) return;

      setState(() {
        _messages.insert(
          0,
          ChatMessage(
            user: _aiUser,
            text: aiText,
            createdAt: DateTime.now(),
          ),
        );
        _isTyping = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.insert(
          0,
          ChatMessage(
            user: _aiUser,
            text: "⚠️ Something went wrong. Please try again.",
            createdAt: DateTime.now(),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pink.shade300,
        leadingWidth: 90,
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              color: Colors.white,
              onPressed: () => Navigator.pop(context),
            ),
            const CircleAvatar(
              radius: 16,
              backgroundImage:
                  AssetImage('assets/icons/dumpling.png'),
              backgroundColor: Colors.transparent,
            ),
          ],
        ),
        title: const Text(
          "Ask Mochi AI",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: DashChat(
              currentUser: _currentUser,
              onSend: _handleSendPressed,
              messages: _messages,
            messageOptions: MessageOptions(
  showCurrentUserAvatar: true,
  showOtherUsersAvatar: true,

  messageDecorationBuilder:
      (ChatMessage msg, ChatMessage? prev, ChatMessage? next) {
    final isUser = msg.user.id == _currentUser.id;

    return BoxDecoration(
      color: isUser ? Colors.pink.shade200 : Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: isUser
          ? []
          : [
              const BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
              ),
            ],
    );
  },

  messageTimeBuilder: (ChatMessage msg, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        DateFormat('HH:mm').format(msg.createdAt),
        style: const TextStyle(
          fontSize: 10,
          color: Colors.grey,
        ),
      ),
    );
  },
),

              inputOptions: InputOptions(
                alwaysShowSend: true,
                inputDecoration: InputDecoration(
                  hintText: "Ask Mochi about your trip...",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          ),

          // 🍡 Mochi typing indicator
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 12),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundImage:
                        AssetImage('assets/icons/dumpling.png'),
                  ),
                  const SizedBox(width: 8),
                  AnimatedBuilder(
                    animation: _typingController,
                    builder: (_, __) {
                      final dots =
                          "." * ((_typingController.value * 3).floor() + 1);
                      return Text(
                        "Mochi AI is typing$dots",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
