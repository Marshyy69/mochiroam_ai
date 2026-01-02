import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/photo_service.dart';
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

  Future<void> _saveTripToFirestore(Map<String, dynamic> tripData, String fullContent) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.id)
          .collection('itineraries')
          .add({
        'trip_name': tripData['trip_name'] ?? "New Trip",
        'duration': tripData['duration'] ?? "Unknown",
        'full_content': fullContent,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Trip saved successfully! 📝✅")),
        );
      }
    } catch (e) {
      print("Error saving trip: $e");
    }
  }

Future<void> _handleMessage(ChatMessage message) async {
    // 1. Show User Message
    setState(() {
      _messages.insert(0, message);
      _typingUsers.add(_aiUser); // Start Mochi typing...
    });

    try {
      // 2. Fetch Data & Preferences
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.id)
          .get();
      final data = userDoc.data() ?? {};
      
      final dynamicPrefs = TravelPreferences(
        pax: data['pax'] ?? 2,
        hasChildren: data['has_children'] ?? false,
        hasElderly: data['has_elderly'] ?? false,
        isHalal: data['is_halal'] ?? false,
      );

      // 3. Call OpenAI
      final response = await OpenAIService.sendMessage(
        userMessage: message.text,
        prefs: dynamicPrefs,                
        rules: dynamicPrefs.toPromptString(), 
        previousMessages: _messages.length > 1 ? _messages.sublist(1) : [],
      );

      String aiText = response['content'];
      bool isItinerary = response['is_itinerary'] ?? false;
      String tripName = response['trip_name'] ?? "";

      // 4. Cleanup & Safety
      if (isItinerary) {
        aiText = aiText.replaceAll("• ", "\n\n• ").replaceAll(" - ", "\n- ");
      }
      if (!isItinerary && aiText.contains('{') && aiText.contains('}')) {
        aiText = "Oops! I got a bit confused writing that plan. 😵‍💫\nCould you ask me again?";
      }

      // 5. Remove initial typing indicator
      setState(() {
        _typingUsers.remove(_aiUser);
      });

      // ---------------------------------------------------------
      // 🌊 ANIMATION LOGIC
      // ---------------------------------------------------------

      // PART A: The Photo (First Bubble)
      if (isItinerary && tripName.isNotEmpty) {
        setState(() => _typingUsers.add(_aiUser)); // Typing...
        
        String imageMarkdown = await PhotoService.getCityImage(tripName);
        
        // Wait a tiny bit for effect
        await Future.delayed(const Duration(milliseconds: 500)); 

        if (mounted) {
          setState(() {
            _typingUsers.remove(_aiUser); 
            _messages.insert(0, ChatMessage(
              text: imageMarkdown, 
              user: _aiUser,
              createdAt: DateTime.now(),
            ));
          });
        }
      }

      // PART B: The Text Plan (Second Bubble)
      // We simulate typing time BEFORE inserting the message
      setState(() => _typingUsers.add(_aiUser)); 
      await Future.delayed(const Duration(milliseconds: 1500)); // Wait 1.5s
      
      // Create the ONE and ONLY text message
      final botMessage = ChatMessage(
        text: aiText,
        user: _aiUser,
        createdAt: DateTime.now(),
        // ✅ Attach the Trip Data for the Save Button
        customProperties: isItinerary ? {
          'is_itinerary': true,
          'trip_data': response, 
        } : null,
      );

      if (mounted) {
        setState(() {
          _typingUsers.remove(_aiUser); // Stop typing
          _messages.insert(0, botMessage); // ✅ INSERT ONCE
        });
      }

    } catch (e) {
      print("Error: $e");
      if (mounted) {
        setState(() {
          _typingUsers.remove(_aiUser);
          _messages.insert(0, ChatMessage(
            text: "I couldn't connect. Please try again.",
            user: _aiUser,
            createdAt: DateTime.now(),
          ));
        });
      }
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
            // 1. If it's the User, just show plain text
            if (message.user.id == _currentUser.id) {
              return Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  message.text,
                  style: const TextStyle(color: Colors.black87),
                ),
              );
            }

            // 2. If it's Mochi (AI), check for trip data
            final bool isPlan = message.customProperties?['is_itinerary'] == true;
            final tripData = message.customProperties?['trip_data'];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A. The Markdown Text
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: MarkdownBody(
                    data: message.text,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(fontSize: 16, color: Colors.black87),
                      strong: TextStyle(fontWeight: FontWeight.w800, color: Colors.pink.shade600),
                      listBullet: TextStyle(color: Colors.pink.shade400),
                    ),
                  ),
                ),

                // B. The Save Button 
                if (isPlan && tripData != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 5),
                    child: ElevatedButton.icon(
                      onPressed: () => _saveTripToFirestore(tripData, message.text),
                      icon: const Icon(Icons.bookmark_add, color: Colors.white, size: 18),
                      label: const Text("Save Itinerary", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ),
              ],
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