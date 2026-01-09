import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  // Basic
  int pax = 1;
  bool hasElderly = false;
  
  // Children Logic
  bool hasChildren = false;
  int childrenCount = 0;
  final TextEditingController _childAgeController = TextEditingController();

  // ✅ FIX 1: Define these lists as constants so we can match them exactly
  final List<String> budgetOptions = [
    "Budget Friendly 💸", 
    "Standard ⚖️", 
    "Luxury ✨"
  ];

  final List<String> accommodationOptions = [
    "Hotel 🏨", 
    "Homestay / Airbnb 🏡", 
    "Hostel / Dorm 🛏️", 
    "Resort 🌴"
  ];

  // ✅ FIX 2: Initialize with the EXACT string (including emojis)
  late String budget;
  late String accommodation;

  List<String> selectedVibes = [];
  final List<String> vibeOptions = [
    "Nature 🌳", "Adventure 🧗", "Shopping 🛍️", 
    "Culture 🏯", "Foodie 🍜", "Relaxing 💆‍♀️", 
    "City Life 🏙️", "Photography 📸"
  ];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    // Set defaults immediately
    budget = budgetOptions[1]; // Standard ⚖️
    accommodation = accommodationOptions[0]; // Hotel 🏨
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => loading = false);
      return;
    }

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        pax = (data['pax'] ?? 1) as int;
        hasChildren = (data['hasChildren'] ?? false) as bool;
        childrenCount = (data['childrenCount'] ?? 0) as int;
        _childAgeController.text = (data['childrenAgeRange'] ?? "") as String;
        hasElderly = (data['hasElderly'] ?? false) as bool;
        selectedVibes = List<String>.from(data['tripVibe'] ?? []);

        // ✅ FIX 3: Safety Check
        // If the database has "Standard" (old) but we need "Standard ⚖️",
        // we check if the loaded value exists in our list. If not, reset to default.
        String loadedBudget = (data['budget'] ?? budgetOptions[1]) as String;
        if (budgetOptions.contains(loadedBudget)) {
          budget = loadedBudget;
        } else {
          budget = budgetOptions[1]; // Fallback
        }

        String loadedAcc = (data['accommodation'] ?? accommodationOptions[0]) as String;
        if (accommodationOptions.contains(loadedAcc)) {
          accommodation = loadedAcc;
        } else {
          accommodation = accommodationOptions[0]; // Fallback
        }
      });
    } else {
      // Defaults if new user
      setState(() {
        selectedVibes = ["Relaxing 💆‍♀️"];
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
      'childrenCount': hasChildren ? childrenCount : 0,
      'childrenAgeRange': hasChildren ? _childAgeController.text : "",
      'hasElderly': hasElderly,
      'tripVibe': selectedVibes.isEmpty ? ["Standard"] : selectedVibes,
      'budget': budget,
      'accommodation': accommodation,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preferences saved! ✅')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Travel Preferences")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Who is traveling?"),
            
            _buildCounterRow("Total Pax", pax, (val) => setState(() => pax = val)),
            const SizedBox(height: 10),

            SwitchListTile(
              title: const Text("Traveling with Children?"),
              value: hasChildren,
              activeColor: Colors.pink,
              onChanged: (v) => setState(() => hasChildren = v),
            ),

            if (hasChildren) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
                child: Column(
                  children: [
                    _buildCounterRow("How many kids?", childrenCount, (val) => setState(() => childrenCount = val)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _childAgeController,
                      decoration: InputDecoration(
                        labelText: "Age range (e.g. 5-10 years)",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SwitchListTile(
              title: const Text("Traveling with Elderly?"),
              subtitle: const Text("We will suggest fewer stairs & easy walks"),
              value: hasElderly,
              activeColor: Colors.pink,
              onChanged: (v) => setState(() => hasElderly = v),
            ),

            const Divider(height: 40),
            _buildSectionTitle("Trip Style & Budget"),

            const Text("What kind of trip do you prefer? (Select multiple)", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0,
              children: vibeOptions.map((vibe) {
                final isSelected = selectedVibes.contains(vibe);
                return FilterChip(
                  label: Text(vibe),
                  selected: isSelected,
                  selectedColor: Colors.pink.shade100,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        selectedVibes.add(vibe);
                      } else {
                        selectedVibes.remove(vibe);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ✅ BUDGET DROPDOWN
            DropdownButtonFormField<String>(
              value: budget, // This value MUST exist in items
              decoration: _inputDecoration("Budget Level"),
              items: budgetOptions.map((String val) {
                return DropdownMenuItem(value: val, child: Text(val));
              }).toList(),
              onChanged: (val) => setState(() => budget = val!),
            ),

            const SizedBox(height: 16),

            // ✅ ACCOMMODATION DROPDOWN
            DropdownButtonFormField<String>(
              value: accommodation, // This value MUST exist in items
              decoration: _inputDecoration("Preferred Stay"),
              items: accommodationOptions.map((String val) {
                return DropdownMenuItem(value: val, child: Text(val));
              }).toList(),
              onChanged: (val) => setState(() => accommodation = val!),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _savePrefs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text("Save Preferences", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCounterRow(String label, int value, Function(int) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Row(
          children: [
            IconButton(
              onPressed: value > 0 ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_circle_outline, color: Colors.pink),
            ),
            Text("$value", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              onPressed: () => onChanged(value + 1),
              icon: const Icon(Icons.add_circle_outline, color: Colors.pink),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}