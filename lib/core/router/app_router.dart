import '../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../screens/onboarding/splash_welcome_screen.dart';
import '../../screens/onboarding/onboarding_intro_ai_screen.dart';
import '../../screens/onboarding/onboarding_vision_ai_screen.dart';
import '../../screens/onboarding/onboarding_kyc_screen.dart';
import '../../screens/onboarding/onboarding_child_profile_screen.dart';
import '../../screens/onboarding/onboarding_pairing_final_screen.dart';
// ADDED: new screens
import '../../screens/onboarding/subscription_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/identity_verification_screen.dart';
import '../../screens/auth/otp_setup_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/dashboard/dashboard_ai_orchestrator_screen.dart';
import '../../screens/dashboard/hub_chat_ai_screen.dart';
import '../../screens/monitoring/real_time_map_screen.dart';
import '../../screens/monitoring/safe_zones_screen.dart';
import '../../screens/child/child_profile_creation_screen.dart';
import '../../screens/child/child_details_screen.dart';
import '../../screens/child/rules_summary_screen.dart';
import '../../screens/child/child_profile_modification_screen.dart';
import '../../screens/child/install_link_generation_screen.dart';
import '../../screens/child/child_install_link_screen.dart';
import '../../screens/settings/general_settings_screen.dart';
import '../../screens/settings/notification_settings_screen.dart';
import '../../screens/settings/privacy_settings_screen.dart';
import '../../screens/settings/roles_permissions_screen.dart';
import '../../screens/misc/visual_tutorials_screen.dart';
import '../../screens/misc/product_page_screen.dart';
import '../../screens/monitoring/ai_thinking_transition_screen.dart';
import '../../screens/onboarding/cinematic_splash_screen.dart';
import '../../screens/child/rules_config_wizard_screen.dart';
import '../../screens/monitoring/ai_alert_detail_screen.dart';
import '../../screens/settings/account_screen.dart';
// NEW: added screens
import '../../screens/child/child_dashboard_screen.dart';
import '../../screens/child/rules_editor_screen.dart';
import '../../screens/monitoring/usage_stats_screen.dart';
import '../../screens/monitoring/alerts_screen.dart';
import '../../screens/auth/child_pairing_screen.dart';

// Routes accessibles SANS être connecté
// ADDED: /otp-setup and /subscription are public (part of auth flow)
// ADDED: /child/* routes are public because the child device is NEVER
// authenticated with Firebase — it uses a stored pairing token only.
const _publicRoutes = [
  '/',
  '/cinematic-splash',
  '/login',
  '/signup',
  '/forgot-password',
  '/otp-setup',
  '/subscription',
  '/onboarding',
  '/onboarding/vision',
  '/onboarding/kyc',
  '/onboarding/child-profile',
  '/onboarding/pairing',
  '/product-page',
  // ── Child device routes (no Firebase Auth on child device) ──────────
  '/child/pair',
  '/child/dashboard',
  '/child/rules',
  '/child/stats',
  '/child/alerts',
  '/child/rules-summary',
];

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',

    refreshListenable: ApiService(),
    redirect: (context, state) {
      final isAuthenticated = FirebaseAuth.instance.currentUser != null;
      final isPublicRoute = _publicRoutes.contains(state.matchedLocation);

      if (!isAuthenticated && !isPublicRoute) {
        return '/login';
      }

      if (isAuthenticated) {
        final api = ApiService();
        final loc = state.matchedLocation;
        final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;

        // Anonymous users (child devices) are exempt from OTP/KYC checks
        // for public routes (which include all /child/* routes).
        if (isAnonymous || isPublicRoute) {
          return null;
        }

        // 1. Force OTP if not verified
        if (!api.isOtpVerified) {
          if (loc != '/otp-setup') {
            return '/otp-setup';
          }
          return null;
        }

        // 2. Force KYC for protected areas if not verified
        if (!api.isKycVerified) {
          final protectedAreas = ['/dashboard', '/child', '/ai-hub'];
          bool isProtected = protectedAreas.any((area) => loc.startsWith(area));
          if (isProtected) {
            return '/onboarding/kyc';
          }
        }

        // 3. Redirect verified users away from auth/onboarding screens
        if (api.isOtpVerified && api.isKycVerified) {
          if (loc == '/login' || loc == '/signup' || loc == '/otp-setup') {
            return '/dashboard';
          }
        }
      }

      return null;
    },

    routes: [
      // Splash & Welcome
      GoRoute(path: '/', builder: (context, state) => const SplashWelcomeScreen()),
      GoRoute(path: '/cinematic-splash', builder: (context, state) => const CinematicSplashScreen()),

      // Auth
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/verify-identity', builder: (context, state) => const IdentityVerificationScreen()),
      // ADDED: new auth routes
      GoRoute(path: '/otp-setup', builder: (context, state) => const OtpSetupScreen()),
      GoRoute(path: '/subscription', builder: (context, state) => const SubscriptionScreen()),

      // Onboarding
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingIntroAiScreen()),
      GoRoute(path: '/onboarding/vision', builder: (context, state) => const OnboardingVisionAiScreen()),
      GoRoute(path: '/onboarding/kyc', builder: (context, state) => const OnboardingKycScreen()),
      GoRoute(path: '/onboarding/child-profile', builder: (context, state) => const OnboardingChildProfileScreen()),
      GoRoute(path: '/onboarding/pairing', builder: (context, state) => const OnboardingPairingFinalScreen()),

      // Dashboard & Central Hub
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/ai-orchestrator', builder: (context, state) => const DashboardAiOrchestratorScreen()),
      GoRoute(path: '/ai-hub', builder: (context, state) => const HubChatAiScreen()),
      GoRoute(path: '/map', builder: (context, state) => RealTimeMapScreen(initialChild: state.extra)),
      GoRoute(path: '/safe-zones', builder: (context, state) => const SafeZonesScreen()),

      // Child Management
      GoRoute(path: '/child/create', builder: (context, state) => const ChildProfileCreationScreen()),
      GoRoute(path: '/child/details', builder: (context, state) => ChildDetailsScreen(child: state.extra)),
      GoRoute(path: '/child/edit', builder: (context, state) => ChildProfileModificationScreen(child: state.extra)),
      GoRoute(path: '/child/link-gen', builder: (context, state) => InstallLinkGenerationScreen(child: state.extra)),
      GoRoute(path: '/child/link-instr', builder: (context, state) => ChildInstallLinkScreen(child: state.extra)),
      GoRoute(
        path: '/child/pair',
        builder: (context, state) => ChildPairingScreen(
          initialCode: state.uri.queryParameters['code'],
        ),
      ),

      // Settings
      GoRoute(path: '/settings/general', builder: (context, state) => const GeneralSettingsScreen()),
      GoRoute(path: '/settings/account', builder: (context, state) => const AccountScreen()),
      GoRoute(path: '/settings/notifications', builder: (context, state) => const NotificationSettingsScreen()),
      GoRoute(path: '/settings/privacy', builder: (context, state) => const PrivacySettingsScreen()),
      GoRoute(path: '/settings/roles', builder: (context, state) => const RolesPermissionsScreen()),

      // Extras
      GoRoute(path: '/tutorials', builder: (context, state) => const VisualTutorialsScreen()),
      GoRoute(path: '/product-page', builder: (context, state) => const ProductPageScreen()),
      GoRoute(path: '/ai-thinking', builder: (context, state) => const AiThinkingTransitionScreen()),
      GoRoute(path: '/child/config', builder: (context, state) => RulesConfigWizardScreen(child: state.extra)),
      GoRoute(path: '/alert/details', builder: (context, state) => const AiAlertDetailScreen()),
      // NEW routes
      GoRoute(path: '/child/dashboard', builder: (context, state) => ChildDashboardScreen(child: state.extra)),
      GoRoute(path: '/child/rules', builder: (context, state) => RulesEditorScreen(child: state.extra)),
      GoRoute(path: '/child/stats', builder: (context, state) => UsageStatsScreen(child: state.extra)),
      GoRoute(path: '/child/alerts', builder: (context, state) => AlertsScreen(child: state.extra)),
      GoRoute(
        path: '/child/rules-summary',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return RulesSummaryScreen(
            child: extra['child'] as Map<String, dynamic>,
            initialRules: extra['rules'] as Map<String, dynamic>?,
          );
        },
      ),
    ],
  );
}
