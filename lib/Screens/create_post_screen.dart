import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/itinerary_model.dart';
import '../models/post_model.dart';
import '../services/cloudinary_service.dart';

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
  bool _isPublic = true;
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) setState(() => _selectedImages.addAll(images));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  void _showAddTagDialog() {
    final headerCtrl = TextEditingController();
    final linkCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Add Highlight 📌",
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(headerCtrl, "E.g., My Hotel, Must Try Food"),
            const SizedBox(height: 10),
            _dialogField(linkCtrl, "Description or link..."),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel",
                  style: TextStyle(color: Color(0xFF9E9E9E)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF06292),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (headerCtrl.text.isNotEmpty && linkCtrl.text.isNotEmpty) {
                setState(() => _customTags.add({
                      'header': headerCtrl.text.trim(),
                      'link': linkCtrl.text.trim(),
                    }));
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  TextField _dialogField(TextEditingController ctrl, String hint) =>
      TextField(
        controller: ctrl,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(color: Color(0xFFBDBDBD), fontSize: 13),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF0F0F0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF0F0F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: Color(0xFFF06292), width: 1.5)),
        ),
      );

  Future<List<String>> _uploadImages() async {
    if (_selectedImages.isEmpty) return [];
    final files = _selectedImages.map((img) => File(img.path)).toList();
    return CloudinaryService.uploadImages(files);
  }

  Future<void> _publishPost() async {
    if (_reviewController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please write a quick review!")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      // Fetch user profile with a timeout so it never hangs forever
      String authorName = "Traveler";
      String authorAvatar = "🍡";
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 10));
        if (userDoc.exists) {
          authorName = userDoc.data()?['username'] ?? "Traveler";
          authorAvatar = userDoc.data()?['avatar'] ?? "🍡";
        }
      } catch (_) {
        // Use defaults if user doc fetch fails or times out
        debugPrint("Could not fetch user profile, using defaults.");
      }

      // Upload images with a timeout
      List<String> imageUrls = [];
      try {
        imageUrls = await _uploadImages()
            .timeout(const Duration(seconds: 30));
      } catch (_) {
        debugPrint("Image upload timed out or failed, continuing without images.");
      }

      final newPost = PostModel(
        authorUid: user.uid,
        authorName: authorName,
        authorAvatar: authorAvatar,
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

      // Fire-and-forget writes to avoid blocking the UI if offline
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('private_memories')
          .add(newPost.toMap());

      // Push to community feed if public
      if (_isPublic) {
        FirebaseFirestore.instance
            .collection('public_posts')
            .add(newPost.toMap());
      }

      // Delete from active itineraries
      if (widget.trip.id != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('itineraries')
            .doc(widget.trip.id)
            .delete();
      }

      if (mounted) {
        Navigator.pop(context); // Pop CreatePostScreen
        Navigator.pop(context); // Pop TripDetailsScreen
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isPublic
              ? "Trip archived & published! 🌍"
              : "Trip saved to memories! 📔"),
          backgroundColor: const Color(0xFFF06292),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      // ALWAYS stop the spinner, no matter what happens
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        title: const Text(
          "Create Memory",
          style: TextStyle(
              fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isUploading
          ? const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFFF06292)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Title ─────────────────────────────────────
                  _SectionCard(
                    title: "Title your Memory ✍️",
                    child: _buildTextField(
                      controller: _titleController,
                      hint: "E.g., The Best Sushi in Tokyo!",
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Star Rating ───────────────────────────────
                  _SectionCard(
                    title: "How was the trip? ⭐",
                    child: Row(
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _rating = index + 1),
                          child: Padding(
                            padding:
                                const EdgeInsets.only(right: 4),
                            child: Icon(
                              index < _rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: const Color(0xFFFFC107),
                              size: 36,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Review ────────────────────────────────────
                  _SectionCard(
                    title: "Your Review 📝",
                    child: TextField(
                      controller: _reviewController,
                      maxLines: 4,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF1A1A1A)),
                      decoration: InputDecoration(
                        hintText:
                            "What were the highlights? Any hidden gems?",
                        hintStyle: const TextStyle(
                            color: Color(0xFFBDBDBD), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: Color(0xFFF0F0F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: Color(0xFFF0F0F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: Color(0xFFF06292), width: 1.5),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Highlights ────────────────────────────────
                  _SectionCard(
                    title: "Trip Highlights 📌",
                    trailing: GestureDetector(
                      onTap: _showAddTagDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCE4EC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "+ Add",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFC2185B)),
                        ),
                      ),
                    ),
                    child: _customTags.isEmpty
                        ? const Text(
                            "Tap + Add to tag hotels, restaurants, or links",
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFBDBDBD)),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _customTags
                                .map((tag) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFCE4EC),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(
                                                0xFFF8BBD0)),
                                      ),
                                      child: RichText(
                                        text: TextSpan(
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF1A1A1A)),
                                          children: [
                                            TextSpan(
                                              text: "${tag['header']}: ",
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w700),
                                            ),
                                            TextSpan(
                                              text: tag['link'],
                                              style: const TextStyle(
                                                  color:
                                                      Color(0xFF1565C0)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                  ),

                  const SizedBox(height: 14),

                  // ── Photos ────────────────────────────────────
                  _SectionCard(
                    title: "Add Photos 📸",
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ..._selectedImages.map((img) => Stack(
                              children: [
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  child: Image.file(File(img.path),
                                      width: 76,
                                      height: 76,
                                      fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 3,
                                  right: 3,
                                  child: GestureDetector(
                                    onTap: () => setState(() =>
                                        _selectedImages.remove(img)),
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.close,
                                          size: 13,
                                          color: Color(0xFF757575)),
                                    ),
                                  ),
                                ),
                              ],
                            )),
                        GestureDetector(
                          onTap: _pickImages,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCE4EC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFF8BBD0),
                                  style: BorderStyle.solid),
                            ),
                            child: const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Color(0xFFF06292),
                                size: 28),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Public toggle ─────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFF5E0E8)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _isPublic
                                ? const Color(0xFFFCE4EC)
                                : const Color(0xFFF5F5F5),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _isPublic ? "🌍" : "🔒",
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Post to Community Feed",
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700),
                              ),
                              Text(
                                _isPublic
                                    ? "Everyone can see and copy this trip."
                                    : "Only visible in your memories.",
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF9E9E9E)),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isPublic,
                          activeColor: const Color(0xFFF06292),
                          onChanged: (v) =>
                              setState(() => _isPublic = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Submit ────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF06292),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: _publishPost,
                      child: const Text(
                        "Save Memory ✨",
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFFBDBDBD), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFF06292), width: 1.5),
        ),
      ),
    );
  }
}

// ── Section Card ──────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard(
      {required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF5E0E8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF06292).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}