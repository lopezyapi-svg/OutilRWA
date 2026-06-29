import 'package:flutter/material.dart';

import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'dashboard_design.dart';

class DashboardCapitalConsumption extends StatelessWidget {
  const DashboardCapitalConsumption({super.key, this.currency = 'XOF', this.data});

  final String currency;
  final DashboardSnapshot? data;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context) ?? PortfolioAmountUnit.billion;

    // Get raw data in XOF from metrics
    double rwaXof = 3180.0 * 1000000000;
    double capitalRequisXof = 254.4 * 1000000000;
    double capitalDetenuXof = 450.0 * 1000000000;
    double solvabilite = 0.1415; // 14.15% fallback

    if (data != null && data!.metrics.isNotEmpty) {
      final rwaMetric = data!.metrics.firstWhere((m) => m.key == 'rwa', orElse: () => DashboardMetric(key: 'rwa', label: 'RWA', value: rwaXof, variation: '', trend: const []));
      final capitalMetric = data!.metrics.firstWhere((m) => m.key == 'capital', orElse: () => DashboardMetric(key: 'capital', label: 'Capital', value: capitalRequisXof, variation: '', trend: const []));
      final solvabiliteMetric = data!.metrics.firstWhere((m) => m.key == 'solvabilite', orElse: () => DashboardMetric(key: 'solvabilite', label: 'Solvabilité', value: solvabilite, variation: '', trend: const []));
      
      rwaXof = rwaMetric.value;
      capitalRequisXof = capitalMetric.value;
      solvabilite = solvabiliteMetric.value;
      capitalDetenuXof = solvabilite * rwaXof;
    }

    // Convert to requested currency and scale to unit
    final capitalDetenu = convertCurrencyAmount(capitalDetenuXof, fromCurrency: 'XOF', toCurrency: currency) / amountUnit.divisor;
    final capitalRequis = convertCurrencyAmount(capitalRequisXof, fromCurrency: 'XOF', toCurrency: currency) / amountUnit.divisor;
    final excedent = capitalDetenu - capitalRequis;
    
    // Status color
    final isSafe = solvabilite >= 0.08;
    final statusColor = isSafe ? c.conforme : c.sousMinimum;

    return DashPanel(
      title: 'RATIO DE SOLVABILITÉ',
      unit: 'En ${amountUnit.label} ($currency)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _buildMetricRow('Fonds propres (Capital détenu)', capitalDetenu, c.navy, c, amountUnit.label),
          const SizedBox(height: 12),
          _buildMetricRow('Exigence minimale (8%)', capitalRequis, c.ink, c, amountUnit.label),
          const SizedBox(height: 12),
          _buildMetricRow('Coussin de sécurité (Excédent)', excedent, excedent >= 0 ? c.conforme : c.sousMinimum, c, amountUnit.label, showPlus: true),
          const SizedBox(height: 16),
          
          // Ratio display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ratio de Solvabilité global', style: TextStyle(fontSize: 13, color: c.muted, fontWeight: FontWeight.w600)),
              Text(
                AppFormatters.percent(solvabilite),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Jauge de Solvabilité (Target: 8%, Max displayed: 20%)
          Stack(
            children: [
              // Fond
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              // Barre remplie (Capped at 20% for visual scale)
              FractionallySizedBox(
                widthFactor: (solvabilite / 0.20).clamp(0.0, 1.0),
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              // Ligne de l'exigence minimale (8%)
              Positioned(
                left: 0,
                right: 0,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (0.08 / 0.20).clamp(0.0, 1.0),
                  child: Container(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 2,
                      height: 12,
                      color: c.ink, // Black tick mark for the 8% target
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0%', style: TextStyle(fontSize: 11, color: c.muted)),
              Text('Min: 8%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.ink)),
              Text('20%+', style: TextStyle(fontSize: 11, color: c.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, double amount, Color color, DashColors c, String unitLabel, {bool showPlus = false}) {
    final prefix = (showPlus && amount > 0) ? '+' : '';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: c.muted, fontWeight: FontWeight.w500)),
        Text(
          '$prefix${AppFormatters.integer(amount)} $unitLabel',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
