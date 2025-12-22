import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // -------------------- BODY --------------------
      body: SafeArea(
        child: Column(
          children: [
            // -------------------- HEADER --------------------
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12,
              ),
              child: Row(
                children: [
                  // Mascot image
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

                  // Profile icon (PNG, NOT SVG)
                  GestureDetector(
                    onTap: () {
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
                        child: Image.asset(
                          'assets/icons/profile.png',
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // -------------------- CONTENT --------------------
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26.0),
                child: Column(
                  children: [
                    const Spacer(flex: 3),

                    const Text(
                      "What's your next adventure?",
                      style: TextStyle(fontSize: 18, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    // Suggestions
                    Column(
                      children: const [
                        SuggestionText('Suggestion'),
                        SuggestionText('Suggestion'),
                        SuggestionText('Suggestion'),
                        SuggestionText('Suggestion'),
                      ],
                    ),

                    const Spacer(flex: 4),

                    // Ask anything button
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

      // -------------------- BOTTOM NAV --------------------
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }
}

// -------------------- HELPER WIDGET --------------------
class SuggestionText extends StatelessWidget {
  final String text;
  const SuggestionText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        text,
        style: const TextStyle(color: Colors.redAccent, fontSize: 14),
      ),
    );
  }
}
