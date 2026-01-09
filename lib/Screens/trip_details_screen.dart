import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripDetailsScreen extends StatefulWidget {
  final String tripId;
  final String tripName;
  final Map<String, dynamic> tripData;

  const TripDetailsScreen({
    super.key,
    required this.tripId,
    required this.tripName,
    required this.tripData,
  });

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _days = [];

  @override
  void initState() {
    super.initState();
    _days = List.from(widget.tripData['days'] ?? []);
    _tabController = TabController(length: _days.length, vsync: this);
  }

  Future<void> _toggleActivity(int dayIndex, int activityIndex, bool? value) async {
    setState(() {
      _days[dayIndex]['activities'][activityIndex]['isDone'] = value;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('itineraries')
          .doc(widget.tripId)
          .update({'trip_data.days': _days});
    }
  }

  Color _getTimeColor(String time) {
    if (time.contains("Lunch") || time.contains("Dinner")) return Colors.orange.shade50; // Food Color
    if (time.contains("Morning")) return Colors.blue.shade50;
    if (time.contains("Afternoon")) return Colors.yellow.shade50;
    if (time.contains("Evening") || time.contains("Night")) return Colors.purple.shade50;
    return Colors.grey.shade50;
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.pink.shade300,
        title: Text(widget.tripName, style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            // ✅ FIX: Center tabs if few, Scroll if many
            isScrollable: _days.length > 4, 
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            labelColor: Colors.white,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            unselectedLabelColor: Colors.white70,
            tabs: _days.map((day) => Tab(text: "Day ${day['day']}")).toList(),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _days.map((dayData) {
          final activities = dayData['activities'] as List;
          
          // Split Logic (Attractions vs Food)
          List<Map<String, dynamic>> attractions = [];
          List<Map<String, dynamic>> foodPlaces = [];

          for (int i = 0; i < activities.length; i++) {
            final item = activities[i];
            final time = (item['time'] ?? "").toString();
            
            // Check if it's a meal
            if (time.contains("Lunch") || time.contains("Dinner")) {
              foodPlaces.add({'data': item, 'index': i});
            } else {
              attractions.add({'data': item, 'index': i});
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Theme Header
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "✨ Today's Theme: ${dayData['theme']}",
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.pink.shade400
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              // 1. ATTRACTIONS
              ...attractions.map((entry) => _buildActivityCard(
                dayData, 
                entry['data'], 
                entry['index']
              )),

              const SizedBox(height: 20),
              
              // 2. FOOD HEADER (Only if food exists)
              if (foodPlaces.isNotEmpty) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.orange.shade100, shape: BoxShape.circle),
                      child: const Icon(Icons.restaurant, color: Colors.orange, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Food places nearby! 🍜",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // 3. FOOD LIST
                ...foodPlaces.map((entry) => _buildActivityCard(
                  dayData, 
                  entry['data'], 
                  entry['index']
                )),
              ]
            ],
          );
        }).toList(),
      ),
    );
  }

  // --- HELPER WIDGET FOR CARDS ---
  Widget _buildActivityCard(dynamic dayData, Map<String, dynamic> item, int originalIndex) {
    final time = item['time'] ?? "";
    final title = item['title'] ?? "";
    final desc = item['desc'] ?? "";
    final isDone = item['isDone'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _getTimeColor(time),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03), 
            blurRadius: 5, 
            offset: const Offset(0, 2)
          )
        ],
      ),
      child: CheckboxListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        value: isDone,
        activeColor: Colors.pink,
        onChanged: (val) => _toggleActivity(_days.indexOf(dayData), originalIndex, val),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(
                time, 
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(title, style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.bold,
              decoration: isDone ? TextDecoration.lineThrough : null,
              color: isDone ? Colors.grey : Colors.black87
            )),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(fontSize: 14, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}