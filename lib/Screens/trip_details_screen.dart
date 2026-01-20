import 'dart:io';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart'; 
import 'package:flutter_rating_bar/flutter_rating_bar.dart'; 
// import 'package:image_picker/image_picker.dart'; // 🚫 Commented out
// import 'package:firebase_storage/firebase_storage.dart'; // 🚫 Commented out

class TripDetailsScreen extends StatefulWidget {
  final String tripId;
  final String tripName;
  final Map<String, dynamic> tripData;
  final bool isCompleted; 

  const TripDetailsScreen({
    super.key,
    required this.tripId,
    required this.tripName,
    required this.tripData,
    this.isCompleted = false,
  });

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _days = [];

  // Review State
  double _rating = 0;
  final TextEditingController _reviewController = TextEditingController();
  
  // 🚫 COMMENTED OUT IMAGE VARIABLES
  // List<XFile> _selectedImages = [];
  bool _isUploading = false; // Kept this for the "saving" spinner

  @override
  void initState() {
    super.initState();
    _days = List.from(widget.tripData['days'] ?? []);
    _tabController = TabController(length: _days.length, vsync: this);
  }

  /* 🚫 COMMENTED OUT IMAGE PICKER
  Future<void> _pickImage() async {
    if (_selectedImages.length >= 3) return; 

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _selectedImages.add(image);
      });
    }
  }
  */

  // 🔥 2. SAVE REVIEW (No Photos)
  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please give a star rating! ⭐")));
      return;
    }

    setState(() => _isUploading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // List<String> imageUrls = []; // 🚫 No images for now

    try {
      /* 🚫 COMMENTED OUT FIREBASE STORAGE LOGIC
     for (var file in _selectedImages) {
        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        Reference ref = FirebaseStorage.instance.ref().child('trip_photos/${user.uid}/$fileName.jpg');
        
        // ✅ FIX FOR WEB UPLOAD
        if (kIsWeb) {
          await ref.putData(await file.readAsBytes()); // Upload as Bytes on Web
        } else {
          await ref.putFile(File(file.path)); // Upload as File on Mobile
        }

        String downloadUrl = await ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      }
      */

      // B. Save Review Data (With empty photos list)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('itineraries')
          .doc(widget.tripId)
          .update({
        'status': 'completed',
        'rating': _rating,
        'review_text': _reviewController.text.trim(),
        'photos': [], // ✅ Sending empty list to prevent errors
      });

      if (!mounted) return;
      Navigator.pop(context); // Close dialog
      Navigator.pop(context); // Go back to list
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Trip saved to Memories! 📸")));

    } catch (e) {
      print("Error saving: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // 🔥 3. SHOW REVIEW DIALOG
  void _showCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder( 
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("How was your trip? ✨", textAlign: TextAlign.center),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Rate your experience:", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 10),
                    
                    // ⭐ RATING BAR
                    RatingBar.builder(
                      initialRating: 0,
                      minRating: 1,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                      itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                      onRatingUpdate: (rating) {
                        setDialogState(() => _rating = rating);
                      },
                    ),

                    const SizedBox(height: 20),

                    // 📝 REVIEW TEXT
                    TextField(
                      controller: _reviewController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "What was your favorite memory?",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),

                    /* 🚫 COMMENTED OUT PHOTO UI
                    const SizedBox(height: 20),
                    const Text("Upload memorable photos (Max 3):", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ..._selectedImages.map((file) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            // ✅ FIX: WEB SUPPORT FOR IMAGE PREVIEW
                            child: kIsWeb 
                                ? Image.network(file.path, width: 60, height: 60, fit: BoxFit.cover)
                                : Image.file(File(file.path), width: 60, height: 60, fit: BoxFit.cover),
                          ),
                        )),
                        if (_selectedImages.length < 3)
                          GestureDetector(
                            onTap: () async {
                              await _pickImage();
                              setDialogState(() {}); 
                            },
                            child: Container(
                              width: 60, height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade400), 
                              ),
                              child: const Icon(Icons.add_a_photo, color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                    */
                  ],
                ),
              ),
              actions: [
                if (_isUploading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _submitReview(); 
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
                    child: const Text("Finish Trip", style: TextStyle(color: Colors.white)),
                  ),
                ]
              ],
            );
          },
        );
      },
    );
  }

  // --- HELPERS ---
  Future<void> _toggleActivity(int dayIndex, int activityIndex, bool? value) async {
    if (widget.isCompleted) return;
    setState(() => _days[dayIndex]['activities'][activityIndex]['isDone'] = value);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users').doc(user.uid)
          .collection('itineraries').doc(widget.tripId)
          .update({'trip_data.days': _days});
    }
  }

  void _shareTrip() {
    String shareText = "✈️ My Trip to ${widget.tripName} with MochiRoam!\n\n";
    for (var day in _days) {
      shareText += "📅 Day ${day['day']}: ${day['theme']}\n";
      for (var act in day['activities']) {
         shareText += "• ${act['time']}: ${act['title']}\n";
      }
      shareText += "\n";
    }
    shareText += "Planned by Mochi AI 🍡";
    Share.share(shareText);
  }

  Color _getTimeColor(String time) {
    if (time.contains("Lunch") || time.contains("Dinner")) return Colors.orange.shade50;
    if (time.contains("Morning") || time.contains("AM")) return Colors.blue.shade50;
    if (time.contains("Afternoon") || time.contains("PM")) return Colors.yellow.shade50;
    if (time.contains("Evening") || time.contains("Night")) return Colors.purple.shade50;
    return Colors.grey.shade50;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: widget.isCompleted ? Colors.grey : Colors.pink.shade300,
        title: Text(widget.tripName, style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: _shareTrip)
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
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
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _days.map((dayData) {
                final activities = dayData['activities'] as List;
                List<Map<String, dynamic>> attractions = [];
                List<Map<String, dynamic>> foodPlaces = [];

                for (int i = 0; i < activities.length; i++) {
                  final item = activities[i];
                  final time = (item['time'] ?? "").toString();
                  if (time.contains("Lunch") || time.contains("Dinner")) {
                    foodPlaces.add({'data': item, 'index': i});
                  } else {
                    attractions.add({'data': item, 'index': i});
                  }
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        decoration: BoxDecoration(color: Colors.pink.shade50, borderRadius: BorderRadius.circular(20)),
                        child: Text("✨ Today's Theme: ${dayData['theme']}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.pink.shade400), textAlign: TextAlign.center),
                      ),
                    ),
                    ...attractions.map((entry) => _buildActivityCard(dayData, entry['data'], entry['index'])),
                    const SizedBox(height: 20),
                    if (foodPlaces.isNotEmpty) ...[
                      Row(
                        children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.shade100, shape: BoxShape.circle), child: const Icon(Icons.restaurant, color: Colors.orange, size: 20)),
                          const SizedBox(width: 10),
                          const Text("Food places nearby! 🍜", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...foodPlaces.map((entry) => _buildActivityCard(dayData, entry['data'], entry['index'])),
                    ]
                  ],
                );
              }).toList(),
            ),
          ),
          if (!widget.isCompleted)
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 5),
                  onPressed: _showCompleteDialog, 
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text("Finish Trip", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
        ],
      ),
    );
  }

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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: CheckboxListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        value: isDone,
        activeColor: Colors.pink,
        onChanged: widget.isCompleted ? null : (val) => _toggleActivity(_days.indexOf(dayData), originalIndex, val),
        title: Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)), child: Text(time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SizedBox(height: 8), Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, decoration: isDone ? TextDecoration.lineThrough : null, color: isDone ? Colors.grey : Colors.black87)), const SizedBox(height: 4), Text(desc, style: const TextStyle(fontSize: 14, color: Colors.black54))]),
      ),
    );
  }
}