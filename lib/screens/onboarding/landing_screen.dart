import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/models/app_state_manager.dart';
import 'widgets/laptop_dashboard_mockup.dart';
import 'widgets/smartphone_app_mockup.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolled = false;
  String _mockupTab = 'parent'; // 'parent' or 'child'
  int? _expandedFaqIndex;

  final List<Map<String, dynamic>> _features = [
    {
      'title': "Orchestrateur IA",
      'description':
          "Analyse en temps réel les comportements numériques pour détecter les risques sans espionner. Il génère des bilans bienveillants et des alertes contextuelles pour guider vos enfants.",
      'icon': Icons.psychology,
    },
    {
      'title': "Géolocalisation & Zones Scolaires",
      'description':
          "Suivez la position géographique de vos enfants et configurez des zones de sécurité géographiques (école, maison) avec alertes automatiques d'arrivée et de départ.",
      'icon': Icons.map,
    },
    {
      'title': "Limites de Temps d'Écran",
      'description':
          "Définissez des limites quotidiennes de temps d'écran globales ou par catégories d'applications (Réseaux Sociaux, Jeux). L'appareil se verrouille automatiquement dès que le quota est atteint.",
      'icon': Icons.access_time_filled,
    },
    {
      'title': "Blocage de Contenu Dynamique",
      'description':
          "Intercepte instantanément l'accès aux sites ou applications non autorisés (catégories sensibles comme les jeux d'argent, violence ou pornographie) grâce au moteur d'analyse réseau.",
      'icon': Icons.lock,
    },
    {
      'title': "Protection Native Inviolable",
      'description':
          "Intègre en profondeur les services système Android (AccessibilityService & DeviceAdmin) pour résister à toute désinstallation non autorisée, fermeture forcée ou contournement par VPN.",
      'icon': Icons.shield,
    },
  ];

  final List<Map<String, dynamic>> _testimonials = [
    {
      'name': "Valérie M.",
      'role': "Maman de Lucas (15 ans)",
      'comment':
          "Depuis que nous avons installé Guardian, les disputes à propos du temps d'écran ont totalement disparu. Lucas sait exactement de combien de temps il dispose, et l'Orchestrateur IA m'alerte s'il y a un réel problème.",
      'avatar': "V",
      'color': const Color(0xFF6366F1),
    },
    {
      'name': "Stéphane T.",
      'role': "Papa de Emma (12 ans)",
      'comment':
          "La fonction 'Zone Scolaire' est rassurante. Je reçois une notification discrète à son arrivée au collège. Le fait que l'application soit inviolable sur Android évite qu'elle ne la désactive par accident.",
      'avatar': "S",
      'color': const Color(0xFF0EA5E9),
    },
    {
      'name': "Isabelle D.",
      'role': "Maman de Léa (14 ans) et Théo (9 ans)",
      'comment':
          "J'apprécie l'Orchestrateur IA qui n'est pas un bête outil d'espionnage mais propose une supervision intelligente. C'est parfait pour accompagner mes enfants vers l'autonomie en toute sécurité.",
      'avatar': "I",
      'color': const Color(0xFF10B981),
    },
  ];

  final List<Map<String, String>> _faqs = [
    {
      'q': "Comment fonctionne l'Orchestrateur IA ?",
      'a':
          "L'Orchestrateur IA analyse en arrière-plan l'activité des applications et la sécurité globale de l'appareil de votre enfant. Plutôt que de simplement bloquer et fliquer de manière aveugle, il détecte les anomalies ou les usages abusifs, et envoie des alertes claires ainsi que des conseils d'accompagnement sur le dashboard parent."
    },
    {
      'q': "Mon enfant peut-il désinstaller ou contourner l'application ?",
      'a':
          "Non. Grâce à l'utilisation des APIs natives du système Android (telles que le gestionnaire d'administration de l'appareil 'DeviceAdmin' et le service d'accessibilité 'AccessibilityService'), Guardian se verrouille au cœur du système. Toute tentative de désinstallation, de modification du GPS ou de contournement nécessite le mot de passe parental."
    },
    {
      'q': "Quelles sont les fonctionnalités de blocage disponibles ?",
      'a':
          "Guardian propose le blocage dynamique par catégories de sites web (par exemple, les jeux d'argent, le contenu adulte, ou la violence), la restriction d'applications spécifiques, et le blocage complet de l'appareil selon des tranches horaires (mode école, heure du coucher) ou suite à un dépassement du temps autorisé."
    },
    {
      'q': "La géolocalisation fonctionne-t-elle en arrière-plan ?",
      'a':
          "Oui, la géolocalisation suit en temps réel la position de l'appareil de manière optimisée pour préserver la batterie. Vous pouvez définir des zones géographiques de confiance (par exemple 'École' ou 'Maison') et être notifié automatiquement dès que votre enfant y pénètre ou en sort."
    },
    {
      'q': "Quels types d'appareils sont supportés ?",
      'a':
          "Notre application est optimisée pour les smartphones et tablettes des enfants sous Android (avec intégration native poussée) et propose une console de gestion web (Orchestrateur Dashboard) accessible aux parents depuis n'importe quel ordinateur ou smartphone."
    }
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 50) {
        if (!_scrolled) {
          setState(() {
            _scrolled = true;
          });
        }
      } else {
        if (_scrolled) {
          setState(() {
            _scrolled = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(double offset) {
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1000;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF020617) : const Color(0xFFF4F6FF),
      body: Stack(
        children: [
          Positioned(
            top: -200,
            left: -200,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 400,
            right: -300,
            child: Container(
              width: 700,
              height: 700,
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6).withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                const SizedBox(height: 120),
                _buildHero(isMobile, width),
                _buildStatsSection(isMobile),
                _buildFeaturesSection(isMobile),
                _buildWhyUsSection(isMobile),
                _buildTestimonialsSection(isMobile),
                _buildPricingSection(isMobile),
                _buildFaqSection(isMobile),
                _buildCtaSection(isMobile),
                _buildFooter(isMobile),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildNavBar(isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar(bool isMobile) {
    final stateManager = context.watch<AppStateManager>();
    final isDark = stateManager.themeMode == ThemeMode.dark ||
        (stateManager.themeMode == ThemeMode.system &&
            Theme.of(context).brightness == Brightness.dark);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 32, vertical: _scrolled ? 16 : 24),
      decoration: BoxDecoration(
        color: _scrolled
            ? (isDark
                ? const Color(0xFF020617).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.85))
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: _scrolled
                ? (isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.4)
                    : const Color(0xFFE2E8F0).withValues(alpha: 0.4))
                : Colors.transparent,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => _scrollToSection(0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Guardian",
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "v2.1",
                        style: TextStyle(
                          color: Color(0xFF818CF8),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                Row(
                  children: [
                    _buildNavLink(
                        "Fonctionnalités", () => _scrollToSection(800), isDark),
                    _buildNavLink(
                        "Pourquoi Nous", () => _scrollToSection(1700), isDark),
                    _buildNavLink(
                        "Témoignages", () => _scrollToSection(2400), isDark),
                    _buildNavLink(
                        "Tarifs", () => _scrollToSection(3100), isDark),
                    _buildNavLink("FAQ", () => _scrollToSection(3900), isDark),
                  ],
                ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      color: isDark ? Colors.amber : const Color(0xFF475569),
                    ),
                    tooltip: isDark
                        ? "Activer le mode clair"
                        : "Activer le mode sombre",
                    onPressed: () {
                      stateManager.setThemeMode(
                          isDark ? ThemeMode.light : ThemeMode.dark);
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => context.push('/login/parent'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Espace Parent",
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavLink(String text, VoidCallback onTap, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 28),
      child: InkWell(
        onTap: onTap,
        child: Text(
          text,
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
      ),
    );
  }

  Widget _buildHero(bool isMobile, double width) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 32, vertical: 40),
          child: Column(
            children: [
              if (isMobile) ...[
                FadeInUp(child: _buildHeroText(isMobile)),
                const SizedBox(height: 40),
                FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: _buildInteractiveMockupArea()),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 5,
                      child: FadeInUp(child: _buildHeroText(isMobile)),
                    ),
                    const SizedBox(width: 140),
                    Expanded(
                      flex: 5,
                      child: FadeInUp(
                          delay: const Duration(milliseconds: 200),
                          child: _buildInteractiveMockupArea()),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroText(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF4F46E5), size: 14),
              SizedBox(width: 8),
              Text(
                "Contrôle Parental Nouvelle Génération",
                style: TextStyle(
                  color: Color(0xFF4F46E5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Sécurité Système Native\n& IA Bienveillante",
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 48,
            fontWeight: FontWeight.w900,
            fontFamily: 'Outfit',
            height: 1.1,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Découvrez Guardian, le contrôle parental intelligent et inviolable pour accompagner vos enfants en toute sécurité. Doté d'un Orchestrateur IA bienveillant et d'une sécurité système robuste.",
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            fontSize: 16,
            height: 1.6,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 36),
        Row(
          mainAxisAlignment:
              isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: () => _scrollToSection(isMobile ? 550 : 0),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
              child: const Text("Découvrir la démo",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 16),
            OutlinedButton(
              onPressed: () => context.push('/login/parent'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF4F46E5)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("Console Parent",
                  style: TextStyle(
                      color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInteractiveMockupArea() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMockupTabButton('parent', "Console Laptop (Parent)"),
              _buildMockupTabButton('child', "Application Smartphone (Enfant)"),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            height: 480,
            child: FittedBox(
              fit: BoxFit.contain,
              child: _mockupTab == 'parent'
                  ? const LaptopDashboardMockup()
                  : const SmartphoneAppMockup(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMockupTabButton(String tab, String label) {
    final active = _mockupTab == tab;
    return InkWell(
      onTap: () {
        setState(() {
          _mockupTab = tab;
        });
      },
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF4F46E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF475569),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(bool isMobile) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 32, vertical: 60),
          child: Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              AnimatedHoverCard(
                  child: _buildStatCard(
                      "Moteur IA Actif", "Analyse sémantique & contextuelle")),
              AnimatedHoverCard(
                  child: _buildStatCard(
                      "Sécurité Native", "100% inviolable sur Android")),
              AnimatedHoverCard(
                  child: _buildStatCard(
                      "Temps Réel", "Position & notifications GPS")),
              AnimatedHoverCard(
                  child: _buildStatCard(
                      "Accompagnement", "Lien parent-enfant renforcé")),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String desc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFF1E293B)
              : const Color(0xFFE2E8F0).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontSize: 11,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF0B0F19) : Colors.white,
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 12 : 32, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              const Text(
                "FONCTIONNALITÉS CLÉS",
                style: TextStyle(
                    color: Color(0xFF4F46E5),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                "Une protection intelligente & complète",
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 48),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: _features
                    .map((f) => AnimatedHoverCard(child: _buildFeatureCard(f)))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> f) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 320,
      height: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(f['icon'] as IconData,
                color: const Color(0xFF4F46E5), size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            f['title'] as String,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            f['description'] as String,
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              fontSize: 11,
              height: 1.5,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyUsSection(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 32, vertical: 80),
          child: Column(
            children: [
              const Text(
                "POURQUOI NOUS REJOINDRE ?",
                style: TextStyle(
                    color: Color(0xFF14B8A6),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                "Une armure inviolable au cœur du système",
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 700,
                child: Text(
                  "Contrairement aux autres solutions facilement contournables, Guardian utilise les outils d'administration système natifs. L'enfant ne peut ni contourner par VPN, ni forcer l'arrêt, ni désinstaller l'application sans votre mot de passe parental. Le filtrage DNS fonctionne 24h/24, assurant une protection sans faille.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569),
                    fontSize: 14,
                    height: 1.6,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestimonialsSection(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 12 : 32, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              const Text(
                "TÉMOIGNAGES",
                style: TextStyle(
                    color: Color(0xFF4F46E5),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                "Ce que disent les parents",
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 48),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: _testimonials
                    .map((t) =>
                        AnimatedHoverCard(child: _buildTestimonialCard(t)))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestimonialCard(Map<String, dynamic> t) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: t['color'] as Color, shape: BoxShape.circle),
                child: Center(
                  child: Text(t['avatar'] as String,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t['name'] as String,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  Text(t['role'] as String,
                      style: const TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            t['comment'] as String,
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              fontSize: 11,
              height: 1.6,
              fontStyle: FontStyle.italic,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF020617) : const Color(0xFFF4F6FF),
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 12 : 32, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              const Text(
                "TARIFS",
                style: TextStyle(
                  color: Color(0xFF4F46E5),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Des plans adaptés à toutes les familles",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 48),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  _buildPricingCard(
                    title: "Starter",
                    price: "0 FCFA",
                    period: "À vie",
                    desc:
                        "L'essentiel pour débuter et protéger un premier appareil.",
                    features: [
                      "1 appareil protégé",
                      "Suivi GPS basique",
                      "Limites de temps d'écran",
                      "Filtre DNS de base",
                    ],
                    buttonText: "Commencer gratuitement",
                    isPopular: false,
                    isDark: isDark,
                  ),
                  _buildPricingCard(
                    title: "Premium",
                    price: "3 250 FCFA",
                    period: "/ mois",
                    desc:
                        "La protection complète assistée par intelligence artificielle.",
                    features: [
                      "Jusqu'à 3 appareils protégés",
                      "Géolocalisation & zones illimitées",
                      "Moteur IA intelligent actif",
                      "Blocage d'applications & web",
                      "Alertes d'inviolabilité natives",
                    ],
                    buttonText: "Essai gratuit 7 jours",
                    isPopular: true,
                    isDark: isDark,
                  ),
                  _buildPricingCard(
                    title: "Famille",
                    price: "6 500 FCFA",
                    period: "/ mois",
                    desc:
                        "La tranquillité d'esprit absolue pour les grandes fratries.",
                    features: [
                      "Appareils illimités",
                      "Tableau de bord multi-parents",
                      "Rapports IA hebdomadaires",
                      "Support client VIP prioritaire",
                      "Sauvegarde cloud sécurisée",
                    ],
                    buttonText: "Sélectionner Famille",
                    isPopular: false,
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPricingCard({
    required String title,
    required String price,
    required String period,
    required String desc,
    required List<String> features,
    required String buttonText,
    required bool isPopular,
    required bool isDark,
  }) {
    final cardBg = isDark
        ? (isPopular ? const Color(0xFF0F172A) : const Color(0xFF0B0F19))
        : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final borderColor = isPopular
        ? const Color(0xFF4F46E5)
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));

    return AnimatedHoverCard(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: borderColor,
            width: isPopular ? 2.5 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isPopular
                  ? const Color(0xFF4F46E5).withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPopular) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF14B8A6)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "LE PLUS POPULAIRE",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              title,
              style: TextStyle(
                color: textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  period,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              desc,
              style: TextStyle(
                color: textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Color(0xFF14B8A6), size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          f,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: isPopular
                  ? ElevatedButton(
                      onPressed: () => context.push('/login/parent'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                      child: Text(
                        buttonText,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            fontFamily: 'Outfit'),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: () => context.push('/login/parent'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFF4F46E5),
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                      ),
                      child: Text(
                        buttonText,
                        style: const TextStyle(
                          color: Color(0xFF4F46E5),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqSection(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 32, vertical: 80),
          child: Column(
            children: [
              const Text(
                "FAQ",
                style: TextStyle(
                    color: Color(0xFF14B8A6),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                "Questions Fréquentes",
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 48),
              Container(
                width: 700,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _faqs.length,
                  separatorBuilder: (context, index) => Divider(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                  ),
                  itemBuilder: (context, index) {
                    final faq = _faqs[index];
                    final isExpanded = _expandedFaqIndex == index;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _expandedFaqIndex = isExpanded ? null : index;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  faq['q']!,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                                Icon(
                                  isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : Colors.grey,
                                ),
                              ],
                            ),
                            if (isExpanded) ...[
                              const SizedBox(height: 12),
                              Text(
                                faq['a']!,
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                  fontSize: 12,
                                  height: 1.6,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCtaSection(bool isMobile) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0F172A),
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 12 : 32, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              const Text(
                "Prêt à protéger vos enfants ?",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "Configurez Guardian en quelques minutes et accédez au dashboard complet.",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 36),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  ElevatedButton(
                    onPressed: () => context.push('/login/parent'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    child: const Text("Accéder Console Parent",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  OutlinedButton(
                    onPressed: () => context.push('/login/admin'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text("Accéder Console Administrateur",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool isMobile) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF090B16),
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 12 : 32, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "© 2026 Guardian Parental Control. Tous droits réservés.",
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const Row(
                children: [
                  Text("Mentions Légales",
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  SizedBox(width: 20),
                  Text("Politique de Confidentialité",
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedHoverCard extends StatefulWidget {
  final Widget child;
  const AnimatedHoverCard({required this.child, super.key});

  @override
  State<AnimatedHoverCard> createState() => _AnimatedHoverCardState();
}

class _AnimatedHoverCardState extends State<AnimatedHoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        transform: Matrix4.identity()..translate(0.0, _isHovered ? -8.0 : 0.0),
        child: widget.child,
      ),
    );
  }
}

class FadeInUp extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const FadeInUp({
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 800),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.delayed(delay),
      builder: (context, snapshot) {
        final show = snapshot.connectionState == ConnectionState.done ||
            delay == Duration.zero;
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: show ? 1.0 : 0.0),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0.0, (1.0 - value) * 30.0),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );
  }
}
