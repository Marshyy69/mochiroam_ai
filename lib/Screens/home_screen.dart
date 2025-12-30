import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const List<Map<String, String>> suggestions = [
    {
      "country": "Japan",
      "emoji": "🇯🇵",
      "prompt": "Plan a trip to Japan",
    },
    {
      "country": "South Korea",
      "emoji": "🇰🇷",
      "prompt": "Plan a trip to South Korea",
    },
    {
      "country": "Thailand",
      "emoji": "🇹🇭",
      "prompt": "Plan a trip to Thailand",
    },
    {
      "country": "Australia",
      "emoji": "🇦🇺",
      "prompt": "Plan a trip to Australia",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Column(
          children: [
            // ---------------- HEADER ----------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/mascot.png',
                    width: 36,
                    height: 36,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'HOME',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/account');
                    },
                    child: CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      child: Image.asset(
                        'assets/icons/acc.png',
                        width: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ---------------- CONTENT ----------------
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    const Text(
                      "Where should Mochi take you next? 🍡✈️",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    // 🌍 Country Suggestions
                    Expanded(
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: suggestions.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.1,
                        ),
                        itemBuilder: (context, index) {
                          final item = suggestions[index];
                          return CountryCard(
                            emoji: item["emoji"]!,
                            country: item["country"]!,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/chat',
                                arguments: item["prompt"],
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Ask anything button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/chat');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink.shade100,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Ask Mochi Anything 💬',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }
}

class CountryCard extends StatefulWidget {
  final String emoji;
  final String country;
  final VoidCallback onTap;

  const CountryCard({
    super.key,
    required this.emoji,
    required this.country,
    required this.onTap,
  });

  @override
  State<CountryCard> createState() => _CountryCardState();
}

class _CountryCardState extends State<CountryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 40),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.country,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

