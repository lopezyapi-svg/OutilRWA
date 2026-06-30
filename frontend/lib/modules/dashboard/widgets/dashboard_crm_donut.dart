import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'dashboard_design.dart';

class DashboardCrmDonut extends StatefulWidget {
  const DashboardCrmDonut({super.key, required this.entries});

  final List<DistributionEntry> entries;

  @override
  State<DashboardCrmDonut> createState() => _DashboardCrmDonutState();
}

class _DashboardCrmDonutState extends State<DashboardCrmDonut> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);

    // Map the CRM entries to sector data
    // Usually there are up to 3 entries: 'CRM financée', 'CRM non financée', 'Aucune'
    final colors = [
      c.navy,
      c.accent,
      const Color(0xFF3B82F6), // Bleu clair
    ];

    List<_SectorData> sectors = [];
    double totalPercent = 0;
    
    // Safety check, handle up to 4 just in case
    final safeColors = [...colors, Colors.purple, Colors.orange];

    for (int i = 0; i < widget.entries.length; i++) {
      final entry = widget.entries[i];
      final percent = entry.percentage * 100;
      totalPercent += percent;
      sectors.add(
        _SectorData(
          entry.label,
          entry.amount,
          percent,
          safeColors[i % safeColors.length],
          entry.count ?? 0,
        ),
      );
    }

    // Find the dominant sector for the central text
    _SectorData? dominantSector;
    if (sectors.isNotEmpty) {
      dominantSector = sectors.reduce((a, b) => a.percentage > b.percentage ? a : b);
    }

    return DashPanel(
      title: 'Répartition totale par type de CRM',
      height: 360,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: SizedBox(
              height: 240,
              child: Stack(
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
                      sectionsSpace: 4,
                      centerSpaceRadius: 65,
                      sections: sectors.asMap().entries.map((entry) {
                        final i = entry.key;
                        final s = entry.value;
                        final isTouched = i == touchedIndex;
                        final radius = isTouched ? 28.0 : 20.0;
                        
                        return PieChartSectionData(
                          color: s.color,
                          value: s.percentage,
                          title: '',
                          radius: radius,
                          badgeWidget: isTouched
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: c.surface,
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: c.ink.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  child: Text(
                                    '${AppFormatters.decimalNumber(s.percentage, maxDecimals: 1)}%',
                                    style: DashText.caption(c, color: s.color).copyWith(fontWeight: FontWeight.w700),
                                  ),
                                )
                              : null,
                          badgePositionPercentageOffset: 1.2,
                        );
                      }).toList(),
                    ),
                    swapAnimationDuration: const Duration(milliseconds: 500),
                    swapAnimationCurve: Curves.easeOutQuint,
                  ),
                  if (dominantSector != null && touchedIndex == -1)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${AppFormatters.decimalNumber(dominantSector.percentage, maxDecimals: 1)}%',
                            style: DashText.hero(c, size: 28),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              dominantSector.label,
                              style: DashText.caption(c, color: c.muted),
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sectors.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _LegendItem(sector: s),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectorData {
  const _SectorData(this.label, this.amount, this.percentage, this.color, this.count);
  final String label;
  final double amount;
  final double percentage;
  final Color color;
  final int count;
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.sector});

  final _SectorData sector;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final countText = '${sector.count} exposition${sector.count > 1 ? 's' : ''}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: c.ink.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: sector.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sector.label, 
                  style: DashText.caption(c, color: c.muted).copyWith(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  countText,
                  style: DashText.caption(c, color: c.ink).copyWith(fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${AppFormatters.decimalNumber(sector.percentage, maxDecimals: 1)}%',
              style: DashText.hero(c, size: 18).copyWith(
                color: Colors.indigo.shade900,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
