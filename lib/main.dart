import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/account_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/itinerary_page.dart';
import 'screens/login_screen.dart';
import 'screens/preferences_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/explore_screen.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load env
 try {
    await dotenv.load(fileName: "assets/.env");
  } catch (_) {
    try {
      await dotenv.load(fileName: ".env");
    } catch (_) {
      // .env not found — API calls won't work but app won't crash
    }
  }

  // initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
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
          surface: const Color(0xFFFFF5F7), // Match scaffold
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

        // 5. Global Input Field Styling
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFF5E0E8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFF5E0E8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFF06292), width: 1.5),
          ),
          hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
        ),

        // 6. Global Button Styling
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF06292),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            textStyle: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // 7. Global Card Styling
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFF5E0E8), width: 0.5),
          ),
        ),

        // 8. Divider Styling
        dividerTheme: const DividerThemeData(
          color: Color(0xFFF5E0E8),
          thickness: 0.8,
          space: 32,
        ),

        // 9. Switch Styling
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return const Color(0xFFF06292);
            return Colors.grey.shade300;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return const Color(0xFFF8BBD0);
            return Colors.grey.shade200;
          }),
        ),

        // 10. Chip Styling
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white,
          selectedColor: const Color(0xFFFCE4EC),
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFF5E0E8)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      ),

      home: const AuthWrapper(),
      routes: {
        "/login": (context) => const LoginScreen(),
        "/signup": (context) => const SignUpScreen(),
        "/home": (context) => const HomeScreen(),
        "/itinerary": (context) => const ItineraryPage(),
        "/chat": (context) => const ChatScreen(),
        "/account": (context) => const AccountScreen(),
        '/explore': (context) => const ExploreScreen(),
        "/preferences": (context) => const PreferencesScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFF06292)),
            ),
          );
        }
        
        final session = snapshot.data?.session;
        if (session != null) {
          return const HomeScreen();
        }
        
        return const LoginScreen();
      },
    );
  }
}