import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';

class DensiteRwaGaugeCard extends StatelessWidget {
  const DensiteRwaGaugeCard({
    super.key,
    required this.density,
    required this.totalExposure,
    required this.totalRwa,
  });

  final double density; // between 0.0 and 1.0 (or slightly above if > 100%)
  final double totalExposure;
  final double totalRwa;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFFDCE4F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DENSITÉ RWA',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF0B4DBA),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Niveau moyen de risque du portefeuille',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF62708C),
                  fontSize: 11,
                ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: _GaugeAnimation(density: density),
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugeAnimation extends StatelessWidget {
  const _GaugeAnimation({required this.density});

  final double density;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: density),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Center(
          child: FractionallySizedBox(
            widthFactor: 0.75,
            heightFactor: 0.75,
            child: CustomPaint(
              size: const Size(double.infinity, double.infinity),
            painter: _SemiCircleGaugePainter(value: value),
            child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: const Offset(0, 45), // Push down to center in the semi-circle
                  child: Container(
                    width: 120,
                    height: 120,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFDCE4F2), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: RichText(
                      text: TextSpan(
                        text: AppFormatters.percent(value).replaceAll('%', '').trim(),
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              color: const Color(0xFF0F1B3D),
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                        children: [
                          TextSpan(
                            text: ' %',
                            style: TextStyle(
                              color: const Color(0xFF62708C),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
  },
);
}
}

class _SemiCircleGaugePainter extends CustomPainter {
  _SemiCircleGaugePainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    // With AspectRatio(1.8) handling the bounds, we can simply anchor the arc at the bottom.
    // We leave 24px space at the bottom for the 0% / 100% texts.
    final center = Offset(size.width / 2, size.height - 24);
    final radius = (size.width / 2) - 24; // 24px horizontal padding to account for strokeWidth
    
    final rect = Rect.fromCircle(center: center, radius: radius);
    
    // Background arc (Gradient from Green to Yellow to Red)
    final sweepGradient = SweepGradient(
      startAngle: math.pi,
      endAngle: math.pi * 2,
      colors: const [
        Color(0xFF22C55E), // Green
        Color(0xFFEAB308), // Yellow
        Color(0xFFEF4444), // Red
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final paintGradient = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.butt;

    // Draw the full background arc with gradient
    canvas.drawArc(rect, math.pi, math.pi, false, paintGradient);

    // Draw needle/progress arc
    final progressPaint = Paint()
      ..color = const Color(0xFF0F1B3D) // Ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    // The value can theoretically exceed 100%, we clamp it for the gauge visual
    final clampedValue = value.clamp(0.0, 1.0);
    final sweepAngle = math.pi * clampedValue;
    
    // Draw an inner arc to show progression
    final progressRect = Rect.fromCircle(center: center, radius: radius - 18);
    canvas.drawArc(progressRect, math.pi, sweepAngle, false, progressPaint);

    // Draw the current value marker (needle point at the end of the arc)
    final needleAngle = math.pi + sweepAngle;
    final needleX = center.dx + (radius - 18) * math.cos(needleAngle);
    final needleY = center.dy + (radius - 18) * math.sin(needleAngle);
    
    canvas.drawCircle(
      Offset(needleX, needleY),
      5,
      Paint()..color = const Color(0xFF0F1B3D),
    );

    // Draw text labels for 0% and 100%
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // 0% label
    textPainter.text = const TextSpan(
      text: '0%',
      style: TextStyle(color: Color(0xFF62708C), fontSize: 12),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - radius - textPainter.width / 2, center.dy + 8),
    );

    // 100% label
    textPainter.text = const TextSpan(
      text: '100%',
      style: TextStyle(color: Color(0xFF62708C), fontSize: 12),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx + radius - textPainter.width / 2, center.dy + 8),
    );

    // 25%, 50%, 75% indicators
    final indicatorPaint = Paint()
      ..color = const Color(0xFF62708C).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final pct in [0.25, 0.50, 0.75]) {
      final angle = math.pi + (math.pi * pct);
      final outerRadius = radius + 10; // Outer edge of the 20px thick arc
      final tickStart = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );
      final tickEnd = Offset(
        center.dx + (outerRadius + 6) * math.cos(angle),
        center.dy + (outerRadius + 6) * math.sin(angle),
      );
      canvas.drawLine(tickStart, tickEnd, indicatorPaint);

      textPainter.text = TextSpan(
        text: '${(pct * 100).toInt()}%',
        style: const TextStyle(color: Color(0xFF62708C), fontSize: 10, fontWeight: FontWeight.w600),
      );
      textPainter.layout();
      
      final textOffset = Offset(
        center.dx + (outerRadius + 18) * math.cos(angle) - textPainter.width / 2,
        center.dy + (outerRadius + 18) * math.sin(angle) - textPainter.height / 2,
      );
      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant _SemiCircleGaugePainter oldDelegate) {
    return oldDelegate.value != value;
  }
}
