import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../services/preferences_service.dart';
import '../services/recommendation_rules.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];

  final ChatUser _currentUser =
      ChatUser(id: "user-1", firstName: "You");

  final ChatUser _aiUser =
      ChatUser(id: "ai-1", firstName: "Mochi AI");

  bool _isTyping = false;

  @override
  void initState() {
    super.initState();

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

  /// When user sends message
  void _handleSendPressed(ChatMessage message) {
    setState(() {
      _messages.insert(0, message);
      _isTyping = true;
    });

    _getAIResponse(message.text);
  }

  /// Call OpenAI API
  Future<void> _getAIResponse(String userText) async {
    try {
      final prefs = await PreferencesService.fetch();
      final rules = RecommendationRules.build(prefs);

      final apiKey = dotenv.env['OPENAI_API_KEY'];

      if (apiKey == null) {
        throw Exception("OpenAI API key not found in .env");
      }

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
User travel preferences:
- Pax: ${prefs.pax}
- Children: ${prefs.hasChildren ? "Yes" : "No"}
- Elderly: ${prefs.hasElderly ? "Yes" : "No"}

Planning rules:
$rules

User request:
$userText

Generate a detailed travel itinerary with:
• Daily schedule
• Activities
• Food suggestions
• Transport tips
• Budget-friendly advice
"""
            }
          ],
          "temperature": 0.7,
        }),
      );

      final data = jsonDecode(response.body);

      final aiText =
          data["choices"][0]["message"]["content"];

      final aiMessage = ChatMessage(
        user: _aiUser,
        text: aiText,
        createdAt: DateTime.now(),
      );

      if (!mounted) return;

      setState(() {
        _messages.insert(0, aiMessage);
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
            text:
                "⚠️ Sorry, I ran into an issue. Please try again.\n\n$e",
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
        title: const Text("Ask Mochi AI"),
        backgroundColor: Colors.pink.shade300,
      ),
      body: DashChat(
        currentUser: _currentUser,
        onSend: _handleSendPressed,
        messages: _messages,
        typingUsers: _isTyping ? [_aiUser] : [],
        messageOptions: const MessageOptions(
          showCurrentUserAvatar: true,
          showOtherUsersAvatar: false,
        ),
        inputOptions: InputOptions(
          alwaysShowSend: true,
          inputDecoration: const InputDecoration(
            hintText: "Ask Mochi about your trip...",
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
