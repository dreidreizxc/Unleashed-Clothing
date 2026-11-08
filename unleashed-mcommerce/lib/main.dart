import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/app_config.dart';
import 'core/app_theme.dart';
import 'core/navigation.dart';
import 'firebase_options.dart';
import 'screens/root/auth_gate.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await Firebase.initializeApp(options: defaultFirebaseOptions);
  } catch (error, stack) {
    debugPrint('[Unleashed] Firebase initialisation failed: $error');
    debugPrintStack(stackTrace: stack, maxFrames: 8);
    runApp(const _StartupFailureApp());
    return;
  }

  AppState.instance.init();
  runApp(const UnleashedApp());
}

class UnleashedApp extends StatelessWidget {
  const UnleashedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.storeName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      navigatorKey: rootNavigatorKey,
      home: const AuthGate(),
    );
  }
}

/// Shown only when Firebase itself cannot start (for example, a malformed
/// configuration or no platform support). It keeps the failure readable
/// instead of leaving the customer on a blank screen.
class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.storeName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront_outlined, size: 48),
                  const SizedBox(height: 18),
                  const Text(
                    'STORE UNAVAILABLE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'The app could not connect to its Firebase project. '
                    'Check your internet connection and try reopening the app.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
