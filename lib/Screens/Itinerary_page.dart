import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/itinerary_model.dart';
import 'trip_details_screen.dart';
import '../widgets/bottom_nav_bar.dart';

class ItineraryPage extends StatefulWidget {
  const ItineraryPage({super.key});

  @override
  State<ItineraryPage> createState() => _ItineraryPageState();
}

class _ItineraryPageState extends State<ItineraryPage> {
  // Cycles through gradients so each trip card looks unique
  static const List<List<Color>> _cardGradients = [
    [Color(0xFFF06292), Color(0xFFAB47BC)], // pink → purple
    [Color(0xFF26C6DA), Color(0xFF00897B)], // teal → green
    [Color(0xFFFFB74D), Color(0xFFF06292)], // amber → pink
    [Color(0xFF7986CB), Color(0xFF26C6DA)], // indigo → teal
    [Color(0xFF66BB6A), Color(0xFF26C6DA)], // green → teal
  ];

  late final Stream<QuerySnapshot>? _upcomingStream;
  late final Stream<QuerySnapshot>? _memoriesStream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _upcomingStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('itineraries')
          .snapshots();

      _memoriesStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('private_memories')
          .orderBy('created_at', descending: true)
          .snapshots();
    } else {
      _upcomingStream = null;
      _memoriesStream = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
          body: Center(child: Text("Please log in to see your trips.")));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBody: true,
        backgroundColor: const Color(0xFFFFF5F7),
        appBar: AppBar(
          title: const Text(
            "My Journeys ✈️",
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Color(0xFFF06292),
            indicatorWeight: 2.5,
            labelColor: Color(0xFFF06292),
            unselectedLabelColor: Color(0xFFBDBDBD),
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: [
              Tab(text: "Upcoming"),
              Tab(text: "Memories"),
            ],
          ),
        ),
        bottomNavigationBar: const BottomNavBar(currentIndex: 2),
        body: TabBarView(
          children: [
            // ── TAB 1: Upcoming ──────────────────────────────────────
            StreamBuilder<QuerySnapshot>(
              stream: _upcomingStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFF06292)));
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return _EmptyState(
                    emoji: "✈️",
                    title: "No upcoming trips!",
                    subtitle: "Ask Mochi to plan your next adventure.",
                  );
                }
                final trips = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    final gradient = _cardGradients[index % _cardGradients.length];
                    return _ActiveTripCard(
                      doc: trips[index],
                      gradient: gradient,
                    ).animate().fade(duration: 400.ms).slideY(begin: 0.1,
                        delay: (index * 60).ms);
                  },
                );
              },
            ),

            // ── TAB 2: Memories ──────────────────────────────────────
            StreamBuilder<QuerySnapshot>(
              stream: _memoriesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFF06292)));
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return _EmptyState(
                    emoji: "📔",
                    title: "No memories yet!",
                    subtitle:
                        "Review an upcoming trip to archive it here.",
                  );
                }
                final memories = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                  itemCount: memories.length,
                  itemBuilder: (context, index) {
                    return _MemoryCard(doc: memories[index])
                        .animate()
                        .fade(duration: 400.ms)
                        .slideY(begin: 0.1, delay: (index * 60).ms);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Active Trip Card ─────────────────────────────────────────────────────────
class _ActiveTripCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final List<Color> gradient;
  const _ActiveTripCard({required this.doc, required this.gradient});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final tripName = data['trip_name'] ?? "Unknown Trip";
    final duration = data['duration'] ?? "? Days";
    final tags = List<String>.from(data['tags'] ?? []);
    final imageUrl = data['cover_image'] ??
        "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1";

    // Progress calculation from isDone activities
    final rawDays = data['trip_data']?['days'] as List? ?? data['days'] as List? ?? [];
    int totalActivities = 0;
    int doneActivities = 0;
    for (var day in rawDays) {
      final acts = day['activities'] as List? ?? [];
      totalActivities += acts.length;
      doneActivities += acts.where((a) => a['isDone'] == true).length;
    }
    final double progress =
        totalActivities > 0 ? doneActivities / totalActivities : 0.0;

    // Countdown (placeholder — in a real app, store a travel date)
    final createdAt = data['created_at'];
    String countdown = "";
    if (createdAt != null) {
      // Just show a friendly label; replace with actual departure date logic
      countdown = "Upcoming";
    }

    return GestureDetector(
      onTap: () {
        final trip = ItineraryModel.fromMap(data, doc.id);
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF5E0E8)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF06292).withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Cover image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: Stack(
                children: [
                  Hero(
                    tag: doc.id,
                    child: Image.network(imageUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        cacheWidth: 600,
                        errorBuilder: (_, __, ___) => Container(
                          height: 160,
                          color: const Color(0xFFFCE4EC),
                          child: const Center(child: Icon(Icons.broken_image_outlined, size: 36, color: Color(0xFFBDBDBD))),
                        ),
                    ),
                  ),
                  // Dark gradient
                  Container(
                    height: 160,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC000000)],
                      ),
                    ),
                  ),
                  // Countdown badge
                  if (countdown.isNotEmpty)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          countdown.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  // Trip name + duration
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            tripName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF06292).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            duration,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Card footer
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tags
                  if (tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: tags
                          .take(3)
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
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

                  // Progress bar
                  if (totalActivities > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Trip progress",
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9E9E9E),
                              fontWeight: FontWeight.w500),
                        ),
                        Text(
                          "$doneActivities/$totalActivities done",
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9E9E9E),
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFFCE4EC),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFF06292)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Memory Card ──────────────────────────────────────────────────────────────
class _MemoryCard extends StatelessWidget {
  final DocumentSnapshot doc;
  const _MemoryCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final postData = doc.data() as Map<String, dynamic>;
    final tripData = postData['itinerary_data'] as Map<String, dynamic>;
    final images = List<String>.from(postData['images'] ?? []);
    final coverImage = images.isNotEmpty
        ? images.first
        : (tripData['cover_image'] ??
            'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1');
    final rating = (postData['rating'] ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF5E0E8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF06292).withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: Image.network(coverImage,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: 600,
                errorBuilder: (_, __, ___) => Container(
                  height: 160,
                  color: const Color(0xFFFCE4EC),
                  child: const Center(child: Icon(Icons.broken_image_outlined, size: 36, color: Color(0xFFBDBDBD))),
                ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        tripData['trip_name'] ?? "My Trip",
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Stars
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < rating.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: const Color(0xFFFFC107),
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  postData['description'] ?? "",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF757575),
                      height: 1.4),
                ),
                // Extra photos strip
                if (images.length > 1) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length - 1,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(images[i + 1],
                              width: 50, height: 50, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  const _EmptyState(
      {required this.emoji, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF9E9E9E), height: 1.4)),
        ],
      ),
    );
  }
}