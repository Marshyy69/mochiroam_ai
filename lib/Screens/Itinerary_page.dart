import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/bottom_nav_bar.dart';
// If you create a details page later, import it here:
// import 'itinerary_details_screen.dart';

class ItineraryPage extends StatelessWidget {
  const ItineraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,

      // -------------------- APP BAR --------------------
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Image.asset("assets/icons/dumpling.png", height: 32),
            const SizedBox(width: 10),
            const Text(
              "ITINERARY",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),

      // -------------------- BODY CONTENT --------------------
      body: user == null
          ? const Center(child: Text("Please log in to view itineraries"))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.flight_takeoff, size: 22, color: Colors.black),
                      SizedBox(width: 6),
                      Text(
                        "Your saved itineraries",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.flight_land, size: 22, color: Colors.black),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 🔥 REAL-TIME DATABASE LISTENER
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('itineraries')
                          .orderBy('created_at', descending: true) // Newest first
                          .snapshots(),
                      builder: (context, snapshot) {
                        // 1. Loading State
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        // 2. Error State
                        if (snapshot.hasError) {
                          return const Center(child: Text("Something went wrong ⚠️"));
                        }

                        // 3. Empty State
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.map_outlined, 
                                  size: 60, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                const Text(
                                  "No trips planned yet!",
                                  style: TextStyle(color: Colors.grey),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pushNamed(context, '/home'),
                                  child: const Text("Ask Mochi to plan one!"),
                                ),
                              ],
                            ),
                          );
                        }

                        // 4. Data List
                        final trips = snapshot.data!.docs;

                        return ListView.builder(
                          itemCount: trips.length,
                          itemBuilder: (context, index) {
                            final doc = trips[index];
                            final data = doc.data() as Map<String, dynamic>;

                            // Safely get data fields
                            final tripName = data['trip_name'] ?? "Unknown Trip";
                            final duration = data['duration'] ?? "? Days";
                            
                            // We will use this later for the details page
                            final fullContent = data['full_content'] ?? ""; 

                            return GestureDetector(
                              onTap: () {
                                // TODO: Navigate to Details Page
                                // Navigator.push(context, MaterialPageRoute(
                                //   builder: (_) => TripDetailsScreen(
                                //     title: tripName, 
                                //     content: fullContent
                                //   )
                                // ));
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.pink.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.pink.shade100),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Trip Name
                                        Expanded(
                                          child: Text(
                                            tripName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // Duration Pill
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            duration,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.pink.shade400,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      "Tap to view full plan ➔",
                                      style: TextStyle(
                                        fontSize: 12, 
                                        color: Colors.grey
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
    );
  }
}