library guardian_landing;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_state_manager.dart';
import 'widgets/laptop_dashboard_mockup.dart';
import 'widgets/smartphone_app_mockup.dart';

part 'landing/navigation_hero.dart';
part 'landing/product_sections.dart';
part 'landing/conversion_sections.dart';
part 'landing/components.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _productKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _securityKey = GlobalKey();
  final GlobalKey _pricingKey = GlobalKey();
  final GlobalKey _faqKey = GlobalKey();

  bool _scrolled = false;
  bool _mobileMenuOpen = false;
  int _activeProductTab = 0;
  int? _expandedFaqIndex;

  static const List<_FeatureData> _features = [
    _FeatureData(
      icon: Icons.dashboard_customize_rounded,
      eyebrow: 'VUE D’ENSEMBLE',
      title: 'Un seul espace pour toute la famille',
      description:
          'Consultez les appareils, le temps d’écran, les alertes et la dernière position de chaque enfant depuis une vue claire et centralisée.',
      accent: Color(0xFF6C4DFF),
    ),
    _FeatureData(
      icon: Icons.schedule_rounded,
      eyebrow: 'RÈGLES',
      title: 'Des limites qui suivent votre quotidien',
      description:
          'Créez des horaires d’école, de sommeil et de loisirs, puis adaptez les règles par application ou par catégorie.',
      accent: Color(0xFF20D7C5),
    ),
    _FeatureData(
      icon: Icons.location_on_rounded,
      eyebrow: 'LOCALISATION',
      title: 'Des repères utiles, pas une surveillance permanente',
      description:
          'Retrouvez une position récente, configurez des zones de confiance et recevez une alerte lorsque cela est réellement utile.',
      accent: Color(0xFF5DA9FF),
    ),
    _FeatureData(
      icon: Icons.notifications_active_rounded,
      eyebrow: 'ALERTES',
      title: 'Les événements importants remontent en premier',
      description:
          'Guardian organise les alertes par niveau de priorité pour vous aider à agir vite sans être submergé par les notifications.',
      accent: Color(0xFFFFA657),
    ),
    _FeatureData(
      icon: Icons.auto_awesome_rounded,
      eyebrow: 'ASSISTANT',
      title: 'Une aide intelligente pour comprendre les usages',
      description:
          'Les tendances sont résumées avec des explications simples afin de favoriser le dialogue et des décisions adaptées à chaque enfant.',
      accent: Color(0xFFC084FC),
    ),
    _FeatureData(
      icon: Icons.devices_rounded,
      eyebrow: 'MULTI-ÉCRANS',
      title: 'La même expérience sur mobile et sur le web',
      description:
          'Les réglages et les informations restent synchronisés entre votre téléphone et votre espace parent sur ordinateur.',
      accent: Color(0xFF34D399),
    ),
  ];

  static const List<_FaqData> _faqs = [
    _FaqData(
      question: 'À quoi sert exactement la version web de Guardian ?',
      answer:
          'La version web donne au parent une vue plus large de son dashboard mobile. Elle est pensée pour gérer plusieurs enfants, consulter les tendances, configurer les règles et analyser les alertes plus confortablement depuis un ordinateur.',
    ),
    _FaqData(
      question: 'Mes réglages sont-ils synchronisés avec l’application mobile ?',
      answer:
          'Oui. Le même compte parent permet de retrouver les profils, règles, appareils et alertes sur les deux interfaces. Une modification effectuée sur le web est destinée à être répercutée sur les appareils associés.',
    ),
    _FaqData(
      question: 'Guardian permet-il de définir des horaires différents ?',
      answer:
          'Oui. Vous pouvez préparer des plages pour l’école, les devoirs, les loisirs ou le sommeil, puis appliquer des exceptions selon les applications autorisées et les besoins de l’enfant.',
    ),
    _FaqData(
      question: 'Quelles informations de localisation sont présentées ?',
      answer:
          'L’espace parent peut afficher la dernière position disponible, l’état de synchronisation et les zones de confiance configurées. L’objectif est de fournir des repères utiles avec une présentation transparente des autorisations nécessaires.',
    ),
    _FaqData(
      question: 'Puis-je gérer plusieurs enfants depuis le même compte ?',
      answer:
          'Oui. Le dashboard est conçu pour regrouper plusieurs profils et permettre de passer rapidement de la vue familiale aux détails d’un enfant.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final next = _scrollController.offset > 24;
    if (next != _scrolled && mounted) {
      setState(() => _scrolled = next);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _scrollTo(GlobalKey key) async {
    setState(() => _mobileMenuOpen = false);
    final sectionContext = key.currentContext;
    if (sectionContext == null) return;
    await Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      alignment: 0.03,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _LandingColors(isDark);

    return Scaffold(
      backgroundColor: colors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isCompact = width < 780;
          final isTablet = width >= 780 && width < 1120;

          return Stack(
            children: [
              Positioned.fill(child: _AmbientBackground(colors: colors)),
              SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    SizedBox(height: isCompact ? 92 : 112),
                    _HeroSection(
                      colors: colors,
                      isCompact: isCompact,
                      isTablet: isTablet,
                      onPrimary: () => context.push('/signup'),
                      onSecondary: () => _scrollTo(_productKey),
                    ),
                    _TrustStrip(colors: colors, isCompact: isCompact),
                    _SectionAnchor(
                      key: _productKey,
                      child: _ProductShowcase(
                        colors: colors,
                        isCompact: isCompact,
                        activeTab: _activeProductTab,
                        onTabChanged: (index) {
                          setState(() => _activeProductTab = index);
                        },
                      ),
                    ),
                    _ContinuitySection(
                      colors: colors,
                      isCompact: isCompact,
                      isTablet: isTablet,
                    ),
                    _SectionAnchor(
                      key: _featuresKey,
                      child: _FeaturesSection(
                        colors: colors,
                        isCompact: isCompact,
                        features: _features,
                      ),
                    ),
                    _DailyJourneySection(
                      colors: colors,
                      isCompact: isCompact,
                    ),
                    _SectionAnchor(
                      key: _securityKey,
                      child: _SecuritySection(
                        colors: colors,
                        isCompact: isCompact,
                      ),
                    ),
                    _SectionAnchor(
                      key: _pricingKey,
                      child: _PricingSection(
                        colors: colors,
                        isCompact: isCompact,
                        onStart: () => context.push('/signup'),
                      ),
                    ),
                    _SectionAnchor(
                      key: _faqKey,
                      child: _FaqSection(
                        colors: colors,
                        isCompact: isCompact,
                        faqs: _faqs,
                        expandedIndex: _expandedFaqIndex,
                        onToggle: (index) {
                          setState(() {
                            _expandedFaqIndex =
                                _expandedFaqIndex == index ? null : index;
                          });
                        },
                      ),
                    ),
                    _FinalCta(
                      colors: colors,
                      isCompact: isCompact,
                      onStart: () => context.push('/signup'),
                      onLogin: () => context.push('/login/parent'),
                    ),
                    _Footer(
                      colors: colors,
                      isCompact: isCompact,
                      onProduct: () => _scrollTo(_productKey),
                      onFeatures: () => _scrollTo(_featuresKey),
                      onSecurity: () => _scrollTo(_securityKey),
                      onPricing: () => _scrollTo(_pricingKey),
                      onFaq: () => _scrollTo(_faqKey),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _NavigationBar(
                  colors: colors,
                  compact: isCompact,
                  scrolled: _scrolled,
                  menuOpen: _mobileMenuOpen,
                  onToggleMenu: () {
                    setState(() => _mobileMenuOpen = !_mobileMenuOpen);
                  },
                  onProduct: () => _scrollTo(_productKey),
                  onFeatures: () => _scrollTo(_featuresKey),
                  onSecurity: () => _scrollTo(_securityKey),
                  onPricing: () => _scrollTo(_pricingKey),
                  onFaq: () => _scrollTo(_faqKey),
                  onLogin: () => context.push('/login/parent'),
                  onSignup: () => context.push('/signup'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionAnchor extends StatelessWidget {
  const _SectionAnchor({required super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
