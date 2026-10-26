import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_config_provider.dart';

import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_waitForStartup());
  }

  Future<void> _waitForStartup() async {
    final configCheck = context
        .read<AppConfigProvider>()
        .initialDownloadAvailabilityCheck;
    await Future.wait<void>([
      Future<void>.delayed(const Duration(seconds: 3)),
      configCheck,
    ]);
    _openApp();
  }

  void _openApp() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const MainScreen(),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
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
