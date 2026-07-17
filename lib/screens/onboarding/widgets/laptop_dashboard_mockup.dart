import 'package:flutter/material.dart';

class LaptopDashboardMockup extends StatefulWidget {
  const LaptopDashboardMockup({super.key});

  @override
  State<LaptopDashboardMockup> createState() => _LaptopDashboardMockupState();
}

class _LaptopDashboardMockupState extends State<LaptopDashboardMockup> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 800,
      height: 520,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E293B), width: 12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    // Sidebar
                    Container(
                      width: 180,
                      color: const Color(0xFF0B1329),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo Header
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF4F46E5),
                                      Color(0xFF14B8A6)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.shield,
                                    color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "GUARDIAN",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 1.5,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Sidebar Navigation Items
                          _buildSidebarItem(
                              Icons.dashboard_outlined, "Dashboard", true),
                          _buildSidebarItem(
                              Icons.map_outlined, "Real-time Map", false),
                          _buildSidebarItem(Icons.chat_bubble_outline,
                              "AI Orchestrator", false),
                          _buildSidebarItem(
                              Icons.settings_outlined, "Settings", false),

                          const Spacer(),

                          // Quick Action: Add Child Profile
                          Container(
                            width: double.infinity,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF14B8A6)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    "Add Child Profile",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Sign Out
                          Row(
                            children: [
                              const Icon(Icons.logout,
                                  color: Colors.redAccent, size: 16),
                              const SizedBox(width: 10),
                              Text(
                                "Sign out",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Main Content Area
                    Expanded(
                      child: Container(
                        color: const Color(0xFF020617),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main Content Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      "THE GUARDIAN",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "/  Dashboard",
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xFF334155)),
                                  ),
                                  child: const Icon(Icons.notifications_none,
                                      color: Colors.white, size: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Greeting
                            const Text(
                              "Good morning, Parent",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Monitoring active. Select a child to view activity.",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Row of Cards
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Column: Family Overview & Child Cards
                                  Expanded(
                                    flex: 11,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              "Family Overview",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              "View Map >",
                                              style: TextStyle(
                                                color: const Color(0xFF14B8A6)
                                                    .withValues(alpha: 0.8),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Child Card: colombie
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F172A),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                                color: const Color(0xFF1E293B)),
                                          ),
                                          child: Row(
                                            children: [
                                              // Child Avatar
                                              Container(
                                                width: 38,
                                                height: 38,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF14B8A6),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Center(
                                                  child: Text(
                                                    "C",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),

                                              // Child Name & limit
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      "colombie",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      "6 yrs · 17h left of 1020m",
                                                      style: TextStyle(
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: 0.5),
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Offline Badge
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Text(
                                                  "Offline",
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),

                                  // Right Column: AI Orchestrator Card
                                  Expanded(
                                    flex: 9,
                                    child: Container(
                                      height: 180,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF4F46E5),
                                            Color(0xFF14B8A6)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF4F46E5)
                                                .withValues(alpha: 0.3),
                                            blurRadius: 15,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Icon(Icons.auto_awesome,
                                                  color: Colors.white,
                                                  size: 24),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: const Text(
                                                  "ACTIVE AI",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                          const Text(
                                            "Orchestrateur IA",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Outfit',
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            "Analyse intelligente • Recommandations personnalisées de sécurité pour colombie.",
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.8),
                                              fontSize: 10,
                                              height: 1.4,
                                            ),
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
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 720,
            height: 16,
            decoration: const BoxDecoration(
              color: Color(0xFF475569),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
          ),
          Container(
            width: 140,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, bool active) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF4F46E5).withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: active ? const Color(0xFF818CF8) : Colors.grey, size: 16),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.grey,
              fontSize: 11,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }
}
