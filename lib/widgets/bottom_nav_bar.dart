import 'dart:ui';
import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;

  const BottomNavBar({super.key, required this.currentIndex});

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;
    switch (index) {
      case 0: Navigator.pushReplacementNamed(context, "/home"); break;
      case 1: Navigator.pushReplacementNamed(context, "/explore"); break;
      case 2: Navigator.pushReplacementNamed(context, "/itinerary"); break;
      case 3: Navigator.pushReplacementNamed(context, "/account"); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFFF06292);
    const inactiveColor = Color(0xFFBDBDBD);

    final items = [
      _NavItem(assetPath: 'assets/images/mascot.png', label: 'Home'),
      _NavItem(icon: Icons.explore_outlined, label: 'Explore'),
      _NavItem(assetPath: 'assets/icons/itinerary.png', label: 'Trips'),
      _NavItem(assetPath: 'assets/icons/acc.png', label: 'Account'),
    ];

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xF0FFF5F7),
            border: const Border(
              top: BorderSide(color: Color(0xFFF8BBD0), width: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF06292).withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: List.generate(items.length, (index) {
                  final isActive = index == currentIndex;
                  final item = items[index];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onItemTapped(context, index),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon
                            AnimatedScale(
                              scale: isActive ? 1.12 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: item.assetPath != null
                                  ? Image.asset(
                                      item.assetPath!,
                                      width: 24,
                                      height: 24,
                                      color: isActive ? activeColor : inactiveColor,
                                    )
                                  : Icon(
                                      item.icon,
                                      size: 24,
                                      color: isActive ? activeColor : inactiveColor,
                                    ),
                            ),
                            const SizedBox(height: 3),
                            // Label
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                color: isActive ? activeColor : inactiveColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            // Active dot indicator
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: isActive ? 5 : 0,
                              height: isActive ? 5 : 0,
                              decoration: const BoxDecoration(
                                color: activeColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String? assetPath;
  final IconData? icon;
  final String label;
  const _NavItem({this.assetPath, this.icon, required this.label});
}