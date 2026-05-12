import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/itinerary_model.dart';
import '../models/post_model.dart';

class CreatePostScreen extends StatefulWidget {
  final ItineraryModel trip;

  const CreatePostScreen({super.key, required this.trip});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _reviewController = TextEditingController();

  List<Map<String, dynamic>> _customTags = [];

  int _rating = 5;
  bool _isPublic = true; // Toggle for Community vs Private
  bool _isUploading = false;
  
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];

  // 📸 Pick multiple images from gallery
  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  // 🆕 THE DIALOG TO ADD A NEW TAG
  void _showAddTagDialog() {
    TextEditingController headerCtrl = TextEditingController();
    TextEditingController linkCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Add a Highlight 📌", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: headerCtrl,
                decoration: const InputDecoration(hintText: "E.g., My Hotel, Must Try Food"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: linkCtrl,
                decoration: const InputDecoration(hintText: "Description or Link..."),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white),
              onPressed: () {
                if (headerCtrl.text.isNotEmpty && linkCtrl.text.isNotEmpty) {
                  setState(() {
                    _customTags.add({
                      'header': headerCtrl.text.trim(),
                      'link': linkCtrl.text.trim(),
                    });
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  // ☁️ Upload to Google Firebase Storage
  Future<List<String>> _uploadImagesToStorage() async {
    List<String> downloadUrls = [];
    final uid = FirebaseAuth.instance.currentUser!.uid;

    for (var image in _selectedImages) {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = FirebaseStorage.instance.ref().child('trip_photos/$uid/$fileName');
      
      UploadTask uploadTask = ref.putFile(File(image.path));
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      downloadUrls.add(downloadUrl);
    }
    return downloadUrls;
  }

  // 🚀 Save the Post
// 🚀 Save the Post & Archive the Itinerary
  Future<void> _publishPost() async {
    if (_reviewController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please write a quick review!")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      // 1. Upload images first
      List<String> imageUrls = await _uploadImagesToStorage();

      // 2. Create the Post Object
      final newPost = PostModel(
        authorUid: user.uid,
        authorName: userDoc.data()?['username'] ?? "Traveler",
        authorAvatar: userDoc.data()?['avatar'] ?? "🍡",
        country: widget.trip.country,
        title: _titleController.text.trim(),
        description: _reviewController.text.trim(),
        highlights: _customTags,
        rating: _rating.toDouble(),
        createdAt: DateTime.now(),
        itinerary: widget.trip,
        isPublic: _isPublic,
        images: imageUrls,
      );

      // 3. ALWAYS save to Private Memories so you have an archive
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('private_memories')
          .add(newPost.toMap());

      // 4. If public toggle is on, ALSO push to the Community Feed
      if (_isPublic) {
        await FirebaseFirestore.instance.collection('public_posts').add(newPost.toMap());
      }

      // 5. ✨ THE MAGIC TRICK: Delete the original from active itineraries!
      if (widget.trip.id != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('itineraries')
            .doc(widget.trip.id)
            .delete();
      }

      if (mounted) {
        // ✨ DOUBLE POP: Close the create screen AND the details screen!
        Navigator.pop(context); 
        Navigator.pop(context); 
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isPublic ? "Trip Archived & Published! 🌍" : "Trip Archived to Memories! 📔"),
            backgroundColor: Colors.pinkAccent,
          )
        );
      }
    } catch (e) {
      print("Upload Error: $e");
      if (mounted) {
         setState(() => _isUploading = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        title: const Text("Create Memory", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isUploading
          ? const Center(child: CircularProgressIndicator(color: Colors.pink))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text("Title your Memory", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: "E.g., The Best Sushi in Tokyo!",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ⭐️ Star Rating
                  const Text("How was the trip?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 36,
                        ),
                        onPressed: () => setState(() => _rating = index + 1),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // 📝 Written Review
                  TextField(
                    controller: _reviewController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "What were the highlights? Any hidden gems?",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 🆕 THE TAGS SECTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Trip Highlights", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ActionChip(
                        label: const Text("+ Tag"),
                        backgroundColor: Colors.pink.shade50,
                        side: BorderSide.none,
                        onPressed: _showAddTagDialog,
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  // Display the tags they added
                  if (_customTags.isNotEmpty)
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _customTags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.pink.shade100)),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black87, fontSize: 13),
                            children: [
                              TextSpan(text: "${tag['header']}: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: tag['link'], style: const TextStyle(color: Colors.blueAccent)),
                            ]
                          )
                        ),
                      )).toList(),
                    ),
                  const SizedBox(height: 30),

                  // 📸 Image Picker
                  const Text("Add Photos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ..._selectedImages.map((img) => ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(File(img.path), width: 80, height: 80, fit: BoxFit.cover),
                          )),
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.add_a_photo, color: Colors.pinkAccent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // 🔒 Public vs Private Toggle
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: SwitchListTile(
                      title: const Text("Post to Community Feed 🌍"),
                      subtitle: Text(_isPublic ? "Everyone can see and copy this trip." : "Only you can see this in your memories."),
                      activeColor: Colors.pinkAccent,
                      value: _isPublic,
                      onChanged: (val) => setState(() => _isPublic = val),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 🚀 Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _publishPost,
                      child: const Text("Save Memory", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}