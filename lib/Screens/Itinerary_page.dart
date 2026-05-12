import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/itinerary_model.dart';
import 'trip_details_screen.dart';
import '../widgets/bottom_nav_bar.dart'; // Make sure this path is correct!

class ItineraryPage extends StatelessWidget {
  const ItineraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please log in to see your trips.")));
    }

    return DefaultTabController(
      length: 2, // ✨ Two distinct tabs!
      child: Scaffold(
        extendBody: true, // For the frosted glass nav bar
        backgroundColor: const Color(0xFFFFF5F7),
        appBar: AppBar(
          title: const Text("My Journeys ✈️", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: Colors.pinkAccent,
            labelColor: Colors.pinkAccent,
            unselectedLabelColor: Colors.black45,
            tabs: const [
              Tab(text: "Upcoming"),
              Tab(text: "Memories"),
            ],
          ),
        ),
        bottomNavigationBar: const BottomNavBar(currentIndex: 2), // Index 2 is Itineraries
        
        body: TabBarView(
          children: [
            // ==========================================
            // TAB 1: UPCOMING TRIPS (Active Planning)
            // ==========================================
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('itineraries') // 👈 Points to active trips
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.pink));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No upcoming trips! Ask Mochi to plan one."));
                }

                final trips = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 100),
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    return _buildActiveTripCard(context, trips[index]);
                  },
                );
              },
            ),

            // ==========================================
            // TAB 2: MEMORIES (Archived Past Trips)
            // ==========================================
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('private_memories') // 👈 Points to archived diary
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.pink));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("No memories yet! Review an upcoming trip to add it here.",
                      style: TextStyle(color: Colors.black54), textAlign: TextAlign.center,
                    ),
                  );
                }

                final memories = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 100),
                  itemCount: memories.length,
                  itemBuilder: (context, index) {
                    return _buildMemoryCard(memories[index]);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // WIDGET: ACTIVE TRIP CARD (With Hero Animation)
  // ---------------------------------------------------------
  Widget _buildActiveTripCard(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final tripName = data['trip_name'] ?? "Unknown Trip";
    final duration = data['duration'] ?? "? Days";
    final tags = List<String>.from(data['tags'] ?? []);
    final imageUrl = data['cover_image'] ?? "https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1";

    return GestureDetector(
      onTap: () {
        ItineraryModel trip = ItineraryModel.fromMap(data, doc.id);
        Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)));
      },
      child: Container(
        height: 200,
        margin: const EdgeInsets.only(bottom: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(tag: doc.id, child: Image.network(imageUrl, fit: BoxFit.cover)),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: Text(tripName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
                          child: Text(duration, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (tags.isNotEmpty)
                      Wrap(
                        spacing: 6, runSpacing: 4,
                        children: tags.take(3).map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white38)),
                          child: Text(tag, style: const TextStyle(fontSize: 10, color: Colors.white)),
                        )).toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fade(duration: 500.ms).slideY(begin: 0.1);
  }

  // ---------------------------------------------------------
  // WIDGET: MEMORY DIARY CARD (With Photos & Rating)
  // ---------------------------------------------------------
  Widget _buildMemoryCard(DocumentSnapshot doc) {
    final postData = doc.data() as Map<String, dynamic>;
    final tripData = postData['itinerary_data'] as Map<String, dynamic>;
    final images = List<String>.from(postData['images'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Image.network(
              images.isNotEmpty ? images.first : (tripData['cover_image'] ?? 'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1'),
              height: 180, width: double.infinity, fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(tripData['trip_name'] ?? "My Trip", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(postData['rating'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Text(postData['description'] ?? "", style: const TextStyle(fontSize: 14, color: Colors.black87)),
                
                if (images.length > 1) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length - 1,
                      itemBuilder: (context, i) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(images[i + 1], width: 50, height: 50, fit: BoxFit.cover)),
                        );
                      },
                    ),
                  ),
                ]
              ],
            ),
          )
        ],
      ),
    ).animate().fade(duration: 500.ms).slideY(begin: 0.1);
  }
}