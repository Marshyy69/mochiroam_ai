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

  Future<void> _saveTripToFirestore(Map<String, dynamic> tripData) async {
    try {
      // 1. Extract Metadata for Filtering
      String country = tripData['country'] ?? "Uncategorized";
      String continent = tripData['continent'] ?? "Other";
      List<dynamic> tags = tripData['tags'] ?? [];

      // 2. Add 'Halal' tag if user is Muslim (Auto-tagging)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser.id).get();
      if (userDoc.exists && (userDoc.data()?['is_halal'] ?? false)) {
        if (!tags.contains('Halal')) tags.add('Halal');
      }

      // 3. Save the FULL JSON object to 'trip_data'
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.id)
          .collection('itineraries')
          .add({
        'trip_name': tripData['trip_name'] ?? "New Trip",
        'duration': tripData['duration'] ?? "Unknown",
        'country': country,
        'continent': continent,
        'tags': tags,
        // ✅ CRITICAL: We save the structured JSON here
        'trip_data': tripData, 
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
    setState(() {
      _messages.insert(0, message);
      _typingUsers.add(_aiUser);
    });

    try {
      // 1. Fetch User Preferences
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser.id).get();
      final data = userDoc.data() ?? {};
      
      final dynamicPrefs = TravelPreferences(
        pax: data['pax'] ?? 2,
        hasChildren: data['hasChildren'] ?? false,
        childrenCount: data['childrenCount'] ?? 0,
        childrenAgeRange: data['childrenAgeRange'] ?? "",
        hasElderly: data['hasElderly'] ?? false,
        isHalal: data['is_halal'] ?? false,
        tripVibe: List<String>.from(data['tripVibe'] ?? ["Balanced"]), 
        budget: data['budget'] ?? "Standard", 
        accommodation: data['accommodation'] ?? "Hotel",
      );

      // 2. Call OpenAI
      final response = await OpenAIService.sendMessage(
        userMessage: message.text,
        prefs: dynamicPrefs,
        rules: dynamicPrefs.toPromptString(),
        previousMessages: _messages.length > 1 ? _messages.sublist(1) : [],
      );

      bool isItinerary = response['is_itinerary'] ?? false;
      String displayText = "";

      // ✅ 3. Construct the Chat Bubble Text (UPDATED)
      if (isItinerary) {
        String tripName = response['trip_name'] ?? "Trip";
        String summary = response['summary'] ?? "";
        List<dynamic> days = response['days'] ?? [];

        // Build a readable text version for the Chat Bubble
        StringBuffer buffer = StringBuffer();
        buffer.writeln("## 🗺️ $tripName");
        if (summary.isNotEmpty) buffer.writeln("\n_${summary}_\n");

        for (var day in days) {
          buffer.writeln("\n**Day ${day['day']}: ${day['theme']}**");
          for (var activity in day['activities']) {
            String time = activity['time'] ?? "";
            String title = activity['title'] ?? "";
            String desc = activity['desc'] ?? "";
            
            // Add emoji based on time
            String emoji = "📍";
            if (time.contains("Morning")) emoji = "☀️";
            if (time.contains("Afternoon")) emoji = "🌤️";
            if (time.contains("Evening") || time.contains("Night")) emoji = "🌙";
            
            buffer.writeln("- $emoji **$time**: $title");
            // Optional: Show description in chat too if you want detailed text
            // buffer.writeln("  _$desc_"); 
          }
        }
        
        displayText = buffer.toString();
        
      } else {
        // Normal chat response
        displayText = response['content'] ?? "I'm listening...";
      }

      setState(() {
        _typingUsers.remove(_aiUser);
      });

      // 4. Photo Animation
      if (isItinerary) {
        setState(() => _typingUsers.add(_aiUser));
        String tripName = response['trip_name'] ?? "";
        String imageMarkdown = await PhotoService.getCityImage(tripName);
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
           setState(() {
            _typingUsers.remove(_aiUser);
            if (imageMarkdown.isNotEmpty) {
              _messages.insert(0, ChatMessage(
                text: imageMarkdown,
                user: _aiUser,
                createdAt: DateTime.now(),
              ));
            }
          });
        }
      }

      // 5. Insert the AI Message
      setState(() => _typingUsers.add(_aiUser));
      await Future.delayed(const Duration(milliseconds: 1000));

      final botMessage = ChatMessage(
        text: displayText,
        user: _aiUser,
        createdAt: DateTime.now(),
        // Store the JSON so the Save Button still works!
        customProperties: isItinerary ? {
          'is_itinerary': true,
          'trip_data': response, 
        } : null,
      );

      if (mounted) {
        setState(() {
          _typingUsers.remove(_aiUser);
          _messages.insert(0, botMessage);
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
              return Padding(
                padding: const EdgeInsets.all(4),
                child: Text(message.text, style: const TextStyle(color: Colors.black87)),
              );
            }

            final bool isPlan = message.customProperties?['is_itinerary'] == true;
            final tripData = message.customProperties?['trip_data'];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: MarkdownBody(
                    data: message.text,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(fontSize: 16, color: Colors.black87),
                      h2: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pink.shade600),
                      strong: TextStyle(fontWeight: FontWeight.w800, color: Colors.pink.shade600),
                    ),
                  ),
                ),
                if (isPlan && tripData != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 5),
                    child: ElevatedButton.icon(
                      // ✅ Pass the Map, not string
                      onPressed: () => _saveTripToFirestore(tripData),
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