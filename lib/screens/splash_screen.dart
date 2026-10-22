import 'dart:async';

import 'package:flutter/material.dart';

import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), _openApp);
  }

  void _openApp() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const MainScreen(),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF00C9D4),
      body: SizedBox.expand(
        child: Image(
          image: AssetImage('assets/images/splash.png'),
          fit: BoxFit.contain,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}
