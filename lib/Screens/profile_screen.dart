import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = Supabase.instance.client.auth.currentUser;
  final TextEditingController _nameController = TextEditingController();

  String _selectedAvatar = "🍡";
  bool _isLoading = true;
  bool _isSaving = false;
  int _upcomingTrips = 0;
  int _completedTrips = 0;

  final List<String> _avatars = [
    "🍡", "🐼", "🐱", "🦊", "🐸", "🐰", "🐯", "🐨"
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (user == null) return;
    try {
      final results = await Future.wait<dynamic>([
        Supabase.instance.client
            .from('users')
            .select()
            .eq('id', user!.id)
            .single(),
        Supabase.instance.client
            .from('itineraries')
            .select()
            .eq('user_id', user!.id),
      ]);

      final doc = results[0] as Map<String, dynamic>?;
      final trips = results[1] as List<dynamic>? ?? [];

      int upcoming = 0, completed = 0;
      for (var d in trips) {
        if (d['status'] == 'completed') {
          completed++;
        } else {
          upcoming++;
        }
      }

      if (mounted) {
        setState(() {
          _nameController.text = doc != null ? (doc['username'] ?? "Traveler") : "Traveler";
          _selectedAvatar = doc != null ? (doc['avatar'] ?? "🍡") : "🍡";
          _upcomingTrips = upcoming;
          _completedTrips = completed;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (user == null) return;
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client
          .from('users')
          .upsert({
        'id': user!.id,
        'username': _nameController.text.trim(),
        'avatar': _selectedAvatar,
        'updated_at': DateTime.now().toIso8601String(),
      });
      // Update Auth metadata if needed
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'username': _nameController.text.trim()})
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text("Profile updated! ✅"),
          backgroundColor: const Color(0xFFF06292),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        Navigator.pop(context);
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
          "Edit Profile",
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF06292)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                children: [
                  // ── Avatar display ────────────────────────────────
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFCE4EC),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFF06292), width: 2.5),
                          ),
                          child: Center(
                            child: Text(_selectedAvatar,
                                style: const TextStyle(fontSize: 44)),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF06292),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Text(
                    "Choose your avatar",
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9E9E9E),
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),

                  // ── Avatar picker ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF5E0E8)),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: _avatars.map((avatar) {
                        final isSelected = _selectedAvatar == avatar;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedAvatar = avatar),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFCE4EC)
                                  : const Color(0xFFF5F5F5),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: const Color(0xFFF06292),
                                      width: 2)
                                  : null,
                            ),
                            child: Center(
                              child: Text(avatar,
                                  style: const TextStyle(fontSize: 26)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Username field ────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF5E0E8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Display Name",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF616161),
                              letterSpacing: 0.3),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF1A1A1A)),
                          decoration: InputDecoration(
                            hintText: "Your name",
                            hintStyle: const TextStyle(
                                color: Color(0xFFBDBDBD)),
                            prefixIcon: const Icon(Icons.person_outline,
                                size: 18, color: Color(0xFFBDBDBD)),
                            filled: true,
                            fillColor: const Color(0xFFFAFAFA),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 13),
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Stats ─────────────────────────────────────────
                  Row(
                    children: [
                      _StatCard(
                        label: "Upcoming",
                        count: _upcomingTrips,
                        bgColor: const Color(0xFFE3F2FD),
                        textColor: const Color(0xFF1565C0),
                        emoji: "✈️",
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: "Memories",
                        count: _completedTrips,
                        bgColor: const Color(0xFFF3E5F5),
                        textColor: const Color(0xFF6A1B9A),
                        emoji: "📔",
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── Save button ───────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF06292),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        shadowColor:
                            const Color(0xFFF06292).withValues(alpha: 0.3),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              "Save Changes",
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
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color bgColor;
  final Color textColor;
  final String emoji;

  const _StatCard({
    required this.label,
    required this.count,
    required this.bgColor,
    required this.textColor,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textColor),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  color: textColor.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}