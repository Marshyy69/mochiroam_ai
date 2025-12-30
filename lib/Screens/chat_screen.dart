import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../services/preferences_service.dart';
import '../services/recommendation_rules.dart';
import '../services/openai_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final List<ChatMessage> _messages = [];

  final ChatUser _currentUser = ChatUser(id: "user-1", firstName: "You");
  final ChatUser _aiUser = ChatUser(id: "ai-1", firstName: "Mochi AI");

  bool _isTyping = false;
  late AnimationController _typingController;

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    // Check if a prompt was passed from Home Screen (e.g., "Plan a trip to Japan")
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        final initialMsg = ChatMessage(
          user: _currentUser,
          text: args,
          createdAt: DateTime.now(),
        );
        _handleSendPressed(initialMsg);
      } else {
        // Default greeting
        setState(() {
          _messages.insert(
            0,
            ChatMessage(
              user: _aiUser,
              text: "Hi! I’m Mochi AI 🍡\nTell me where you want to go!",
              createdAt: DateTime.now(),
            ),
          );
        });
      }
    });
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
      // 1. Fetch User Context
      final prefs = await PreferencesService.fetch();
      final rules = RecommendationRules.build(prefs);

      // 2. Call OpenAI Service
      final aiResponseMap = await OpenAIService.sendMessage(
        userMessage: userText,
        prefs: prefs,
        rules: rules,
      );

      final aiText = aiResponseMap['content'] ?? "Thinking...";
      final isItinerary = aiResponseMap['is_itinerary'] == true;

      // 3. If it's a valid itinerary, save it to Firebase!
      if (isItinerary) {
        await _saveItineraryToFirebase(aiResponseMap);
      }

      if (!mounted) return;

      setState(() {
        _isTyping = false;
        _messages.insert(
          0,
          ChatMessage(
            user: _aiUser,
            text: aiText,
            createdAt: DateTime.now(),
          ),
        );
      });

      // Show a little popup if saved
      if (isItinerary) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Trip saved to your Itineraries! ✈️✅"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.insert(
          0,
          ChatMessage(
            user: _aiUser,
            text: "⚠️ Oops, something went wrong: $e",
            createdAt: DateTime.now(),
          ),
        );
      });
    }
  }

  Future<void> _saveItineraryToFirebase(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('itineraries')
        .add({
      'trip_name': data['trip_name'] ?? 'New Trip',
      'duration': data['duration'] ?? 'TBD',
      'full_content': data['content'],
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pink.shade300,
        title: const Text("Ask Mochi AI", style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
                showOtherUsersAvatar: true,
                avatarBuilder: (user, onPress, onLongPress) {
                  if (user.id == _aiUser.id) {
                    return const CircleAvatar(
                      backgroundImage: AssetImage('assets/icons/dumpling.png'),
                    );
                  }
                  return const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, color: Colors.white),
                  );
                },

                // 🔥 NEW: THIS IS THE FIX FOR BOLD TEXT
                messageTextBuilder: (message, previous, next) {
                  final isUser = message.user.id == _currentUser.id;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: MarkdownBody(
                      data: message.text,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          fontSize: 16,
                          color: isUser ? Colors.black87 : Colors.black,
                        ),
                        // Make bold text PINK and thicker!
                        strong: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.pink.shade600, 
                        ),
                      ),
                    ),
                  );
                },

                messageDecorationBuilder: (msg, prev, next) {
                  final isUser = msg.user.id == _currentUser.id;
                  return BoxDecoration(
                    color: isUser ? Colors.pink.shade200 : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      const BoxShadow(color: Colors.black12, blurRadius: 4),
                    ],
                  );
                },
              ),
            ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                "Mochi is typing...",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }
}