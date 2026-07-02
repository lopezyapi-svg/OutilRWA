import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../models/dashboard_models.dart';
import 'dashboard_design.dart';

String _cleanLabel(String label) {
  final cleaned = label.replaceAll(RegExp(r'^\([a-zA-Z]\)\s*'), '');
  if (cleaned.isEmpty) return cleaned;
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}

const List<Color> _barColors = [
  Color(0xFF1A237E), // Indigo 900 (deepblue)
  Color(0xFF3F51B5), // Indigo 500 (indigo)
  Color(0xFF2196F3), // Blue 500 (bleu)
  Color(0xFF64B5F6), // Blue 300 (clair)
  Color(0xFF90CAF9), // Blue 200 (très clair)
];

class DashboardTopRwaChart extends StatelessWidget {
  const DashboardTopRwaChart({
    super.key,
    required this.entries,
    this.displayCurrency = 'XOF',
    this.trailing,
  });

  final List<DistributionEntry> entries;
  final String displayCurrency;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final top5 = entries.take(5).toList();
    if (top5.isEmpty) {
      return const Center(child: Text('Aucune donnée disponible'));
    }

    final maxAmount = top5.map((e) => e.amount).fold<double>(0.0, math.max);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: top5.map((entry) {
            final amountUnit = PortfolioAmountUnitScope.maybeOf(context) ?? PortfolioAmountUnit.billion;
            final valScaled = entry.amount / amountUnit.divisor;
            final formatted = AppFormatters.decimalNumber(valScaled, maxDecimals: 2);
            final suffix = amountUnit.label;
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                alignment: Alignment.bottomCenter,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$formatted $suffix',
                    style: DashText.caption(DashColors.of(context), color: DashColors.of(context).muted)
                        .copyWith(fontSize: 10, fontWeight: FontWeight.w600),
                    maxLines: 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: top5.asMap().entries.map((mapEntry) {
              final index = mapEntry.key;
              final entry = mapEntry.value;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: _VerticalBarItem(
                    entry: entry,
                    maxAmount: maxAmount,
                    color: _barColors[index % _barColors.length],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: top5.map((entry) {
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                alignment: Alignment.topCenter,
                child: Text(
                  _cleanLabel(entry.label),
                  textAlign: TextAlign.center,
                  style: DashText.caption(DashColors.of(context), color: DashColors.of(context).ink)
                      .copyWith(fontWeight: FontWeight.w500, fontSize: 11),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _VerticalBarItem extends StatefulWidget {
  const _VerticalBarItem({
    required this.entry,
    required this.maxAmount,
    required this.color,
  });

  final DistributionEntry entry;
  final double maxAmount;
  final Color color;

  @override
  State<_VerticalBarItem> createState() => _VerticalBarItemState();
}

class _VerticalBarItemState extends State<_VerticalBarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final percentage = widget.entry.percentage * 100;
    
    final ratio = widget.entry.percentage;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.maxHeight;
          final availableBarHeight = maxHeight - 24;
          final barHeight = availableBarHeight * ratio;

          return AnimatedScale(
            scale: _isHovered ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            alignment: Alignment.bottomCenter,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                    Container(
                      width: 32,
                      height: maxHeight,
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      width: 32,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: _isHovered ? [BoxShadow(color: widget.color.withValues(alpha: 0.4), blurRadius: 4, offset: const Offset(0, -2))] : [],
                      ),
                    ),
                Positioned(
                  bottom: barHeight + 4,
                  child: Text(
                    '${AppFormatters.decimalNumber(percentage, maxDecimals: 1)}%',
                    style: DashText.caption(c, color: widget.color).copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
