import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'core/models/app_state_manager.dart';
import 'core/services/api_service.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/widgets/alert_overlay.dart';
import 'core/services/firestore_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/global_monitor_service.dart';
import 'core/repositories/child_repository.dart';
import 'core/repositories/rules_repository.dart';
import 'core/repositories/alert_repository.dart';
import 'core/repositories/stats_repository.dart';
import 'core/services/child_enforcement_service.dart';
import 'core/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    debugPrint('APP_LOG: .env loaded successfully.');
  } catch (e) {
    debugPrint('APP_LOG: Failed to load .env file: $e');
  }

  debugPrint('APP_LOG: Initializing Firebase...');

  // DEFINITIVE CORRECTION: Firebase.initializeApp() MUST succeed.
  // If it fails, an error screen is shown instead of launching
  // the app in a broken state that would crash everywhere.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('APP_LOG: Firebase initialized successfully.');
  } catch (e) {
    debugPrint('APP_LOG: FATAL - Firebase init failed: $e');
    runApp(_FirebaseErrorApp(error: e.toString()));
    return;
  }

  // Pre-UI setup
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final stateManager = AppStateManager();

  // Task 1: Optimization — Sequential initialization removed.
  // We launch the app immediately and run heavy services in the background.
  // NOTE: GlobalMonitorService is initialized by AppStateManager.updateState(authenticated)
  // after the user signs in — NOT here, to avoid race conditions with Firebase Auth.
  unawaited(Future.wait([
    ApiService().initialize(),
    NotificationService().initialize(),
    FirestoreService().updateLastActive(),
    _startChildEnforcementIfNeeded(),
  ]).then((_) {
    debugPrint('APP_LOG: Background services initialized.');
  }).catchError((e) {
    debugPrint('APP_LOG: Background init error: $e');
  }));

  debugPrint('APP_LOG: Starting app UI...');
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: stateManager),
        ChangeNotifierProvider.value(value: ApiService()),
        Provider(create: (_) => ChildRepository()),
        Provider(create: (_) => RulesRepository()),
        Provider(create: (_) => AlertRepository()),
        Provider(create: (_) => StatsRepository()),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _startChildEnforcementIfNeeded() async {
  final pairing = await StorageService().getChildPairing();
  if (pairing['mode'] == 'child' &&
      pairing['parentId'] != null &&
      pairing['childId'] != null) {
    await ChildEnforcementService().start();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final stateManager = context.watch<AppStateManager>();

    return MaterialApp.router(
      title: 'The Guardian',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: stateManager.themeMode,
      routerConfig: AppRouter.router,
      builder: (context, child) => AlertOverlay(child: child!),
    );
  }
}

/// Displayed only if Firebase fails to initialize.
/// Helps diagnose the problem without an opaque crash.
class _FirebaseErrorApp extends StatelessWidget {
  final String error;
  const _FirebaseErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Firebase Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Check that google-services.json is correctly\n'
                      'in android/app/ and that the package name\n'
                      'matches com.example.virt',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}