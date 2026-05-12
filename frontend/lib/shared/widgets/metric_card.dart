// Ce fichier affiche une carte KPI reutilisable.
import 'package:flutter/material.dart';

import '../../core/localization/app_localization.dart';
import '../../core/state/portfolio_currency_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_conversion.dart';
import '../../core/utils/formatters.dart';
import 'mini_trend_chart.dart';

/// Carte compacte réutilisable pour afficher une métrique et sa tendance.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.variation,
    required this.color,
    required this.icon,
    required this.trend,
    this.isPercent = false,
    this.currencyCode = 'XOF',
  });

  final String label;
  final double value;
  final String variation;
  final Color color;
  final IconData icon;
  final List<double> trend;
  final bool isPercent;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final displayCurrency = PortfolioCurrencyScope.maybeOf(
      context,
      fallback: currencyCode,
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
                MiniTrendChart(values: trend, color: color),
              ],
            ),
            const SizedBox(height: AppTheme.spacing),
            Text(
              label.tr(context),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              isPercent
                  ? AppFormatters.percent(value)
                  : formatCurrencyForDisplay(
                      value,
                      fromCurrency: currencyCode,
                      toCurrency: displayCurrency,
                    ),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              variation.tr(context),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
