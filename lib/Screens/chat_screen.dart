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
  final OpenAIService _openAIService = OpenAIService(); // Ensure you have this service instantiated
  
  // 🤖 AI User (Static)
  final ChatUser _aiUser = ChatUser(
    id: 'mochi_ai',
    firstName: 'Mochi AI',
    profileImage: 'assets/icons/dumpling.png', // We'll handle this in builder too
  );

  List<ChatMessage> _messages = [];
  List<ChatUser> _typingUsers = [];

  @override
  void initState() {
    super.initState();
    // Initial Greeting
    _messages.add(
      ChatMessage(
        text: "Hi! I'm Mochi. Where do you want to go today? ✈️🍡",
        user: _aiUser,
        createdAt: DateTime.now(),
      ),
    );

    // Check for arguments (prompts from Home Screen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is String) {
        _handleInitialPrompt(args);
      }
    });
  }

  // Handle prompt passed from Home Screen
  void _handleInitialPrompt(String prompt) {
    final user = FirebaseAuth.instance.currentUser;
    // Temporary user for immediate display (will be updated by stream)
    ChatUser me = ChatUser(id: user?.uid ?? 'user', firstName: user?.displayName ?? 'Traveler');
    
    ChatMessage message = ChatMessage(
      text: prompt,
      user: me,
      createdAt: DateTime.now(),
    );
    _handleMessage(message);
  }

  // ... [Keep your existing _saveTripToFirestore function here] ...
  Future<void> _saveTripToFirestore(Map<String, dynamic> tripData) async {
    // (Paste your existing save logic here to keep the file clean)
    // For brevity, I'm assuming you kept the logic from your previous code.
     try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String country = tripData['country'] ?? "Uncategorized";
      String continent = tripData['continent'] ?? "Other";
      List<dynamic> tags = tripData['tags'] ?? [];

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('itineraries')
          .add({
        'trip_name': tripData['trip_name'] ?? "New Trip",
        'duration': tripData['duration'] ?? "Unknown",
        'country': country,
        'continent': continent,
        'tags': tags,
        'trip_data': tripData, 
        'created_at': FieldValue.serverTimestamp(),
        'status': 'upcoming', // Default status
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
      _typingUsers.add(_aiUser); // 1. Add typing indicator
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Fetch User Preferences
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
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

      if (isItinerary) {
        // Build Itinerary Text
        String tripName = response['trip_name'] ?? "Trip";
        String summary = response['summary'] ?? "";
        List<dynamic> days = response['days'] ?? [];

        StringBuffer buffer = StringBuffer();
        buffer.writeln("## 🗺️ $tripName");
        if (summary.isNotEmpty) buffer.writeln("\n_${summary}_\n");

        for (var day in days) {
          buffer.writeln("\n**Day ${day['day']}: ${day['theme']}**");
          for (var activity in day['activities']) {
             String time = activity['time'] ?? "";
             String title = activity['title'] ?? "";
             String emoji = "📍";
             if (time.contains("Morning")) emoji = "☀️";
             if (time.contains("Afternoon")) emoji = "🌤️";
             if (time.contains("Evening") || time.contains("Night")) emoji = "🌙";
             buffer.writeln("- $emoji **$time**: $title");
          }
        }
        displayText = buffer.toString();
      } else {
        displayText = response['content'] ?? "I'm listening...";
      }

      // Remove typing indicator from Step 1
      setState(() => _typingUsers.remove(_aiUser));

      // 3. Photo Animation (Only if Itinerary)
      if (isItinerary) {
        setState(() => _typingUsers.add(_aiUser)); // Add again for photo
        String tripName = response['trip_name'] ?? "";
        String imageMarkdown = await PhotoService.getCityImage(tripName);
        
        if (mounted) {
           setState(() {
            _typingUsers.remove(_aiUser); // ✅ FIX: Remove immediately after photo loads
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

      // 4. Add Text Response
      setState(() => _typingUsers.add(_aiUser)); // Add again for text
      await Future.delayed(const Duration(milliseconds: 500)); 

      final botMessage = ChatMessage(
        text: displayText,
        user: _aiUser,
        createdAt: DateTime.now(),
        customProperties: isItinerary ? {
          'is_itinerary': true,
          'trip_data': response, 
        } : null,
      );

      if (mounted) {
        setState(() {
          _typingUsers.remove(_aiUser); // Final remove
          _messages.insert(0, botMessage);
        });
      }

    } catch (e) {
      print("Error: $e");
      if (mounted) {
        setState(() {
          // Safety: Remove ALL instances of Mochi if error occurs
          _typingUsers.removeWhere((u) => u.id == _aiUser.id);
          _messages.insert(0, ChatMessage(text: "I couldn't connect. Please try again.", user: _aiUser, createdAt: DateTime.now()));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
      // 🔥 STREAM BUILDER: Listen to Real-time Profile Changes
      body: StreamBuilder<DocumentSnapshot>(
        stream: user != null 
            ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots() 
            : null,
        builder: (context, snapshot) {
          
          // 1. Get Live User Data
          String currentAvatar = "🍡"; // Default
          String currentName = "Traveler";

          if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            currentAvatar = data['avatar'] ?? "🍡";
            currentName = data['username'] ?? "Traveler";
          }

          // 2. Create "Me" User with Custom Properties for the Emoji
          ChatUser me = ChatUser(
            id: user?.uid ?? 'user',
            firstName: currentName,
            // We pass the emoji in customProperties so we can read it in the builder
            customProperties: {'avatar': currentAvatar}, 
          );

          return DashChat(
            currentUser: me,
            typingUsers: _typingUsers,
            messages: _messages,
            onSend: _handleMessage,
            
            // 🎨 3. CUSTOM AVATAR BUILDER
            messageOptions: MessageOptions(
              showOtherUsersAvatar: true,
              showCurrentUserAvatar: true, // Show YOUR avatar
              
              avatarBuilder: (ChatUser chatUser, onPress, onLongPress) {
                // A. IF IT IS MOCHI (The AI)
                if (chatUser.id == _aiUser.id) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Container(
                      width: 35, height: 35,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Image.asset('assets/icons/dumpling.png'),
                    ),
                  );
                }

                // B. IF IT IS YOU (The User)
                // Read the emoji from the customProperties we set earlier
                String emoji = chatUser.customProperties?['avatar'] ?? "🍡";
                
                return Padding(
                  padding: const EdgeInsets.only(left: 8.0), // Padding for right side
                  child: Container(
                    width: 38, height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.pink.shade50,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.pink.shade100, width: 1.5),
                    ),
                    child: Text(
                      emoji, 
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                );
              },

              // Message Bubble Styling
              messageTextBuilder: (message, previous, next) {
                final isUser = message.user.id == me.id;
                
                // Normal Text for User
                if (isUser) {
                  return Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(message.text, style: const TextStyle(color: Colors.black87)),
                  );
                }

                // Markdown for Mochi
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
                 final isUser = msg.user.id == me.id;
                 return BoxDecoration(
                   color: isUser ? Colors.pink.shade100 : Colors.white,
                   borderRadius: BorderRadius.circular(18),
                   border: isUser ? null : Border.all(color: Colors.grey.shade200),
                 );
              },
            ),

            // Input Field Styling
            inputOptions: InputOptions(
              inputDecoration: InputDecoration(
                hintText: "Ask me to plan a trip...",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              alwaysShowSend: true,
              sendButtonBuilder: (onSend) => IconButton(
                icon: const Icon(Icons.send, color: Colors.pinkAccent), 
                onPressed: onSend,
              ),
            ),
          );
        },
      ),
    );
  }
}