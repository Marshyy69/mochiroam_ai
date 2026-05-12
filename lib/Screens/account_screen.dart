import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/bottom_nav_bar.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isHalal = false; 
  bool _isLoading = true;
  String _appVersion = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = "v${packageInfo.version} (Build ${packageInfo.buildNumber})";
    });

    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists && doc.data() != null) {
        setState(() {
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

  Future<void> _toggleHalal(bool value) async {
    setState(() => _isHalal = value);
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'is_halal': value,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? "Halal Mode ON 🕌" : "Halal Mode OFF")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Simple Avatar Logic (Initials)
    String initials = "U";
    if (user?.email != null && user!.email!.isNotEmpty) {
      initials = user!.email![0].toUpperCase();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("My Account"),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.pinkAccent),
            onPressed: () {
               Navigator.pushNamed(context, "/profile");
            },
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Profile Header
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.pink.shade100,
                          child: Text(
                            initials,
                            style: const TextStyle(fontSize: 40, color: Colors.pink, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user?.email ?? "Guest User",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        const Text("Traveler Level 1 🌟", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Settings List
                  ListTile(
                    leading: const Icon(Icons.restaurant_menu, color: Colors.green),
                    title: const Text("Halal Preference"),
                    subtitle: const Text("Prioritize Halal food options"),
                    trailing: Switch(
                      value: _isHalal,
                      activeColor: Colors.green,
                      onChanged: _toggleHalal,
                    ),
                  ),

                  const SizedBox(height: 10),

                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: const Text("Other Preferences"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pushNamed(context, "/preferences");
                    },
                  ),

                  const Divider(),

                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text("Logout", style: TextStyle(color: Colors.red)),
                    // 🛡️ UPDATED LOGOUT LOGIC
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();

                      if (!context.mounted) return;
                      
                      // Removes all previous routes so user can't "Back" to this screen
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        "/login", 
                        (Route<dynamic> route) => false, 
                      );
                    },
                  ),
             
                  const SizedBox(height: 40),

                  Center(
                    child: Text(
                      "MochiRoam AI - $_appVersion",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }
}