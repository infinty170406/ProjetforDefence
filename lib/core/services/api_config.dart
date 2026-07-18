class ApiConfig {
  /// Backend Render utilisé par l'application distribuée.
  static const String productionBaseUrl =
      'https://guardian-secure-api.onrender.com';
  static const String productionWsUrl =
      'wss://guardian-secure-api.onrender.com';

  /// Nouvelle variable de configuration. Une ancienne configuration utilisant
  /// API_BASE_URL reste reconnue, mais les URL locales/HTTP sont refusées.
  static const String _configuredBaseUrl = String.fromEnvironment(
    'GUARDIAN_API_BASE_URL',
  );
  static const String _legacyConfiguredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );
  static const String _configuredWsUrl = String.fromEnvironment(
    'GUARDIAN_WS_URL',
  );

  /// URL REST générale.
  ///
  /// Une valeur locale telle que localhost, 127.0.0.1 ou 10.0.2.2 ne peut plus
  /// remplacer Render, même si elle est encore présente dans une ancienne
  /// configuration de lancement ou un ancien --dart-define.
  static String get baseUrl {
    final configured = _configuredBaseUrl.trim().isNotEmpty
        ? _configuredBaseUrl
        : _legacyConfiguredBaseUrl;
    return _resolveSecureHttpUrl(configured);
  }

  /// URL WebSocket générale. Seules les URL wss:// distantes sont acceptées.
  static String get wsUrl => _resolveSecureWebSocketUrl(_configuredWsUrl);

  // ==================== AUTH ====================
  // login and register are now handled via Firebase Magic Link / OTP
  static const String sendOtp = '/api/v1/auth/otp/send';
  static const String verifyOtp = '/api/v1/auth/otp/verify';
  static const String createInvite = '/api/v1/family/invites';
  static const String acceptInvite = '/api/v1/family/invites/accept';
  static const String pairDevice = '/api/v1/device/pair';
  static const String reportAlert = '/api/v1/device/alerts';
  static const String updateMetadata = '/api/v1/device/metadata';
  static const String analyzeNotification =
      '/api/v1/device/notifications/analyze';
  static const String verifyKyc = '/api/v1/auth/kyc/verify';

  // ==================== BILLING ====================
  static const String billingCheckout = '/api/v1/billing/checkout';
  static const String billingCharge = '/api/v1/billing/charge';
  static String billingPaymentStatus(String reference) =>
      '/api/v1/billing/payments/$reference';

  /// Les paiements sont volontairement verrouillés sur Render.
  /// Ils ne dépendent d'aucun --dart-define afin qu'une ancienne configuration
  /// locale ne puisse jamais envoyer un paiement vers 10.0.2.2/localhost.
  static String get billingCheckoutUrl =>
      '$productionBaseUrl$billingCheckout';
  static String get billingChargeUrl => '$productionBaseUrl$billingCharge';
  static String billingPaymentStatusUrl(String reference) =>
      '$productionBaseUrl${billingPaymentStatus(reference)}';

  static bool isBillingRequest(String pathOrUrl) {
    final uri = Uri.tryParse(pathOrUrl);
    final path = uri?.path ?? pathOrUrl;
    return path == '/api/v1/billing' || path.startsWith('/api/v1/billing/');
  }

  /// Retourne uniquement le chemin d'une requête de paiement afin que Dio
  /// puisse lui appliquer de force [productionBaseUrl].
  static String billingPathFrom(String pathOrUrl) {
    final uri = Uri.tryParse(pathOrUrl);
    if (uri == null || !uri.hasScheme) {
      return pathOrUrl.startsWith('/') ? pathOrUrl : '/$pathOrUrl';
    }

    final query = uri.hasQuery ? '?${uri.query}' : '';
    return '${uri.path}$query';
  }

  // ==================== PARENT ====================
  static const String myChildren = '/api/v1/parents/me/children';
  static const String linkChild = '/api/v1/parents/me/children/link';

  // ==================== PARENTAL CONTROL ====================
  static String parentalProfile(String childId) =>
      '/api/v1/children/$childId/parental/profile';

  static String schedules(String childId) =>
      '/api/v1/children/$childId/parental/schedules';

  static String schedule(String childId, String scheduleId) =>
      '/api/v1/children/$childId/parental/schedules/$scheduleId';

  static String contentRule(String childId, String category) =>
      '/api/v1/children/$childId/parental/content/$category';

  static String contentKeywords(String childId, String category) =>
      '/api/v1/children/$childId/parental/content/$category/keywords';

  // ==================== HISTORY ====================
  static String history(String childId) => '/api/v1/children/$childId/history';

  // ==================== DEVICE ====================
  static String deviceRules(String childId) =>
      '/api/v1/device/children/$childId/rules';

  static String deviceEvents(String childId) =>
      '/api/v1/device/children/$childId/events';

  // ==================== AI ====================
  // Get your free API key from https://aistudio.google.com/
  static String geminiApiKey = '';

  // ==================== EXECUTE ====================
  static const String execute = '/api/v1/execute';

  static String _resolveSecureHttpUrl(String configured) {
    final candidate = configured.trim();
    if (candidate.isEmpty) return productionBaseUrl;

    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        _isLocalOrPrivateHost(uri.host)) {
      return productionBaseUrl;
    }

    return candidate.replaceFirst(RegExp(r'/+$'), '');
  }

  static String _resolveSecureWebSocketUrl(String configured) {
    final candidate = configured.trim();
    if (candidate.isEmpty) return productionWsUrl;

    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'wss' ||
        uri.host.isEmpty ||
        _isLocalOrPrivateHost(uri.host)) {
      return productionWsUrl;
    }

    return candidate.replaceFirst(RegExp(r'/+$'), '');
  }

  static bool _isLocalOrPrivateHost(String host) {
    final normalized = host.toLowerCase();

    if (normalized == 'localhost' ||
        normalized == '0.0.0.0' ||
        normalized == '::1' ||
        normalized.endsWith('.local') ||
        normalized.startsWith('127.') ||
        normalized.startsWith('10.') ||
        normalized.startsWith('192.168.')) {
      return true;
    }

    final parts = normalized.split('.');
    if (parts.length == 4 && parts[0] == '172') {
      final secondOctet = int.tryParse(parts[1]);
      if (secondOctet != null && secondOctet >= 16 && secondOctet <= 31) {
        return true;
      }
    }

    return false;
  }
}
