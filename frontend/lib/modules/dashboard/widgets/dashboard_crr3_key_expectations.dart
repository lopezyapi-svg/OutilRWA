import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'dashboard_design.dart';

class DashboardCrr3KeyExpectations extends StatelessWidget {
  const DashboardCrr3KeyExpectations({
    super.key,
    required this.data,
    required this.displayCurrency,
  });

  final DashboardSnapshot data;
  final String displayCurrency;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final rows = _buildRows(context);
    final priorityRows = rows.where((row) => row.status != DashStatus.conforme);
    final priority = priorityRows.isEmpty
        ? 'Aucune rupture immediate: surveiller les coussins et les grands risques.'
        : priorityRows
            .map((row) => row.action)
            .take(2)
            .join('  ');

    return DashPanel(
      title: 'Attentes cles CRR3',
      subtitle: 'Comparaison entre les seuils attendus, le niveau observe et le capital a couvrir',
      trailing: DashStatusTag(
        status: rows.any((row) => row.status == DashStatus.sousMinimum)
            ? DashStatus.sousMinimum
            : rows.any((row) => row.status == DashStatus.sousCible)
                ? DashStatus.sousCible
                : DashStatus.conforme,
        dense: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 980;
              if (compact) {
                return Column(
                  children: rows
                      .map(
                        (row) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ExpectationRow(row: row),
                        ),
                      )
                      .toList(),
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rows.asMap().entries.map((entry) {
                  final isLast = entry.key == rows.length - 1;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: isLast ? 0 : 12),
                      child: _ExpectationRow(row: entry.value),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              border: Border.all(color: c.divider, width: Dash.hairline),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    'LECTURE',
                    style: DashText.eyebrow(c, color: c.navy),
                  ),
                ),
                Expanded(
                  child: Text(
                    priority,
                    style: DashText.value(c, weight: FontWeight.w600)
                        .copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_Expectation> _buildRows(BuildContext context) {
    final metrics = {for (final metric in data.metrics) metric.key: metric};
    final rwa = metrics['rwa']?.value ?? 0.0;
    final unit =
        PortfolioAmountUnitScope.maybeOf(context) ?? PortfolioAmountUnit.billion;

    _Expectation capitalRatio({
      required String label,
      required String key,
      required double minimum,
      required double target,
      required String action,
    }) {
      final actual = (metrics[key]?.value ?? 0.0) * 100;
      final gapPct = actual - target;
      final gapAmount = (actual - target) / 100 * rwa;
      final status = dashRatioStatus(actual, minimum, target);
      return _Expectation(
        label: label,
        observed: '${_pct(actual)} %',
        expected: '${_pct(minimum)} % min. / ${_pct(target)} % cible',
        gap: '${gapPct >= 0 ? '+' : ''}${_pct(gapPct)} pts',
        capitalGap: _formatGap(gapAmount, unit),
        status: status,
        action: action,
      );
    }

    final largeExposureMax = data.grandsRisques.isEmpty
        ? 0.0
        : data.grandsRisques.map((row) => row.fpRatio).reduce(math.max);
    final largeExposureBreaches =
        data.grandsRisques.where((row) => row.fpRatio > 25.0).length;
    final largeExposureStatus = largeExposureBreaches > 0
        ? DashStatus.sousMinimum
        : largeExposureMax > 20.0
            ? DashStatus.sousCible
            : DashStatus.conforme;

    return [
      capitalRatio(
        label: 'CET1',
        key: 'cet1_ratio',
        minimum: 5.0,
        target: 7.5,
        action: 'Priorite CET1: renforcer le capital dur ou reduire les RWA les plus consommateurs.',
      ),
      capitalRatio(
        label: 'Tier 1',
        key: 'tier1_ratio',
        minimum: 6.0,
        target: 8.5,
        action: 'Priorite Tier 1: reequilibrer les fonds propres de base avant croissance du portefeuille.',
      ),
      capitalRatio(
        label: 'FPE',
        key: 'solvabilite',
        minimum: 9.0,
        target: 11.5,
        action: 'Priorite FPE: couvrir le coussin de conservation et arbitrer les expositions a forte ponderation.',
      ),
      _Expectation(
        label: 'Grands risques',
        observed: '${_pct(largeExposureMax)} % FP',
        expected: '<= 25 % par contrepartie',
        gap: largeExposureBreaches == 0
            ? '0 depassement'
            : '$largeExposureBreaches depassement(s)',
        capitalGap: 'Seuil 25 %',
        status: largeExposureStatus,
        action: 'Priorite concentration: limiter les contreparties au-dessus de 25 % des fonds propres.',
      ),
    ];
  }

  String _formatGap(double xofAmount, PortfolioAmountUnit unit) {
    final converted = convertCurrencyAmount(
      xofAmount,
      fromCurrency: 'XOF',
      toCurrency: displayCurrency,
    );
    final value = converted / unit.divisor;
    final sign = value >= 0 ? '+' : '';
    return '$sign${AppFormatters.decimalNumber(value, maxDecimals: 2)} ${unit.label}';
  }

  String _pct(double value) => AppFormatters.decimalNumber(value, maxDecimals: 1);
}

class _ExpectationRow extends StatelessWidget {
  const _ExpectationRow({required this.row});

  final _Expectation row;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final statusColor = c.status(row.status);

    return Container(
      constraints: const BoxConstraints(minHeight: 156),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: c.border, width: Dash.hairline),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.label.toUpperCase(),
                  style: DashText.eyebrow(c, color: c.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DashStatusTag(status: row.status, dense: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            row.observed,
            style: DashText.hero(c, size: 24, color: statusColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          _Line(label: 'Attendu', value: row.expected),
          _Line(label: 'Ecart', value: row.gap, valueColor: statusColor),
          _Line(label: 'Capital', value: row.capitalGap),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(label, style: DashText.caption(c)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: DashText.value(c, color: valueColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Expectation {
  const _Expectation({
    required this.label,
    required this.observed,
    required this.expected,
    required this.gap,
    required this.capitalGap,
    required this.status,
    required this.action,
  });

  final String label;
  final String observed;
  final String expected;
  final String gap;
  final String capitalGap;
  final DashStatus status;
  final String action;
}
