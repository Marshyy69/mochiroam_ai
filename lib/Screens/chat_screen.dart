import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';

import '../services/preferences_service.dart';
import '../services/recommendation_rules.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];

  final ChatUser _currentUser = ChatUser(id: "user-1", firstName: "You");

  final ChatUser _aiUser = ChatUser(id: "ai-1", firstName: "Mochi AI");

  @override
  void initState() {
    super.initState();

    // Starting message
    _messages.insert(
      0,
      ChatMessage(
        user: _aiUser,
        text: "Hello! I am Mochi AI. How can I help you today?",
        createdAt: DateTime.now(),
      ),
    );
  }

  /// When user sends a message
  void _handleSendPressed(ChatMessage message) {
    setState(() {
      _messages.insert(0, message);
    });

    _simulateAIResponse(message.text);
  }

  /// Personalised AI response using saved preferences (Option A)
  Future<void> _simulateAIResponse(String userText) async {
    // 1) Load prefs from Firestore (with fallback defaults)
    final prefs = await PreferencesService.fetch();

    // 2) Build rule guidance
    final rules = RecommendationRules.build(prefs);

    // 3) Build response (rule-based “AI”)
    final responseText = """
Here’s a personalised suggestion for your trip 👇

✅ Your travel preferences:
• Pax: ${prefs.pax}
• Children: ${prefs.hasChildren ? "Yes" : "No"}
• Elderly: ${prefs.hasElderly ? "Yes" : "No"}

🧠 I will plan based on:
$rules

✍️ Your request:
"$userText"

Tell me:
1) Destination
2) Days
3) Budget (Low/Medium/High)
""";

    final aiMessage = ChatMessage(
      user: _aiUser,
      text: responseText,
      createdAt: DateTime.now().add(const Duration(milliseconds: 400)),
    );

    if (!mounted) return;
    setState(() {
      _messages.insert(0, aiMessage);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ask Mochi AI")),
      body: DashChat(
        currentUser: _currentUser,
        onSend: _handleSendPressed,
        messages: _messages,
        messageOptions: const MessageOptions(
          showCurrentUserAvatar: true,
          showOtherUsersAvatar: false,
        ),
      ),
    );
  }
}
