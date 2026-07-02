import 'package:flutter/material.dart';

import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/formatters.dart';
import 'dashboard_design.dart';

/// Capital détenu vs capital requis, par strate de fonds propres.
///
/// Barres bicolores en monochrome navy (détenu = navy plein, requis = navy
/// clair), surplus en texte de statut — pas de pastille colorée.
class DashboardCapitalVsRequired extends StatelessWidget {
  const DashboardCapitalVsRequired({super.key});

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context) ?? PortfolioAmountUnit.billion;

    return DashPanel(
      height: 300,
      title: 'Capital détenu vs capital requis',
      unit: 'En ${amountUnit.label} FCFA',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _legend(c, c.navy, 'Détenu'),
              const SizedBox(width: 20),
              _legend(c, c.ramp[3], 'Requis'),
            ],
          ),
          const Spacer(),
          _row(c, 'CET1', held: 120 * 1e9, requiredAmt: 80 * 1e9, unit: amountUnit),
          const SizedBox(height: 16),
          _row(c, 'Tier 1', held: 135 * 1e9, requiredAmt: 95 * 1e9, unit: amountUnit),
          const SizedBox(height: 16),
          _row(c, 'Total FP', held: 180 * 1e9, requiredAmt: 120 * 1e9, unit: amountUnit),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _legend(DashColors c, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500, color: c.muted),
        ),
      ],
    );
  }

  Widget _row(
    DashColors c,
    String label, {
    required double held,
    required double requiredAmt,
    required PortfolioAmountUnit unit,
  }) {
    // Determine a reasonable max relative to the unit, scaled to 200B for the mock 
    final maxValRaw = 200.0 * 1e9;
    final maxVal = maxValRaw / unit.divisor;
    final heldVal = held / unit.divisor;
    final reqVal = requiredAmt / unit.divisor;

    final surplus = heldVal - reqVal;
    final surplusPct = reqVal > 0 ? surplus / reqVal * 100 : 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label.toUpperCase(),
            style: DashText.eyebrow(c, color: c.ink),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final track = constraints.maxWidth - 44;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(c, c.navy, heldVal, maxVal, track),
                  const SizedBox(height: 5),
                  _bar(c, c.ramp[3], reqVal, maxVal, track),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '+${AppFormatters.compactNumber(surplus)} ${unit.label}',
                style: DashText.value(c, color: c.conforme),
              ),
              const SizedBox(height: 2),
              Text(
                '+${surplusPct.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 10.5,
                  color: c.muted,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bar(
    DashColors c,
    Color color,
    double value,
    double maxVal,
    double track,
  ) {
    final w = maxVal > 0 ? (value / maxVal) * track : 0.0;
    return Row(
      children: [
        if (w > 0)
          Container(
            height: 13,
            width: w,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(2),
                bottomRight: Radius.circular(2),
              ),
            ),
          ),
        const SizedBox(width: 8),
        Text(
          AppFormatters.compactNumber(value),
          style: DashText.value(c, color: c.ink, weight: FontWeight.w600),
        ),
      ],
    );
  }
}

