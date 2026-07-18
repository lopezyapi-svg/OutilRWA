import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/utils/formatters.dart';
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
    final ratios = _DashboardRatios.from(data);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RatioTile(
                  label: 'Ratio CET1',
                  value: ratios.cet1,
                  pilier1: 5.00,
                  coussin: 2.50),
              const SizedBox(height: 8),
              _RatioTile(
                  label: 'Ratio Tier 1',
                  value: ratios.tier1,
                  pilier1: 7.50,
                  coussin: 2.50),
              const SizedBox(height: 8),
              _RatioTile(
                  label: 'Ratio de solvabilité',
                  value: ratios.solvabilite,
                  pilier1: 9.00,
                  coussin: 2.50),
              const SizedBox(height: 8),
              _RatioTile(
                  label: 'Ratio de Levier',
                  value: ratios.levier,
                  pilier1: 3.00,
                  coussin: 0.00),
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _RatioTile(
                    label: 'Ratio CET1',
                    value: ratios.cet1,
                    pilier1: 5.00,
                    coussin: 2.50),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RatioTile(
                    label: 'Ratio Tier 1',
                    value: ratios.tier1,
                    pilier1: 7.50,
                    coussin: 2.50),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RatioTile(
                    label: 'Ratio de solvabilité',
                    value: ratios.solvabilite,
                    pilier1: 9.00,
                    coussin: 2.50),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RatioTile(
                    label: 'Ratio de Levier',
                    value: ratios.levier,
                    pilier1: 3.00,
                    coussin: 0.00),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardRatios {
  const _DashboardRatios({
    required this.cet1,
    required this.tier1,
    required this.solvabilite,
    required this.levier,
  });

  final double cet1;
  final double tier1;
  final double solvabilite;
  final double levier;

  factory _DashboardRatios.from(DashboardSnapshot data) {
    final metrics = {for (final metric in data.metrics) metric.key: metric};
    final fp = data.fondsPropres;
    final rwaBase = _positiveMetric(metrics, 'rwa') ??
        data.portfolioOverview.fold<double>(0.0, (sum, row) => sum + row.rwa);
    final exposureBase = _positiveMetric(metrics, 'encours') ??
        data.portfolioOverview
            .fold<double>(0.0, (sum, row) => sum + row.grossAmount);

    return _DashboardRatios(
      cet1: _ratioPercent(
        numerator: fp?.cet1,
        denominator: rwaBase,
        fallback: metrics['cet1_ratio']?.value,
      ),
      tier1: _ratioPercent(
        numerator: fp?.tier1,
        denominator: rwaBase,
        fallback: metrics['tier1_ratio']?.value,
      ),
      solvabilite: _ratioPercent(
        numerator: fp?.totalFp,
        denominator: rwaBase,
        fallback: metrics['solvabilite']?.value,
      ),
      levier: _ratioPercent(
        numerator: fp?.tier1,
        denominator: exposureBase,
        fallback: metrics['ratio_levier']?.value,
      ),
    );
  }

  static double? _positiveMetric(
      Map<String, DashboardMetric> metrics, String key) {
    final value = metrics[key]?.value;
    if (value == null || value <= 0) {
      return null;
    }
    return value;
  }

  static double _ratioPercent({
    required double? numerator,
    required double denominator,
    required double? fallback,
  }) {
    if (numerator != null && numerator > 0 && denominator > 0) {
      return numerator / denominator * 100;
    }
    return (fallback ?? 0.0) * 100;
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
      badgeText = 'Excédent'.tr(context);
    } else if (status == DashStatus.sousCible) {
      badgeText = 'Sous surveillance'.tr(context);
    } else {
      badgeText = 'Déficit'.tr(context);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColor;
    Color borderColor;
    Color textColor;

    if (status == DashStatus.conforme) {
      bgColor = isDark
          ? const Color(0xFF064E3B).withValues(alpha: 0.5)
          : const Color(0xFFECFDF5);
      borderColor = isDark ? const Color(0xFF059669) : const Color(0xFF6EE7B7);
      textColor = isDark ? const Color(0xFF34D399) : const Color(0xFF065F46);
    } else if (status == DashStatus.sousCible) {
      bgColor = isDark
          ? const Color(0xFF78350F).withValues(alpha: 0.5)
          : const Color(0xFFFFFBEB);
      borderColor = isDark ? const Color(0xFFD97706) : const Color(0xFFFCD34D);
      textColor = isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E);
    } else {
      bgColor = isDark
          ? const Color(0xFF7F1D1D).withValues(alpha: 0.5)
          : const Color(0xFFFEF2F2);
      borderColor = isDark ? const Color(0xFFDC2626) : const Color(0xFFFCA5A5);
      textColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Dash.radius),
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label.tr(context).toUpperCase(),
              style: DashText.eyebrow(
                c,
                color:
                    isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('${_fr(value)}%', style: DashText.hero(c, size: 18)),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Seuil réglementaire :'.tr(context),
                  style: DashText.caption(c, color: c.ink)
                      .copyWith(fontWeight: FontWeight.w600, fontSize: 9.5),
                ),
                const SizedBox(width: 6),
                Text(
                  context.tr('Pilier 1 ({{value}}%)', args: {'value': _fr(pilier1)}),
                  style: DashText.caption(c, color: c.muted).copyWith(fontSize: 9.5),
                ),
                if (coussin > 0) ...[
                  const SizedBox(width: 6),
                  Container(width: 1, height: 10, color: c.divider),
                  const SizedBox(width: 6),
                  Text(
                    context.tr('Coussin ({{value}}%)', args: {'value': _fr(coussin)}),
                    style: DashText.caption(c, color: c.muted).copyWith(fontSize: 9.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, thickness: Dash.hairline, color: c.divider),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 10),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: CustomPaint(
                  painter: _DottedLinePainter(c.muted.withValues(alpha: 0.15)),
                  size: const Size(double.infinity, 1),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${ecart >= 0 ? "+" : ""}${_fr(ecart)} pts',
                style: DashText.value(
                  c,
                  color: c.status(status),
                  weight: FontWeight.w700,
                ).copyWith(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Jusqu'à 3 décimales, sans zéros de remplissage : 7,5 s'affiche « 7,5 »
  // (et non « 7,500 », illisible avec la virgule décimale française).
  static String _fr(double v) =>
      AppFormatters.decimalNumber(v, maxDecimals: 3);
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
