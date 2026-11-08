import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../widgets/common.dart';
import '../auth/complete_profile_screen.dart';
import '../auth/login_screen.dart';
import '../shell/main_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return AppStateBuilder(
      builder: (context, state) {
        if (state.initializing) return const SplashScreen();

        // Guests browse the public storefront immediately. The auth screen is
        // only shown when a guest explicitly starts checkout or asks to sign
        // in from a private tab.
        if (state.user == null) {
          if (state.authPromptOpen) return const LoginScreen(isPrompt: true);
          return const MainShell(key: ValueKey('guest-shell'));
        }

        // Registration's temporary Firebase session must not mount the
        // storefront: it would consume the pending guest checkout. The
        // customer is signed out and returned to the login prompt instead.
        if (state.registrationInProgress) return const SplashScreen();

        if (state.needsProfileCompletion) return const CompleteProfileScreen();

        return MainShell(key: ValueKey(state.user!.uid));
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppWordmark(fontSize: 22, onDark: true),
              const SizedBox(height: 18),
              Text(
                'WEAR YOUR IDENTITY.',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
