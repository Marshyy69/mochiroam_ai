import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/itinerary_model.dart';
import 'trip_details_screen.dart';
import 'edit_memory_screen.dart';
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

  Stream<List<Map<String, dynamic>>>? _upcomingStream;
  Stream<List<Map<String, dynamic>>>? _memoriesStream;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        _upcomingStream = Supabase.instance.client
            .from('itineraries')
            .stream(primaryKey: ['id'])
            .eq('user_id', user.id);

        _memoriesStream = Supabase.instance.client
            .from('private_memories')
            .stream(primaryKey: ['id'])
            .eq('user_id', user.id)
            .order('created_at', ascending: false);
      });
    } else {
      setState(() {
        _upcomingStream = null;
        _memoriesStream = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

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
        bottomNavigationBar: const BottomNavBar(currentIndex: 1),
        body: TabBarView(
          children: [
            // ── TAB 1: Upcoming ──────────────────────────────────────
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _upcomingStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFF06292)));
                }
                final docs = snapshot.data!;
                if (docs.isEmpty) {
                  return RefreshIndicator(
                    color: const Color(0xFFF06292),
                    onRefresh: () async {
                      _refreshData();
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: _EmptyState(
                          emoji: "✈️",
                          title: "No upcoming trips!",
                          subtitle: "Ask Mochi to plan your next adventure.",
                        ),
                      ),
                    ),
                  );
                }
                final trips = snapshot.data!;
                return RefreshIndicator(
                  color: const Color(0xFFF06292),
                  onRefresh: () async {
                    _refreshData();
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                    itemCount: trips.length,
                    itemBuilder: (context, index) {
                      final gradient = _cardGradients[index % _cardGradients.length];
                      return _ActiveTripCard(
                        doc: trips[index],
                        gradient: gradient,
                        onRefresh: _refreshData,
                      ).animate().fade(duration: 400.ms).slideY(begin: 0.1,
                          delay: (index * 60).ms);
                    },
                  ),
                );
              },
            ),

            // ── TAB 2: Memories ──────────────────────────────────────
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _memoriesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFF06292)));
                }
                final docs = snapshot.data!;
                if (docs.isEmpty) {
                  return RefreshIndicator(
                    color: const Color(0xFFF06292),
                    onRefresh: () async {
                      _refreshData();
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: _EmptyState(
                          emoji: "📔",
                          title: "No memories yet!",
                          subtitle:
                              "Review an upcoming trip to archive it here.",
                        ),
                      ),
                    ),
                  );
                }
                final memories = snapshot.data!;
                return RefreshIndicator(
                  color: const Color(0xFFF06292),
                  onRefresh: () async {
                    _refreshData();
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                    itemCount: memories.length,
                    itemBuilder: (context, index) {
                      return _MemoryCard(doc: memories[index], onRefresh: _refreshData)
                          .animate()
                          .fade(duration: 400.ms)
                          .slideY(begin: 0.1, delay: (index * 60).ms);
                    },
                  ),
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
  final Map<String, dynamic> doc;
  final List<Color> gradient;
  final VoidCallback onRefresh;
  const _ActiveTripCard({required this.doc, required this.gradient, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final data = doc;
    final docId = doc['id'] as String;
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
      onTap: () async {
        final trip = ItineraryModel.fromMap(data, docId);
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)));
        onRefresh();
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
                    tag: docId,
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

// ── Memory Card (now tappable!) ──────────────────────────────────────────────
class _MemoryCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onRefresh;
  const _MemoryCard({required this.doc, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final postData = doc;
    final tripData = postData['itinerary_data'] as Map<String, dynamic>? ?? {};
    final images = List<String>.from(postData['images'] ?? []);
    final coverImage = images.isNotEmpty
        ? images.first
        : (tripData['cover_image'] ??
            'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1');
    final rating = (postData['rating'] ?? 0).toDouble();
    final title = postData['title'] ?? tripData['trip_name'] ?? 'My Trip';
    final country = postData['country'] ?? tripData['country'] ?? '';
    final duration = tripData['duration'] ?? '';

    return GestureDetector(
      onTap: () => _showMemoryModal(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
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
            // Cover image with gradient overlay
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              child: Stack(
                children: [
                  Image.network(coverImage,
                      height: 170,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      cacheWidth: 600,
                      errorBuilder: (_, __, ___) => Container(
                        height: 170,
                        color: const Color(0xFFFCE4EC),
                        child: const Center(child: Icon(Icons.broken_image_outlined, size: 36, color: Color(0xFFBDBDBD))),
                      ),
                  ),
                  // Gradient overlay
                  Container(
                    height: 170,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x99000000)],
                      ),
                    ),
                  ),
                  // Country + duration badge
                  if (country.isNotEmpty || duration.isNotEmpty)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          [country, duration].where((s) => s.isNotEmpty).join(' • '),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  // Rating badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 14),
                          const SizedBox(width: 3),
                          Text(rating.toStringAsFixed(1),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF795548))),
                        ],
                      ),
                    ),
                  ),
                  // Title on image
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                width: 50, height: 50, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 50, height: 50,
                                  color: const Color(0xFFFCE4EC),
                                )),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Tap to view hint
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCE4EC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text("View details",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFC2185B))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Memory Detail Modal ──────────────────────────────────────────
  void _showMemoryModal(BuildContext context) {
    final postData = doc;
    final docId = doc['id'] as String;
    final tripData = postData['itinerary_data'] as Map<String, dynamic>? ?? {};
    final images = List<String>.from(postData['images'] ?? []);
    final title = postData['title'] ?? tripData['trip_name'] ?? 'My Trip';
    final country = postData['country'] ?? tripData['country'] ?? '';
    final duration = tripData['duration'] ?? '';
    final rating = (postData['rating'] ?? 0).toDouble();

    // Build an ItineraryModel for the preview
    ItineraryModel? trip;
    try {
      trip = ItineraryModel.fromMap(tripData, docId);
    } catch (_) {
      trip = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 4,
                width: 36,
                decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(10)),
              ),

              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _MemoryImageCarousel(
                      images: images.isNotEmpty
                          ? images
                          : (tripData['cover_image'] != null
                              ? [tripData['cover_image'] as String]
                              : ['https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1']),
                      height: 240,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Author row
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                    color: Color(0xFFFCE4EC),
                                    shape: BoxShape.circle),
                                child: Center(
                                    child: Text(
                                        postData['author_avatar'] ?? "🍡",
                                        style: const TextStyle(fontSize: 18))),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        postData['author_name'] ?? "Traveler",
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700)),
                                    Text(
                                      [country, duration]
                                          .where((s) => s.isNotEmpty)
                                          .join(' • '),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9E9E9E)),
                                    ),
                                  ],
                                ),
                              ),
                              // Rating
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        color: Color(0xFFFFC107), size: 16),
                                    const SizedBox(width: 3),
                                    Text(rating.toStringAsFixed(1),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: Color(0xFF795548))),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          Text(
                            postData['description'] ?? "No review provided.",
                            style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF616161),
                                height: 1.55),
                          ),
                          const SizedBox(height: 20),

                          // Highlights
                          if (postData['highlights'] != null &&
                              (postData['highlights'] as List).isNotEmpty) ...[
                            const Text("Highlights 📌",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            ...List.from(postData['highlights']).map((tag) =>
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFFCE4EC),
                                      borderRadius: BorderRadius.circular(14)),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("📌",
                                          style: TextStyle(fontSize: 14)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                                color: Color(0xFF1A1A1A),
                                                fontSize: 13),
                                            children: [
                                              TextSpan(
                                                  text: "${tag['header']}: ",
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.w700)),
                                              TextSpan(
                                                  text: tag['link'],
                                                  style: const TextStyle(
                                                      color: Color(0xFF1565C0))),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                            const SizedBox(height: 10),
                          ],

                          // Itinerary Preview
                          if (trip != null && trip.days.isNotEmpty) ...[
                            const Text("Itinerary Preview 📋",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            _MemoryItineraryPreview(trip: trip),
                            const SizedBox(height: 16),
                          ],

                          // ── Action Buttons ─────────────────────────────
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Edit button
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF06292),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16)),
                                    ),
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    label: const Text("Edit",
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700)),
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => EditMemoryScreen(
                                            memoryData: postData,
                                            memoryId: docId,
                                          ),
                                        ),
                                      );
                                      onRefresh();
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Delete button
                              SizedBox(
                                height: 48,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFEBEE),
                                    foregroundColor: const Color(0xFFE53935),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16)),
                                  ),
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  label: const Text("Delete",
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                  onPressed: () =>
                                      _confirmDelete(context, ctx, docId, postData),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext parentContext, BuildContext modalContext,
      String docId, Map<String, dynamic> postData) {
    showDialog(
      context: modalContext,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Delete Memory? 🗑️",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: const Text(
          "This will permanently delete this memory. If it was shared publicly, it will also be removed from the Explore feed.",
          style: TextStyle(fontSize: 14, color: Color(0xFF616161), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancel",
                style: TextStyle(color: Color(0xFF9E9E9E))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx); // Close dialog
              Navigator.pop(modalContext); // Close modal

              try {
                // Delete from private_memories
                await Supabase.instance.client
                    .from('private_memories')
                    .delete()
                    .eq('id', docId);

                // Also delete from public_posts if it was public
                final isPublic = postData['is_public'] ?? false;
                if (isPublic) {
                  final authorUid = postData['author_uid'] ?? '';
                  final createdAt = postData['created_at'] ?? '';
                  try {
                    await Supabase.instance.client
                        .from('public_posts')
                        .delete()
                        .eq('author_uid', authorUid)
                        .eq('created_at', createdAt);
                  } catch (_) {}
                }

                if (parentContext.mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(SnackBar(
                    content: const Text("Memory deleted 🗑️"),
                    backgroundColor: const Color(0xFFE53935),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                }
                onRefresh();
              } catch (e) {
                if (parentContext.mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(content: Text("Error deleting: $e")));
                }
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}

// ── Memory Image Carousel ────────────────────────────────────────────────────
class _MemoryImageCarousel extends StatefulWidget {
  final List<String> images;
  final double height;
  const _MemoryImageCarousel({required this.images, required this.height});

  @override
  State<_MemoryImageCarousel> createState() => _MemoryImageCarouselState();
}

class _MemoryImageCarouselState extends State<_MemoryImageCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => Image.network(widget.images[i],
                fit: BoxFit.cover,
                width: double.infinity,
                cacheWidth: 800,
                errorBuilder: (_, __, ___) => Container(
                    height: widget.height,
                    color: const Color(0xFFFCE4EC),
                    child: const Center(
                        child: Icon(Icons.broken_image_outlined,
                            size: 40, color: Color(0xFFBDBDBD))))),
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                    widget.images.length,
                    (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _current == i ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color:
                                _current == i ? Colors.white : Colors.white54,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        )),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Memory Itinerary Preview ─────────────────────────────────────────────────
class _MemoryItineraryPreview extends StatefulWidget {
  final ItineraryModel trip;
  const _MemoryItineraryPreview({required this.trip});

  @override
  State<_MemoryItineraryPreview> createState() =>
      _MemoryItineraryPreviewState();
}

class _MemoryItineraryPreviewState extends State<_MemoryItineraryPreview> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.map_outlined, color: Color(0xFFF06292), size: 18),
            const SizedBox(width: 8),
            Text(
                "${widget.trip.country} • ${widget.trip.duration}",
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A))),
          ]),
          const SizedBox(height: 10),
          ...widget.trip.days.map((day) {
            final acts =
                _expanded ? day.activities : day.activities.take(2).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFCE4EC),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text("Day ${day.day}: ${day.theme}",
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFC2185B))),
                ),
                ...acts.map((a) => Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Row(children: [
                        Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                                color: Color(0xFFBDBDBD),
                                shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text("${a.time} — ${a.title}",
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF757575)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                      ]),
                    )),
                if (!_expanded && day.activities.length > 2)
                  Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Text("+ ${day.activities.length - 2} more...",
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFBDBDBD),
                              fontStyle: FontStyle.italic))),
                const SizedBox(height: 6),
              ],
            );
          }),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Center(
                child: Text(
                    _expanded ? "Show less ▲" : "Show all activities ▼",
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF06292)))),
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