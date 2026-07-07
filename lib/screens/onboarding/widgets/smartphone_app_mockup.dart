import 'dart:async';
import 'package:flutter/material.dart';

class SmartphoneAppMockup extends StatefulWidget {
  const SmartphoneAppMockup({super.key});

  @override
  State<SmartphoneAppMockup> createState() => _SmartphoneAppMockupState();
}

class _SmartphoneAppMockupState extends State<SmartphoneAppMockup> {
  Timer? _timer;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _ticks++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 520,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF020617),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: const Color(0xFF1E293B), width: 10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
            BoxShadow(
              color: const Color(0xFF14B8A6).withValues(alpha: 0.08),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Scaffold(
            backgroundColor: const Color(0xFF020617),
            body: Column(
              children: [
                // Notch & Status Bar
                Container(
                  height: 36,
                  color: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "12:${(_ticks % 60).toString().padLeft(2, '0')}",
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        width: 70,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                        ),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.wifi, color: Colors.white, size: 10),
                          SizedBox(width: 4),
                          Icon(Icons.battery_full, color: Colors.white, size: 10),
                        ],
                      ),
                    ],
                  ),
                ),

                // Mobile Content
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF020617)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Navigation Bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(Icons.arrow_back, color: Colors.white.withValues(alpha: 0.8), size: 18),
                              Icon(Icons.settings_outlined, color: Colors.white.withValues(alpha: 0.8), size: 18),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Name and Status
                          const Text(
                            "colombie",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                "Offline",
                                style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "•",
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.sync, color: Colors.white.withValues(alpha: 0.2), size: 11),
                              const SizedBox(width: 4),
                              Text(
                                "Last sync: 2m ago",
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Screen Time Today Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.timer_outlined, color: Color(0xFF4F46E5), size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      "Screen Time Today",
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: const LinearProgressIndicator(
                                    value: 0.38,
                                    backgroundColor: Color(0xFF0F172A),
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("1h 15min", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    Text("of 2h", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Last Location Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_outlined, color: Color(0xFF14B8A6), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Last Location",
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        "4.5709, -74.2973",
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.map_outlined, color: const Color(0xFF4F46E5).withValues(alpha: 0.8), size: 18),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Quick Actions Row
                          const Text(
                            "Quick Actions",
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _quickAction(Icons.block_flipped, "Block Apps", Colors.redAccent),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _quickAction(Icons.bar_chart, "Stats", const Color(0xFF14B8A6)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _quickAction(Icons.notifications_active_outlined, "Alerts", Colors.purpleAccent),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Recent Alerts
                          const Text(
                            "Recent Alerts",
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),

                          // SOS Tile
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.sos, color: Colors.red, size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  "SOS",
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Indicator
                Container(
                  height: 16,
                  color: Colors.black,
                  child: Center(
                    child: Container(
                      width: 90,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
