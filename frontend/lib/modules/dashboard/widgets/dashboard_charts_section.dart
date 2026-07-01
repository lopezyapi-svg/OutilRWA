import 'package:flutter/material.dart';

import '../models/dashboard_models.dart';
import 'dashboard_crm_donut.dart';
import 'dashboard_design.dart';
import 'dashboard_top_gross_chart.dart';
import 'dashboard_top_rwa_chart.dart';

class DashboardChartsSection extends StatefulWidget {
  const DashboardChartsSection({
    super.key,
    required this.displayCurrency,
    required this.grossCategoryEntries,
    required this.rwaCategoryEntries,
    required this.crmEntries,
    required this.coveredRatio,
  });

  final String displayCurrency;
  final List<DistributionEntry> grossCategoryEntries;
  final List<DistributionEntry> rwaCategoryEntries;
  final List<DistributionEntry> crmEntries;
  final double coveredRatio; // Kept for API compatibility

  @override
  State<DashboardChartsSection> createState() => _DashboardChartsSectionState();
}

class _DashboardChartsSectionState extends State<DashboardChartsSection> {
  bool _showGross = true;

  Widget _buildToggle(DashColors c) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _showGross = true),
            borderRadius: BorderRadius.circular(4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _showGross ? c.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: DashText.caption(c).copyWith(
                  fontWeight: _showGross ? FontWeight.w700 : FontWeight.w500,
                  color: _showGross ? Colors.white : c.muted,
                ),
                child: const Text('EAD'),
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _showGross = false),
            borderRadius: BorderRadius.circular(4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: !_showGross ? c.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: DashText.caption(c).copyWith(
                  fontWeight: !_showGross ? FontWeight.w700 : FontWeight.w500,
                  color: !_showGross ? Colors.white : c.muted,
                ),
                child: const Text('RWA'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final toggleWidget = _buildToggle(c);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= 1200;

        final grossContent = DashboardTopGrossChart(
          key: const ValueKey('grossChart'),
          entries: widget.grossCategoryEntries,
          displayCurrency: widget.displayCurrency,
        );

        final rwaContent = DashboardTopRwaChart(
          key: const ValueKey('rwaChart'),
          entries: widget.rwaCategoryEntries,
          displayCurrency: widget.displayCurrency,
        );

        final donutChart = DashboardCrmDonut(
          entries: widget.crmEntries,
        );

        final activeChart = DashPanel(
          title: _showGross ? 'Top 5 de l\'EAD par catégorie' : 'Top 5 du RWA total par catégorie',
          trailing: toggleWidget,
          height: 360,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            reverseDuration: const Duration(milliseconds: 100),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _showGross ? grossContent : rwaContent,
          ),
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 45,
              child: activeChart,
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 55,
              child: donutChart,
            ),
          ],
        );
      },
    );
  }
}
