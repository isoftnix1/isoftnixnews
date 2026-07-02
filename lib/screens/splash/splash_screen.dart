import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuth());
  }

  Future<void> _checkAuth() async {
    final startTime = DateTime.now();
    
    final auth = context.read<AuthProvider>();
    final lang = context.read<LanguageProvider>();

    final results = await Future.wait([
      auth.tryAutoLogin(),
      lang.initializationDone,
    ]);
    final isLoggedIn = results[0] as bool;
    
    final elapsedTime = DateTime.now().difference(startTime);
    final remainingDelay = const Duration(milliseconds: 1500) - elapsedTime;
    
    if (remainingDelay > Duration.zero) {
      await Future.delayed(remainingDelay);
    }

    if (!mounted) return;

    if (isLoggedIn) {
      if (auth.user?.role == 'admin') {
        Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Centered logo + branding ───────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Responsive logo — large but never overflows
                  Builder(builder: (context) {
                    final size = MediaQuery.of(context).size;
                    final logoSize = (size.shortestSide * 0.5).clamp(160.0, 280.0);
                    return Image.asset(
                      'assets/icon/app_icon.png',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                    );
                  }),

                  const SizedBox(height: 24),

                  // App name
                  const Text(
                    'Updates',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Tagline
                  Text(
                    AppLocalizations.of(context, 'splash_subtitle'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF888888),
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // ── Loading indicator pinned to bottom ─────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFFE64A19).withAlpha(180),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


