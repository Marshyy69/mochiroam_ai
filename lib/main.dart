import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/itinerary_page.dart';


void main() {
  runApp(const MochiRoamApp());
}

class MochiRoamApp extends StatelessWidget {
  const MochiRoamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MochiRoam AI',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        primarySwatch: Colors.pink,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),

      // -------------------- 👇 ADD ROUTES HERE --------------------
      home: const HomeScreen(),
      routes: {
        "/home": (context) => const HomeScreen(),
        "/itinerary": (context) => const ItineraryPage(),
        // "/account": (context) => const AccountPage(),
         '/chat': (context) => const ChatScreen(),
      },
      // --------------------------------------------------------------
    );
  }
}
