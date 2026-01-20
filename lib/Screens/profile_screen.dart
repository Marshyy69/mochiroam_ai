import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  
  String _selectedAvatar = "🍡"; // Default Avatar
  bool _isLoading = true;
  bool _isSaving = false;

  // 🎭 Available Avatars (Emojis work great!)
  final List<String> _avatars = ["🍡", "🐼", "🐱", "🦊", "🐸", "🐰", "🐯", "🐨"];

  // 📊 Stats
  int _upcomingTrips = 0;
  int _completedTrips = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (user == null) return;

    try {
      // 1. Get User Profile
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      
      // 2. Get Trip Stats
      QuerySnapshot trips = await FirebaseFirestore.instance
          .collection('users').doc(user!.uid).collection('itineraries').get();

      int upcoming = 0;
      int completed = 0;
      
      for (var doc in trips.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['status'] == 'completed') {
          completed++;
        } else {
          upcoming++;
        }
      }

      if (mounted) {
        setState(() {
          _nameController.text = userDoc.exists ? (userDoc['username'] ?? "Traveler") : "Traveler";
          _selectedAvatar = userDoc.exists ? (userDoc['avatar'] ?? "🍡") : "🍡";
          _upcomingTrips = upcoming;
          _completedTrips = completed;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading profile: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (user == null) return;
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'username': _nameController.text.trim(),
        'avatar': _selectedAvatar,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update FirebaseAuth display name
      await user!.updateDisplayName(_nameController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated! ✅")));
        Navigator.pop(context); // Go back
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
       // Navigate back to Login Screen (Adjust route name if needed)
       Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
            tooltip: "Logout",
          )
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 🎭 AVATAR SECTION
                  Center(
                    child: Container(
                      width: 100, height: 100,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.pink.shade100, width: 2),
                      ),
                      child: Text(_selectedAvatar, style: const TextStyle(fontSize: 50)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text("Choose your avatar", style: TextStyle(color: Colors.grey)),
                  
                  const SizedBox(height: 15),
                  
                  // AVATAR SELECTOR GRID
                  Wrap(
                    spacing: 10,
                    children: _avatars.map((avatar) {
                      final isSelected = _selectedAvatar == avatar;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedAvatar = avatar),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.pink.shade100 : Colors.grey.shade100,
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: Colors.pink, width: 2) : null,
                          ),
                          child: Text(avatar, style: const TextStyle(fontSize: 24)),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 30),

                  // 📝 EDIT NAME
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "Username",
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 📊 STATS CARDS
                  Row(
                    children: [
                      _buildStatCard("Upcoming", _upcomingTrips, Colors.blue.shade50, Colors.blue),
                      const SizedBox(width: 16),
                      _buildStatCard("Memories", _completedTrips, Colors.purple.shade50, Colors.purple),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // 💾 SAVE BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _isSaving 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Save Changes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, int count, Color bgColor, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(count.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}