import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_api_availability/google_api_availability.dart';
import 'providers/app_state.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'services/link_handler_service.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  debugPrint('Main: Flutter binding and Firebase initialized.');

  // Vérifier Google Play Services (crucial pour Firestore sur Xiaomi/Huawei)
  try {
    final availability = await GoogleApiAvailability.instance
        .checkGooglePlayServicesAvailability();
    if (availability != GooglePlayServicesAvailability.success) {
      debugPrint('Main: Google Play Services missing: $availability');
      await GoogleApiAvailability.instance.makeGooglePlayServicesAvailable();
    }
  } catch (e) {
    debugPrint('Main: Google Play Services check error (non-fatal): $e');
  }

  // 1. Canaux de notification (AVANT le background service)
  final notificationService = NotificationService();
  try {
    await notificationService.initialize();
    debugPrint('Main: Notification service initialized.');
  } catch (e) {
    debugPrint('Main: Notification service init failed (non-fatal): $e');
  }

  // 2. Background service (foreground service Android)
  try {
    await BackgroundService().initialize();
    debugPrint('Main: Background service initialized.');
  } catch (e) {
    debugPrint('Main: Background service init failed (non-fatal): $e');
  }

  // 3. Gestionnaire de deep links (jumelage)
  try {
    LinkHandlerService().initialize();
    debugPrint('Main: Link handler initialized.');
  } catch (e) {
    debugPrint('Main: Link handler init failed (non-fatal): $e');
  }

  // 4. Initialisation du mode enfant si déjà appairé (Enforcement immédiat)
  try {
    final authService = AuthService();
    final isActivated = await authService.isDeviceActivated();
    if (isActivated) {
      debugPrint('Main: Device is activated.');
    }
  } catch (e) {
    debugPrint('Main: Mode initialization failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        Provider<NotificationService>.value(value: notificationService),
      ],
      child: const TheGuardianApp(),
    ),
  );
}

class TheGuardianApp extends StatelessWidget {
  const TheGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'The Guardian Child',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
