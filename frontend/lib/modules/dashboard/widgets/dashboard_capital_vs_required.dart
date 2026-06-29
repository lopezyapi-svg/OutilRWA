import 'package:flutter/material.dart';

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

    return DashPanel(
      height: 300,
      title: 'Capital détenu vs capital requis',
      unit: 'En milliards FCFA',
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
          _row(c, 'CET1', held: 120, requiredAmt: 80),
          const SizedBox(height: 16),
          _row(c, 'Tier 1', held: 135, requiredAmt: 95),
          const SizedBox(height: 16),
          _row(c, 'Total FP', held: 180, requiredAmt: 120),
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
  }) {
    const maxVal = 200.0;
    final surplus = held - requiredAmt;
    final surplusPct = requiredAmt > 0 ? surplus / requiredAmt * 100 : 0;

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
                  _bar(c, c.navy, held, maxVal, track),
                  const SizedBox(height: 5),
                  _bar(c, c.ramp[3], requiredAmt, maxVal, track),
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
                '+${surplus.toInt()} Md',
                style: DashText.value(c, color: c.conforme),
              ),
              const SizedBox(height: 2),
              Text(
                '+${surplusPct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 10.5,
                  color: c.muted,
                  fontWeight: FontWeight.w500,
                  fontFeatures: Dash.tabular,
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
    final w = (value / maxVal) * track;
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
          value.toInt().toString(),
          style: DashText.value(c, color: c.ink, weight: FontWeight.w600),
        ),
      ],
    );
  }
}
