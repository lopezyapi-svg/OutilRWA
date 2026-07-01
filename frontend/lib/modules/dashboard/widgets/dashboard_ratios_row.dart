import 'package:flutter/material.dart';

import '../models/dashboard_models.dart';
import 'dashboard_design.dart';

/// Bandeau des trois ratios prudentiels.
///
/// Tuiles plates à filet fin : sur-titre tracé, chiffre-héros tabulaire,
/// minimum réglementaire en légende, point de statut. Aucun icon-box teinté,
/// aucune pastille décorative — la couleur ne porte que le statut.
class DashboardRatiosRow extends StatelessWidget {
  const DashboardRatiosRow({super.key, required this.data});

  final DashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final cet1Metric = data.metrics.firstWhere((m) => m.key == 'cet1_ratio', orElse: () => const DashboardMetric(key: '', label: '', value: 0.0, variation: '', trend: []));
    final t1Metric = data.metrics.firstWhere((m) => m.key == 'tier1_ratio', orElse: () => const DashboardMetric(key: '', label: '', value: 0.0, variation: '', trend: []));
    final solvMetric = data.metrics.firstWhere((m) => m.key == 'solvabilite', orElse: () => const DashboardMetric(key: '', label: '', value: 0.0, variation: '', trend: []));

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 750) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RatioTile(label: 'Ratio CET1', value: cet1Metric.value * 100, pilier1: 5.00, coussin: 2.50),
              const SizedBox(height: 12),
              _RatioTile(label: 'Ratio Tier 1', value: t1Metric.value * 100, pilier1: 6.00, coussin: 2.50),
              const SizedBox(height: 12),
              _RatioTile(
                  label: 'Ratio de solvabilité', value: solvMetric.value * 100, pilier1: 9.00, coussin: 2.50),
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child:
                    _RatioTile(label: 'Ratio CET1', value: cet1Metric.value * 100, pilier1: 5.00, coussin: 2.50),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _RatioTile(
                    label: 'Ratio Tier 1', value: t1Metric.value * 100, pilier1: 6.00, coussin: 2.50),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _RatioTile(
                    label: 'Ratio de solvabilité',
                    value: solvMetric.value * 100,
                    pilier1: 9.00,
                    coussin: 2.50),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RatioTile extends StatelessWidget {
  const _RatioTile({
    required this.label,
    required this.value,
    required this.pilier1,
    required this.coussin,
  });

  final String label;
  final double value;
  final double pilier1;
  final double coussin;

  double get minimum => pilier1 + coussin;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final target = pilier1 + coussin;
    final status = dashRatioStatus(value, pilier1, target);
    final ecart = value - target;

    String badgeText;
    if (status == DashStatus.conforme) {
      badgeText = 'Excédent';
    } else if (status == DashStatus.sousCible) {
      badgeText = 'Sous surveillance';
    } else {
      badgeText = 'Déficit';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor;
    Color borderColor;
    Color textColor;

    if (status == DashStatus.conforme) {
      bgColor = isDark ? const Color(0xFF064E3B).withOpacity(0.5) : const Color(0xFFECFDF5);
      borderColor = isDark ? const Color(0xFF059669) : const Color(0xFF6EE7B7);
      textColor = isDark ? const Color(0xFF34D399) : const Color(0xFF065F46);
    } else if (status == DashStatus.sousCible) {
      bgColor = isDark ? const Color(0xFF78350F).withOpacity(0.5) : const Color(0xFFFFFBEB);
      borderColor = isDark ? const Color(0xFFD97706) : const Color(0xFFFCD34D);
      textColor = isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E);
    } else {
      bgColor = isDark ? const Color(0xFF7F1D1D).withOpacity(0.5) : const Color(0xFFFEF2F2);
      borderColor = isDark ? const Color(0xFFDC2626) : const Color(0xFFFCA5A5);
      textColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Dash.radius),
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: DashText.eyebrow(
              c,
              color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(height: 14),
          Text('${_fr(value)} %', style: DashText.hero(c, size: 32)),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                'Seuil réglementaire :',
                style: DashText.caption(c, color: c.ink).copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                'Pilier 1 (${_fr(pilier1)} %)',
                style: DashText.caption(c, color: c.muted),
              ),
              Container(width: 1, height: 10, color: c.divider),
              Text(
                'Coussin (${_fr(coussin)} %)',
                style: DashText.caption(c, color: c.muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: Dash.hairline, color: c.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Text(
                  badgeText,
                  style: DashText.caption(
                    c,
                    color: textColor,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomPaint(
                  painter: _DottedLinePainter(c.muted.withOpacity(0.15)),
                  size: const Size(double.infinity, 1),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${ecart >= 0 ? "+" : ""}${_fr(ecart)} pts',
                style: DashText.value(
                  c,
                  color: c.status(status),
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fr(double v) =>
      v.toStringAsFixed(2).replaceAll('.', ',');
}

class _DottedLinePainter extends CustomPainter {
  const _DottedLinePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    const dashWidth = 1.5;
    const dashSpace = 4.5;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter old) => old.color != color;
}
