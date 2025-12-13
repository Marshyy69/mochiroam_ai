// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/bottom_nav_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Main body
      body: SafeArea(
        child: Column(
          children: [
            // Header row: mascot, HOME, profile icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
              child: Row(
                children: [
                  // Mascot image (PNG)
                  Image.asset(
                    'assets/images/mascot.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(width: 10),

                  // Title
                  const Expanded(
                    child: Text(
                      'HOME',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  // Profile icon (svg) wrapped in a circle
                  GestureDetector(
                    onTap: () {
                      // go to account page via route
                      Navigator.pushReplacementNamed(context, '/account');
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/profile.svg',
                          width: 20,
                          height: 20,
                          // color tint
                          colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26.0),
                child: Column(
                  children: [
                    const Spacer(flex: 3),

                    // Main prompt text
                    const Text(
                      "What's your next adventure?",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    // Suggestion list (static placeholders)
                    Column(
                      children: const [
                        SuggestionText('Suggestion'),
                        SuggestionText('Suggestion'),
                        SuggestionText('Suggestion'),
                        SuggestionText('Suggestion'),
                      ],
                    ),

                    const Spacer(flex: 4),

                    // "Ask anything!" button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                      onPressed: () {
  Navigator.pushNamed(context, '/chat');
},

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'Ask anything!',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Global bottom navigation bar (reusable)
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }
}

/// Small helper widget for suggestion text (keeps HomeScreen tidy)
class SuggestionText extends StatelessWidget {
  final String text;
  const SuggestionText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.redAccent,
          fontSize: 14,
        ),
      ),
    );
  }
}
