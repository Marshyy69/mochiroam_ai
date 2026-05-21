import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../widgets/bottom_nav_bar.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final user = Supabase.instance.client.auth.currentUser;
  bool _isHalal = false;
  bool _isLoading = true;
  String _appVersion = "";
  int _upcomingCount = 0;
  int _memoriesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final info = await PackageInfo.fromPlatform();
    setState(() =>
        _appVersion = "v${info.version} (${info.buildNumber})");

    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final results = await Future.wait<dynamic>([
        Supabase.instance.client
            .from('users')
            .select()
            .eq('id', user!.id)
            .single(),
        Supabase.instance.client
            .from('itineraries')
            .select('id')
            .eq('user_id', user!.id),
        Supabase.instance.client
            .from('private_memories')
            .select('id')
            .eq('user_id', user!.id),
      ]);

      final doc = results[0] as Map<String, dynamic>?;
      final upcoming = results[1] as List<dynamic>?;
      final memories = results[2] as List<dynamic>?;

      if (mounted) {
        setState(() {
          _isHalal = doc != null ? (doc['is_halal'] ?? false) : false;
          _upcomingCount = upcoming?.length ?? 0;
          _memoriesCount = memories?.length ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleHalal(bool value) async {
    setState(() => _isHalal = value);
    if (user != null) {
      // Fire-and-forget — don't block UI
      Supabase.instance.client
          .from('users')
          .update({'is_halal': value})
          .eq('id', user!.id)
          .catchError((_) {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(value ? "Halal Mode ON 🕌" : "Halal Mode OFF"),
          backgroundColor: value ? Colors.green : Colors.grey[700],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String avatar = "🍡";
    String email = user?.email ?? "Guest User";

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        title: const Text(
          "My Account",
          style: TextStyle(
              fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, "/profile"),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE4EC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF8BBD0)),
                ),
                child: const Text(
                  "Edit ✏️",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFC2185B)),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF06292)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                children: [
                  // ── Profile Hero Card ─────────────────────────────
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: user != null
                        ? Supabase.instance.client
                            .from('users')
                            .stream(primaryKey: ['id'])
                            .eq('id', user!.id)
                        : null,
                    builder: (context, snapshot) {
                      if (snapshot.hasData &&
                          snapshot.data != null &&
                          snapshot.data!.isNotEmpty) {
                        final data = snapshot.data!.first;
                        avatar = data['avatar'] ?? "🍡";
                      }
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFCE4EC),
                              Color(0xFFF8BBD0)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border:
                              Border.all(color: const Color(0xFFF8BBD0)),
                        ),
                        child: Column(
                          children: [
                            // Avatar
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFFF06292),
                                    width: 2),
                              ),
                              child: Center(
                                child: Text(avatar,
                                    style:
                                        const TextStyle(fontSize: 34)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              email,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A)),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF06292)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "Traveler Level 1 🌟",
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFC2185B)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Mini stats row
                            Row(
                              children: [
                                _StatPill(
                                    value: _upcomingCount,
                                    label: "Upcoming"),
                                const SizedBox(width: 8),
                                _StatPill(
                                    value: _memoriesCount,
                                    label: "Memories"),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // ── Settings Card ─────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF5E0E8)),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFF06292).withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Halal toggle
                        _SettingsRow(
                          iconBg: const Color(0xFFE8F5E9),
                          icon: "🕌",
                          title: "Halal Preference",
                          subtitle: "Prioritize halal food options",
                          trailing: Switch(
                            value: _isHalal,
                            activeTrackColor: Colors.green,
                            onChanged: _toggleHalal,
                          ),
                        ),
                        _Divider(),
                        // Preferences
                        _SettingsRow(
                          iconBg: const Color(0xFFFCE4EC),
                          icon: "⚙️",
                          title: "Other Preferences",
                          subtitle: "Pax, budget, vibe & more",
                          trailing: const Icon(Icons.arrow_forward_ios,
                              size: 14, color: Color(0xFFBDBDBD)),
                          onTap: () =>
                              Navigator.pushNamed(context, "/preferences"),
                        ),
                        _Divider(),
                        // Logout
                        _SettingsRow(
                          iconBg: const Color(0xFFFFEBEE),
                          icon: "🚪",
                          title: "Logout",
                          titleColor: const Color(0xFFE53935),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              size: 14, color: Color(0xFFBDBDBD)),
                          onTap: () async {
                            await Supabase.instance.client.auth.signOut();
                            if (!context.mounted) return;
                            Navigator.of(context)
                                .pushNamedAndRemoveUntil(
                                    "/login",
                                    (Route<dynamic> route) => false);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Version ───────────────────────────────────────
                  Text(
                    "MochiRoam AI  •  $_appVersion",
                    style: const TextStyle(
                        color: Color(0xFFBDBDBD), fontSize: 12),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }
}

class _StatPill extends StatelessWidget {
  final int value;
  final String label;
  const _StatPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFC2185B)),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFC2185B),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final Color iconBg;
  final String icon;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.iconBg,
    required this.icon,
    required this.title,
    this.titleColor,
    this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: iconBg, shape: BoxShape.circle),
              child: Center(
                  child: Text(icon,
                      style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: titleColor ?? const Color(0xFF1A1A1A)),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9E9E9E)),
                    ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 0.5, color: Color(0xFFF5E0E8)),
    );
  }
}