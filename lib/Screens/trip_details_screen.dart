import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/itinerary_model.dart';
import '../services/itinerary_service.dart';
import 'create_post_screen.dart';

class TripDetailsScreen extends StatefulWidget {
  final ItineraryModel trip;
  const TripDetailsScreen({super.key, required this.trip});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ItineraryService _service = ItineraryService();

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: widget.trip.days.length, vsync: this);
  }

  void _toggleActivity(int dayIndex, int activityIndex, bool? value) {
    setState(() {
      widget.trip.days[dayIndex].activities[activityIndex].isDone =
          value ?? false;
    });
    if (widget.trip.id != null) {
      _service.updateActivityStatus(widget.trip.id!, widget.trip.days);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _shareTrip() {
    String shareText =
        "✈️ My Trip to ${widget.trip.tripName} with MochiRoam!\n\n";
    for (var day in widget.trip.days) {
      shareText += "📅 Day ${day.day}: ${day.theme}\n";
      for (var act in day.activities) {
        shareText += "• ${act.time}: ${act.title}\n";
      }
      shareText += "\n";
    }
    shareText += "Planned by Mochi AI 🍡";
    Share.share(shareText);
  }

  // Compute overall progress
  int get _totalActivities =>
      widget.trip.days.fold(0, (sum, d) => sum + d.activities.length);
  int get _doneActivities => widget.trip.days.fold(
      0,
      (sum, d) =>
          sum + d.activities.where((a) => a.isDone).length);

  @override
  Widget build(BuildContext context) {
    if (widget.trip.days.isEmpty) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text("This trip has no days yet.")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: const Color(0xFFF06292),
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 16),
              ),
            ),
            actions: [
              // Archive / Create Memory
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          CreatePostScreen(trip: widget.trip)),
                ),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Archive 📔",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              // Share
              GestureDetector(
                onTap: _shareTrip,
                child: Container(
                  margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.share_outlined,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 56),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.trip.tripName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
                  ),
                  // Progress indicator under title
                  if (_totalActivities > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: _doneActivities / _totalActivities,
                              minHeight: 3,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.3),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "$_doneActivities/$_totalActivities",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: widget.trip.id ?? widget.trip.tripName,
                    child: Image.network(
                      widget.trip.coverImage.isNotEmpty
                          ? widget.trip.coverImage
                          : "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1",
                      fit: BoxFit.cover,
                      cacheWidth: 800,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFFCE4EC),
                        child: const Center(child: Icon(Icons.broken_image_outlined, size: 48, color: Color(0xFFBDBDBD))),
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0xBBF06292),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Container(
                color: const Color(0xFFF06292),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: widget.trip.days.length > 4,
                  indicatorColor: Colors.white,
                  indicatorWeight: 2.5,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12),
                  tabs: widget.trip.days
                      .map((day) => Tab(text: "Day ${day.day}"))
                      .toList(),
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: widget.trip.days.asMap().entries.map((entry) {
            final dayIndex = entry.key;
            final day = entry.value;

            // Split into attractions vs food
            List<Map<String, dynamic>> attractions = [];
            List<Map<String, dynamic>> foodPlaces = [];

            for (int i = 0; i < day.activities.length; i++) {
              final act = day.activities[i];
              final t = act.time.toLowerCase();
              final title = act.title.toLowerCase();
              bool isFood = t.contains("lunch") ||
                  t.contains("dinner") ||
                  title.contains("lunch at") ||
                  title.contains("dinner at") ||
                  title.contains("eat at");
              if (isFood) {
                foodPlaces.add({'act': act, 'index': i});
              } else {
                attractions.add({'act': act, 'index': i});
              }
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // Theme pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE4EC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFF8BBD0)),
                  ),
                  child: Text(
                    "✨ ${day.theme}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFFC2185B),
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ),

                const SizedBox(height: 12),

                // Attractions
                ...attractions.map((item) => _ActivityCard(
                      act: item['act'],
                      dayIndex: dayIndex,
                      actIndex: item['index'],
                      tripName: widget.trip.tripName,
                      onToggle: _toggleActivity,
                    )),

                // Food section
                if (foodPlaces.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.restaurant_rounded,
                            color: Color(0xFFF57C00), size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Restaurants 🍜",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...foodPlaces.map((item) => _ActivityCard(
                        act: item['act'],
                        dayIndex: dayIndex,
                        actIndex: item['index'],
                        tripName: widget.trip.tripName,
                        onToggle: _toggleActivity,
                        isFood: true,
                      )),
                ],
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Activity Card ─────────────────────────────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  final Activity act;
  final int dayIndex;
  final int actIndex;
  final String tripName;
  final void Function(int, int, bool?) onToggle;
  final bool isFood;

  const _ActivityCard({
    required this.act,
    required this.dayIndex,
    required this.actIndex,
    required this.tripName,
    required this.onToggle,
    this.isFood = false,
  });

  Color get _bgColor {
    if (isFood) return const Color(0xFFFFF3E0);
    final t = act.time.toLowerCase();
    if (t.contains("am") || t.contains("morning"))
      return const Color(0xFFE3F2FD);
    return const Color(0xFFF3E5F5);
  }

  Color get _timeColor {
    if (isFood) return const Color(0xFFF57C00);
    final t = act.time.toLowerCase();
    if (t.contains("am") || t.contains("morning"))
      return const Color(0xFF1565C0);
    return const Color(0xFF6A1B9A);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: act.isDone ? const Color(0xFFF5F5F5) : _bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: act.isDone
              ? const Color(0xFFE0E0E0)
              : _bgColor.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          // Checkbox
          Checkbox(
            value: act.isDone,
            activeColor: const Color(0xFFF06292),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            onChanged: (val) => onToggle(dayIndex, actIndex, val),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      act.time,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _timeColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    act.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: act.isDone
                          ? const Color(0xFF9E9E9E)
                          : const Color(0xFF1A1A1A),
                      decoration: act.isDone
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (act.desc.isNotEmpty)
                    Text(
                      act.desc,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF757575),
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),

          // Maps button
          GestureDetector(
            onTap: () async {
              final query =
                  Uri.encodeComponent("${act.title} $tripName");
              final url = Uri.parse(
                  "https://www.google.com/maps/search/?api=1&query=$query");
              launchUrl(url, mode: LaunchMode.externalApplication);
            },
            child: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFFE3F2FD)),
              ),
              child: const Icon(Icons.map_outlined,
                  color: Color(0xFF1565C0), size: 18),
            ),
          ),
        ],
      ),
    );
  }
}