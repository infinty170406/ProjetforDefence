import 'package:flutter/material.dart';

/// Reusable Google "G" logo widget used on login and signup screens.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final colors = [
      const Color(0xFF4285F4),
      const Color(0xFF34A853),
      const Color(0xFFFBBC05),
      const Color(0xFFEA4335),
    ];
    for (int i = 0; i < 4; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.72),
        (i * 3.14159 / 2) - 0.3,
        3.14159 / 2 + 0.3,
        false,
        paint,
      );
    }
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = size.width * 0.18;
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + radius * 0.7, center.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
