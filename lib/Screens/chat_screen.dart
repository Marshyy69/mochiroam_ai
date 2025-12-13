import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart'; // <-- THIS is where ChatUser is defined
// import 'package:flutter_chat_types/flutter_chat_types.dart' as types; // <-- REMOVE this line if you still have it, as it defines a conflicting type.
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
 final ChatUser _currentUser = ChatUser(id: "user-1", firstName: "You");
// AND REMOVE 'const' HERE
final ChatUser _aiUser = ChatUser(id: "ai-1", firstName: "Mochi AI");

  // --- REMOVED: The ChatController is no longer needed/defined in the latest DashChat ---
  // final ChatController _chatController = ChatController(); 
  

  @override
  void initState() {
    super.initState();
    // For demonstration, adding a starting AI message
    _messages.insert(0, ChatMessage(
      user: _aiUser,
      text: "Hello! I am Mochi AI. How can I help you today?",
      createdAt: DateTime.now(),
    ));
  }

  /// -------------------------------------------------------------
  /// When user sends a message
  /// -------------------------------------------------------------
  void _handleSendPressed(ChatMessage message) {
    setState(() {
      _messages.insert(0, message);
    });
    _simulateAIResponse(message.text);
    // You would call your save function here: _saveMessages();
  }
  
  /// Simulate an AI response
  void _simulateAIResponse(String userText) {
    final responseText = "Thanks for your message: '$userText'. I'm processing your request now!";
    
    final aiMessage = ChatMessage(
      user: _aiUser,
      text: responseText,
      createdAt: DateTime.now().add(const Duration(milliseconds: 500)),
    );
    
    setState(() {
      _messages.insert(0, aiMessage);
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ask Mochi AI (Dash Chat 2)"),
      ),
      body: DashChat(
        currentUser: _currentUser, 
        onSend: _handleSendPressed, 
        messages: _messages, 
        
        // --- REMOVED: chatController is no longer defined ---
        // chatController: _chatController, 
        
        messageOptions: const MessageOptions(
          showCurrentUserAvatar: true,
          // --- FIX 2: Renamed from showOtherUserAvatar (singular) to showOtherUsersAvatar (plural) ---
          showOtherUsersAvatar: false,
        ),
      ),
    );
  }
}