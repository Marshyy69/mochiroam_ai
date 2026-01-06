import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/bottom_nav_bar.dart';
import 'trip_details_screen.dart';

class ItineraryPage extends StatefulWidget {
  const ItineraryPage({super.key});

  @override
  State<ItineraryPage> createState() => _ItineraryPageState();
}

class _ItineraryPageState extends State<ItineraryPage> {
  // ---------------- STATE: Active Filters ----------------
  String _selectedRegion = "All"; // All, Asia, Europe, etc.
  String _selectedTripType = "All"; // All, Family, Couple, Friends
  bool _filterHalal = false;
  String _durationFilter = "Any"; // Any, Short (< 5), Long (5+)

  // ---------------- UI: The Filter Modal ----------------
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) {
        // Local state for the modal (so switches update instantly visually)
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50, height: 5,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  const Text("Filter Trips ✨", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // 1. Region / Continent
                  const Text("Region", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ["All", "Asia", "Europe", "Oceania", "America"].map((region) {
                      final isSelected = _selectedRegion == region;
                      return ChoiceChip(
                        label: Text(region),
                        selected: isSelected,
                        selectedColor: Colors.pinkAccent,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                        onSelected: (bool selected) {
                          setModalState(() => _selectedRegion = selected ? region : "All");
                        },
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 16),

                  // 2. Trip Type (Tags)
                  const Text("Trip Vibe", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ["All", "Family", "Couple", "Friends", "Solo"].map((type) {
                      final isSelected = _selectedTripType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        selectedColor: Colors.purpleAccent.shade100,
                         labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                        onSelected: (bool selected) {
                          setModalState(() => _selectedTripType = selected ? type : "All");
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // 3. Halal Toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Halal / Muslim Friendly 🌙", style: TextStyle(fontWeight: FontWeight.w600)),
                    value: _filterHalal,
                    activeColor: Colors.green,
                    onChanged: (val) => setModalState(() => _filterHalal = val),
                  ),

                  const SizedBox(height: 20),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: () {
                        // Save state to main widget and close
                        setState(() {}); 
                        Navigator.pop(context);
                      },
                      child: const Text("Apply Filters", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

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
              "MY TRIPS",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),

      // -------------------- BODY --------------------
      body: user == null
          ? const Center(child: Text("Please log in to view itineraries"))
          : Column(
              children: [
                // 🔥 HEADER WITH FILTER BUTTON
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.flight_takeoff, size: 22, color: Colors.black),
                          SizedBox(width: 8),
                          Text(
                            "Your saved itineraries",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      
                      // FILTER BUTTON
                      InkWell(
                        onTap: _showFilterModal,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.pink.shade50,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.pink.shade100),
                          ),
                          child: const Icon(Icons.tune, color: Colors.pink, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),

                // 🔥 LIST WITH LOGIC
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('itineraries')
                        .orderBy('created_at', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      var docs = snapshot.data!.docs;

                      // ---------------- APPLY FILTERS ----------------
                      var filteredDocs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        
                        String continent = data['continent'] ?? "Uncategorized";
                        List<dynamic> tags = data['tags'] ?? [];
                        
                        // 1. Region Filter
                        if (_selectedRegion != "All" && continent != _selectedRegion) return false;

                        // 2. Trip Type Filter
                        if (_selectedTripType != "All") {
                           // Ensure tag list contains the specific string
                           if (!tags.contains(_selectedTripType)) return false; 
                        }

                        // 3. Halal Filter
                        if (_filterHalal && !tags.contains("Halal")) return false;

                        return true;
                      }).toList();
                      // ----------------------------------------------

                      if (filteredDocs.isEmpty) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.filter_list_off, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 10),
                            const Text("No trips match your filters!", style: TextStyle(color: Colors.grey)),
                            TextButton(
                                onPressed: () => setState(() {
                                  _selectedRegion = "All";
                                  _selectedTripType = "All";
                                  _filterHalal = false;
                                }), 
                                child: const Text("Clear Filters")
                            )
                          ],
                        );
                      }

                      // ---------------- GROUPING LOGIC ----------------
                      // Group filtered results by Country
                      Map<String, List<QueryDocumentSnapshot>> groupedTrips = {};
                      for (var doc in filteredDocs) {
                        final data = doc.data() as Map<String, dynamic>;
                        String country = data['country'] ?? "Other Trips";
                        if (!groupedTrips.containsKey(country)) {
                          groupedTrips[country] = [];
                        }
                        groupedTrips[country]!.add(doc);
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: groupedTrips.length,
                        itemBuilder: (context, index) {
                          String countryName = groupedTrips.keys.elementAt(index);
                          List<QueryDocumentSnapshot> trips = groupedTrips[countryName]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Country Header
                              Padding(
                                padding: const EdgeInsets.only(top: 10, bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 16, color: Colors.pinkAccent),
                                    const SizedBox(width: 6),
                                    Text(
                                      countryName.toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.pink.shade300,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const Expanded(child: Divider(indent: 10)),
                                  ],
                                ),
                              ),
                              
                              // Cards
                              ...trips.map((doc) => _buildTripCard(context, doc)),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No trips planned yet!", style: TextStyle(color: Colors.grey)),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/home'),
            child: const Text("Ask Mochi to plan one!"),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final tripName = data['trip_name'] ?? "Unknown Trip";
    final duration = data['duration'] ?? "? Days";
    final tags = List<String>.from(data['tags'] ?? []);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TripDetailsScreen(
              tripId: doc.id,
              tripName: tripName,
              content: data['full_content'] ?? "",
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withOpacity(0.05),
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
                Expanded(
                  child: Text(
                    tripName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    duration,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.pink.shade400),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (tags.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(tag, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                )).toList(),
              ),
          ],
        ),
      ),
    );
  }
}