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
  bool hasElderly = false;
  bool hasChildren = false;
  int childrenCount = 0;
  final TextEditingController _childAgeController = TextEditingController();

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

  late String budget;
  late String accommodation;

  List<String> selectedVibes = [];
  final List<String> vibeOptions = [
    "Nature 🌳",
    "Adventure 🧗",
    "Shopping 🛍️",
    "Culture 🏯",
    "Foodie 🍜",
    "Relaxing 💆‍♀️",
    "City Life 🏙️",
    "Photography 📸",
  ];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    budget = budgetOptions[1];
    accommodation = accommodationOptions[0];
    _loadPrefs();
  }

  @override
  void dispose() {
    _childAgeController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => loading = false); return; }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          pax = (data['pax'] ?? 1) as int;
          hasChildren = (data['hasChildren'] ?? false) as bool;
          childrenCount = (data['childrenCount'] ?? 0) as int;
          _childAgeController.text = (data['childrenAgeRange'] ?? "") as String;
          hasElderly = (data['hasElderly'] ?? false) as bool;
          selectedVibes = List<String>.from(data['tripVibe'] ?? []);

          String lb = (data['budget'] ?? budgetOptions[1]) as String;
          budget = budgetOptions.contains(lb) ? lb : budgetOptions[1];

          String la = (data['accommodation'] ?? accommodationOptions[0]) as String;
          accommodation = accommodationOptions.contains(la) ? la : accommodationOptions[0];
        });
      } else {
        setState(() => selectedVibes = ["Relaxing 💆‍♀️"]);
      }
    } catch (e) {
      setState(() => selectedVibes = ["Relaxing 💆‍♀️"]);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _savePrefs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Preferences saved! ✅'),
        backgroundColor: const Color(0xFFF06292),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save preferences: $e'),
          backgroundColor: const Color(0xFFC2185B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFFF06292))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        title: const Text(
          "Travel Preferences",
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Section: Who is traveling ─────────────────────────
            _SectionCard(
              title: "Who is traveling? 👥",
              children: [
                _CounterRow(
                  label: "Total Pax",
                  value: pax,
                  onChanged: (v) => setState(() => pax = v),
                ),
                const SizedBox(height: 4),
                _PinkSwitchTile(
                  title: "Traveling with Children?",
                  value: hasChildren,
                  onChanged: (v) => setState(() => hasChildren = v),
                ),
                if (hasChildren) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        _CounterRow(
                          label: "How many kids?",
                          value: childrenCount,
                          onChanged: (v) =>
                              setState(() => childrenCount = v),
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: _childAgeController,
                          hint: "Age range (e.g. 5–10 years)",
                          icon: Icons.child_care_outlined,
                        ),
                      ],
                    ),
                  ),
                ],
                _PinkSwitchTile(
                  title: "Traveling with Elderly?",
                  subtitle: "Fewer stairs & easier walks",
                  value: hasElderly,
                  onChanged: (v) => setState(() => hasElderly = v),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Section: Trip Vibe ────────────────────────────────
            _SectionCard(
              title: "Trip Vibe ✨",
              children: [
                const Text(
                  "What kind of trip? (Select multiple)",
                  style:
                      TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: vibeOptions.map((vibe) {
                    final isSelected = selectedVibes.contains(vibe);
                    return GestureDetector(
                      onTap: () => setState(() {
                        isSelected
                            ? selectedVibes.remove(vibe)
                            : selectedVibes.add(vibe);
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFCE4EC)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFF06292)
                                : const Color(0xFFF0F0F0),
                          ),
                        ),
                        child: Text(
                          vibe,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFFC2185B)
                                : const Color(0xFF757575),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Section: Budget & Stay ────────────────────────────
            _SectionCard(
              title: "Budget & Stay 💰",
              children: [
                _buildDropdown(
                  label: "Budget Level",
                  value: budget,
                  items: budgetOptions,
                  onChanged: (v) => setState(() => budget = v!),
                ),
                const SizedBox(height: 14),
                _buildDropdown(
                  label: "Preferred Accommodation",
                  value: accommodation,
                  items: accommodationOptions,
                  onChanged: (v) => setState(() => accommodation = v!),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Save button ───────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _savePrefs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF06292),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text(
                  "Save Preferences",
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFFBDBDBD), fontSize: 13),
        prefixIcon:
            Icon(icon, size: 18, color: const Color(0xFFBDBDBD)),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      items: items
          .map((v) => DropdownMenuItem(
              value: v,
              child: Text(v,
                  style: const TextStyle(fontSize: 13))))
          .toList(),
      onChanged: onChanged,
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

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
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  final String label;
  final int value;
  final void Function(int) onChanged;
  const _CounterRow(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A))),
        Row(
          children: [
            _CountBtn(
              icon: Icons.remove,
              onTap: value > 0 ? () => onChanged(value - 1) : null,
            ),
            SizedBox(
              width: 36,
              child: Center(
                child: Text(
                  "$value",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            _CountBtn(
              icon: Icons.add,
              onTap: () => onChanged(value + 1),
            ),
          ],
        ),
      ],
    );
  }
}

class _CountBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CountBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: onTap != null
              ? const Color(0xFFFCE4EC)
              : const Color(0xFFF5F5F5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null
              ? const Color(0xFFF06292)
              : const Color(0xFFBDBDBD),
        ),
      ),
    );
  }
}

class _PinkSwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final void Function(bool) onChanged;
  const _PinkSwitchTile(
      {required this.title,
      this.subtitle,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A))),
              if (subtitle != null)
                Text(subtitle!,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9E9E9E))),
            ],
          ),
        ),
        Switch(
          value: value,
          activeColor: const Color(0xFFF06292),
          onChanged: onChanged,
        ),
      ],
    );
  }
}