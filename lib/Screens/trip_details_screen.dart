import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripDetailsScreen extends StatefulWidget {
  final String tripId;
  final String tripName;
  final String content;

  const TripDetailsScreen({
    super.key,
    required this.tripId,
    required this.tripName,
    required this.content,
  });

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  late TextEditingController _contentController;
  late TextEditingController _titleController;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.content);
    _titleController = TextEditingController(text: widget.tripName);
  }

  @override
  void dispose() {
    _contentController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  // 🔥 DELETE FUNCTION
  Future<void> _deleteTrip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Trip?"),
        content: const Text("Are you sure? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('itineraries')
          .doc(widget.tripId)
          .delete();
      
      if (!mounted) return;
      Navigator.pop(context); // Go back to list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Trip deleted.")),
      );
    }
  }

  // 🔥 SAVE EDITS FUNCTION
  Future<void> _saveChanges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('itineraries')
        .doc(widget.tripId)
        .update({
      'trip_name': _titleController.text.trim(),
      'full_content': _contentController.text,
      // We don't update 'created_at' so it stays in the same order
    });

    setState(() {
      _isLoading = false;
      _isEditing = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Changes saved! ✅")),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If we are editing, show TextField. If not, show Markdown.
    Widget contentWidget;
    if (_isEditing) {
      contentWidget = TextField(
        controller: _contentController,
        maxLines: null, // Grows with text
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: "Edit your itinerary...",
          contentPadding: EdgeInsets.all(16),
        ),
      );
    } else {
      contentWidget = Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: MarkdownBody(
          data: _contentController.text, // Show current text
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
            strong: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.pink.shade600,
            ),
            listBullet: TextStyle(color: Colors.pink.shade400, fontSize: 16),
            blockSpacing: 12.0,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.pink.shade300,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isEditing
            ? TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Trip Name",
                  hintStyle: TextStyle(color: Colors.white70),
                ),
              )
            : Text(
                _titleController.text,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
        actions: [
          // Edit / Save Button
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit, color: Colors.white),
            onPressed: _isLoading ? null : (_isEditing ? _saveChanges : () => setState(() => _isEditing = true)),
          ),
          // Delete Button (Only show when not editing)
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _isLoading ? null : _deleteTrip,
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isEditing) ...[
                       // Header Icon
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.pink.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.map_outlined, size: 40, color: Colors.pink),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    contentWidget,
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }
}