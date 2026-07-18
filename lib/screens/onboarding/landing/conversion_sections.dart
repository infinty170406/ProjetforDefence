part of guardian_landing;

class _SecuritySection extends StatelessWidget {
  const _SecuritySection({required this.colors, required this.isCompact});

  final _LandingColors colors;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment:
          isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          colors: colors,
          eyebrow: 'SÉCURITÉ ET TRANSPARENCE',
          title: 'Les données familiales méritent des règles claires.',
          description:
              'Guardian est conçu autour d’un accès parent authentifié, de permissions explicites et d’une présentation transparente des informations collectées.',
          centered: isCompact,
          compact: isCompact,
        ),
        const SizedBox(height: 28),
        const _SecurityPoint(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Accès parent protégé',
          text: 'Les actions de gestion sont réservées au compte parent connecté.',
        ),
        const SizedBox(height: 14),
        const _SecurityPoint(
          icon: Icons.visibility_outlined,
          title: 'Permissions visibles',
          text: 'La localisation et les fonctions système doivent être expliquées clairement.',
        ),
        const SizedBox(height: 14),
        const _SecurityPoint(
          icon: Icons.delete_outline_rounded,
          title: 'Contrôle des données',
          text: 'Les familles doivent pouvoir gérer leurs appareils et demander la suppression de leurs données.',
        ),
      ],
    );

    final visual = _GlassPanel(
      colors: colors,
      radius: 32,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C4DFF), Color(0xFF20D7C5)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.shield_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Centre de confidentialité',
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Votre compte familial',
                      style: TextStyle(
                        color: colors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF20D7C5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Protégé',
                  style: TextStyle(
                    color: Color(0xFF20D7C5),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _PrivacyRow(
            colors: colors,
            icon: Icons.phonelink_lock_rounded,
            title: 'Appareils associés',
            value: '3 actifs',
          ),
          _PrivacyRow(
            colors: colors,
            icon: Icons.location_on_outlined,
            title: 'Partage de localisation',
            value: 'Configuré',
          ),
          _PrivacyRow(
            colors: colors,
            icon: Icons.notifications_none_rounded,
            title: 'Préférences d’alertes',
            value: 'Personnalisées',
          ),
          _PrivacyRow(
            colors: colors,
            icon: Icons.history_rounded,
            title: 'Historique du compte',
            value: 'Consultable',
            last: true,
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6C4DFF).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF6C4DFF).withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFF8B7CFF), size: 20),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'La confiance se construit avec des règles visibles et un dialogue adapté à l’âge de l’enfant.',
                    style: TextStyle(
                      color: colors.bodyText,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      color: colors.sectionTint,
      child: _SectionFrame(
        paddingTop: isCompact ? 76 : 112,
        paddingBottom: isCompact ? 76 : 112,
        horizontalPadding: isCompact ? 18 : 28,
        child: isCompact
            ? Column(
                children: [
                  copy,
                  const SizedBox(height: 42),
                  visual,
                ],
              )
            : Row(
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 72),
                  Expanded(child: visual),
                ],
              ),
      ),
    );
  }
}

class _PricingSection extends StatelessWidget {
  const _PricingSection({
    required this.colors,
    required this.isCompact,
    required this.onStart,
  });

  final _LandingColors colors;
  final bool isCompact;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    const plans = [
      _PlanData(
        name: 'Starter',
        price: '0 FCFA',
        description: 'Pour découvrir l’espace parent Guardian.',
        features: [
          '1 profil enfant',
          'Vue d’ensemble du dashboard',
          'Règles essentielles',
          'Accès web parent',
        ],
      ),
      _PlanData(
        name: 'Premium',
        price: '3 250 FCFA',
        description: 'Pour un suivi quotidien plus complet.',
        features: [
          'Jusqu’à 3 profils enfants',
          'Localisation et zones de confiance',
          'Règles avancées par application',
          'Alertes et rapports détaillés',
          'Assistant intelligent',
        ],
        popular: true,
      ),
      _PlanData(
        name: 'Famille',
        price: '6 500 FCFA',
        description: 'Pour les familles avec plusieurs appareils.',
        features: [
          'Profils enfants étendus',
          'Gestion multi-appareils',
          'Historique enrichi',
          'Fonctions Premium incluses',
          'Support prioritaire',
        ],
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
            eyebrow: 'DES FORMULES LISIBLES',
            title: 'Choisissez l’espace adapté à votre famille.',
            description:
                'L’accès web parent est présenté comme une partie intégrante de l’expérience Guardian.',
            centered: true,
            compact: isCompact,
          ),
          SizedBox(height: isCompact ? 38 : 58),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 920;
              if (stacked) {
                return Column(
                  children: plans
                      .map(
                        (plan) => Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: _PricingCard(
                            colors: colors,
                            plan: plan,
                            onStart: onStart,
                          ),
                        ),
                      )
                      .toList(),
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                  plans.length,
                  (index) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 0 : 9,
                        right: index == plans.length - 1 ? 0 : 9,
                      ),
                      child: _PricingCard(
                        colors: colors,
                        plan: plans[index],
                        onStart: onStart,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Tarifs mensuels indicatifs · Les fonctions exactes peuvent évoluer avant la mise en production.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.mutedText,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({
    required this.colors,
    required this.plan,
    required this.onStart,
  });

  final _LandingColors colors;
  final _PlanData plan;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return _HoverLift(
      offset: plan.popular ? 8 : 5,
      child: Container(
        constraints: const BoxConstraints(minHeight: 510),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: plan.popular
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF6C4DFF).withValues(alpha: 0.16),
                    colors.card,
                    const Color(0xFF20D7C5).withValues(alpha: 0.08),
                  ],
                )
              : null,
          color: plan.popular ? null : colors.card,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: plan.popular
                ? const Color(0xFF8B7CFF).withValues(alpha: 0.55)
                : colors.border,
            width: plan.popular ? 1.6 : 1,
          ),
          boxShadow: plan.popular
              ? [
                  BoxShadow(
                    color: const Color(0xFF6C4DFF).withValues(alpha: 0.14),
                    blurRadius: 38,
                    offset: const Offset(0, 18),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  plan.name,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                if (plan.popular)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C4DFF), Color(0xFF20D7C5)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'RECOMMANDÉ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              plan.description,
              style: TextStyle(
                color: colors.bodyText,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 26),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan.price,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(width: 7),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '/ mois',
                    style: TextStyle(
                      color: colors.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Divider(color: colors.border),
            const SizedBox(height: 20),
            ...plan.features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: plan.popular
                          ? const Color(0xFF20D7C5)
                          : const Color(0xFF8B7CFF),
                      size: 19,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(
                          color: colors.bodyText,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: plan.popular
                  ? _GradientButton(
                      label: 'Choisir Premium',
                      onPressed: onStart,
                    )
                  : OutlinedButton(
                      onPressed: onStart,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.text,
                        side: BorderSide(color: colors.border),
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: Text('Choisir ${plan.name}'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqSection extends StatelessWidget {
  const _FaqSection({
    required this.colors,
    required this.isCompact,
    required this.faqs,
    required this.expandedIndex,
    required this.onToggle,
  });

  final _LandingColors colors;
  final bool isCompact;
  final List<_FaqData> faqs;
  final int? expandedIndex;
  final ValueChanged<int> onToggle;

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
              eyebrow: 'QUESTIONS FRÉQUENTES',
              title: 'Les réponses essentielles avant de commencer.',
              description:
                  'Comprenez le rôle du dashboard web et la manière dont il complète l’application parent mobile.',
              centered: true,
              compact: isCompact,
            ),
            SizedBox(height: isCompact ? 36 : 50),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: List.generate(
                  faqs.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FaqTile(
                      colors: colors,
                      data: faqs[index],
                      expanded: expandedIndex == index,
                      onTap: () => onToggle(index),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.colors,
    required this.data,
    required this.expanded,
    required this.onTap,
  });

  final _LandingColors colors;
  final _FaqData data;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: data.question,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: expanded
                ? const Color(0xFF6C4DFF).withValues(alpha: 0.08)
                : colors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: expanded
                  ? const Color(0xFF8B7CFF).withValues(alpha: 0.34)
                  : colors.border,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.question,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  AnimatedRotation(
                    turns: expanded ? 0.125 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.add_rounded,
                      color: expanded
                          ? const Color(0xFF8B7CFF)
                          : colors.mutedText,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      data.answer,
                      style: TextStyle(
                        color: colors.bodyText,
                        fontSize: 14,
                        height: 1.65,
                      ),
                    ),
                  ),
                ),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinalCta extends StatelessWidget {
  const _FinalCta({
    required this.colors,
    required this.isCompact,
    required this.onStart,
    required this.onLogin,
  });

  final _LandingColors colors;
  final bool isCompact;
  final VoidCallback onStart;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return _SectionFrame(
      paddingTop: isCompact ? 68 : 96,
      paddingBottom: isCompact ? 68 : 96,
      horizontalPadding: isCompact ? 18 : 28,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 24 : 64,
          vertical: isCompact ? 46 : 66,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF352A74), Color(0xFF0C5360)],
          ),
          borderRadius: BorderRadius.circular(isCompact ? 30 : 42),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C4DFF).withValues(alpha: 0.22),
              blurRadius: 46,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -70,
              top: -100,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF20D7C5).withValues(alpha: 0.1),
                ),
              ),
            ),
            Column(
              children: [
                const Icon(Icons.shield_rounded,
                    color: Colors.white, size: 42),
                const SizedBox(height: 20),
                Text(
                  'Votre dashboard familial, disponible partout.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 30 : 44,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 17),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Text(
                    'Créez votre espace parent ou connectez-vous pour retrouver les mêmes profils et les mêmes contrôles que sur votre application mobile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.74),
                      fontSize: isCompact ? 14.5 : 16,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: onStart,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Créer mon espace parent'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF30256A),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: onLogin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.38)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Se connecter'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.colors,
    required this.isCompact,
    required this.onProduct,
    required this.onFeatures,
    required this.onSecurity,
    required this.onPricing,
    required this.onFaq,
  });

  final _LandingColors colors;
  final bool isCompact;
  final VoidCallback onProduct;
  final VoidCallback onFeatures;
  final VoidCallback onSecurity;
  final VoidCallback onPricing;
  final VoidCallback onFaq;

  @override
  Widget build(BuildContext context) {
    final List<(String, List<(String, VoidCallback)>)> columns = [
      (
        'Produit',
        [
          ('Dashboard web', onProduct),
          ('Fonctionnalités', onFeatures),
          ('Tarifs', onPricing),
        ],
      ),
      (
        'Confiance',
        [
          ('Sécurité', onSecurity),
          ('Confidentialité', onSecurity),
          ('FAQ', onFaq),
        ],
      ),
      (
        'Accès',
        [
          ('Espace parent', () { context.push('/login/parent'); }),
          ('Créer un compte', () { context.push('/signup'); }),
          ('Mot de passe oublié', () { context.push('/forgot-password'); }),
        ],
      ),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.footer,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: _SectionFrame(
        paddingTop: 56,
        paddingBottom: 34,
        horizontalPadding: isCompact ? 18 : 28,
        child: Column(
          children: [
            if (isCompact) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: _FooterBrand(colors: colors),
              ),
              const SizedBox(height: 36),
              ...columns.map(
                (column) => Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: _FooterColumn(
                    colors: colors,
                    title: column.$1,
                    links: column.$2,
                  ),
                ),
              ),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _FooterBrand(colors: colors)),
                  const SizedBox(width: 40),
                  ...columns.map(
                    (column) => Expanded(
                      child: _FooterColumn(
                        colors: colors,
                        title: column.$1,
                        links: column.$2,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 36),
            Divider(color: colors.border),
            const SizedBox(height: 22),
            if (isCompact)
              Column(
                children: [
                  Text(
                    '© ${DateTime.now().year} Guardian. Tous droits réservés.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.mutedText,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Protection familiale · Mobile + Web',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.mutedText,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '© ${DateTime.now().year} Guardian. Tous droits réservés.',
                      style: TextStyle(
                        color: colors.mutedText,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  Text(
                    'Protection familiale · Mobile + Web',
                    style: TextStyle(
                      color: colors.mutedText,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
