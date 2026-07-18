part of guardian_landing;

class _ProductShowcase extends StatelessWidget {
  const _ProductShowcase({
    required this.colors,
    required this.isCompact,
    required this.activeTab,
    required this.onTabChanged,
  });

  final _LandingColors colors;
  final bool isCompact;
  final int activeTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (
        'Vue familiale',
        Icons.dashboard_rounded,
        'Une lecture immédiate de la situation familiale.',
        'Repérez les enfants connectés, les appareils actifs, le temps d’écran et les dernières alertes sans multiplier les écrans.',
      ),
      (
        'Règles intelligentes',
        Icons.tune_rounded,
        'Des règles précises, compréhensibles et faciles à ajuster.',
        'Configurez les horaires, les limites et les applications autorisées depuis une interface confortable sur grand écran.',
      ),
      (
        'Alertes prioritaires',
        Icons.notifications_active_rounded,
        'L’important remonte, le reste reste organisé.',
        'Les événements sont regroupés par priorité afin de distinguer une information normale d’une situation qui demande votre attention.',
      ),
    ];
    final current = tabs[activeTab];

    return Container(
      color: colors.sectionTint,
      child: _SectionFrame(
        paddingTop: isCompact ? 72 : 108,
        paddingBottom: isCompact ? 72 : 108,
        horizontalPadding: isCompact ? 18 : 28,
        child: Column(
          children: [
            _SectionHeading(
              colors: colors,
              eyebrow: 'LE PRODUIT AU CENTRE',
              title: 'Toute votre famille, dans un seul espace.',
              description:
                  'Guardian transforme le navigateur en véritable centre de contrôle parent, avec davantage de recul et de confort que sur un petit écran.',
              centered: true,
              compact: isCompact,
            ),
            SizedBox(height: isCompact ? 36 : 54),
            if (isCompact) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(
                    tabs.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _ProductTab(
                        label: tabs[index].$1,
                        icon: tabs[index].$2,
                        selected: activeTab == index,
                        colors: colors,
                        onTap: () => onTabChanged(index),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
            ],
            _GlassPanel(
              colors: colors,
              radius: 34,
              padding: EdgeInsets.all(isCompact ? 14 : 24),
              child: isCompact
                  ? Column(
                      children: [
                        _ProductWindow(
                          colors: colors,
                          activeTab: activeTab,
                          compact: true,
                        ),
                        const SizedBox(height: 24),
                        _ProductDescription(
                          colors: colors,
                          title: current.$3,
                          description: current.$4,
                          activeTab: activeTab,
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 260,
                          child: Column(
                            children: List.generate(
                              tabs.length,
                              (index) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ProductTab(
                                  label: tabs[index].$1,
                                  icon: tabs[index].$2,
                                  selected: activeTab == index,
                                  colors: colors,
                                  vertical: true,
                                  onTap: () => onTabChanged(index),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 22),
                        Expanded(
                          child: _ProductWindow(
                            colors: colors,
                            activeTab: activeTab,
                            compact: false,
                          ),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 270,
                          child: _ProductDescription(
                            colors: colors,
                            title: current.$3,
                            description: current.$4,
                            activeTab: activeTab,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductWindow extends StatelessWidget {
  const _ProductWindow({
    required this.colors,
    required this.activeTab,
    required this.compact,
  });

  final _LandingColors colors;
  final int activeTab;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      child: Container(
        key: ValueKey(activeTab),
        height: compact ? 330 : 460,
        decoration: BoxDecoration(
          color: const Color(0xFF071020),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C4DFF).withValues(alpha: 0.12),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: activeTab == 0
            ? const FittedBox(
                fit: BoxFit.contain,
                child: LaptopDashboardMockup(),
              )
            : activeTab == 1
                ? _RulesPreview(compact: compact)
                : _AlertsPreview(compact: compact),
      ),
    );
  }
}

class _RulesPreview extends StatelessWidget {
  const _RulesPreview({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(compact ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PreviewTopBar(
            title: 'Règles de Lucas',
            subtitle: 'Aujourd’hui · Mercredi',
          ),
          const SizedBox(height: 22),
          Expanded(
            child: Row(
              children: [
                if (!compact) ...[
                  Expanded(
                    flex: 4,
                    child: _PreviewPanel(
                      title: 'Routine du jour',
                      icon: Icons.calendar_month_rounded,
                      child: const Column(
                        children: [
                          _TimelineRule(
                            time: '07:30',
                            title: 'Mode école',
                            description: 'Jeux et réseaux en pause',
                            color: Color(0xFF5DA9FF),
                          ),
                          _TimelineRule(
                            time: '16:30',
                            title: 'Temps libre',
                            description: '1 h 30 disponible',
                            color: Color(0xFF20D7C5),
                          ),
                          _TimelineRule(
                            time: '21:00',
                            title: 'Mode sommeil',
                            description: 'Seuls les appels restent actifs',
                            color: Color(0xFFC084FC),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  flex: 5,
                  child: _PreviewPanel(
                    title: 'Applications',
                    icon: Icons.apps_rounded,
                    child: Column(
                      children: const [
                        _AppRuleRow(
                          icon: Icons.smart_display_rounded,
                          name: 'Vidéo',
                          value: '45 min',
                          progress: 0.68,
                          color: Color(0xFFFF6B7D),
                        ),
                        _AppRuleRow(
                          icon: Icons.sports_esports_rounded,
                          name: 'Jeux',
                          value: '30 min',
                          progress: 0.42,
                          color: Color(0xFF8B7CFF),
                        ),
                        _AppRuleRow(
                          icon: Icons.school_rounded,
                          name: 'Éducation',
                          value: 'Toujours',
                          progress: 1,
                          color: Color(0xFF20D7C5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertsPreview extends StatelessWidget {
  const _AlertsPreview({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(compact ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PreviewTopBar(
            title: 'Centre d’alertes',
            subtitle: '4 événements aujourd’hui',
          ),
          const SizedBox(height: 20),
          Row(
            children: const [
              Expanded(
                child: _AlertSummary(
                  label: 'À vérifier',
                  value: '1',
                  color: Color(0xFFFF6B7D),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _AlertSummary(
                  label: 'Informations',
                  value: '3',
                  color: Color(0xFF5DA9FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Expanded(
            child: Column(
              children: [
                _AlertRow(
                  icon: Icons.location_on_rounded,
                  title: 'Emma a quitté la zone École',
                  subtitle: 'Il y a 8 minutes · Position synchronisée',
                  color: Color(0xFF5DA9FF),
                  tag: 'Information',
                ),
                _AlertRow(
                  icon: Icons.download_rounded,
                  title: 'Nouvelle application installée',
                  subtitle: 'Lucas · Vérification recommandée',
                  color: Color(0xFFFFA657),
                  tag: 'À vérifier',
                ),
                _AlertRow(
                  icon: Icons.schedule_rounded,
                  title: 'Limite de temps presque atteinte',
                  subtitle: '15 minutes restantes aujourd’hui',
                  color: Color(0xFFC084FC),
                  tag: 'Rappel',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductDescription extends StatelessWidget {
  const _ProductDescription({
    required this.colors,
    required this.title,
    required this.description,
    required this.activeTab,
  });

  final _LandingColors colors;
  final String title;
  final String description;
  final int activeTab;

  @override
  Widget build(BuildContext context) {
    const bullets = [
      ['Profils et appareils visibles immédiatement', 'Actions rapides depuis la même page'],
      ['Horaires réutilisables et faciles à modifier', 'Règles par catégorie ou par application'],
      ['Priorité claire pour chaque événement', 'Historique lisible et contexte conservé'],
    ];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Column(
        key: ValueKey(activeTab),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C4DFF), Color(0xFF20D7C5)],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              [
                Icons.dashboard_customize_rounded,
                Icons.tune_rounded,
                Icons.notifications_active_rounded,
              ][activeTab],
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 23,
              height: 1.2,
              fontWeight: FontWeight.w900,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              color: colors.bodyText,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          ...bullets[activeTab].map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF20D7C5),
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: colors.bodyText,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinuitySection extends StatelessWidget {
  const _ContinuitySection({
    required this.colors,
    required this.isCompact,
    required this.isTablet,
  });

  final _LandingColors colors;
  final bool isCompact;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final visual = SizedBox(
      height: isCompact ? 430 : 540,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: isCompact ? 4 : 0,
            right: isCompact ? 4 : 70,
            top: 50,
            bottom: 38,
            child: _GlassPanel(
              colors: colors,
              radius: 30,
              padding: const EdgeInsets.all(10),
              child: const FittedBox(
                fit: BoxFit.contain,
                child: LaptopDashboardMockup(),
              ),
            ),
          ),
          Positioned(
            right: isCompact ? 6 : 0,
            bottom: 0,
            child: SizedBox(
              width: isCompact ? 125 : 190,
              height: isCompact ? 265 : 390,
              child: const FittedBox(
                fit: BoxFit.contain,
                child: SmartphoneAppMockup(),
              ),
            ),
          ),
          Positioned(
            left: isCompact ? 10 : 26,
            top: 8,
            child: _SyncBadge(colors: colors),
          ),
        ],
      ),
    );

    final copy = Column(
      crossAxisAlignment:
          isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          colors: colors,
          eyebrow: 'MOBILE + WEB',
          title: 'Commencez sur mobile. Continuez sur le web.',
          description:
              'Vos profils, règles, alertes et appareils restent dans le même espace. Utilisez le téléphone pour agir vite et le navigateur pour prendre du recul.',
          centered: isCompact,
          compact: isCompact,
        ),
        const SizedBox(height: 28),
        const _ContinuityPoint(
          icon: Icons.sync_rounded,
          title: 'Synchronisation continue',
          description:
              'Une modification du parent est destinée à être retrouvée sur chaque interface associée.',
          color: Color(0xFF20D7C5),
        ),
        const SizedBox(height: 16),
        const _ContinuityPoint(
          icon: Icons.space_dashboard_rounded,
          title: 'Vue détaillée sur grand écran',
          description:
              'Analysez plusieurs enfants et configurez les règles avec davantage de confort.',
          color: Color(0xFF8B7CFF),
        ),
        const SizedBox(height: 16),
        const _ContinuityPoint(
          icon: Icons.bolt_rounded,
          title: 'Actions rapides sur mobile',
          description:
              'Consultez une alerte ou adaptez une limite lorsque vous êtes en déplacement.',
          color: Color(0xFFFFA657),
        ),
      ],
    );

    return _SectionFrame(
      paddingTop: isCompact ? 74 : 112,
      paddingBottom: isCompact ? 74 : 112,
      horizontalPadding: isCompact ? 18 : 28,
      child: isCompact || isTablet
          ? Column(
              children: [
                copy,
                const SizedBox(height: 42),
                visual,
              ],
            )
          : Row(
              children: [
                Expanded(flex: 9, child: visual),
                const SizedBox(width: 70),
                Expanded(flex: 8, child: copy),
              ],
            ),
    );
  }
}

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection({
    required this.colors,
    required this.isCompact,
    required this.features,
  });

  final _LandingColors colors;
  final bool isCompact;
  final List<_FeatureData> features;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.sectionTint,
      child: _SectionFrame(
        paddingTop: isCompact ? 76 : 112,
        paddingBottom: isCompact ? 76 : 112,
        horizontalPadding: isCompact ? 18 : 28,
        child: Column(
          children: [
            _SectionHeading(
              colors: colors,
              eyebrow: 'DES OUTILS QUI SERVENT LE QUOTIDIEN',
              title: 'Plus qu’un contrôle parental : une vue familiale claire.',
              description:
                  'Chaque fonction répond à une situation concrète, avec une interface lisible et des actions compréhensibles.',
              centered: true,
              compact: isCompact,
            ),
            SizedBox(height: isCompact ? 36 : 54),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1050
                    ? 3
                    : constraints.maxWidth >= 660
                        ? 2
                        : 1;
                final spacing = 18.0;
                final cardWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: features
                      .map(
                        (feature) => SizedBox(
                          width: cardWidth,
                          child: _FeatureCard(
                            colors: colors,
                            feature: feature,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.colors, required this.feature});

  final _LandingColors colors;
  final _FeatureData feature;

  @override
  Widget build(BuildContext context) {
    return _HoverLift(
      child: Container(
        constraints: const BoxConstraints(minHeight: 282),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: colors.isDark ? 0.12 : 0.035),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: feature.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: feature.accent.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(feature.icon, color: feature.accent, size: 25),
            ),
            const SizedBox(height: 34),
            Text(
              feature.eyebrow,
              style: TextStyle(
                color: feature.accent,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              feature.title,
              style: TextStyle(
                color: colors.text,
                fontSize: 21,
                height: 1.2,
                fontWeight: FontWeight.w900,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              feature.description,
              style: TextStyle(
                color: colors.bodyText,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyJourneySection extends StatelessWidget {
  const _DailyJourneySection({required this.colors, required this.isCompact});

  final _LandingColors colors;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    const moments = [
      _JourneyMoment(
        time: '07:30',
        icon: Icons.school_rounded,
        title: 'Avant l’école',
        description:
            'Le mode école se prépare et les applications importantes restent disponibles.',
        color: Color(0xFF5DA9FF),
      ),
      _JourneyMoment(
        time: '12:20',
        icon: Icons.location_on_rounded,
        title: 'Pendant la journée',
        description:
            'Le parent retrouve un repère de localisation et l’état de synchronisation.',
        color: Color(0xFF20D7C5),
      ),
      _JourneyMoment(
        time: '17:00',
        icon: Icons.sports_esports_rounded,
        title: 'Après l’école',
        description:
            'Les loisirs sont disponibles dans les limites définies pour la journée.',
        color: Color(0xFFC084FC),
      ),
      _JourneyMoment(
        time: '21:00',
        icon: Icons.bedtime_rounded,
        title: 'Le soir',
        description:
            'Le mode sommeil réduit les distractions tout en conservant les usages essentiels.',
        color: Color(0xFFFFA657),
      ),
    ];

    return _SectionFrame(
      paddingTop: isCompact ? 76 : 112,
      paddingBottom: isCompact ? 76 : 112,
      horizontalPadding: isCompact ? 18 : 28,
      child: Column(
        children: [
          _SectionHeading(
            colors: colors,
            eyebrow: 'UNE JOURNÉE AVEC GUARDIAN',
            title: 'Des règles qui accompagnent le rythme de la famille.',
            description:
                'Plutôt que de tout bloquer en permanence, Guardian permet de préparer des moments adaptés au quotidien.',
            centered: true,
            compact: isCompact,
          ),
          SizedBox(height: isCompact ? 38 : 58),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 780) {
                return Column(
                  children: moments
                      .map(
                        (moment) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _JourneyCard(
                            colors: colors,
                            moment: moment,
                            horizontal: true,
                          ),
                        ),
                      )
                      .toList(),
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                  moments.length,
                  (index) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index == moments.length - 1 ? 0 : 14,
                      ),
                      child: _JourneyCard(
                        colors: colors,
                        moment: moments[index],
                        horizontal: false,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
