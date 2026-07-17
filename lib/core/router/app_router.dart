import '../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../screens/onboarding/splash_welcome_screen.dart';
import '../../screens/onboarding/onboarding_intro_ai_screen.dart';
import '../../screens/onboarding/onboarding_vision_ai_screen.dart';
import '../../screens/onboarding/onboarding_kyc_screen.dart';
import '../../screens/onboarding/onboarding_child_profile_screen.dart';
import '../../screens/onboarding/onboarding_pairing_final_screen.dart';
import '../../screens/onboarding/subscription_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/identity_verification_screen.dart';
import '../../screens/onboarding/initial_setup_screen.dart';
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
import '../../screens/dashboard/weekly_report_screen.dart';
import '../../screens/settings/account_screen.dart';
import '../../screens/child/child_dashboard_screen.dart';
import '../../screens/child/rules_editor_screen.dart';
import '../../screens/monitoring/usage_stats_screen.dart';
import '../../screens/monitoring/alerts_screen.dart';
import '../../screens/auth/child_pairing_screen.dart';
import '../../features/subscription/presentation/my_subscription_screen.dart';
import '../../features/subscription/presentation/premium_showcase_screen.dart';
import '../../screens/onboarding/landing_screen.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/dashboard/main_shell.dart';
import '../widgets/route_argument_error_screen.dart';

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
  '/login/parent',
  '/login/admin',
  '/child/pair',
];

Map<String, dynamic>? _childRouteExtra(Object? extra) {
  if (extra is Map<String, dynamic> &&
      (extra['id'] is String || extra['childId'] is String)) {
    return extra;
  }
  return null;
}

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
        final isAnonymous =
            FirebaseAuth.instance.currentUser?.isAnonymous ?? false;

        if (isAnonymous || isPublicRoute) {
          return null;
        }

        if (!api.isOtpVerified) {
          if (loc != '/otp-setup') {
            return '/otp-setup';
          }
          return null;
        }

        if (!api.isKycVerified && !api.isKycBypassed) {
          final protectedAreas = ['/dashboard', '/child', '/ai-hub'];
          bool isProtected = protectedAreas.any((area) => loc.startsWith(area));
          if (isProtected) {
            return '/onboarding/kyc';
          }
        }

        if (api.isOtpVerified && api.isKycVerified) {
          if (loc == '/login' ||
              loc == '/signup' ||
              loc == '/otp-setup' ||
              loc == '/login/parent' ||
              loc == '/login/admin' ||
              loc == '/dashboard/web') {
            return '/dashboard';
          }
        }
      }

      return null;
    },
    routes: [
      // Splash & Welcome
      GoRoute(
        path: '/',
        builder: (context, state) =>
            kIsWeb ? const LandingScreen() : const SplashWelcomeScreen(),
      ),
      GoRoute(
          path: '/cinematic-splash',
          builder: (context, state) => const CinematicSplashScreen()),

      // Auth
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(
          path: '/verify-identity',
          builder: (context, state) => const IdentityVerificationScreen()),
      GoRoute(
          path: '/otp-setup',
          builder: (context, state) => const OtpSetupScreen()),
      GoRoute(
          path: '/subscription',
          builder: (context, state) => const SubscriptionScreen()),

      // Web specific auth routes
      GoRoute(
          path: '/login/parent',
          builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/login/admin',
          builder: (context, state) => const LoginScreen(isAdmin: true)),
      GoRoute(
          path: '/dashboard/web',
          builder: (context, state) => const DashboardScreen()),
      GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(
          path: '/admin/web',
          builder: (context, state) => const AdminDashboardScreen()),

      // Onboarding
      GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingIntroAiScreen()),
      GoRoute(
          path: '/onboarding/vision',
          builder: (context, state) => const OnboardingVisionAiScreen()),
      GoRoute(
          path: '/onboarding/kyc',
          builder: (context, state) => const OnboardingKycScreen()),
      GoRoute(
          path: '/onboarding/child-profile',
          builder: (context, state) => const OnboardingChildProfileScreen()),
      GoRoute(
          path: '/onboarding/pairing',
          builder: (context, state) => const OnboardingPairingFinalScreen()),
      GoRoute(
          path: '/initial-setup',
          builder: (context, state) => const InitialSetupScreen()),

      // Shell Route for Parent Dashboard pages containing sidebar/bottom bar
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen()),
          GoRoute(
              path: '/ai-orchestrator',
              builder: (context, state) =>
                  const DashboardAiOrchestratorScreen()),
          GoRoute(
              path: '/ai-hub',
              builder: (context, state) => const HubChatAiScreen()),
          GoRoute(
              path: '/map',
              builder: (context, state) =>
                  RealTimeMapScreen(initialChild: state.extra)),
          GoRoute(
              path: '/safe-zones',
              builder: (context, state) => const SafeZonesScreen()),

          // Child Management (inside the shell so we keep the sidebar on desktop/tablet)
          GoRoute(
              path: '/subscription/manage',
              builder: (context, state) => const MySubscriptionScreen()),
          GoRoute(
              path: '/child/create',
              builder: (context, state) => const ChildProfileCreationScreen()),
          GoRoute(
              path: '/child/details',
              builder: (context, state) => _childPage(
                  state.extra, (child) => ChildDetailsScreen(child: child))),
          GoRoute(
              path: '/child/edit',
              builder: (context, state) => _childPage(state.extra,
                  (child) => ChildProfileModificationScreen(child: child))),
          GoRoute(
              path: '/child/link-gen',
              builder: (context, state) => _childPage(state.extra,
                  (child) => InstallLinkGenerationScreen(child: child))),
          GoRoute(
              path: '/child/link-instr',
              builder: (context, state) => _childPage(state.extra,
                  (child) => ChildInstallLinkScreen(child: child))),
          GoRoute(
              path: '/child/pair',
              builder: (context, state) => ChildPairingScreen(
                  initialCode: state.uri.queryParameters['code'])),
          GoRoute(
              path: '/child/config',
              builder: (context, state) => _childPage(state.extra,
                  (child) => RulesConfigWizardScreen(child: child))),
          GoRoute(
              path: '/child/dashboard',
              builder: (context, state) => _childPage(
                  state.extra, (child) => ChildDashboardScreen(child: child))),
          GoRoute(
              path: '/child/rules',
              builder: (context, state) => _childPage(
                  state.extra, (child) => RulesEditorScreen(child: child))),
          GoRoute(
              path: '/child/stats',
              builder: (context, state) => _childPage(
                  state.extra, (child) => UsageStatsScreen(child: child))),
          GoRoute(
              path: '/child/alerts',
              builder: (context, state) => _childPage(
                  state.extra, (child) => AlertsScreen(child: child))),
          GoRoute(
            path: '/child/rules-summary',
            builder: (context, state) {
              final extra = state.extra;
              if (extra is! Map<String, dynamic> ||
                  _childRouteExtra(extra['child']) == null) {
                return const RouteArgumentErrorScreen();
              }
              return RulesSummaryScreen(
                child: _childRouteExtra(extra['child'])!,
                initialRules: extra['rules'] as Map<String, dynamic>?,
              );
            },
          ),

          // Settings
          GoRoute(
              path: '/settings/general',
              builder: (context, state) => const GeneralSettingsScreen()),
          GoRoute(
              path: '/settings/account',
              builder: (context, state) => const AccountScreen()),
          GoRoute(
              path: '/settings/notifications',
              builder: (context, state) => const NotificationSettingsScreen()),
          GoRoute(
              path: '/settings/privacy',
              builder: (context, state) => const PrivacySettingsScreen()),
          GoRoute(
              path: '/settings/roles',
              builder: (context, state) => const RolesPermissionsScreen()),
          GoRoute(
              path: '/settings/subscription',
              builder: (context, state) => const MySubscriptionScreen()),
          GoRoute(
              path: '/premium-showcase',
              builder: (context, state) => const PremiumShowcaseScreen()),
          GoRoute(
              path: '/premium',
              builder: (context, state) => const PremiumShowcaseScreen()),

          // Extras
          GoRoute(
              path: '/tutorials',
              builder: (context, state) => const VisualTutorialsScreen()),
          GoRoute(
              path: '/product-page',
              builder: (context, state) => const ProductPageScreen()),
          GoRoute(
              path: '/ai-thinking',
              builder: (context, state) => const AiThinkingTransitionScreen()),
          GoRoute(
              path: '/alert/details',
              builder: (context, state) => AiAlertDetailScreen(
                  args: state.extra as Map<String, dynamic>?)),
          GoRoute(
              path: '/ai-report',
              builder: (context, state) =>
                  WeeklyReportScreen(child: state.extra)),
        ],
      ),
    ],
  );
}

Widget _childPage(
  Object? extra,
  Widget Function(Map<String, dynamic> child) builder,
) {
  final child = _childRouteExtra(extra);
  if (child == null) return const RouteArgumentErrorScreen();
  return builder(child);
}
