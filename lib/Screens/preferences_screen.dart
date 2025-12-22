// lib/screens/preferences_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  int pax = 1;
  bool hasChildren = false;
  bool hasElderly = false;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => loading = false);
      return;
    }

    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        pax = (data['pax'] ?? 1) as int;
        hasChildren = (data['hasChildren'] ?? false) as bool;
        hasElderly = (data['hasElderly'] ?? false) as bool;
      });
    }

    setState(() => loading = false);
  }

  Future<void> _savePrefs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'pax': pax,
      'hasChildren': hasChildren,
      'hasElderly': hasElderly,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Preferences saved ✅')));

    Navigator.pop(context); // go back after save
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Travel Preferences")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Pax row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "How many pax?",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: pax > 1 ? () => setState(() => pax--) : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      "$pax",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => pax++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Children toggle
            SwitchListTile(
              title: const Text("Trip includes children"),
              value: hasChildren,
              onChanged: (v) => setState(() => hasChildren = v),
            ),

            // Elderly toggle
            SwitchListTile(
              title: const Text("Trip includes elderly"),
              value: hasElderly,
              onChanged: (v) => setState(() => hasElderly = v),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _savePrefs,
                child: const Text("Save Preferences"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
