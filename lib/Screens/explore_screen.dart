import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/post_model.dart';
import '../models/itinerary_model.dart';
import '../widgets/bottom_nav_bar.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _selectedCountry = 'All';

  // The function to copy a trip to your account
  Future<void> _copyTripToMyAccount(BuildContext context, ItineraryModel publicTrip) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please log in to save trips!")));
        return;
      }

      // 1. Re-map it to strip old ownership
      Map<String, dynamic> tripData = publicTrip.toMap();
      ItineraryModel copiedTrip = ItineraryModel.fromMap(tripData, '');
      
      copiedTrip.userId = currentUser.uid;
      copiedTrip.createdAt = DateTime.now(); 
      copiedTrip.status = 'upcoming'; 

      // 2. Save to active itineraries
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('itineraries')
          .add(copiedTrip.toMap());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✨ '${publicTrip.tripName}' saved to your trips!"),
            backgroundColor: Colors.pinkAccent,
          ),
        );
      }
    } catch (e) {
      print("Error copying trip: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        title: const Text("Community Explore 🌍", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 1), // Index 1 is Explore
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('public_posts')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.pink));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No public trips yet. Be the first to publish one!"));
          }

          final allPosts = snapshot.data!.docs;

          // ✨ DYNAMICALLY EXTRACT COUNTRIES FOR THE FILTER TABS
          Set<String> uniqueCountries = {'All'};
          for (var doc in allPosts) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['country'] != null) uniqueCountries.add(data['country']);
          }
          List<String> filterList = uniqueCountries.toList();

          // ✨ CLIENT-SIDE FILTERING (Prevents Firebase Index Errors!)
          final filteredPosts = _selectedCountry == 'All' 
              ? allPosts 
              : allPosts.where((doc) => (doc.data() as Map<String, dynamic>)['country'] == _selectedCountry).toList();

          return Column(
            children: [
              // 1. THE COUNTRY FILTER BAR
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filterList.length,
                  itemBuilder: (context, index) {
                    final country = filterList[index];
                    final isSelected = _selectedCountry == country;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(country, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                        selected: isSelected,
                        selectedColor: Colors.pinkAccent,
                        backgroundColor: Colors.white,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedCountry = country);
                        },
                      ),
                    );
                  },
                ),
              ),

              // 2. THE BLOG FEED
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
                  itemCount: filteredPosts.length,
                  itemBuilder: (context, index) {
                    final doc = filteredPosts[index];
                    final postData = doc.data() as Map<String, dynamic>;
                    final tripData = postData['itinerary_data'] as Map<String, dynamic>;
                    final publicTrip = ItineraryModel.fromMap(tripData, doc.id);
                    final images = List<String>.from(postData['images'] ?? []);

                    return _buildBlogCard(context, postData, publicTrip, images)
                        .animate().fade(duration: 400.ms).slideY(begin: 0.1);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // THE BEAUTIFUL BLOG POST CARD
  // 1. THE CLEAN FEED CARD
  Widget _buildBlogCard(BuildContext context, Map<String, dynamic> postData, ItineraryModel publicTrip, List<String> images) {
    // Provide a fallback in case old posts don't have a title
    String title = postData['title'] ?? publicTrip.tripName; 
    String coverImage = images.isNotEmpty ? images.first : publicTrip.coverImage;

    return GestureDetector(
      // ✨ THIS TRIGGERS THE POPUP WHEN TAPPED!
      onTap: () => _showPostDetailsModal(context, postData, publicTrip, images),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author Header
            ListTile(
              leading: CircleAvatar(backgroundColor: Colors.pink.shade50, child: Text(postData['author_avatar'] ?? "🍡")),
              title: Text(postData['author_name'] ?? "Traveler", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${postData['country'] ?? 'Unknown'} • ${publicTrip.duration}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  Text(postData['rating'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            
            // Just the Cover Image (Clean & Simple)
            Image.network(coverImage, height: 200, width: double.infinity, fit: BoxFit.cover),

            // Just the Title at the bottom
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // 2. ✨ THE POPUP BOTTOM SHEET (Reveals full details)
  void _showPostDetailsModal(BuildContext context, Map<String, dynamic> postData, ItineraryModel publicTrip, List<String> images) {
    String title = postData['title'] ?? publicTrip.tripName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the popup to be taller
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85, // Takes up 85% of screen
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              // Little drag handle pill at the top
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 5, width: 40,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),

              // The Photo Gallery
              if (images.isNotEmpty)
                SizedBox(
                  height: 250,
                  child: PageView.builder(
                    itemCount: images.length,
                    itemBuilder: (context, i) => Image.network(images[i], fit: BoxFit.cover, width: double.infinity),
                  ),
                )
              else
                Image.network(publicTrip.coverImage, height: 250, width: double.infinity, fit: BoxFit.cover),

              // Details & Buttons inside a scrollable view
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text(
                      postData['description'] ?? "No review provided.",
                      style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
                    ),
                    const SizedBox(height: 30),

                    if (postData['highlights'] != null && (postData['highlights'] as List).isNotEmpty) ...[
                      const Text("Highlights & Links 📌", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...List.from(postData['highlights']).map((tag) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.pink.shade50, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.push_pin, size: 16, color: Colors.pinkAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                                  children: [
                                    TextSpan(text: "${tag['header']}:\n", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    TextSpan(text: tag['link'], style: const TextStyle(color: Colors.blueAccent)),
                                  ]
                                )
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                    
                    // The Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.copy),
                        label: const Text("Save Itinerary to My Trips", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(context); // Close the popup first
                          _copyTripToMyAccount(context, publicTrip); // Then trigger the copy logic
                        },
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
}