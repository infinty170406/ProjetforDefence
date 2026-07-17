import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _activeNav = 'dashboard';
  String _activeFilter = 'critical';

  Future<void> _handleLogout() async {
    ApiService().clearToken();
    await FirebaseAuth.instance.signOut();
    await StorageService().clearAll();
    if (mounted) context.go('/login/admin');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: const Color(0xFF2563EB),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 950;

    return Scaffold(
      backgroundColor: const Color(0xFF141624),
      drawer: isSmallScreen ? Drawer(child: _buildSidebar()) : null,
      body: Row(
        children: [
          if (!isSmallScreen) _buildSidebar(),
          Expanded(child: _buildMain()),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 950;

    final navItems = [
      {'id': 'dashboard', 'label': 'Tableau de bord', 'icon': Icons.home},
      {'id': 'users', 'label': 'Utilisateurs', 'icon': Icons.people},
      {'id': 'devices', 'label': 'Appareils', 'icon': Icons.smartphone},
      {'id': 'alerts', 'label': 'Alertes', 'icon': Icons.shield},
      {'id': 'activity', 'label': 'Activité', 'icon': Icons.show_chart},
      {'id': 'settings', 'label': 'Paramètres', 'icon': Icons.settings},
    ];

    return Container(
      width: 240,
      color: const Color(0xFF17192B).withOpacity(0.95),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.shield, color: Color(0xFF3B82F6), size: 28),
            const SizedBox(width: 10),
            const Text('GUARDIAN',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5)),
          ]),
          const SizedBox(height: 40),
          ...navItems.map((item) {
            final isActive = _activeNav == item['id'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () {
                  setState(() => _activeNav = item['id'] as String);
                  if (isSmallScreen) Navigator.of(context).pop();
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color:
                        isActive ? const Color(0xFF2563EB) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    Icon(item['icon'] as IconData,
                        color: isActive ? Colors.white : Colors.grey, size: 18),
                    const SizedBox(width: 14),
                    Text(item['label'] as String,
                        style: TextStyle(
                            color: isActive ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ]),
                ),
              ),
            );
          }),
          const Spacer(),
          InkWell(
            onTap: () async {
              if (isSmallScreen) Navigator.of(context).pop();
              await _handleLogout();
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: const Row(children: [
                Icon(Icons.logout, color: Colors.grey, size: 18),
                SizedBox(width: 14),
                Text('Déconnexion',
                    style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMain() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 950;

    return Stack(
      children: [
        Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.08),
                  shape: BoxShape.circle),
            )),
        Positioned(
            bottom: 0,
            left: 200,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.08),
                  shape: BoxShape.circle),
            )),
        Column(children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 32),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Supervision Globale',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text(
                        'Gerez les alertes et analysez l\'activité du réseau Guardian.',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 32),
                    isSmallScreen
                        ? Column(
                            children: [
                              _buildFilterRow(),
                              const SizedBox(height: 20),
                              _buildAlertsList(),
                              const SizedBox(height: 20),
                              _buildAiBanner(),
                              const SizedBox(height: 24),
                              _buildDailySummary(),
                              const SizedBox(height: 20),
                              _buildDevicesCard(),
                              const SizedBox(height: 20),
                              _buildTrafficChart(),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Expanded(
                                    flex: 8,
                                    child: Column(children: [
                                      _buildFilterRow(),
                                      const SizedBox(height: 20),
                                      _buildAlertsList(),
                                      const SizedBox(height: 20),
                                      _buildAiBanner(),
                                    ])),
                                const SizedBox(width: 24),
                                Expanded(
                                    flex: 4,
                                    child: Column(children: [
                                      _buildDailySummary(),
                                      const SizedBox(height: 20),
                                      _buildDevicesCard(),
                                      const SizedBox(height: 20),
                                      _buildTrafficChart(),
                                    ])),
                              ]),
                  ]),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildHeader() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 950;

    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 32),
      decoration: BoxDecoration(
        border:
            Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            if (isSmallScreen) ...[
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.home, color: Colors.grey, size: 14),
            const SizedBox(width: 8),
            if (!isSmallScreen) ...[
              Text('Accueil',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('/', style: TextStyle(color: Colors.grey))),
            ],
            const Text('Tableau de bord',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            if (!isSmallScreen) ...[
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('/', style: TextStyle(color: Colors.grey))),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('10 Juin',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
          Row(children: [
            if (!isSmallScreen) ...[
              _buildAvatar('A', const Color(0xFF8B5CF6)),
              Transform.translate(
                  offset: const Offset(-8, 0),
                  child: _buildAvatar('B', const Color(0xFF2563EB))),
              Transform.translate(
                  offset: const Offset(-16, 0),
                  child: _buildAvatar('C', const Color(0xFF10B981))),
              const SizedBox(width: 16),
            ],
            _buildIconBtn(Icons.search, () => _toast('Recherche...')),
            const SizedBox(width: 10),
            Stack(children: [
              _buildIconBtn(Icons.notifications_none, () {}),
              Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle))),
            ]),
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF8B5CF6)]),
              ),
              child: const Center(
                  child: Text('AD',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900))),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildAvatar(String letter, Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: const Color(0xFF141624), width: 2)),
      child: Center(
          child: Text(letter,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.grey[400], size: 16),
      ),
    );
  }

  Widget _buildFilterRow() {
    final filters = [
      {'id': 'online', 'label': 'En ligne', 'color': const Color(0xFF10B981)},
      {
        'id': 'warnings',
        'label': 'Avertissements',
        'color': const Color(0xFF3B82F6)
      },
      {
        'id': 'critical',
        'label': 'Alertes critiques',
        'color': const Color(0xFFEF4444)
      },
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isActive = _activeFilter == f['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () => setState(() => _activeFilter = f['id'] as String),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color: isActive
                          ? Colors.white.withOpacity(0.2)
                          : Colors.white.withOpacity(0.1)),
                ),
                child: Row(children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: f['color'] as Color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(f['label'] as String,
                      style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAlertsList() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C1F36), Color(0xFF151728)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Row(children: [
            Icon(Icons.shield, color: Color(0xFFEF4444), size: 18),
            SizedBox(width: 8),
            Text('Alertes Recentes',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ]),
          InkWell(
            onTap: () {},
            child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle),
                child:
                    const Icon(Icons.more_horiz, color: Colors.grey, size: 14)),
          ),
        ]),
        const SizedBox(height: 20),
        _buildAlertItem(
            'Tentative d\'accès bloquée',
            'Appareil \'iPad de Leo\' a tente d\'accéder à un site non autorise (Categorie: Jeux d\'argent).',
            'Aujourd\'hui, 14:30',
            'high'),
        const SizedBox(height: 12),
        _buildAlertItem(
            'Desactivation du GPS',
            'La localisation a ete desactivee manuellement sur \'iPhone de Emma\'.',
            'Aujourd\'hui, 09:15',
            'medium'),
        const SizedBox(height: 12),
        _buildAlertItem(
            'Temps d\'écran depasse',
            'La limite de 2h pour la categorie Reseaux Sociaux a ete atteinte.',
            'Hier, 20:00',
            'low'),
      ]),
    );
  }

  Widget _buildAlertItem(
      String title, String desc, String time, String severity) {
    final isHigh = severity == 'high';
    final color = isHigh ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.shield, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title,
                style: TextStyle(
                    color: isHigh ? const Color(0xFFFEE2E2) : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            Text(time,
                style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ]),
          const SizedBox(height: 4),
          Text(desc,
              style: const TextStyle(
                  color: Colors.grey, fontSize: 11, height: 1.5)),
          if (isHigh) ...[
            const SizedBox(height: 12),
            Row(children: [
              InkWell(
                onTap: () => _toast('Details de l\'alerte ouverts.'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('Voir details',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _toast('Appareil bloque avec succès.'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('Bloquer l\'appareil',
                      style: TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ],
        ])),
      ]),
    );
  }

  Widget _buildAiBanner() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 950;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF3730A3)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
      ),
      child: isSmallScreen
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Moteur d\'analyse IA',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text(
                        'Le filtrage dynamique fonctionne de manière optimale. Base de données à jour.',
                        style:
                            TextStyle(color: Color(0xFFBFDBFE), fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Menaces bloquees',
                            style: TextStyle(color: Colors.grey, fontSize: 11)),
                        Text('1,432',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF3B82F6).withOpacity(0.3),
                            width: 3),
                      ),
                      child: const Center(
                          child: Text('99%',
                              style: TextStyle(
                                  color: Color(0xFF60A5FA),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold))),
                    ),
                  ],
                )
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Moteur d\'analyse IA',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text(
                          'Le filtrage dynamique fonctionne de manière optimale. Base de données à jour.',
                          style: TextStyle(
                              color: Color(0xFFBFDBFE), fontSize: 11)),
                    ]),
                Row(children: [
                  const Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Menaces bloquees',
                            style: TextStyle(color: Colors.grey, fontSize: 11)),
                        Text('1,432',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                      ]),
                  const SizedBox(width: 16),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF3B82F6).withOpacity(0.3),
                          width: 3),
                    ),
                    child: const Center(
                        child: Text('99%',
                            style: TextStyle(
                                color: Color(0xFF60A5FA),
                                fontSize: 11,
                                fontWeight: FontWeight.bold))),
                  ),
                ]),
              ],
            ),
    );
  }

  Widget _buildDailySummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3A8A), Color(0xFF312E81)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Resume du jour',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.description, color: Colors.grey, size: 12),
          ),
        ]),
        const SizedBox(height: 12),
        const Text(
          'L\'activite globale est stable. 3 alertes necessitent votre attention. Le temps d\'ecran moyen a baisse de 12% cette semaine.',
          style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 11, height: 1.5),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: Color(0xFF10B981), shape: BoxShape.circle)),
            const SizedBox(width: 6),
            const Text('24h',
                style: TextStyle(color: Colors.grey, fontSize: 11)),
          ]),
          InkWell(
            onTap: () => _toast('Rapport detaille genere.'),
            child: const Row(children: [
              Icon(Icons.chevron_right, color: Color(0xFF60A5FA), size: 14),
              Text('Rapport detaille',
                  style: TextStyle(
                      color: Color(0xFF60A5FA),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _buildDevicesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F36),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Appareils Actifs',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          InkWell(
              onTap: () {},
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle),
                child:
                    const Icon(Icons.more_horiz, color: Colors.grey, size: 14),
              )),
        ]),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 80,
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: const Center(
              child: Icon(Icons.smartphone, color: Colors.grey, size: 32)),
        ),
        const SizedBox(height: 12),
        const Text('12 appareils surveilles en temps reel.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _toast('Ajout d\'un appareil…'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12)),
            child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Color(0xFF60A5FA), size: 16),
                  SizedBox(width: 8),
                  Text('Ajouter un appareil',
                      style: TextStyle(
                          color: Color(0xFF60A5FA),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildTrafficChart() {
    final bars = [40, 60, 30, 80, 50, 90, 70, 40, 100, 60];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F36),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Trafic Analyse',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6)),
            child: const Text('En direct',
                style: TextStyle(
                    color: Color(0xFF60A5FA),
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: bars.map((h) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Stack(alignment: Alignment.bottomCenter, children: [
                    Container(
                        width: double.infinity,
                        height: 80,
                        color: const Color(0xFF2563EB).withOpacity(0.08)),
                    FractionallySizedBox(
                      widthFactor: 1,
                      heightFactor: h / 100,
                      child: Container(color: const Color(0xFF2563EB)),
                    ),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}
