import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../services/gemini_service.dart';
import '../services/preferences_service.dart';
import '../services/photo_service.dart';
import '../services/itinerary_service.dart';
import '../models/travel_preferences.dart';
import '../models/itinerary_model.dart';
import 'trip_details_screen.dart'; // Import this to navigate!

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ItineraryService _itineraryService = ItineraryService();
  
  final ChatUser _currentUser = ChatUser(
    id: FirebaseAuth.instance.currentUser?.uid ?? 'user',
    firstName: 'You',
  );
  
  final ChatUser _aiUser = ChatUser(
    id: 'mochi_ai',
    firstName: 'Mochi',
    profileImage: 'assets/icons/dumpling.png', 
  );

  List<ChatMessage> _messages = [];
  List<ChatUser> _typingUsers = [];

  @override
  void initState() {
    super.initState();
    _addSystemMessage("Hi! I'm Mochi. Where do you want to go today? ✈️🍡");
  }

  void _addSystemMessage(String text, {Map<String, dynamic>? customProperties}) {
    setState(() {
      _messages.insert(0, ChatMessage(
        text: text,
        user: _aiUser,
        createdAt: DateTime.now(),
        customProperties: customProperties, // ✅ We use this to pass Trip Data to the bubble
      ));
    });
  }

  Future<void> _onSend(ChatMessage message) async {
    setState(() {
      _messages.insert(0, message);
      _typingUsers.add(_aiUser);
    });

    try {
      TravelPreferences prefs = await PreferencesService.fetch();
      
     final response = await GeminiService.sendMessage(
  userMessage: message.text,
  prefs: prefs,
  rules: "", 
  previousMessages: _messages,
);

      if (response.containsKey('trip_name')) {
        await _handleItineraryGeneration(response);
      } else {
        final String text = response['content'] ?? "I'm having trouble thinking right now.";
        _addSystemMessage(text);
      }

    } catch (e) {
      _addSystemMessage("Error: $e");
    } finally {
      setState(() {
        _typingUsers.remove(_aiUser);
      });
    }
  }

  Future<void> _handleItineraryGeneration(Map<String, dynamic> data) async {
    try {
      _addSystemMessage("Ooo! Let me plan that for you... ✍️");

      String city = data['country'] ?? data['trip_name'] ?? 'Travel';
      String imageUrl = await PhotoService.getCityImage(city);
      
      String cleanUrl = "";
      if (imageUrl.contains("](") && imageUrl.contains(")")) {
         int start = imageUrl.indexOf("](") + 2;
         int end = imageUrl.indexOf(")", start);
         cleanUrl = imageUrl.substring(start, end);
      }

      ItineraryModel newTrip = ItineraryModel(
        userId: _currentUser.id,
        tripName: data['trip_name'] ?? "Unknown Trip",
        country: data['country'] ?? "Unknown",
        duration: data['duration'] ?? "N/A",
        summary: data['full_content'] ?? "No summary provided",
        coverImage: cleanUrl.isNotEmpty ? cleanUrl : "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1", 
        tags: List<String>.from(data['tags'] ?? []),
        isHalal: data['is_halal'] ?? false,
        days: (data['trip_data'] != null && data['trip_data']['days'] != null)
            ? (data['trip_data']['days'] as List).map((d) => DaySchedule.fromMap(d)).toList()
            : (data['days'] as List? ?? []).map((d) => DaySchedule.fromMap(d)).toList(), // ✅ FIX: Check both spots
        createdAt: DateTime.now(),
        status: 'upcoming',
      );

      // Save to Firebase
      await _itineraryService.saveTrip(newTrip);

      // ✅ SHOW THE TRIP CARD IN CHAT
      _addSystemMessage(
        "I've planned your trip to ${newTrip.tripName}! 🎉",
        customProperties: {
          'isTrip': true,
          'tripData': newTrip, // Pass the whole object to the UI
        }
      );
      
    } catch (e) {
      print("Error saving trip: $e");
      _addSystemMessage("I planned it, but couldn't save it. ($e)");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Chat with Mochi"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: DashChat(
        currentUser: _currentUser,
        onSend: _onSend,
        messages: _messages,
        typingUsers: _typingUsers,
        messageOptions: MessageOptions(
          showOtherUsersAvatar: true,
          showCurrentUserAvatar: false,
          avatarBuilder: (user, onPress, onLongPress) {
            if (user.id == 'mochi_ai') {
               return Padding(
                 padding: const EdgeInsets.only(right: 8.0),
                 child: CircleAvatar(
                   backgroundColor: Colors.pink.shade50,
                   backgroundImage: const AssetImage('assets/icons/dumpling.png'),
                 ),
               );
            }
            return const SizedBox.shrink();
          },
          messageDecorationBuilder: (msg, prev, next) {
             final isUser = msg.user.id == _currentUser.id;
             // If it's a Trip Card, transparent background
             if (msg.customProperties != null && msg.customProperties!['isTrip'] == true) {
               return const BoxDecoration(color: Colors.transparent);
             }
             return BoxDecoration(
               color: isUser ? Colors.pink.shade100 : Colors.grey.shade100,
               borderRadius: BorderRadius.circular(18),
             );
          },
          // ✅ CUSTOM MESSAGE BUILDER
          messageTextBuilder: (message, previousMessage, nextMessage) {
             // 1. Check if this is a Trip Card
             if (message.customProperties != null && message.customProperties!['isTrip'] == true) {
               final ItineraryModel trip = message.customProperties!['tripData'];
               
               return Container(
                 width: 250,
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: Colors.white,
                   borderRadius: BorderRadius.circular(16),
                   border: Border.all(color: Colors.pink.shade100),
                   boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                 ),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     // Image Header
                     ClipRRect(
                       borderRadius: BorderRadius.circular(12),
                       child: Image.network(
                         trip.coverImage.isNotEmpty ? trip.coverImage : "https://via.placeholder.com/150", 
                         height: 100, width: double.infinity, fit: BoxFit.cover
                       ),
                     ),
                     const SizedBox(height: 10),
                     Text("Trip to ${trip.tripName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                     Text("${trip.duration} • ${trip.tags.firstOrNull ?? 'Fun'}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                     const SizedBox(height: 10),
                     SizedBox(
                       width: double.infinity,
                       child: ElevatedButton(
                         style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                         onPressed: () {
                           // ✅ NAVIGATE TO DETAILS
                           Navigator.push(
                             context, 
                             MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip))
                           );
                         },
                         child: const Text("View Itinerary ➔", style: TextStyle(color: Colors.white)),
                       ),
                     )
                   ],
                 ),
               );
             }

             // 2. Normal Message
             final isUser = message.user.id == _currentUser.id;
             return MarkdownBody(
               data: message.text,
               styleSheet: MarkdownStyleSheet(
                 p: TextStyle(color: isUser ? Colors.black87 : Colors.black87, fontSize: 16),
               ),
             );
          },
        ),
        inputOptions: InputOptions(
          inputDecoration: InputDecoration(
            hintText: "Ask me to plan a trip...",
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          sendButtonBuilder: (onSend) => IconButton(
            icon: const Icon(Icons.send_rounded, color: Colors.pinkAccent),
            onPressed: onSend,
          ),
        ),
      ),
    );
  }
}