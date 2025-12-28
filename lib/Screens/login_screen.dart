import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _rememberMe = false;

  // ---------------- LOGIN ----------------
  Future<void> _login() async {
    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/home");
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? "Login failed";
      if (e.code == "user-not-found") msg = "No user found for that email.";
      if (e.code == "wrong-password") msg = "Wrong password.";

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- REGISTER (RESTORED) ----------------
  Future<void> _register() async {
    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/home");
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? "Register failed";
      if (e.code == "weak-password") {
        msg = "Password too weak (minimum 6 characters).";
      }
      if (e.code == "email-already-in-use") {
        msg = "Email already in use.";
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9A3BC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Mascot
              Image.asset(
                'assets/images/mascot.png',
                height: 120,
              ),

              const SizedBox(height: 12),

              const Text(
                "MochiRoam AI",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                "Log in to continue.",
                style: TextStyle(color: Colors.white70),
              ),

              const SizedBox(height: 30),

              // Email
              TextField(
                controller: _email,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black38,
                  hintText: "Email or username",
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Password
              TextField(
                controller: _password,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black38,
                  hintText: "Password",
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Remember me
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Remember me",
                      style: TextStyle(color: Colors.white70)),
                  Switch(
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v),
                  )
                ],
              ),

              const SizedBox(height: 20),

              // LOGIN button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(_loading ? "Loading..." : "LOG IN"),
                ),
              ),

              const SizedBox(height: 16),

              // SIGN UP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don’t have an account? ",
                      style: TextStyle(color: Colors.white70)),
                  GestureDetector(
                    onTap: _loading ? null : _register,
                    child: const Text(
                      "SIGN UP",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
