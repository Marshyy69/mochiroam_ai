import 'dart:ui'; // ✅ Required for ImageFilter
import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;

  const BottomNavBar({super.key, required this.currentIndex});

void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, "/home");
        break;
      case 1: // 🆕 INDEX 1 IS NOW EXPLORE
        Navigator.pushReplacementNamed(context, "/explore");
        break;
      case 2: // INDEX 2 IS NOW ITINERARIES
        Navigator.pushReplacementNamed(context, "/itinerary");
        break;
      case 3: // INDEX 3 IS NOW ACCOUNT
        Navigator.pushReplacementNamed(context, "/account");
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // 🧊 Frosted Glass Blur
        child: Container(
          // Soft pink translucent tint
          color: const Color(0xFFFFF5F7).withOpacity(0.75), 
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (index) => _onItemTapped(context, index),
            selectedItemColor: Colors.pinkAccent,
            unselectedItemColor: Colors.black45,
            backgroundColor: Colors.transparent, // Must be transparent for glass effect
            elevation: 0,
            items: [
              BottomNavigationBarItem(
                icon: Image.asset('assets/images/mascot.png', width: 26, height: 26),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.explore_outlined, size: 26), // 🆕 The Community Tab
                label: 'Explore',
              ),
              BottomNavigationBarItem(
                icon: Image.asset('assets/icons/itinerary.png', width: 26, height: 26),
                label: 'Itineraries',
              ),
              BottomNavigationBarItem(
                icon: Image.asset('assets/icons/acc.png', width: 26, height: 26),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
    );
  }
}