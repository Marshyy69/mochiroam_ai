import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/cloudinary_service.dart';

class EditMemoryScreen extends StatefulWidget {
  final Map<String, dynamic> memoryData;
  final String memoryId;

  const EditMemoryScreen({
    super.key,
    required this.memoryData,
    required this.memoryId,
  });

  @override
  State<EditMemoryScreen> createState() => _EditMemoryScreenState();
}

class _EditMemoryScreenState extends State<EditMemoryScreen> {
  late TextEditingController _titleController;
  late TextEditingController _reviewController;
  late int _rating;
  late List<Map<String, dynamic>> _highlights;
  late List<String> _existingImages;
  List<XFile> _newImages = [];
  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final data = widget.memoryData;
    final tripData = data['itinerary_data'] as Map<String, dynamic>? ?? {};

    _titleController = TextEditingController(
      text: data['title'] ?? tripData['trip_name'] ?? '',
    );
    _reviewController = TextEditingController(
      text: data['description'] ?? '',
    );
    _rating = (data['rating'] ?? 5).toInt();
    _highlights = List<Map<String, dynamic>>.from(
      (data['highlights'] as List?)?.map((h) => Map<String, dynamic>.from(h)) ?? [],
    );
    _existingImages = List<String>.from(data['images'] ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) setState(() => _newImages.addAll(images));
  }

  void _showAddTagDialog() {
    final headerCtrl = TextEditingController();
    final linkCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Add Highlight 📌",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
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
                setState(() => _highlights.add({
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

  TextField _dialogField(TextEditingController ctrl, String hint) => TextField(
        controller: ctrl,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 13),
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
              borderSide:
                  const BorderSide(color: Color(0xFFF06292), width: 1.5)),
        ),
      );

  Future<void> _saveChanges() async {
    if (_reviewController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please write a review!")));
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Upload new images
      List<String> newImageUrls = [];
      if (_newImages.isNotEmpty) {
        final files = _newImages.map((img) => File(img.path)).toList();
        newImageUrls = await CloudinaryService.uploadImages(files)
            .timeout(const Duration(seconds: 30));
      }

      final allImages = [..._existingImages, ...newImageUrls];

      final updates = {
        'title': _titleController.text.trim(),
        'description': _reviewController.text.trim(),
        'rating': _rating.toDouble(),
        'highlights': _highlights,
        'images': allImages,
      };

      // Update private_memories
      await Supabase.instance.client
          .from('private_memories')
          .update(updates)
          .eq('id', widget.memoryId);

      // Also update public_posts if this memory was public
      final isPublic = widget.memoryData['is_public'] ?? false;
      if (isPublic) {
        final authorUid = widget.memoryData['author_uid'] ?? '';
        final createdAt = widget.memoryData['created_at'] ?? '';
        // Find matching public post by author and created_at
        try {
          await Supabase.instance.client
              .from('public_posts')
              .update(updates)
              .eq('author_uid', authorUid)
              .eq('created_at', createdAt);
        } catch (_) {
          // Public post may not exist, that's fine
        }
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate changes saved
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text("Memory updated! ✨"),
          backgroundColor: const Color(0xFFF06292),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        title: const Text(
          "Edit Memory",
          style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Color(0xFF1A1A1A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isSaving
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF06292)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title ─────────────────────────────
                  _SectionCard(
                    title: "Memory Title ✍️",
                    child: TextField(
                      controller: _titleController,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF1A1A1A)),
                      decoration: _inputDecoration("Give your memory a name"),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Star Rating ────────────────────────
                  _SectionCard(
                    title: "Your Rating ⭐",
                    child: Row(
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () => setState(() => _rating = index + 1),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
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

                  // ── Review ─────────────────────────────
                  _SectionCard(
                    title: "Your Review 📝",
                    child: TextField(
                      controller: _reviewController,
                      maxLines: 4,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF1A1A1A)),
                      decoration: _inputDecoration(
                          "What were the highlights? Any hidden gems?"),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Highlights ─────────────────────────
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
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFC2185B)),
                        ),
                      ),
                    ),
                    child: _highlights.isEmpty
                        ? const Text(
                            "Tap + Add to tag hotels, restaurants, or links",
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFFBDBDBD)),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _highlights.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final tag = entry.value;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFCE4EC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFF8BBD0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: RichText(
                                        text: TextSpan(
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF1A1A1A)),
                                          children: [
                                            TextSpan(
                                              text: "${tag['header']}: ",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700),
                                            ),
                                            TextSpan(
                                              text: tag['link'],
                                              style: const TextStyle(
                                                  color: Color(0xFF1565C0)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => setState(
                                          () => _highlights.removeAt(idx)),
                                      child: const Icon(Icons.close,
                                          size: 14, color: Color(0xFF9E9E9E)),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),

                  const SizedBox(height: 14),

                  // ── Photos ─────────────────────────────
                  _SectionCard(
                    title: "Photos 📸",
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        // Existing uploaded images
                        ..._existingImages.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final url = entry.value;
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(url,
                                    width: 76,
                                    height: 76,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                        width: 76,
                                        height: 76,
                                        color: const Color(0xFFFCE4EC),
                                        child: const Icon(
                                            Icons.broken_image_outlined,
                                            color: Color(0xFFBDBDBD)))),
                              ),
                              Positioned(
                                top: 3,
                                right: 3,
                                child: GestureDetector(
                                  onTap: () => setState(
                                      () => _existingImages.removeAt(idx)),
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.close,
                                        size: 13, color: Color(0xFF757575)),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        // Newly picked images
                        ..._newImages.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final img = entry.value;
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(File(img.path),
                                    width: 76, height: 76, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 3,
                                right: 3,
                                child: GestureDetector(
                                  onTap: () => setState(
                                      () => _newImages.removeAt(idx)),
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.close,
                                        size: 13, color: Color(0xFF757575)),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        // Add button
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

                  const SizedBox(height: 24),

                  // ── Save Button ─────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF06292),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _saveChanges,
                      child: const Text(
                        "Save Changes ✨",
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding: const EdgeInsets.all(14),
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
      );
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
