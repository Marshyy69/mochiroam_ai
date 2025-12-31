// lib/screens/account_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import '../widgets/bottom_nav_bar.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isHalal = false; // Default value
  bool _isLoading = true; // To prevent toggle jumping

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // 1. Load current setting from Firestore
  Future<void> _loadPreferences() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          // If the field doesn't exist yet, default to false
          _isHalal = doc.data()!['is_halal'] ?? false;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error loading preferences: $e");
      setState(() => _isLoading = false);
    }
  }

  // 2. Save new setting to Firestore
  Future<void> _toggleHalal(bool value) async {
    if (user == null) return;

    // Update UI immediately for snappiness
    setState(() => _isHalal = value); 

    // Save to backend
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'is_halal': value,
    }, SetOptions(merge: true)); // 'merge: true' prevents overwriting other data
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value ? "Halal preference ON 🌙" : "Halal preference OFF"),
        backgroundColor: value ? Colors.green.shade700 : Colors.grey.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Account"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Greeting
              const Text(
                "Hi 👋",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              if (user?.email != null) ...[
                const SizedBox(height: 4),
                Text(user!.email!, style: const TextStyle(color: Colors.grey)),
              ],

              const SizedBox(height: 30),
              
              const Text(
                "Settings",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 10),

              // 🔥 NEW: Halal Toggle Switch
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: SwitchListTile(
                  title: const Text("Muslim / Halal Friendly", style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text("Prioritize Halal food & prayer facilities", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.mosque, color: Colors.green.shade600),
                  ),
                  value: _isHalal,
                  activeColor: Colors.green,
                  onChanged: _toggleHalal,
                ),
              ),

              const SizedBox(height: 20),

              // ---------------- Existing Preferences (Optional) ----------------
              // You can keep this if you have other settings, or remove it if 'Halal' was the only one.
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text("Other Preferences"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pushNamed(context, "/preferences");
                },
              ),

              const Divider(),

              // ---------------- Logout ----------------
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("Logout", style: TextStyle(color: Colors.red)),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();

                  if (!context.mounted) return;
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    "/login",
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),

      bottomNavigationBar: const BottomNavBar(currentIndex: 2),
    );
  }
}