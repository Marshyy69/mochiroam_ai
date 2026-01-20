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

class _ItineraryPageState extends State<ItineraryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ---------------- STATE: Active Filters ----------------
  String _selectedRegion = "All"; // All, Asia, Europe, etc.
  String _selectedTripType = "All"; // All, Family, Couple, Friends
  bool _filterHalal = false;
  
  // Unused in your code but kept just in case
  String _durationFilter = "Any"; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // ---------------- UI: The Filter Modal (YOUR EXACT CODE) ----------------
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) {
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

      // -------------------- APP BAR (Updated with Tabs) --------------------
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.pink,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.pink,
          tabs: const [
            Tab(text: "Upcoming ✈️"),
            Tab(text: "Memories 📸"),
          ],
        ),
      ),

      // -------------------- BODY --------------------
      body: user == null
          ? const Center(child: Text("Please log in to view itineraries"))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTripList(user.uid, isCompleted: false), // Upcoming
                _buildTripList(user.uid, isCompleted: true),  // Memories
              ],
            ),

      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
    );
  }

  // 🔥 REUSABLE LIST BUILDER (Keeps your exact style)
  Widget _buildTripList(String uid, {required bool isCompleted}) {
    return Column(
      children: [
        // 🔥 HEADER WITH FILTER BUTTON (Your Original Code)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(isCompleted ? Icons.photo_library : Icons.flight_takeoff, size: 22, color: Colors.black),
                  const SizedBox(width: 8),
                  Text(
                    isCompleted ? "Your past trips" : "Your saved itineraries",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
                .doc(uid)
                .collection('itineraries')
                .orderBy('created_at', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState(isCompleted);
              }

              var docs = snapshot.data!.docs;

              // ---------------- APPLY FILTERS ----------------
              var filteredDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                
                // 1. Status Filter (New!)
                String status = data['status'] ?? "upcoming";
                if (isCompleted && status != 'completed') return false;
                if (!isCompleted && status == 'completed') return false;

                String continent = data['continent'] ?? "Uncategorized";
                List<dynamic> tags = data['tags'] ?? [];
                
                // 2. Region Filter
                if (_selectedRegion != "All" && continent != _selectedRegion) return false;

                // 3. Trip Type Filter
                if (_selectedTripType != "All") {
                   if (!tags.contains(_selectedTripType)) return false; 
                }

                // 4. Halal Filter
                if (_filterHalal && !tags.contains("Halal")) return false;

                return true;
              }).toList();
              // ----------------------------------------------

              if (filteredDocs.isEmpty) {
                return _buildEmptyState(isCompleted, isFilterEmpty: true);
              }

              // ---------------- GROUPING LOGIC (Your Original) ----------------
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
                      ...trips.map((doc) => _buildTripCard(context, doc, isCompleted)),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isCompleted, {bool isFilterEmpty = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFilterEmpty ? Icons.filter_list_off : (isCompleted ? Icons.photo_album : Icons.map_outlined), 
            size: 60, 
            color: Colors.grey.shade300
          ),
          const SizedBox(height: 16),
          Text(
            isFilterEmpty 
              ? "No trips match your filters!" 
              : (isCompleted ? "No memories yet!" : "No upcoming trips!"), 
            style: const TextStyle(color: Colors.grey)
          ),
          if (isFilterEmpty)
            TextButton(
              onPressed: () => setState(() {
                _selectedRegion = "All";
                _selectedTripType = "All";
                _filterHalal = false;
              }), 
              child: const Text("Clear Filters"),
            ),
          if (!isFilterEmpty && !isCompleted)
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/home'),
              child: const Text("Ask Mochi to plan one!"),
            ),
        ],
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, DocumentSnapshot doc, bool isCompleted) {
    final data = doc.data() as Map<String, dynamic>;
    final tripName = data['trip_name'] ?? "Unknown Trip";
    final duration = data['duration'] ?? "? Days";
    final tags = List<String>.from(data['tags'] ?? []);

    return GestureDetector(
      onTap: () {
        // Safe Data Parsing
        Map<String, dynamic> tripData = {};
        if (data['trip_data'] != null) {
          tripData = data['trip_data'] as Map<String, dynamic>;
        } else {
           tripData = {
             "days": [], 
             "trip_name": tripName,
             "summary": data['full_content'] ?? "Legacy Trip"
           };
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TripDetailsScreen(
              tripId: doc.id,
              tripName: tripName,
              tripData: tripData,
              isCompleted: isCompleted, 
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
            // 1. TOP ROW: Name + Duration
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
                    color: isCompleted ? Colors.grey.shade100 : Colors.pink.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    duration,
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.bold, 
                      color: isCompleted ? Colors.grey : Colors.pink.shade400
                    ),
                  ),
                ),
              ],
            ),
            
            // 👇👇👇 PASTE THE NEW CODE HERE (BETWEEN ROW AND TAGS) 👇👇👇
            
            const SizedBox(height: 8),

            // 🔥 Show Rating if available (Only for Completed Trips)
            if (isCompleted && data['rating'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    // Generate Star Icons based on rating
                    ...List.generate(5, (index) {
                       double rating = (data['rating'] as num).toDouble();
                       if (index < rating) {
                         return const Icon(Icons.star, size: 16, color: Colors.amber);
                       } else {
                         return const Icon(Icons.star_border, size: 16, color: Colors.grey);
                       }
                    }),
                    const SizedBox(width: 5),
                    Text(
                      "${data['rating']}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                    )
                  ],
                ),
              ),

            // 👆👆👆 END OF NEW CODE 👆👆👆

            // 3. TAGS WRAP
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