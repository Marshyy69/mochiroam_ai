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
      case 1:
        Navigator.pushReplacementNamed(context, "/itinerary");
        break;
      case 2:
        Navigator.pushReplacementNamed(context, "/account");
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _onItemTapped(context, index),
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.black54,
      backgroundColor: const Color(0xFFECC4E8),
      elevation: 10,

      // ✅ remove `const` here because Image.asset isn't const
      items: [
        BottomNavigationBarItem(
          icon: Image.asset('assets/images/mascot.png', width: 26, height: 26),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/icons/itinerary.png',
            width: 26,
            height: 26,
          ),
          label: 'Itineraries',
        ),
        BottomNavigationBarItem(
          icon: Image.asset('assets/icons/acc.png', width: 26, height: 26),
          label: 'Account',
        ),
      ],
    );
  }
}
