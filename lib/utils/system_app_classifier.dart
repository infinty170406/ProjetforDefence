/// Source unique de vérité pour classifier les packages Android.
///
/// Deux contextes :
///   - [forUsageStats] : exclut launchers, GMS, paramètres… des stats d'usage.
///   - [forEnforcement] : respecte les apps explicitement bloquées par le parent
///     (ex. Paramètres) et les apps sociales/jeux connues.
class SystemAppClassifier {
  SystemAppClassifier._();

  /// Apps utilisateur — jamais considérées comme système.
  static const Set<String> userPackages = {
    'com.google.android.youtube',
    'com.google.android.apps.youtube.kids',
    'com.google.android.apps.maps',
    'com.google.android.gm',
    'com.google.android.googlequicksearchbox',
    'com.android.chrome',
    'com.android.vending',
    'com.whatsapp',
    'com.snapchat.android',
    'com.instagram.android',
    'com.facebook.katana',
    'com.tiktok',
    'com.zhiliaoapp.musically',
    'com.miui.gallery',
    'com.miui.video',
    'com.miui.player',
    'com.miui.notes',
    'com.miui.browser',
  };

  /// Infrastructure toujours exclue (stats + enforcement).
  static const Set<String> infrastructurePackages = {
    'android',
    'com.android.systemui',
    'com.android.launcher',
    'com.android.launcher3',
    'com.android.phone',
    'com.android.inputmethod.latin',
    'com.google.android.inputmethod.latin',
    'com.google.android.gms',
    'com.google.android.gsf',
    'com.miui.home',
    'com.miui.securitycenter',
    'com.miui.msa.global',
    'com.miui.bugreport',
    'com.miui.daemon',
    'com.miui.analytics',
    'com.xiaomi.market',
    'com.xiaomi.simactivate.service',
    'com.lbe.security.miui',
    'app.theguardian.child',
  };

  /// Exclu des stats d'usage uniquement (Paramètres = infra pour les stats).
  static const Set<String> usageStatsOnlyInfrastructure = {
    'com.android.settings',
  };

  static const List<String> systemPrefixes = [
    'com.android.',
    'com.google.android.',
    'com.miui.',
    'com.xiaomi.',
    'com.qualcomm.',
    'com.mediatek.',
    'com.samsung.',
    'com.huawei.',
    'com.oppo.',
    'com.vivo.',
    'com.oneplus.',
    'com.coloros.',
    'com.heytap.',
    'com.bbk.',
  ];

  /// Pour les stats d'usage (UsageStats) — exclut launchers, GMS, paramètres…
  static bool forUsageStats(String pkg) =>
      _isSystem(pkg, includeUsageOnlyInfrastructure: true);

  /// Pour l'enforcement — une app bloquée par le parent n'est jamais "système".
  static bool forEnforcement(
    String pkg, {
    Set<String>? blockedByParent,
    Set<String>? additionalUserPackages,
  }) {
    if (blockedByParent != null && blockedByParent.contains(pkg)) return false;
    return _isSystem(
      pkg,
      additionalUserPackages: additionalUserPackages,
      includeUsageOnlyInfrastructure: false,
    );
  }

  static bool _isSystem(
    String pkg, {
    Set<String>? additionalUserPackages,
    required bool includeUsageOnlyInfrastructure,
  }) {
    if (userPackages.contains(pkg)) return false;
    if (additionalUserPackages != null && additionalUserPackages.contains(pkg)) {
      return false;
    }
    if (infrastructurePackages.contains(pkg)) return true;
    if (includeUsageOnlyInfrastructure &&
        usageStatsOnlyInfrastructure.contains(pkg)) {
      return true;
    }
    return systemPrefixes.any(pkg.startsWith);
  }
}
