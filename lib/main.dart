import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'screens/account_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/itinerary_page.dart';
import 'screens/login_screen.dart';
import 'screens/preferences_screen.dart';
import 'screens/signup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load env
 try {
    // Attempt 1: Standard Path (If file is in assets/.env)
    await dotenv.load(fileName: "assets/.env");
    print("✅ SUCCESS: Loaded .env from 'assets/.env'");
  } catch (e1) {
    try {
      // Attempt 2: Root Path (If file is just .env)
      await dotenv.load(fileName: ".env");
      print("✅ SUCCESS: Loaded .env from '.env'");
    } catch (e2) {
      print("🚨 CRITICAL ERROR: Could not load .env file!");
      print("Attempt 1 error: $e1");
      print("Attempt 2 error: $e2");
      // If all fails, we create an empty map to prevent crashing
      // (But your API calls won't work)
    }
  }

  // initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MochiRoamApp());
}

class MochiRoamApp extends StatelessWidget {
  const MochiRoamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MochiRoam AI',
      debugShowCheckedModeBanner: false,
      
      // 🎨 GLOBAL THEME SETTINGS
      theme: ThemeData(
        useMaterial3: true,

        // 1. The Mochi Background Color (Soft Pink Tint) 🌸
        // This applies to ALL screens automatically!
        scaffoldBackgroundColor: const Color(0xFFFFF5F7),

        // 2. Cute Round Font for everything
        textTheme: GoogleFonts.nunitoTextTheme(
          Theme.of(context).textTheme,
        ),

        // 3. Color Palette
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.pinkAccent,
          primary: Colors.pinkAccent,
          secondary: Colors.pink.shade200,
          background: const Color(0xFFFFF5F7), // Match scaffold
        ),
        
        // 4. App Bar Styling (Clean White & Pink Text)
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent, // Blends with background
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black),
          titleTextStyle: GoogleFonts.nunito(
            color: Colors.black87, 
            fontSize: 22, 
            fontWeight: FontWeight.w800, // Extra Bold for cuteness
          ),
        ),
      ),

      // Start at login
      initialRoute: "/login",
      routes: {
        "/login": (context) => const LoginScreen(),
        "/signup": (context) => const SignUpScreen(),
        "/home": (context) => const HomeScreen(),
        "/itinerary": (context) => const ItineraryPage(),
        "/chat": (context) => const ChatScreen(),
        "/account": (context) => const AccountScreen(),
        "/preferences": (context) => const PreferencesScreen(),
      },
    );
  }
}