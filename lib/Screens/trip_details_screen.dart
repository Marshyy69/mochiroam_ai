import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart'; 
import 'package:url_launcher/url_launcher.dart'; 

import '../models/itinerary_model.dart';
import '../services/itinerary_service.dart';
import 'create_post_screen.dart'; // 🆕 Routes to your new full-screen creator!

class TripDetailsScreen extends StatefulWidget {
  final ItineraryModel trip;

  const TripDetailsScreen({super.key, required this.trip});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ItineraryService _service = ItineraryService(); 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.trip.days.length, vsync: this);
  }

  void _toggleActivity(int dayIndex, int activityIndex, bool? value) {
    setState(() {
      widget.trip.days[dayIndex].activities[activityIndex].isDone = value ?? false;
    });
    
    if (widget.trip.id != null) {
      _service.updateActivityStatus(widget.trip.id!, widget.trip.days);
    }
  }

  void _shareTrip() {
    String shareText = "✈️ My Trip to ${widget.trip.tripName} with MochiRoam!\n\n";
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

  Color _getTimeColor(String time, String title) {
    if (time.contains("Lunch") || time.contains("Dinner") || title.contains("Lunch") || title.contains("Dinner")) {
      return Colors.orange.shade50;
    }
    if (time.contains("Morning") || time.contains("AM")) return Colors.blue.shade50;
    return Colors.purple.shade50;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trip.days.isEmpty) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text("Empty Trip")));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 250.0,
              pinned: true,
              backgroundColor: Colors.pink.shade300,
              leading: const BackButton(color: Colors.white),
              actions: [
                // ✨ THIS ROUTES PERFECTLY TO YOUR NEW CREATOR SCREEN
                IconButton(
                  icon: const Icon(Icons.public, color: Colors.white), 
                  tooltip: "Create Memory",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CreatePostScreen(trip: widget.trip)),
                    );
                  },
                ),
                // Your existing Share button
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white), 
                  onPressed: _shareTrip
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  widget.trip.tripName, 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: widget.trip.id ?? widget.trip.tripName, 
                      child: Image.network(
                        widget.trip.coverImage.isNotEmpty ? widget.trip.coverImage : "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1",
                        fit: BoxFit.cover,
                      ),
                    ),
                    Container(color: Colors.black.withOpacity(0.3)),
                  ],
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.pink.shade300, 
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: widget.trip.days.length > 4,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: widget.trip.days.map((day) => Tab(text: "Day ${day.day}")).toList(),
                  ),
                ),
              ),
            ),
          ];
        },
        
        body: TabBarView(
          controller: _tabController,
          children: widget.trip.days.asMap().entries.map((entry) {
            final dayIndex = entry.key;
            final day = entry.value;

            List<Map<String, dynamic>> attractions = [];
            List<Map<String, dynamic>> foodPlaces = [];

            for (int i = 0; i < day.activities.length; i++) {
              final act = day.activities[i];
              final t = act.time.toLowerCase();
              final title = act.title.toLowerCase();

              bool isFood = t.contains("lunch") || t.contains("dinner") || 
                            title.contains("lunch at") || title.contains("dinner at") ||
                            title.contains("eat at");

              if (isFood) {
                foodPlaces.add({'act': act, 'index': i});
              } else {
                attractions.add({'act': act, 'index': i});
              }
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(color: Colors.pink.shade50, borderRadius: BorderRadius.circular(20)),
                  child: Text("✨ ${day.theme}", textAlign: TextAlign.center, style: TextStyle(color: Colors.pink.shade400, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                
                ...attractions.map((item) {
                  return _buildActivityCard(day, item['act'], dayIndex, item['index']);
                }),

                if (foodPlaces.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.orange.shade100, shape: BoxShape.circle),
                        child: const Icon(Icons.restaurant, color: Colors.orange, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text("Restaurants nearby 🍜", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...foodPlaces.map((item) {
                    return _buildActivityCard(day, item['act'], dayIndex, item['index']);
                  }),
                ]
              ],
            );
          }).toList(),
        ),
      ), 
    ); 
  }

  Widget _buildActivityCard(DaySchedule day, Activity act, int dayIndex, int actIndex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _getTimeColor(act.time, act.title),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: CheckboxListTile(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
              child: Text(act.time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             const SizedBox(height: 4),
             Text(act.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
             Text(act.desc, style: const TextStyle(fontSize: 13)),
          ],
        ),
        value: act.isDone,
        activeColor: Colors.pink,
        onChanged: (val) => _toggleActivity(dayIndex, actIndex, val),
        secondary: IconButton(
          icon: const Icon(Icons.map_outlined, color: Colors.blueAccent),
          onPressed: () async {
             final query = Uri.encodeComponent("${act.title} ${widget.trip.tripName}");
             final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");
             launchUrl(url, mode: LaunchMode.externalApplication);
          },
        ),
      ),
    );
  }
}