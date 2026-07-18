part of guardian_landing;

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    required this.colors,
    required this.compact,
    required this.scrolled,
    required this.menuOpen,
    required this.onToggleMenu,
    required this.onProduct,
    required this.onFeatures,
    required this.onSecurity,
    required this.onPricing,
    required this.onFaq,
    required this.onLogin,
    required this.onSignup,
  });

  final _LandingColors colors;
  final bool compact;
  final bool scrolled;
  final bool menuOpen;
  final VoidCallback onToggleMenu;
  final VoidCallback onProduct;
  final VoidCallback onFeatures;
  final VoidCallback onSecurity;
  final VoidCallback onPricing;
  final VoidCallback onFaq;
  final VoidCallback onLogin;
  final VoidCallback onSignup;

  @override
  Widget build(BuildContext context) {
    final stateManager = context.watch<AppStateManager>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 12 : 24,
          compact ? 8 : 12,
          compact ? 12 : 24,
          0,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: scrolled || menuOpen ? 18 : 10,
                  sigmaY: scrolled || menuOpen ? 18 : 10,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    color: scrolled || menuOpen
                        ? colors.navBackground
                        : colors.navBackground.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.border),
                    boxShadow: scrolled
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ]
                        : const [],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 14 : 18,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const _BrandMark(),
                            const Spacer(),
                            if (!compact) ...[
                              _NavLink(label: 'Produit', onTap: onProduct),
                              _NavLink(
                                  label: 'Fonctionnalités', onTap: onFeatures),
                              _NavLink(label: 'Sécurité', onTap: onSecurity),
                              _NavLink(label: 'Tarifs', onTap: onPricing),
                              _NavLink(label: 'FAQ', onTap: onFaq),
                              const SizedBox(width: 10),
                            ],
                            Tooltip(
                              message: isDark
                                  ? 'Activer le thème clair'
                                  : 'Activer le thème sombre',
                              child: IconButton(
                                onPressed: () {
                                  stateManager.setThemeMode(
                                    isDark ? ThemeMode.light : ThemeMode.dark,
                                  );
                                },
                                icon: Icon(
                                  isDark
                                      ? Icons.light_mode_rounded
                                      : Icons.dark_mode_rounded,
                                  color: colors.mutedText,
                                ),
                              ),
                            ),
                            if (!compact) ...[
                              TextButton(
                                onPressed: onLogin,
                                style: TextButton.styleFrom(
                                  foregroundColor: colors.text,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text('Se connecter'),
                              ),
                              const SizedBox(width: 6),
                              _GradientButton(
                                label: 'Créer un compte',
                                onPressed: onSignup,
                                compact: true,
                              ),
                            ] else
                              IconButton(
                                onPressed: onToggleMenu,
                                tooltip: menuOpen
                                    ? 'Fermer le menu'
                                    : 'Ouvrir le menu',
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    menuOpen
                                        ? Icons.close_rounded
                                        : Icons.menu_rounded,
                                    key: ValueKey(menuOpen),
                                    color: colors.text,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox(width: double.infinity),
                        secondChild: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: Column(
                            children: [
                              _MobileNavItem(
                                icon: Icons.dashboard_customize_rounded,
                                label: 'Produit',
                                onTap: onProduct,
                              ),
                              _MobileNavItem(
                                icon: Icons.auto_awesome_rounded,
                                label: 'Fonctionnalités',
                                onTap: onFeatures,
                              ),
                              _MobileNavItem(
                                icon: Icons.shield_outlined,
                                label: 'Sécurité',
                                onTap: onSecurity,
                              ),
                              _MobileNavItem(
                                icon: Icons.workspace_premium_outlined,
                                label: 'Tarifs',
                                onTap: onPricing,
                              ),
                              _MobileNavItem(
                                icon: Icons.help_outline_rounded,
                                label: 'FAQ',
                                onTap: onFaq,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: onLogin,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: colors.text,
                                        side: BorderSide(color: colors.border),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 15),
                                      ),
                                      child: const Text('Connexion'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _GradientButton(
                                      label: 'Créer un compte',
                                      onPressed: onSignup,
                                      compact: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        crossFadeState: menuOpen
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 260),
                        sizeCurve: Curves.easeOutCubic,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.colors,
    required this.isCompact,
    required this.isTablet,
    required this.onPrimary,
    required this.onSecondary,
  });

  final _LandingColors colors;
  final bool isCompact;
  final bool isTablet;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return _SectionFrame(
      paddingTop: isCompact ? 36 : 54,
      paddingBottom: isCompact ? 56 : 86,
      horizontalPadding: isCompact ? 18 : 28,
      child: isCompact || isTablet
          ? Column(
              children: [
                _HeroCopy(
                  colors: colors,
                  centered: true,
                  compact: isCompact,
                  onPrimary: onPrimary,
                  onSecondary: onSecondary,
                ),
                SizedBox(height: isCompact ? 42 : 58),
                _HeroVisual(
                  colors: colors,
                  compact: isCompact,
                  tablet: isTablet,
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 9,
                  child: _HeroCopy(
                    colors: colors,
                    centered: false,
                    compact: false,
                    onPrimary: onPrimary,
                    onSecondary: onSecondary,
                  ),
                ),
                const SizedBox(width: 56),
                Expanded(
                  flex: 11,
                  child: _HeroVisual(
                    colors: colors,
                    compact: false,
                    tablet: false,
                  ),
                ),
              ],
            ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.colors,
    required this.centered,
    required this.compact,
    required this.onPrimary,
    required this.onSecondary,
  });

  final _LandingColors colors;
  final bool centered;
  final bool compact;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final titleSize = compact ? 42.0 : 64.0;
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment:
            centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          _Pill(
            icon: Icons.shield_rounded,
            label: 'LE CENTRE DE CONTRÔLE DE VOTRE FAMILLE',
            colors: colors,
          ),
          const SizedBox(height: 24),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Protégez leur monde numérique.\n'),
                TextSpan(
                  text: 'Gardez l’essentiel sous vos yeux.',
                  style: TextStyle(
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [Color(0xFF8B7CFF), Color(0xFF20D7C5)],
                      ).createShader(const Rect.fromLTWH(0, 0, 720, 90)),
                  ),
                ),
              ],
            ),
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: colors.text,
              fontSize: titleSize,
              height: 1.02,
              fontWeight: FontWeight.w900,
              letterSpacing: -2.3,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 670),
            child: Text(
              'Guardian réunit localisation, temps d’écran, règles, alertes et accompagnement intelligent dans un espace parent accessible sur mobile et sur le web.',
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                color: colors.bodyText,
                fontSize: compact ? 16 : 18,
                height: 1.65,
                fontFamily: 'Outfit',
              ),
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            alignment: centered ? WrapAlignment.center : WrapAlignment.start,
            spacing: 12,
            runSpacing: 12,
            children: [
              _GradientButton(
                label: 'Créer mon espace parent',
                icon: Icons.arrow_forward_rounded,
                onPressed: onPrimary,
              ),
              OutlinedButton.icon(
                onPressed: onSecondary,
                icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                label: const Text('Découvrir le dashboard'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.text,
                  backgroundColor: colors.surface.withValues(alpha: 0.42),
                  side: BorderSide(color: colors.border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Wrap(
            alignment: centered ? WrapAlignment.center : WrapAlignment.start,
            spacing: 20,
            runSpacing: 12,
            children: const [
              _HeroAssurance(
                icon: Icons.sync_rounded,
                text: 'Mobile et web synchronisés',
              ),
              _HeroAssurance(
                icon: Icons.family_restroom_rounded,
                text: 'Gestion multi-enfants',
              ),
              _HeroAssurance(
                icon: Icons.lock_outline_rounded,
                text: 'Accès parent sécurisé',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroVisual extends StatelessWidget {
  const _HeroVisual({
    required this.colors,
    required this.compact,
    required this.tablet,
  });

  final _LandingColors colors;
  final bool compact;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 430.0 : (tablet ? 570.0 : 620.0);
    return Semantics(
      label:
          'Aperçu du dashboard web Guardian avec la version mobile synchronisée',
      image: true,
      child: SizedBox(
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6C4DFF).withValues(alpha: 0.26),
                      const Color(0xFF20D7C5).withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              left: compact ? 4 : 0,
              right: compact ? 4 : 40,
              top: compact ? 52 : 36,
              bottom: compact ? 58 : 42,
              child: _GlassPanel(
                colors: colors,
                radius: 30,
                padding: EdgeInsets.all(compact ? 8 : 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: const FittedBox(
                    fit: BoxFit.contain,
                    child: LaptopDashboardMockup(),
                  ),
                ),
              ),
            ),
            if (!compact)
              Positioned(
                right: 0,
                bottom: 0,
                child: SizedBox(
                  width: tablet ? 190 : 220,
                  height: tablet ? 360 : 410,
                  child: const FittedBox(
                    fit: BoxFit.contain,
                    child: SmartphoneAppMockup(),
                  ),
                ),
              ),
            Positioned(
              left: compact ? 8 : 4,
              top: compact ? 12 : 4,
              child: _FloatingStatusCard(
                colors: colors,
                icon: Icons.verified_user_rounded,
                iconColor: const Color(0xFF20D7C5),
                title: '3 appareils protégés',
                subtitle: 'Synchronisation active',
              ),
            ),
            if (!compact)
              Positioned(
                right: 24,
                top: 74,
                child: _FloatingStatusCard(
                  colors: colors,
                  icon: Icons.location_on_rounded,
                  iconColor: const Color(0xFF5DA9FF),
                  title: 'Emma est arrivée',
                  subtitle: 'Zone École · à l’instant',
                ),
              ),
            Positioned(
              left: compact ? 16 : 34,
              bottom: compact ? 6 : 10,
              child: _FloatingStatusCard(
                colors: colors,
                icon: Icons.schedule_rounded,
                iconColor: const Color(0xFFFFA657),
                title: '1 h 15 restante',
                subtitle: 'Temps d’écran aujourd’hui',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip({required this.colors, required this.isCompact});

  final _LandingColors colors;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.monitor_heart_outlined, 'Vue familiale', 'Tout au même endroit'),
      (Icons.sync_alt_rounded, 'Temps réel', 'Mobile et web reliés'),
      (Icons.tune_rounded, 'Règles flexibles', 'Adaptées au quotidien'),
      (Icons.shield_outlined, 'Confidentialité', 'Contrôles transparents'),
    ];

    return _SectionFrame(
      paddingTop: 0,
      paddingBottom: isCompact ? 64 : 86,
      horizontalPadding: isCompact ? 18 : 28,
      child: _GlassPanel(
        colors: colors,
        radius: 26,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 18 : 28,
          vertical: 22,
        ),
        child: Wrap(
          spacing: 18,
          runSpacing: 20,
          alignment: WrapAlignment.spaceAround,
          children: items.map((item) {
            return SizedBox(
              width: isCompact ? 145 : 245,
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C4DFF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(item.$1,
                        color: const Color(0xFF8B7CFF), size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$2,
                          style: TextStyle(
                            color: colors.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$3,
                          style: TextStyle(
                            color: colors.mutedText,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
