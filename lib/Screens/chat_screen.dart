import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../services/gemini_service.dart';
import '../services/preferences_service.dart';
import '../services/photo_service.dart';
import '../services/itinerary_service.dart';
import '../models/travel_preferences.dart';
import '../models/itinerary_model.dart';
import 'trip_details_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ItineraryService _itineraryService = ItineraryService();

  final ChatUser _currentUser = ChatUser(
    id: Supabase.instance.client.auth.currentUser?.id ?? 'user',
    firstName: 'You',
  );

  final ChatUser _aiUser = ChatUser(
    id: 'mochi_ai',
    firstName: 'Mochi',
    profileImage: 'assets/icons/dumpling.png',
  );

  final List<ChatMessage> _messages = [];
  final List<ChatUser> _typingUsers = [];
  bool _promptHandled = false;
  TravelPreferences? _cachedPrefs;

  @override
  void initState() {
    super.initState();
    _addSystemMessage(
        "Hi! I'm Mochi 🍡 Your AI travel buddy!\nWhere do you want to go today? ✈️");
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _cachedPrefs = await PreferencesService.fetch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_promptHandled) {
      _promptHandled = true;
      final prompt = ModalRoute.of(context)?.settings.arguments as String?;
      if (prompt != null && prompt.isNotEmpty) {
        // Auto-send the destination card prompt after build completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onSend(ChatMessage(
            text: prompt,
            user: _currentUser,
            createdAt: DateTime.now(),
          ));
        });
      }
    }
  }

  void _addSystemMessage(String text,
      {Map<String, dynamic>? customProperties}) {
    setState(() {
      _messages.insert(
          0,
          ChatMessage(
            text: text,
            user: _aiUser,
            createdAt: DateTime.now(),
            customProperties: customProperties,
          ));
    });
  }

  Future<void> _onSend(ChatMessage message) async {
    setState(() {
      _messages.insert(0, message);
      _typingUsers.add(_aiUser);
    });

    try {
      // Use cached prefs (loaded in initState), fallback to fresh fetch if not ready
      final prefs = _cachedPrefs ?? await PreferencesService.fetch();
      _cachedPrefs ??= prefs;

      final response = await GeminiService.sendMessage(
        userMessage: message.text,
        prefs: prefs,
        rules: "",
        previousMessages: _messages,
      );

      if (response.containsKey('trip_name')) {
        await _handleItineraryGeneration(response);
      } else {
        final String text =
            response['content'] ?? "I'm having trouble thinking right now.";
        _addSystemMessage(text);
      }
    } catch (e) {
      _addSystemMessage("Error: $e");
    } finally {
      setState(() => _typingUsers.remove(_aiUser));
    }
  }

  Future<void> _handleItineraryGeneration(
      Map<String, dynamic> data) async {
    try {
      _addSystemMessage("Ooo! Let me plan that for you... ✍️");

      // PhotoService now returns a raw URL string directly
      final String city = data['country'] ?? data['trip_name'] ?? 'Travel';
      final String coverUrl = await PhotoService.getCityImage(city);

      ItineraryModel newTrip = ItineraryModel(
        userId: _currentUser.id,
        tripName: data['trip_name'] ?? "Unknown Trip",
        country: data['country'] ?? "Unknown",
        duration: data['duration'] ?? "N/A",
        summary: data['full_content'] ?? "No summary provided",
        coverImage: coverUrl.isNotEmpty
            ? coverUrl
            : "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1",
        tags: List<String>.from(data['tags'] ?? []),
        isHalal: data['is_halal'] ?? false,
        days: (data['trip_data'] != null &&
                data['trip_data']['days'] != null)
            ? (data['trip_data']['days'] as List)
                .map((d) => DaySchedule.fromMap(d))
                .toList()
            : (data['days'] as List? ?? [])
                .map((d) => DaySchedule.fromMap(d))
                .toList(),
        createdAt: DateTime.now(),
        status: 'upcoming',
      );

      final savedId = await _itineraryService.saveTrip(newTrip);
      newTrip.id = savedId;

      _addSystemMessage(
        "I've planned your trip to ${newTrip.tripName}! 🎉",
        customProperties: {
          'isTrip': true,
          'tripData': newTrip,
        },
      );
    } catch (e) {
      _addSystemMessage("I planned it, but couldn't save it. ($e)");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFCE4EC),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF8BBD0), width: 1.5),
              ),
              child: ClipOval(
                child: Image.asset('assets/icons/dumpling.png',
                    fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mochi',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A)),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Online',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: DashChat(
        currentUser: _currentUser,
        onSend: _onSend,
        messages: _messages,
        typingUsers: _typingUsers,
        messageOptions: MessageOptions(
          showOtherUsersAvatar: false,
          showCurrentUserAvatar: false,
          messageDecorationBuilder: (msg, prev, next) {
            final isUser = msg.user.id == _currentUser.id;
            if (msg.customProperties != null &&
                msg.customProperties!['isTrip'] == true) {
              return const BoxDecoration(color: Colors.transparent);
            }
            return BoxDecoration(
              gradient: isUser
                  ? const LinearGradient(
                      colors: [Color(0xFFF06292), Color(0xFFEC407A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isUser ? null : Colors.white,
              borderRadius: isUser
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(4),
                    )
                  : const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
              border: isUser
                  ? null
                  : Border.all(color: const Color(0xFFF5E0E8)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF06292).withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            );
          },
          messageTextBuilder: (message, previousMessage, nextMessage) {
            // Trip card
            if (message.customProperties != null &&
                message.customProperties!['isTrip'] == true) {
              final ItineraryModel trip =
                  message.customProperties!['tripData'];
              return _TripCard(trip: trip);
            }

            final isUser = message.user.id == _currentUser.id;

            // Mochi sender label for AI messages
            if (!isUser) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mochi 🍡',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF06292),
                    ),
                  ),
                  const SizedBox(height: 3),
                  MarkdownBody(
                    data: message.text,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                          color: Color(0xFF1A1A1A), fontSize: 15),
                    ),
                  ),
                ],
              );
            }

            return MarkdownBody(
              data: message.text,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            );
          },
        ),
        inputOptions: InputOptions(
          inputDecoration: InputDecoration(
            hintText: "Ask me to plan a trip...",
            hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: const BorderSide(color: Color(0xFFF5E0E8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: const BorderSide(color: Color(0xFFF5E0E8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide:
                  const BorderSide(color: Color(0xFFF06292), width: 1.5),
            ),
          ),
          sendButtonBuilder: (onSend) => GestureDetector(
            onTap: onSend,
            child: Container(
              width: 42,
              height: 42,
              margin: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF06292),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x30F06292),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Trip Card Widget ─────────────────────────────────────────────────────────
class _TripCard extends StatelessWidget {
  final ItineraryModel trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF5E0E8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF06292).withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image with duration badge overlay
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(
              children: [
                Image.network(
                  trip.coverImage.isNotEmpty
                      ? trip.coverImage
                      : "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1",
                  height: 110,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  cacheWidth: 480,
                  errorBuilder: (_, __, ___) => Container(
                    height: 110,
                    color: const Color(0xFFFCE4EC),
                    child: const Center(child: Icon(Icons.broken_image_outlined, size: 28, color: Color(0xFFBDBDBD))),
                  ),
                ),
                // Gradient overlay
                Container(
                  height: 110,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x88000000)],
                    ),
                  ),
                ),
                // Duration badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      trip.duration.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                // Trip name at bottom of image
                Positioned(
                  bottom: 8,
                  left: 10,
                  child: Text(
                    trip.tripName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tags
                Wrap(
                  spacing: 4,
                  children: trip.tags
                      .take(2)
                      .map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCE4EC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFC2185B),
                                  fontWeight: FontWeight.w600),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                // CTA button
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => TripDetailsScreen(trip: trip)),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF06292),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        "View Itinerary ➔",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}