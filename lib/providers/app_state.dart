import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_service.dart';
import '../services/link_handler_service.dart';
import '../services/rules_service.dart';
import '../services/enforcement_service.dart';
import '../services/background_service.dart';
import '../models/child_profile.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AppState
class AppState extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final RulesService _rulesService = RulesService();

  bool _isActivated   = false;
  bool _isLoading     = true;
  bool _isOnline      = false;
  bool _hasUsagePermission = false;
  bool _hasAccessibilityPermission = false;
  bool _hasOverlayPermission = false;
  bool _hasLocationPermission = false;
  bool _hasBatteryExemption = false;
  ChildProfile? _childProfile;
  ActiveRules _activeRules = ActiveRules.empty;

  StreamSubscription<ChildProfile?>? _profileSub;
  Timer? _usageTimer;

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get isActivated  => _isActivated;
  bool get isLoading    => _isLoading;
  bool get isOnline     => _isOnline;
  bool get hasUsagePermission => _hasUsagePermission;
  bool get hasAccessibilityPermission => _hasAccessibilityPermission;
  bool get hasOverlayPermission => _hasOverlayPermission;
  bool get hasLocationPermission => _hasLocationPermission;
  bool get hasBatteryExemption => _hasBatteryExemption;
  ChildProfile? get childProfile => _childProfile;
  String get childName  => _childProfile?.name ?? '';
  ActiveRules get activeRules => _activeRules;

  bool get isScreenTimeLimitReached {
    final rules = _activeRules;
    final isReached = rules.dailyLimitMinutes > 0 &&
        (_todayUsedMinutes >= rules.dailyLimitMinutes);
    if (isReached) {
      debugPrint('AppState: Daily limit reached! Used: $_todayUsedMinutes, Limit: ${rules.dailyLimitMinutes}');
    }
    return isReached;
  }

  bool get isOutsideAllowedHours {
    final rules = _activeRules;
    final start = rules.allowedTimeStart;
    final end   = rules.allowedTimeEnd;
    if (start == null || end == null) return false;

    final now     = DateTime.now();
    final current = now.hour * 60 + now.minute;
    final s       = _parseTime(start);
    final e       = _parseTime(end);
    if (s == null || e == null) return false;

    if (s <= e) return current < s || current >= e;
    return current >= e && current < s;
  }

  DateTime? get nextUnlockTime {
    final rules = _activeRules;
    final now = DateTime.now();

    if (isScreenTimeLimitReached) {
      return DateTime(now.year, now.month, now.day + 1);
    }

    if (isOutsideAllowedHours) {
      final startStr = rules.allowedTimeStart;
      if (startStr != null) {
        final start = _parseTime(startStr);
        if (start != null) {
          var unlock = DateTime(now.year, now.month, now.day, start ~/ 60, start % 60);
          if (unlock.isBefore(now)) {
            unlock = unlock.add(const Duration(days: 1));
          }
          return unlock;
        }
      }
    }
    return null;
  }

  int get blockedAppCount => _activeRules.effectiveBlockedPackages(
    socialMediaPackages: EnforcementService.socialMedia,
    gamingPackages: EnforcementService.gaming,
  ).length;

  bool get isWebFilteringActive =>
      _activeRules.blockAdultContent ||
      _activeRules.blockViolence ||
      _activeRules.blockGambling;

  int get blockedWebsiteCount => _activeRules.blockedWebsites.length;
  int get keywordCount => _activeRules.customKeywords.length;

  String get geofenceSummary => _activeRules.geofences.isEmpty
      ? ''
      : _activeRules.geofences.map((g) => g.name).join(', ');

  int _todayUsedMinutes = 0;

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _isLoading = true;
    _isActivated = await _authService.isDeviceActivated();

    if (_isActivated) {
      await _loadProfile();
      await _startListeners();
      _isOnline = true;
      debugPrint('AppState: Activated device found, checking permissions...');
      await checkAllPermissions();
    }

    _isLoading = false;
    notifyListeners();
    LinkHandlerService().processPendingLink();
  }

  Future<void> _loadProfile() async {
    _childProfile = await _authService.getChildProfile();
    notifyListeners();
  }

  Future<void> _startListeners() async {
    _profileSub = _authService.watchChildProfile().listen((p) {
      if (p != null) {
        _childProfile = p;
        notifyListeners();
      }
    });

    // On attend le premier chargement des règles pour que l'UI soit à jour immédiatement
    await _rulesService.start(waitForFirstLoad: true);
    _rulesService.addListener(_onRulesChanged);
    _activeRules = _rulesService.current;

    FlutterBackgroundService().on('screenTimeUpdate').listen((data) {
      final minutes = data?['minutes'] as int? ?? 0;
      if (minutes != _todayUsedMinutes) {
        _todayUsedMinutes = minutes;
        notifyListeners();
      }
    });
    
    notifyListeners();
  }



  void _onRulesChanged(ActiveRules rules) {
    _activeRules = rules;
    notifyListeners();
  }

  Future<void> onDeviceActivated() async {
    debugPrint('AppState: Handling device activation...');
    _isActivated = true;
    _isOnline = true;
    FlutterBackgroundService().invoke('onActivated');
    await _loadProfile();
    await _startListeners();
    await checkAllPermissions();
    notifyListeners();
  }

  Future<bool> checkAllPermissions() async {
    final r = await Future.wait([
      UsageStats.checkUsagePermission(),
      const MethodChannel('app.theguardian.child/system').invokeMethod<bool>('isAccessibilityEnabled'),
      const MethodChannel('app.theguardian.child/system').invokeMethod<bool>('hasOverlayPermission'),
      Permission.location.isGranted,
      const MethodChannel('app.theguardian.child/system').invokeMethod<bool>('isIgnoringBatteryOptimizations'),
    ]);

    _hasUsagePermission         = r[0] ?? false;
    _hasAccessibilityPermission = r[1] ?? false;
    _hasOverlayPermission       = r[2] ?? false;
    _hasLocationPermission      = r[3] ?? false;
    _hasBatteryExemption        = r[4] ?? false;
    
    // NOUVEAU : Onboarding considéré fini si le trio critique (Usage + A11y + Overlay) est là.
    // La localisation est importante pour le parent mais ne bloque pas l'enforcement des apps.
    final hasCriticalPermissions = _hasUsagePermission && 
                                  _hasAccessibilityPermission && 
                                  _hasOverlayPermission;

    if (hasCriticalPermissions) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
      await BackgroundService().startIfPermissionsGranted();
    }

    notifyListeners();
    return hasCriticalPermissions;
  }

  Future<void> requestUsagePermission() async {
    await UsageStats.grantUsagePermission();
    await checkAllPermissions();
  }

  Future<void> requestAccessibilityPermission() async {
    const MethodChannel('app.theguardian.child/system')
        .invokeMethod('openAccessibilitySettings');
    await Future.delayed(const Duration(seconds: 2));
    await checkAllPermissions();
  }

  Future<void> requestOverlayPermission() async {
    const MethodChannel('app.theguardian.child/system')
        .invokeMethod('openOverlaySettings');
    await Future.delayed(const Duration(seconds: 2));
    await checkAllPermissions();
  }

  Future<void> requestLocationPermission() async {
    await Permission.location.request();
    await checkAllPermissions();
  }

  Future<void> requestBatteryExemption() async {
    await const MethodChannel('app.theguardian.child/system')
        .invokeMethod('requestIgnoreBatteryOptimizations');
    await Future.delayed(const Duration(seconds: 2));
    await checkAllPermissions();
  }

  int? _parseTime(String t) {
    final p = t.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _rulesService.removeListener(_onRulesChanged);
    super.dispose();
  }
}
