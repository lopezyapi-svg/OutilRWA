import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'dashboard_design.dart';

class DashboardRwaDonut extends StatefulWidget {
  const DashboardRwaDonut({super.key, this.currency = 'XOF', required this.data});

  final String currency;
  final DashboardSnapshot data;

  @override
  State<DashboardRwaDonut> createState() => _DashboardRwaDonutState();
}

class _DashboardRwaDonutState extends State<DashboardRwaDonut> {
  int touchedIndex = -1;

  DashboardMetric _metric(String key) {
    return widget.data.metrics.firstWhere((m) => m.key == key, orElse: () => DashboardMetric(key: key, label: '', value: 0.0, variation: '', trend: []));
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final amountUnit = PortfolioAmountUnitScope.maybeOf(context) ?? PortfolioAmountUnit.billion;
    final scale = 1.0 / amountUnit.divisor;

    // RWA Data from explicit metrics
    final creditRawXof = _metric('rwa_credit').value > 0 ? _metric('rwa_credit').value : 2450.0 * 1000000000;
    final operationnelRawXof = _metric('rwa_op').value > 0 ? _metric('rwa_op').value : 410.0 * 1000000000;
    final marcheRawXof = _metric('rwa_market').value > 0 ? _metric('rwa_market').value : 320.0 * 1000000000;

    // Convert to requested currency, then scale to the display unit (M/Md).
    final credit = convertCurrencyAmount(creditRawXof, fromCurrency: 'XOF', toCurrency: widget.currency) * scale;
    final operationnel = convertCurrencyAmount(operationnelRawXof, fromCurrency: 'XOF', toCurrency: widget.currency) * scale;
    final marche = convertCurrencyAmount(marcheRawXof, fromCurrency: 'XOF', toCurrency: widget.currency) * scale;
    
    final total = credit + operationnel + marche;

    final sectors = [
      _SectorData('RWA Crédit', credit, total > 0 ? (credit/total)*100 : 0, c.navy),
      _SectorData('RWA Opérationnel', operationnel, total > 0 ? (operationnel/total)*100 : 0, c.accent),
      _SectorData('RWA Marché', marche, total > 0 ? (marche/total)*100 : 0, const Color(0xFF38BDF8)), // Light Sky Blue
    ];

    return DashPanel(
      title: 'STRUCTURE DES RWA',
      unit: 'En ${amountUnit.label} (${widget.currency})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  touchedIndex = -1;
                                  return;
                                }
                                touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: sectors.asMap().entries.map((entry) {
                            final isTouched = entry.key == touchedIndex;
                            final sector = entry.value;
                            final radius = isTouched ? 35.0 : 30.0;
                            final fontSize = isTouched ? 14.0 : 12.0;

                            return PieChartSectionData(
                              color: sector.color,
                              value: sector.percentage,
                              title: sector.percentage >= 5 ? '${sector.percentage.toStringAsFixed(0)}%' : '',
                              radius: radius,
                              titleStyle: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // Inner text
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Total', style: TextStyle(fontSize: 9, color: c.muted)),
                          Text(AppFormatters.compactNumber(total), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.ink)),
                          Text('${amountUnit.label} (${widget.currency})', style: TextStyle(fontSize: 8, color: c.muted)),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sectors.map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, color: s.color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    s.label,
                                    style: TextStyle(fontSize: 12, color: c.muted),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${AppFormatters.compactNumber(s.amount)} ${amountUnit.label}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.ink),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: Dash.hairline, color: c.divider),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Capital minimum requis = ${AppFormatters.compactNumber(total)} × 8%', style: TextStyle(fontSize: 12, color: c.muted, fontWeight: FontWeight.w500)),
              Text(
                '${AppFormatters.compactNumber(total * 0.08)} ${amountUnit.label}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.ink),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectorData {
  const _SectorData(this.label, this.amount, this.percentage, this.color);
  final String label;
  final double amount;
  final double percentage;
  final Color color;
}
