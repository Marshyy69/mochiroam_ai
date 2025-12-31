import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/account_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/itinerary_page.dart';
import 'screens/login_screen.dart';
import 'screens/preferences_screen.dart';
import 'screens/signup_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load env
  await dotenv.load(fileName: ".env");

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
      theme: ThemeData(
        primarySwatch: Colors.pink,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),

      // Start at login -- my route
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
