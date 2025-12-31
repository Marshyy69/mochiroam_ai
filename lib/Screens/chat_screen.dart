import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/openai_service.dart';
import '../models/travel_preferences.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatUser _currentUser = ChatUser(
    id: FirebaseAuth.instance.currentUser?.uid ?? 'user',
    firstName: FirebaseAuth.instance.currentUser?.displayName ?? 'Traveler',
  );

  final ChatUser _aiUser = ChatUser(
    id: 'mochi_ai',
    firstName: 'Mochi AI',
    profileImage: 'assets/icons/dumpling.png', 
  );

  List<ChatMessage> _messages = [];
  List<ChatUser> _typingUsers = [];

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        text: "Hi! I'm Mochi. Where do you want to go today? ✈️🍡",
        user: _aiUser,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _handleMessage(ChatMessage message) async {
    setState(() {
      _messages.insert(0, message);
      _typingUsers.add(_aiUser);
    });

    try {
      // 1. Fetch Preferences from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.id)
          .get();

      final data = userDoc.data() ?? {};
      
      bool isHalalPref = data['is_halal'] ?? false;
      int storedPax = data['pax'] ?? 2;          
      bool hasChildren = data['has_children'] ?? false;
      bool hasElderly = data['has_elderly'] ?? false;

      // 2. Create Object (with isHalal inside)
      final dynamicPrefs = TravelPreferences(
        pax: storedPax,
        hasChildren: hasChildren,
        hasElderly: hasElderly,
        isHalal: isHalalPref, // ✅ Added here
      );

      // 3. Call Service (Cleaner call)
      final response = await OpenAIService.sendMessage(
        userMessage: message.text,
        prefs: dynamicPrefs,                
        rules: dynamicPrefs.toPromptString(), 
        // No need to pass isHalal separately anymore!
      );

      // 4. Handle Response
      String aiText = response['content'];
      bool isItinerary = response['is_itinerary'] ?? false;

      final botMessage = ChatMessage(
        text: aiText,
        user: _aiUser,
        createdAt: DateTime.now(),
      );

      setState(() {
        _messages.insert(0, botMessage);
      });

      if (isItinerary) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser.id)
            .collection('itineraries')
            .add({
          'trip_name': response['trip_name'] ?? "New Trip",
          'duration': response['duration'] ?? "Unknown",
          'full_content': aiText,
          'created_at': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Trip saved to yout Itineraries! 📝")),
          );
        }
      }

    } catch (e) {
      print("Error: $e");
      setState(() {
        _messages.insert(0, ChatMessage(
          text: "I couldn't connect. Please try again.",
          user: _aiUser,
          createdAt: DateTime.now(),
        ));
      });
    } finally {
      setState(() {
        _typingUsers.remove(_aiUser);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // title: const Text("Chat with Mochi", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.pink.shade300,
        title: const Text("Ask Mochi AI", style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: DashChat(
        currentUser: _currentUser,
        typingUsers: _typingUsers,
        messages: _messages,
        onSend: _handleMessage,
        inputOptions: InputOptions(
          inputDecoration: InputDecoration(
            hintText: "Ask me to plan a trip...",
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          alwaysShowSend: true,
        ),
        messageOptions: MessageOptions(
          showOtherUsersAvatar: true,
          avatarBuilder: (user, onPress, onLongPress) {
            if (user.id == _aiUser.id) {
              return const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: CircleAvatar(
                  backgroundImage: AssetImage('assets/icons/dumpling.png'),
                  backgroundColor: Colors.pinkAccent,
                ),
              );
            }
            return const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white)),
            );
          },
          messageTextBuilder: (message, previous, next) {
            if (message.user.id == _currentUser.id) {
              return Padding(padding: const EdgeInsets.all(4), child: Text(message.text));
            }
            return Padding(
              padding: const EdgeInsets.all(4),
              child: MarkdownBody(
                data: message.text,
                styleSheet: MarkdownStyleSheet(
                  strong: TextStyle(fontWeight: FontWeight.w800, color: Colors.pink.shade600),
                  listBullet: TextStyle(color: Colors.pink.shade400),
                ),
              ),
            );
          },
          messageDecorationBuilder: (msg, prev, next) {
             final isUser = msg.user.id == _currentUser.id;
             return BoxDecoration(
               color: isUser ? Colors.pink.shade100 : Colors.white,
               borderRadius: BorderRadius.circular(18),
               border: isUser ? null : Border.all(color: Colors.grey.shade200),
             );
          },
        ),
      ),
    );
  }
}