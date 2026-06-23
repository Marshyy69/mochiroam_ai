import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/bottom_nav_bar.dart';
import 'profile_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Large pool of trending destinations
  static const List<Map<String, dynamic>> _allDestinations = [
    {"country": "Japan", "emoji": "🇯🇵", "days": "7 days", "gradientStart": Color(0xFFF48FB1), "gradientEnd": Color(0xFFF06292)},
    {"country": "South Korea", "emoji": "🇰🇷", "days": "5 days", "gradientStart": Color(0xFF80DEEA), "gradientEnd": Color(0xFF26C6DA)},
    {"country": "Thailand", "emoji": "🇹🇭", "days": "6 days", "gradientStart": Color(0xFFA5D6A7), "gradientEnd": Color(0xFF66BB6A)},
    {"country": "Australia", "emoji": "🇦🇺", "days": "10 days", "gradientStart": Color(0xFFFFCC80), "gradientEnd": Color(0xFFFFA726)},
    {"country": "Italy", "emoji": "🇮🇹", "days": "8 days", "gradientStart": Color(0xFFEF9A9A), "gradientEnd": Color(0xFFEF5350)},
    {"country": "France", "emoji": "🇫🇷", "days": "7 days", "gradientStart": Color(0xFF90CAF9), "gradientEnd": Color(0xFF42A5F5)},
    {"country": "Turkey", "emoji": "🇹🇷", "days": "6 days", "gradientStart": Color(0xFFFFAB91), "gradientEnd": Color(0xFFFF7043)},
    {"country": "Vietnam", "emoji": "🇻🇳", "days": "5 days", "gradientStart": Color(0xFFE6EE9C), "gradientEnd": Color(0xFFD4E157)},
    {"country": "Spain", "emoji": "🇪🇸", "days": "7 days", "gradientStart": Color(0xFFFFCC80), "gradientEnd": Color(0xFFFF9800)},
    {"country": "Indonesia", "emoji": "🇮🇩", "days": "8 days", "gradientStart": Color(0xFF80CBC4), "gradientEnd": Color(0xFF26A69A)},
    {"country": "United Kingdom", "emoji": "🇬🇧", "days": "6 days", "gradientStart": Color(0xFFB39DDB), "gradientEnd": Color(0xFF7E57C2)},
    {"country": "Morocco", "emoji": "🇲🇦", "days": "5 days", "gradientStart": Color(0xFFFFAB91), "gradientEnd": Color(0xFFE64A19)},
    {"country": "Egypt", "emoji": "🇪🇬", "days": "6 days", "gradientStart": Color(0xFFFFE082), "gradientEnd": Color(0xFFFFCA28)},
    {"country": "New Zealand", "emoji": "🇳🇿", "days": "9 days", "gradientStart": Color(0xFFA5D6A7), "gradientEnd": Color(0xFF43A047)},
    {"country": "Switzerland", "emoji": "🇨🇭", "days": "5 days", "gradientStart": Color(0xFF90CAF9), "gradientEnd": Color(0xFF1E88E5)},
    {"country": "Greece", "emoji": "🇬🇷", "days": "6 days", "gradientStart": Color(0xFF80DEEA), "gradientEnd": Color(0xFF00ACC1)},
    {"country": "Malaysia", "emoji": "🇲🇾", "days": "5 days", "gradientStart": Color(0xFFF48FB1), "gradientEnd": Color(0xFFE91E63)},
    {"country": "Mexico", "emoji": "🇲🇽", "days": "7 days", "gradientStart": Color(0xFFA5D6A7), "gradientEnd": Color(0xFF2E7D32)},
    {"country": "Portugal", "emoji": "🇵🇹", "days": "6 days", "gradientStart": Color(0xFFFFCC80), "gradientEnd": Color(0xFFEF6C00)},
    {"country": "Singapore", "emoji": "🇸🇬", "days": "4 days", "gradientStart": Color(0xFFCE93D8), "gradientEnd": Color(0xFFAB47BC)},
  ];

  late List<Map<String, dynamic>> _featured;

  @override
  void initState() {
    super.initState();
    _shuffleDestinations();
  }

  void _shuffleDestinations() {
    final shuffled = List<Map<String, dynamic>>.from(_allDestinations)..shuffle(Random());
    _featured = shuffled.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFCE4EC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF8BBD0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/mascot.png', width: 22, height: 22),
                  const SizedBox(width: 6),
                  const Text(
                    'MochiRoam',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFC2185B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              borderRadius: BorderRadius.circular(50),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: user != null
                    ? Supabase.instance.client
                        .from('users')
                        .stream(primaryKey: ['id'])
                        .eq('id', user.id)
                    : null,
                builder: (context, snapshot) {
                  String avatar = "🍡";
                  if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                    final data = snapshot.data!.first;
                    if (data.containsKey('avatar')) avatar = data['avatar'];
                  }
                  return Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCE4EC),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFF8BBD0), width: 1.5),
                    ),
                    child: Text(avatar,
                        style: const TextStyle(fontSize: 20)),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Greeting ─────────────────────────────────────────────
                Builder(
                  builder: (context) {
                    final hour = DateTime.now().hour;
                    String greeting;
                    String emoji;
                    if (hour < 12) {
                      greeting = 'Good morning';
                      emoji = '☀️';
                    } else if (hour < 17) {
                      greeting = 'Good afternoon';
                      emoji = '🌤️';
                    } else {
                      greeting = 'Good evening';
                      emoji = '🌙';
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        '$greeting! $emoji',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ).animate().fade(duration: 400.ms);
                  },
                ),

                // ── Hero Banner ──────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFCE4EC), Color(0xFFF8BBD0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF8BBD0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF06292).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'WHERE TO NEXT?',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFC2185B),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Where should Mochi\ntake you? 🍡✈️",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushNamed(context, '/chat'),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF06292),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF06292)
                                    .withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Ask Mochi Anything 💬',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fade(duration: 400.ms).slideY(begin: 0.15),

                const SizedBox(height: 28),

                // ── Section Title ─────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Trending Destinations 🔥',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _shuffleDestinations()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCE4EC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF8BBD0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded, size: 14, color: Color(0xFFC2185B)),
                            SizedBox(width: 4),
                            Text('Shuffle',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFC2185B))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ).animate().fade(duration: 400.ms, delay: 100.ms),

                const SizedBox(height: 14),

                // ── Destination Grid ──────────────────────────────────
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _featured.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (context, index) {
                    final item = _featured[index];
                    return _DestinationCard(item: item)
                        .animate(delay: (index * 80).ms)
                        .fade(duration: 350.ms)
                        .scale(begin: const Offset(0.93, 0.93));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }
}

class _DestinationCard extends StatefulWidget {
  final Map<String, dynamic> item;
  const _DestinationCard({required this.item});

  @override
  State<_DestinationCard> createState() => _DestinationCardState();
}

class _DestinationCardState extends State<_DestinationCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () => Navigator.pushNamed(
        context,
        '/chat',
        arguments: "Plan a trip to ${widget.item["country"]}",
      ),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFF5E0E8)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF06292).withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Gradient image area
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.item["gradientStart"] as Color,
                        widget.item["gradientEnd"] as Color,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22)),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: Text(
                          widget.item["emoji"] as String,
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                      // Subtle gradient overlay at the bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.05),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Text area
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.item["country"] as String,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      widget.item["days"] as String,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9E9E9E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}