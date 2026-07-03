import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../../expositions/models/exposition_models.dart';
import '../models/rwa_credit_analysis.dart';
import '../widgets/densite_rwa_gauge_card.dart';

const double _pageRadius = 8;
const Color _deepBlue = Color(0xFF001F4E);
const Color _blue700 = Color(0xFF0B4DBA);
const Color _ink = Color(0xFF0F1B3D);
const Color _muted = Color(0xFF62708C);
const Color _line = Color(0xFFDCE4F2);
const Color _soft = Color(0xFFF7F9FD);
const List<Color> _agentPalette = [
  Color(0xFF0B4DBA),
  Color(0xFF2F9E62),
  Color(0xFFF3B11F),
  Color(0xFF7662B7),
  Color(0xFF1595B6),
];

/// Regroupe les données nécessaires à l'écran : le module d'expositions (pour
/// l'état vide et l'en-tête) et l'analyse RWA Crédit agrégée côté backend.
class _RwaEngineData {
  const _RwaEngineData({required this.module, required this.analysis});

  final ExposureModuleData module;
  final RwaCreditAnalysis analysis;
}

class RwaEngineScreen extends StatefulWidget {
  const RwaEngineScreen({super.key, required this.api});

  final RwaApiService api;

  @override
  State<RwaEngineScreen> createState() => _RwaEngineScreenState();
}

class _RwaEngineScreenState extends State<RwaEngineScreen> {
  late Future<_RwaEngineData> _future;
  StreamSubscription<int>? _refreshSubscription;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _refreshSubscription = widget.api.portfolioRefreshStream.listen((_) {
      if (!mounted) return;
      setState(() => _future = _load());
    });
  }

  Future<_RwaEngineData> _load() async {
    final module = await widget.api.fetchExpositionsModule();
    final analysis = await widget.api.fetchRwaCreditAnalysis();
    return _RwaEngineData(module: module, analysis: analysis);
  }

  @override
  void dispose() {
    _refreshSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RwaEngineData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final data = snapshot.data;
        if (data == null ||
            data.module.exposures.isEmpty ||
            data.analysis.isEmpty) {
          return const _EngineEmptyState();
        }

        final view = _RwaPilotageView.from(data.module.exposures);
        final analysis = data.analysis;

        return Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 5, 8, 0),
                child: _PilotageHeader(view: view),
              ),
              _PilotageTabs(
                selectedIndex: _selectedTab,
                onChanged: (index) => setState(() => _selectedTab = index),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                  child: switch (_selectedTab) {
                    0 => _AnalysisRwaTab(analysis: analysis, view: view),
                    1 => const _RiskAppetiteTab(animation: AlwaysStoppedAnimation(1.0)),
                    _ => const _RegulatoryWeightingTab(),
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RwaPilotageView {
  const _RwaPilotageView({
    required this.currentRows,
    required this.referenceDate,
    required this.totalGross,
    required this.totalEad,
    required this.totalRwa,
    required this.monthlyVariation,
    required this.annualVariation,
    required this.agentRows,
    required this.dominantAgent,
    required this.dominantEntities,
    required this.dominantFactors,
  });

  final List<ExposureRecord> currentRows;
  final DateTime referenceDate;
  final double totalGross;
  final double totalEad;
  final double totalRwa;
  final double? monthlyVariation;
  final double? annualVariation;
  final List<_AgentRwaRow> agentRows;
  final _AgentRwaRow dominantAgent;
  final List<_DominantEntityRow> dominantEntities;
  final List<String> dominantFactors;

  factory _RwaPilotageView.from(List<ExposureRecord> exposures) {
    final latest = exposures
        .map((item) => DateUtils.dateOnly(item.analysisDate))
        .reduce((left, right) => left.isAfter(right) ? left : right);
    final currentRows = exposures
        .where((item) => DateUtils.isSameDay(item.analysisDate, latest))
        .toList(growable: false);
    final effectiveRows =
        currentRows.isEmpty ? exposures.toList(growable: false) : currentRows;

    final totalGross =
        effectiveRows.fold<double>(0, (sum, item) => sum + item.grossAmount);
    final totalEad =
        effectiveRows.fold<double>(0, (sum, item) => sum + item.ead);
    final totalRwa =
        effectiveRows.fold<double>(0, (sum, item) => sum + item.rwa);
    final agentMap = <String, _AgentAccumulator>{};
    for (final item in effectiveRows) {
      agentMap
          .putIfAbsent(
            item.categoryLabel,
            () => _AgentAccumulator(label: item.categoryLabel),
          )
          .add(item);
    }

    var agentRows = agentMap.values
        .map((item) => item.toRow(totalRwa))
        .toList(growable: false)
      ..sort((left, right) => right.rwa.compareTo(left.rwa));
    if (agentRows.isEmpty) {
      agentRows = [
        const _AgentRwaRow(
          label: 'Non renseigné',
          count: 0,
          exposure: 0,
          ead: 0,
          rwa: 0,
          averageRw: 0,
          crmCoverage: 0,
          defaultCount: 0,
          share: 0,
        ),
      ];
    }

    final dominantAgent = agentRows.first;
    final dominantRows = effectiveRows
        .where((item) => item.categoryLabel == dominantAgent.label)
        .toList(growable: false);
    final entityMap = <String, _EntityAccumulator>{};
    for (final item in dominantRows) {
      entityMap
          .putIfAbsent(
            item.counterparty.name.trim().isEmpty
                ? 'Contrepartie non renseignée'
                : item.counterparty.name.trim(),
            () => _EntityAccumulator(
              name: item.counterparty.name.trim().isEmpty
                  ? 'Contrepartie non renseignée'
                  : item.counterparty.name.trim(),
              sector: _sectorForExposure(item),
            ),
          )
          .add(item);
    }
    final dominantEntities = entityMap.values
        .map((item) => item.toRow(dominantAgent.rwa))
        .toList(growable: false)
      ..sort((left, right) => right.exposure.compareTo(left.exposure));

    final monthBase = _snapshotRwaBefore(
      exposures,
      DateTime(latest.year, latest.month, 1),
    );
    final yearBase = _snapshotRwaBefore(
      exposures,
      DateTime(latest.year, 1, 1),
    );

    return _RwaPilotageView(
      currentRows: effectiveRows,
      referenceDate: latest,
      totalGross: totalGross,
      totalEad: totalEad,
      totalRwa: totalRwa,
      monthlyVariation: _variation(totalRwa, monthBase),
      annualVariation: _variation(totalRwa, yearBase),
      agentRows: agentRows,
      dominantAgent: dominantAgent,
      dominantEntities: dominantEntities.take(5).toList(growable: false),
      dominantFactors: _dominantFactors(
        dominantAgent,
        dominantEntities.take(5).toList(growable: false),
        totalGross,
      ),
    );
  }
}

class _AgentAccumulator {
  _AgentAccumulator({required this.label});

  final String label;
  var count = 0;
  var exposure = 0.0;
  var ead = 0.0;
  var rwa = 0.0;
  var coveredExposure = 0.0;
  var defaultCount = 0;

  void add(ExposureRecord item) {
    count += 1;
    exposure += item.grossAmount;
    ead += item.ead;
    rwa += item.rwa;
    coveredExposure += item.grossAmount * item.crmCoveragePercent.clamp(0, 1);
    if (item.isDefaultLike) {
      defaultCount += 1;
    }
  }

  _AgentRwaRow toRow(double totalRwa) {
    return _AgentRwaRow(
      label: label,
      count: count,
      exposure: exposure,
      ead: ead,
      rwa: rwa,
      averageRw: ead <= 0 ? 0 : rwa / ead,
      crmCoverage: exposure <= 0 ? 0 : coveredExposure / exposure,
      defaultCount: defaultCount,
      share: totalRwa <= 0 ? 0 : rwa / totalRwa,
    );
  }
}

class _AgentRwaRow {
  const _AgentRwaRow({
    required this.label,
    required this.count,
    required this.exposure,
    required this.ead,
    required this.rwa,
    required this.averageRw,
    required this.crmCoverage,
    required this.defaultCount,
    required this.share,
  });

  final String label;
  final int count;
  final double exposure;
  final double ead;
  final double rwa;
  final double averageRw;
  final double crmCoverage;
  final int defaultCount;
  final double share;
}

class _EntityAccumulator {
  _EntityAccumulator({required this.name, required this.sector});

  final String name;
  String sector;
  var exposure = 0.0;
  var rwa = 0.0;

  void add(ExposureRecord item) {
    exposure += item.grossAmount;
    rwa += item.rwa;
    if (sector == 'Non renseigné') {
      sector = _sectorForExposure(item);
    }
  }

  _DominantEntityRow toRow(double dominantRwa) {
    return _DominantEntityRow(
      name: name,
      sector: sector,
      exposure: exposure,
      rwa: rwa,
      share: dominantRwa <= 0 ? 0 : rwa / dominantRwa,
    );
  }
}

class _DominantEntityRow {
  const _DominantEntityRow({
    required this.name,
    required this.sector,
    required this.exposure,
    required this.rwa,
    required this.share,
  });

  final String name;
  final String sector;
  final double exposure;
  final double rwa;
  final double share;
}

class _PilotageHeader extends StatelessWidget {
  const _PilotageHeader({required this.view});

  final _RwaPilotageView view;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pilotage RWA Crédit',
              textAlign: TextAlign.left,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: _ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Suivi des expositions pondérées et du capital réglementaire.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceDateBadge extends StatelessWidget {
  const _ReferenceDateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _blue700.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.calendar, color: Colors.white, size: 15),
          const SizedBox(width: 9),
          Text(
            'Date de référence : ${AppFormatters.shortDate(date)}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
          ),
        ],
      ),
    );
  }
}

class _PilotageTabs extends StatelessWidget {
  const _PilotageTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const _tabs = [
    'Analyse RWA Crédit',
    'Alertes et décisions',
    'Pondération réglementaire',
  ];

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.75);

    return SizedBox(
      width: double.infinity,
      height: 38,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(width: 8),
            for (var index = 0; index < _tabs.length; index++)
              _PilotageTabButton(
                label: _tabs[index],
                selected: selectedIndex == index,
                onTap: () => onChanged(index),
              ),
          ],
        ),
      ),
    );
  }
}

class _PilotageTabButton extends StatelessWidget {
  const _PilotageTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? _deepBlue
        : _deepBlue.withValues(alpha: 0.76);

    return SizedBox(
      width: label.startsWith('Analyse')
          ? 170
          : label.startsWith('Alertes')
              ? 165
              : 195,
      height: double.infinity,
      child: InkWell(
        onTap: onTap,
        splashColor: _deepBlue.withValues(alpha: 0.06),
        highlightColor: _deepBlue.withValues(alpha: 0.035),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? _deepBlue : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontSize: 12.8,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  height: 1,
                ),
          ),
        ),
      ),
    );
  }
}

class _AnalysisRwaTab extends StatelessWidget {
  const _AnalysisRwaTab({required this.analysis, required this.view});

  final RwaCreditAnalysis analysis;
  final _RwaPilotageView view;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCardsRow(analysis: analysis),
        const SizedBox(height: 12),
        _AgentTablePanel(analysis: analysis, view: view),
      ],
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _blue700,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _SummaryCardsRow extends StatelessWidget {
  const _SummaryCardsRow({required this.analysis});

  final RwaCreditAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final ratioLabel = AppFormatters.percent(0.09); // Forced to 9% per user request
    final totals = analysis.totals;

    final cards = <Widget>[
      _SummaryCard(
        title: 'EXPOSITION EN CAS DE DÉFAUT',
        value: _formatMoney(totals.ead, maxDecimals: 2),
        subtitle: 'Montant exposé au risque',
      ),
      _SummaryCard(
        title: 'RWA CRÉDIT',
        value: _formatMoney(totals.rwa, maxDecimals: 2),
        subtitle: 'Actifs pondérés au risque',
      ),
      _SummaryCard(
        title: 'DENSITÉ RWA',
        value: AppFormatters.percent(analysis.densityRwa ?? 0),
        subtitle: 'RWA/EAD',
      ),
      _SummaryCard(
        title: 'CAPITAL REQUIS',
        value: _formatMoney(totals.rwa * 0.09, maxDecimals: 2),
        subtitle: 'RWA × $ratioLabel',
      ),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 12.0),
          Expanded(child: cards[1]),
          const SizedBox(width: 12.0),
          Expanded(child: cards[2]),
          const SizedBox(width: 12.0),
          Expanded(child: cards[3]),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatefulWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: _isHovered ? Colors.indigo.withOpacity(0.5) : _line,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                widget.title,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.indigo,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.4,
                    ),
              ),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, thickness: 1, color: _line.withOpacity(0.6)),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final match = RegExp(r'(\s*[A-Za-z%]+)$').firstMatch(widget.value);
                final baseStyle = Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: _ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    );

                Widget valueWidget;
                if (match != null) {
                  final unit = match.group(1)!;
                  final number = widget.value.substring(0, widget.value.length - unit.length);
                  valueWidget = RichText(
                    maxLines: 1,
                    text: TextSpan(
                      text: number,
                      style: baseStyle,
                      children: [
                        TextSpan(
                          text: unit,
                          style: baseStyle?.copyWith(
                            color: _muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  valueWidget = Text(
                    widget.value,
                    maxLines: 1,
                    style: baseStyle,
                  );
                }
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: valueWidget,
                );
              },
            ),
            const SizedBox(height: 10),
            if (widget.subtitle != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.subtitle!,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                ),
              ),
        ],
      ),
    ),
  );
}
}

class _AgentTablePanel extends StatelessWidget {
  const _AgentTablePanel({required this.analysis, required this.view});

  final RwaCreditAnalysis analysis;
  final _RwaPilotageView view;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'DÉCOMPOSITION DES RWA PAR AGENT ÉCONOMIQUE',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _blue700,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0,
                ),
          ),
          const SizedBox(height: 12),
          _AgentBreakdownSection(analysis: analysis, view: view),
        ],
      ),
    );
  }
}

class _VariationBadge extends StatelessWidget {
  const _VariationBadge({
    required this.label,
    required this.value,
  });

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final variation = value;
    final isPositive = variation == null || variation >= 0;
    final color = variation == null
        ? _muted
        : isPositive
            ? AppColors.success
            : AppColors.danger;
    final icon = variation == null
        ? CupertinoIcons.info_circle_fill
        : isPositive
            ? CupertinoIcons.arrow_up_right
            : CupertinoIcons.arrow_down_right;

    return Row(
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                variation == null ? 'N/D' : _formatSignedPercent(variation),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AgentBreakdownSection extends StatelessWidget {
  const _AgentBreakdownSection({required this.analysis, required this.view});

  final RwaCreditAnalysis analysis;
  final _RwaPilotageView view;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 60,
            child: _AgentContributionTable(
              agents: analysis.agents,
              totals: analysis.totals,
              reconciliationThreshold: analysis.reconciliationThreshold,
              view: view,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 40,
            child: DensiteRwaGaugeCard(
              density: analysis.densityRwa ?? 0.0,
              totalExposure: analysis.totals.exposureTotal,
              totalRwa: analysis.totals.rwa,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentDonutPanel extends StatelessWidget {
  const _AgentDonutPanel({required this.view});

  final _RwaPilotageView view;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 284,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(_pageRadius),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: SizedBox(
                width: 224,
                height: 224,
                child: CustomPaint(
                  painter: _AgentDonutPainter(rows: view.agentRows),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'RWA CRÉDIT',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: _deepBlue,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatMoneyValue(view.totalRwa),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: _deepBlue,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                        ),
                        Text(
                          _formatMoneyUnit(view.totalRwa),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: _blue700,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 220,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < view.agentRows.length; index++)
                  _AgentLegendItem(
                    row: view.agentRows[index],
                    color: _agentPalette[index % _agentPalette.length],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentLegendItem extends StatelessWidget {
  const _AgentLegendItem({
    required this.row,
    required this.color,
  });

  final _AgentRwaRow row;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              row.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            AppFormatters.percent(row.share),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _deepBlue,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

enum _AgentSortKey { exposure, rwa, weight, capital, contribution, variation }

const double _agentNumWidth = 40;
const Color _weightAlertBg = Color(0xFFFBE7D2);
const Color _weightAlertFg = Color(0xFF8A5A00);

class _AgentContributionTable extends StatefulWidget {
  const _AgentContributionTable({
    required this.agents,
    required this.totals,
    required this.reconciliationThreshold,
    required this.view,
  });

  final List<RwaCreditAgentRow> agents;
  final RwaCreditTotals totals;
  final _RwaPilotageView view;

  /// Seuil de tolérance (ratio) du contrôle de réconciliation (backend).
  final double reconciliationThreshold;

  @override
  State<_AgentContributionTable> createState() =>
      _AgentContributionTableState();
}

class _AgentContributionTableState extends State<_AgentContributionTable> {
  _AgentSortKey _sortKey = _AgentSortKey.rwa;
  bool _ascending = false;
  final Set<String> _expanded = <String>{};

  double _valueFor(RwaCreditAgentRow row, _AgentSortKey key) {
    switch (key) {
      case _AgentSortKey.exposure:
        return row.exposureTotal;
      case _AgentSortKey.rwa:
        return row.rwa;
      case _AgentSortKey.weight:
        return row.averageWeight ?? 0;
      case _AgentSortKey.capital:
        return row.capitalRequired;
      case _AgentSortKey.contribution:
        return row.contribution;
      case _AgentSortKey.variation:
        return row.rwaVariation?.percent ?? 0;
    }
  }

  List<RwaCreditAgentRow> get _sortedRows {
    final list = [...widget.agents];
    list.sort((a, b) {
      final result = _valueFor(a, _sortKey).compareTo(_valueFor(b, _sortKey));
      return _ascending ? result : -result;
    });
    return list;
  }

  void _sort(_AgentSortKey key) {
    setState(() {
      if (_sortKey == key) {
        _ascending = !_ascending;
      } else {
        _sortKey = key;
        _ascending = false;
      }
    });
  }

  // Toggle state is no longer needed since we open a dialog

  @override
  Widget build(BuildContext context) {
    final rows = _sortedRows;
    final tableRwa =
        widget.agents.fold<double>(0, (sum, item) => sum + item.rwa);
    final cardRwa = widget.totals.rwa;
    final reconciliationGap =
        cardRwa <= 0 ? 0.0 : (tableRwa - cardRwa).abs() / cardRwa;
    final showWarning = reconciliationGap > widget.reconciliationThreshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 320,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: _line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < rows.length; index++)
                        _buildDataRow(context, index, rows[index]),
                    ],
                  ),
                ),
              ),
              _buildTotalRow(context),
            ],
          ),
        ),
        if (showWarning) ...[
          const SizedBox(height: 8),
          Text(
            'Avertissement : le total RWA du tableau '
            '(${_formatMoney(tableRwa, maxDecimals: 0)}) diffère de la valeur de la '
            'carte RWA Crédit (${_formatMoney(cardRwa, maxDecimals: 0)}) de '
            '${AppFormatters.percent(reconciliationGap)}, au-delà du seuil de '
            'tolérance de ${AppFormatters.percent(widget.reconciliationThreshold)}. '
            'Vérifier la cohérence des données.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _deepBlue,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
          ),
        ],
      ],
    );
  }

  Widget _separator() => Container(width: 0.5, color: _line);

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _deepBlue,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: _agentNumWidth,
              padding: const EdgeInsets.only(left: 12, top: 9, bottom: 9),
              alignment: Alignment.centerLeft,
              child: const _TableHeaderText('N°'),
            ),
            _separator(),
            const Expanded(
              flex: 28,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: _TableHeaderText('Agent économique'),
              ),
            ),
            _separator(),
            _sortableHeader('Exposition totale', 14, _AgentSortKey.exposure,
                tooltip:
                    'EAD : Exposure at Default, exposition en cas de défaut'),
            _separator(),
            _sortableHeader('RWA', 13, _AgentSortKey.rwa,
                tooltip:
                    'RWA : Risk Weighted Assets, actifs pondérés par les risques'),
            _separator(),
            _sortableHeader('Capital requis', 14, _AgentSortKey.capital,
                tooltip: 'RWA × taux minimum réglementaire'),
            _separator(),
            _sortableHeader('Contribution', 17, _AgentSortKey.contribution,
                alignRight: true, tooltip: 'Contribution au RWA total'),
          ],
        ),
      ),
    );
  }

  Widget _sortableHeader(
    String label,
    int flex,
    _AgentSortKey key, {
    bool alignRight = false,
    String? tooltip,
  }) {
    final active = _sortKey == key;
    final suffix = active ? (_ascending ? ' ▴' : ' ▾') : '';
    final text = _TableHeaderText('$label$suffix', alignRight: alignRight);
    return Expanded(
      flex: flex,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _sort(key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
            child: text,
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, int index, RwaCreditAgentRow row) {
    final tranches = row.tranches ?? const [];
    final labelStyle = Theme.of(context)
        .textTheme
        .labelMedium
        ?.copyWith(height: 1.25, fontSize: 11);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: index.isOdd ? const Color(0xFFF8FAFC) : Colors.white,
          child: InkWell(
            onTap: tranches.isEmpty ? null : () => _showTrancheDetail(context, row, tranches),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: _agentNumWidth,
                    padding: const EdgeInsets.only(left: 12, top: 9, bottom: 9),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      (index + 1).toString().padLeft(2, '0'),
                      style: labelStyle?.copyWith(
                        color: _muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _separator(),
                  Expanded(
                    flex: 28,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 9),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        row.label,
                        softWrap: true,
                        style: labelStyle?.copyWith(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  _separator(),
                  _numericCell(_formatMoney(row.exposureTotal, maxDecimals: 0), 14,
                      FontWeight.w700),
                  _separator(),
                  _numericCell(
                      _formatMoney(row.rwa, maxDecimals: 0), 13, FontWeight.w900),
                  _separator(),
                  _numericCell(_formatMoney(row.capitalRequired, maxDecimals: 0), 14,
                      FontWeight.w700),
                  _separator(),
                  _contributionCell(context, row),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _numericCell(
    String text,
    int flex,
    FontWeight weight, {
    bool alignRight = false,
    Color color = _deepBlue,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          text,
          softWrap: true,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: weight,
                height: 1.25,
                fontSize: 11,
              ),
        ),
      ),
    );
  }



  Widget _contributionCell(BuildContext context, RwaCreditAgentRow row) {
    return Expanded(
      flex: 17,
      child: Container(
        padding: const EdgeInsets.only(right: 14, left: 10, top: 9, bottom: 9),
        alignment: Alignment.centerRight,
        child: Text(
          AppFormatters.percent(row.contribution),
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: _deepBlue,
                fontWeight: FontWeight.w900,
                height: 1.1,
                fontSize: 11,
              ),
        ),
      ),
    );
  }


  void _showTrancheDetail(
    BuildContext context,
    RwaCreditAgentRow row,
    List<RwaCreditTranche> tranches,
  ) {
    // Extract real exposures for this agent
    final agentExposures = widget.view.currentRows
        .where((e) {
          String normalize(String s) {
            return s.trim().toLowerCase()
                .replaceAll(RegExp(r'[éèêë]'), 'e')
                .replaceAll(RegExp(r'[àâä]'), 'a')
                .replaceAll(RegExp(r'[îï]'), 'i')
                .replaceAll(RegExp(r'[ôö]'), 'o')
                .replaceAll(RegExp(r'[ùûü]'), 'u')
                .replaceAll(RegExp(r'[ç]'), 'c')
                .replaceAll(RegExp(r'\s+'), ' ');
          }
          final normalizedModelLabel = normalize(e.categoryOption.label);
          final normalizedRowLabel = normalize(row.label);
          return normalizedModelLabel == normalizedRowLabel;
        })
        .toList(growable: false);

    // Group by counterparty
    final counterpartyMap = <String, _RealCounterpartyAccumulator>{};
    for (final exp in agentExposures) {
      final cpName = exp.counterparty.name.trim().isEmpty
          ? 'Contrepartie non renseignée'
          : exp.counterparty.name.trim();
      counterpartyMap.putIfAbsent(cpName, () => _RealCounterpartyAccumulator(name: cpName)).add(exp);
    }

    // Convert to _RealCounterparty and sort by exposure
    final allCounterparties = counterpartyMap.values
        .map((acc) => acc.toRealCounterparty(row.exposureTotal))
        .toList(growable: false)
      ..sort((a, b) => b.exposure.compareTo(a.exposure));

    showDialog(
      context: context,
      builder: (context) {
        bool showAll = false;
        int? selectedIndex;
        final headerStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            );
        return StatefulBuilder(
          builder: (context, setState) {
            final top5 = showAll ? allCounterparties : allCounterparties.take(5).toList();
            final totalEad = top5.fold<double>(0, (s, t) => s + t.exposure);
            final totalRwa = top5.fold<double>(0, (s, t) => s + t.rwa);
            final totalCap = top5.fold<double>(0, (s, t) => s + t.capitalRequired);
            final totalPct = top5.fold<double>(0, (s, t) => s + t.percentage);

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: 1200,
                height: 700,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            showAll ? 'TOUTES LES CONTREPARTIES - ${row.label.toUpperCase()}' : 'TOP 5 DES CONTREPARTIES - ${row.label.toUpperCase()}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: _blue700,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => showAll = !showAll),
                          style: TextButton.styleFrom(
                            backgroundColor: _deepBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          child: Text(showAll ? 'Voir le top 5' : 'Voir tout'),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, color: _muted),
                          onPressed: () => Navigator.of(context).pop(),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Builder(
                      builder: (context) {
                        if (allCounterparties.isEmpty) {
                          return Container(
                            height: 250,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(color: _line, width: 1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.info_outline, size: 48, color: _muted),
                                const SizedBox(height: 16),
                                Text(
                                  'Aucune exposition détaillée disponible pour cette catégorie.',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: _muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final rowContent = Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                    Expanded(
                      flex: 5,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: _line, width: 1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                color: _deepBlue,
                              ),
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: Text('Contrepartie', style: headerStyle)),
                                Expanded(flex: 2, child: Text('Exposition', style: headerStyle)),
                                Expanded(flex: 2, child: Text('RWA', style: headerStyle)),
                                Expanded(flex: 2, child: Text('Cap. Requis', style: headerStyle)),
                                Expanded(flex: 2, child: Text('%', style: headerStyle, textAlign: TextAlign.right)),
                              ],
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              final rows = <Widget>[
                                for (var i = 0; i < top5.length; i++)
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            selectedIndex = selectedIndex == i ? null : i;
                                          });
                                        },
                                        child: Container(
                                          color: selectedIndex == i
                                              ? Colors.green.withOpacity(0.15)
                                              : (i % 2 == 0 ? Colors.transparent : const Color(0xFFF1F5F9)), // Alternating row color
                                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                          child: Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                top5[i].name,
                                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                      color: _ink,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _formatMoney(top5[i].exposure, maxDecimals: 0),
                                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                      color: _deepBlue,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _formatMoney(top5[i].rwa, maxDecimals: 0),
                                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                      color: _deepBlue,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                _formatMoney(top5[i].capitalRequired, maxDecimals: 0),
                                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                      color: _muted,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                AppFormatters.percent(top5[i].percentage),
                                                textAlign: TextAlign.right,
                                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                      color: _blue700,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ),
                                    ],
                                  ),
                          ];
                          return showAll
                              ? Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: rows,
                                    ),
                                  ),
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: rows,
                                );
                            },
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E3A5F),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    showAll ? 'TOTAL' : 'TOTAL TOP 5',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _formatMoney(totalEad, maxDecimals: 0),
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _formatMoney(totalRwa, maxDecimals: 0),
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _formatMoney(totalCap, maxDecimals: 0),
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    AppFormatters.percent(totalPct),
                                    textAlign: TextAlign.right,
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      ),
                    ),
                    if (!showAll) const SizedBox(width: 32),
                    if (!showAll)
                      Expanded(
                        flex: 5,
                        child: Container(
                          padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: _line, width: 1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: _TopExposuresChart(
                                  top5: top5,
                                  selectedIndex: selectedIndex,
                                  onSelect: (index) {
                                    setState(() => selectedIndex = index);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
                return showAll ? Expanded(child: rowContent) : IntrinsicHeight(child: rowContent);
              },
            ),
          ),
        ],
      ),
          ),
        );
          },
        );
      },
    );
  }

  Widget _buildTotalRow(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: _deepBlue,
          fontWeight: FontWeight.w900,
          height: 1.25,
          fontSize: 11,
        );
    Widget cell(int flex, String text, {bool alignRight = false}) {
      return Expanded(
        flex: flex,
        child: Container(
          padding: EdgeInsets.only(
              right: alignRight ? 14 : 10, left: 10, top: 11, bottom: 11),
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(text,
              textAlign: alignRight ? TextAlign.right : TextAlign.left,
              style: labelStyle),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFEDF2FA),
        border: Border(top: BorderSide(color: _line)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: _agentNumWidth,
              padding: const EdgeInsets.only(left: 12, top: 11, bottom: 11),
            ),
            _separator(),
            cell(28, 'Total'),
            _separator(),
            cell(14, _formatMoney(widget.totals.exposureTotal, maxDecimals: 0)),
            _separator(),
            cell(13, _formatMoney(widget.totals.rwa, maxDecimals: 0)),
            _separator(),
            cell(14, _formatMoney(widget.totals.capitalRequired, maxDecimals: 0)),
            _separator(),
            cell(17, AppFormatters.percent(1), alignRight: true),
          ],
        ),
      ),
    );
  }
}

class _RealCounterpartyAccumulator {
  _RealCounterpartyAccumulator({required this.name});
  final String name;
  double exposure = 0;
  double rwa = 0;
  double capital = 0;

  void add(ExposureRecord record) {
    exposure += record.ead; // Using EAD for exposure like the rest of the engine
    rwa += record.rwa;
    capital += record.capital;
  }

  _RealCounterparty toRealCounterparty(double totalAgentExposure) {
    return _RealCounterparty(
      name,
      exposure,
      rwa,
      capital,
      totalAgentExposure > 0 ? exposure / totalAgentExposure : 0,
    );
  }
}

class _RealCounterparty {
  final String name;
  final double exposure;
  final double rwa;
  final double capitalRequired;
  final double percentage;

  _RealCounterparty(this.name, this.exposure, this.rwa, this.capitalRequired, this.percentage);
}

class _DominantAgentSection extends StatelessWidget {
  const _DominantAgentSection({required this.view});

  final _RwaPilotageView view;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 900;
            final summary = _DominantSummaryCard(row: view.dominantAgent);
            final factors = _DominantFactorsCard(factors: view.dominantFactors);
            if (narrow) {
              return Column(
                children: [
                  summary,
                  const SizedBox(height: 10),
                  factors,
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 38, child: summary),
                  const SizedBox(width: 12),
                  Expanded(flex: 62, child: factors),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Text(
          'TOP 5 DES ENTITÉS LES PLUS EXPOSÉES',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: _blue700,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Classement limité à l’agent économique dominant : ${view.dominantAgent.label}.',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: _muted,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 1080;
            final table = _DominantTopTable(rows: view.dominantEntities);
            final chart = _DominantTopBarChart(rows: view.dominantEntities);
            if (narrow) {
              return Column(
                children: [
                  table,
                  const SizedBox(height: 12),
                  chart,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 58, child: table),
                const SizedBox(width: 14),
                Expanded(flex: 42, child: chart),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DominantSummaryCard extends StatelessWidget {
  const _DominantSummaryCard({required this.row});

  final _AgentRwaRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(_pageRadius),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _deepBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(_pageRadius),
            ),
            child: const Icon(
              CupertinoIcons.building_2_fill,
              color: _deepBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agent économique dominant',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: _deepBlue,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 9),
                Text(
                  row.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _blue700,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                ),
                const SizedBox(height: 12),
                _MetricLine(label: 'RWA associé', value: _formatMoney(row.rwa)),
                const SizedBox(height: 7),
                _MetricLine(
                  label: 'Contribution au RWA total',
                  value: AppFormatters.percent(row.share),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: _deepBlue,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: _blue700,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _DominantFactorsCard extends StatelessWidget {
  const _DominantFactorsCard({required this.factors});

  final List<String> factors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_pageRadius),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Facteurs explicatifs',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _deepBlue,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final factor in factors) _FactorChip(label: factor),
            ],
          ),
        ],
      ),
    );
  }
}

class _FactorChip extends StatelessWidget {
  const _FactorChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _blue700.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(_pageRadius),
        border: Border.all(color: _blue700.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: _deepBlue,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _DominantTopTable extends StatelessWidget {
  const _DominantTopTable({required this.rows});

  final List<_DominantEntityRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_pageRadius),
        border: Border.all(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 720,
          child: Column(
            children: [
              Container(
                color: _soft,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: const Row(
                  children: [
                    _TopHeaderCell('Rang', flex: 9),
                    _TopHeaderCell('Entité', flex: 28),
                    _TopHeaderCell('Secteur', flex: 20),
                    _TopHeaderCell('Exposition', flex: 17),
                    _TopHeaderCell('RWA', flex: 15),
                    _TopHeaderCell('%', flex: 11, alignRight: true),
                  ],
                ),
              ),
              for (var index = 0; index < rows.length; index++)
                _DominantTopTableRow(
                  rank: index + 1,
                  row: rows[index],
                ),
              Container(
                color: _soft,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 57,
                      child: Text(
                        'Total Top 5',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: _deepBlue,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    Expanded(
                      flex: 17,
                      child: Text(
                        _formatMoney(
                          rows.fold<double>(
                            0,
                            (sum, item) => sum + item.exposure,
                          ),
                        ),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: _deepBlue,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    Expanded(
                      flex: 15,
                      child: Text(
                        _formatMoney(
                          rows.fold<double>(0, (sum, item) => sum + item.rwa),
                        ),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: _deepBlue,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    Expanded(
                      flex: 11,
                      child: Text(
                        AppFormatters.percent(
                          rows.fold<double>(
                            0,
                            (sum, item) => sum + item.share,
                          ),
                        ),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: _blue700,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopHeaderCell extends StatelessWidget {
  const _TopHeaderCell(
    this.label, {
    required this.flex,
    this.alignRight = false,
  });

  final String label;
  final int flex;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _deepBlue,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _DominantTopTableRow extends StatelessWidget {
  const _DominantTopTableRow({
    required this.rank,
    required this.row,
  });

  final int rank;
  final _DominantEntityRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          _TopValueCell('$rank', flex: 9),
          _TopValueCell(row.name, flex: 28),
          _TopValueCell(row.sector, flex: 20),
          _TopValueCell(_formatMoney(row.exposure), flex: 17),
          _TopValueCell(_formatMoney(row.rwa), flex: 15),
          _TopValueCell(
            AppFormatters.percent(row.share),
            flex: 11,
            alignRight: true,
            strong: true,
          ),
        ],
      ),
    );
  }
}

class _TopValueCell extends StatelessWidget {
  const _TopValueCell(
    this.value, {
    required this.flex,
    this.alignRight = false,
    this.strong = false,
  });

  final String value;
  final int flex;
  final bool alignRight;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: strong ? _blue700 : _ink,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
      ),
    );
  }
}

class _DominantTopBarChart extends StatelessWidget {
  const _DominantTopBarChart({required this.rows});

  final List<_DominantEntityRow> rows;

  @override
  Widget build(BuildContext context) {
    final maxRwa = rows.fold<double>(
      0,
      (current, item) => math.max(current, item.rwa),
    );
    return Container(
      height: 286,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(_pageRadius),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bar Chart horizontal - RWA du Top 5',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _deepBlue,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final row in rows)
                  _HorizontalBarLine(
                    label: row.name,
                    value: row.rwa,
                    ratio: maxRwa <= 0 ? 0 : row.rwa / maxRwa,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalBarLine extends StatelessWidget {
  const _HorizontalBarLine({
    required this.label,
    required this.value,
    required this.ratio,
  });

  final String label;
  final double value;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 118,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _deepBlue,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _line),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    width: constraints.maxWidth * ratio.clamp(0.03, 1.0),
                    height: 14,
                    decoration: BoxDecoration(
                      color: _blue700,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 86,
          child: Text(
            _formatMoney(value),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _deepBlue,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      ],
    );
  }
}

class _RiskAppetiteTab extends StatelessWidget {
  const _RiskAppetiteTab({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 560),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_pageRadius),
        border: Border.all(color: _line),
        boxShadow: _cardShadow,
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final pulse = 0.96 + (animation.value * 0.05);
            return Transform.scale(
              scale: pulse,
              child: child,
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              Text(
                'APPÉTENCE AUX RISQUES DE LA BANQUE',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: _deepBlue,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
              ),

              const SizedBox(height: 24),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PulseDot(active: true),
                  SizedBox(width: 7),
                  _PulseDot(active: false),
                  SizedBox(width: 7),
                  _PulseDot(active: false),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: active ? 9 : 7,
      height: active ? 9 : 7,
      decoration: BoxDecoration(
        color: active ? _blue700 : _blue700.withValues(alpha: 0.32),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _RegulatoryWeightingTab extends StatelessWidget {
  const _RegulatoryWeightingTab();

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title:
          'ARCHITECTURE DE CALCUL DES RWA (CRÉDIT)',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 1040;
          const diagram = _RegulatoryDiagram();
          const sidePanel = _RegulatorySidePanel();

          if (narrow) {
            return const Column(
              children: [
                diagram,
                SizedBox(height: 12),
                sidePanel,
              ],
            );
          }

          return const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: diagram),
              SizedBox(width: 18),
              SizedBox(width: 330, child: sidePanel),
            ],
          );
        },
      ),
    );
  }
}

class _RegulatoryDiagram extends StatelessWidget {
  const _RegulatoryDiagram();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_pageRadius),
        border: Border.all(color: _line),
      ),
      child: const Column(
        children: [
          _RegulationStepCard(
            step: '1',
            title: 'Exposition au risque de crédit (EAD)',
            description:
                'Montant exposé après prise en compte des expositions au bilan et hors bilan.',
          ),
          _DownArrow(),
          _RegulationStepCard(
            step: '2',
            title: 'Pondération réglementaire (Risk Weight)',
            description:
                'La pondération dépend de la catégorie d’exposition et des exigences prudentielles.',
          ),
          _DownArrow(),
          _RegulatorySubSteps(),
          _DownArrow(),
          _RegulationStepCard(
            step: '4',
            title: 'Calcul du RWA Crédit',
            description: 'RWA = EAD × Pondération réglementaire ± Ajustements',
          ),
          _DownArrow(),
          _RegulationStepCard(
            step: '5',
            title: 'Taux réglementaire',
            description: '9 %',
            compactValue: true,
          ),
          _DownArrow(),
          _RegulationStepCard(
            step: '6',
            title: 'Capital requis',
            description: 'Capital requis = RWA Crédit × 9 %',
            finalStep: true,
          ),
        ],
      ),
    );
  }
}

class _RegulatorySubSteps extends StatelessWidget {
  const _RegulatorySubSteps();

  static const labels = [
    'Approche Standard',
    'Notations externes',
    'Techniques ARC',
    'Ajustements réglementaires',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 680;
        final cards = [
          for (final label in labels) _RegulatorySubCard(label: label),
        ];
        if (narrow) {
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: cards,
          );
        }
        return Row(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              Expanded(child: cards[index]),
              if (index < cards.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }
}

class _RegulatorySubCard extends StatelessWidget {
  const _RegulatorySubCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 78,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(_pageRadius),
        border: Border.all(color: _line),
        boxShadow: _innerShadow,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: _deepBlue,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
      ),
    );
  }
}

class _RegulationStepCard extends StatelessWidget {
  const _RegulationStepCard({
    required this.step,
    required this.title,
    required this.description,
    this.compactValue = false,
    this.finalStep = false,
  });

  final String step;
  final String title;
  final String description;
  final bool compactValue;
  final bool finalStep;

  @override
  Widget build(BuildContext context) {
    final color = finalStep ? AppColors.success : _deepBlue;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
      decoration: BoxDecoration(
        color: finalStep ? AppColors.success : Colors.white,
        borderRadius: BorderRadius.circular(_pageRadius),
        border: Border.all(
          color:
              finalStep ? AppColors.success : _blue700.withValues(alpha: 0.48),
        ),
        boxShadow: _innerShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  finalStep ? Colors.white.withValues(alpha: 0.18) : _deepBlue,
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: finalStep ? Colors.white : color,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 7),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: finalStep
                            ? Colors.white.withValues(alpha: 0.92)
                            : compactValue
                                ? _blue700
                                : _deepBlue,
                        fontSize: compactValue ? 20 : 12,
                        fontWeight:
                            compactValue ? FontWeight.w900 : FontWeight.w600,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DownArrow extends StatelessWidget {
  const _DownArrow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Container(width: 1.5, height: 20, color: _deepBlue),
          CustomPaint(
            size: const Size(12, 8),
            painter: _ArrowHeadPainter(),
          ),
        ],
      ),
    );
  }
}

class _ArrowHeadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _deepBlue
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RegulatorySidePanel extends StatelessWidget {
  const _RegulatorySidePanel();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _InfoListPanel(
          title: 'ELEMENTS CLES',
          items: [
            'EAD',
            'Pondération réglementaire',
            'Techniques d’atténuation du risque de crédit',
            'Garanties éligibles',
            'Expositions hors bilan',
            'Expositions en défaut',
          ],
        ),
        SizedBox(height: 14),
        _InfoListPanel(
          title: 'REFERENCES REGLEMENTAIRES',
          items: [
            'Dispositif prudentiel UMOA',
            'CRR',
            'CRR3',
            'Accords de Bâle',
          ],
        ),
      ],
    );
  }
}

class _InfoListPanel extends StatelessWidget {
  const _InfoListPanel({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(_pageRadius),
        border: Border.all(color: _blue700.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _blue700,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: const BoxDecoration(
                      color: _blue700,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _deepBlue,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AgentDonutPainter extends CustomPainter {
  const _AgentDonutPainter({required this.rows});

  final List<_AgentRwaRow> rows;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = radius * 0.28;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );
    final basePaint = Paint()
      ..color = _line
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - strokeWidth / 2, basePaint);

    var start = -math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    for (var index = 0; index < rows.length; index++) {
      final sweep = rows[index].share * math.pi * 2;
      if (sweep <= 0) continue;
      paint.color = _agentPalette[index % _agentPalette.length];
      canvas.drawArc(rect, start, sweep, false, paint);
      _paintDonutLabel(canvas, center, radius, start + sweep / 2,
          AppFormatters.percent(rows[index].share));
      start += sweep;
    }
  }

  void _paintDonutLabel(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    String label,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelRadius = radius * 0.76;
    final offset = Offset(
      center.dx + math.cos(angle) * labelRadius - textPainter.width / 2,
      center.dy + math.sin(angle) * labelRadius - textPainter.height / 2,
    );
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _AgentDonutPainter oldDelegate) {
    return oldDelegate.rows != rows;
  }
}

class _TableHeaderText extends StatelessWidget {
  const _TableHeaderText(this.label, {this.alignRight = false});

  final String label;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 10,
          ),
    );
  }
}

class _EngineEmptyState extends StatelessWidget {
  const _EngineEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_pageRadius),
            border: Border.all(color: _line),
            boxShadow: _cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _blue700.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(_pageRadius),
                ),
                child: const Icon(
                  CupertinoIcons.chart_bar_alt_fill,
                  color: _blue700,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Aucune exposition chargée',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: _deepBlue,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'La page Pilotage RWA Crédit utilisera les expositions créées ou importées dans la section Expositions.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<BoxShadow> get _cardShadow => [
      BoxShadow(
        color: _deepBlue.withValues(alpha: 0.08),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ];

List<BoxShadow> get _innerShadow => [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.035),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];

String _economicAgentFor(ExposureRecord item) {
  final normalized = _normalize(item.categoryLabel);
  if (normalized.contains('entreprise')) {
    return 'Entreprises';
  }
  if (normalized.contains('detail') ||
      normalized.contains('particulier') ||
      normalized.contains('immo r')) {
    return 'Clientèle de détail';
  }
  if (normalized.contains('souverain') ||
      normalized.contains('organismes pub') ||
      normalized.contains('bmd') ||
      normalized.contains('administration')) {
    return 'Administrations publiques';
  }
  if (normalized.contains('institution') ||
      normalized.contains('banque') ||
      normalized.contains('etablissement')) {
    return 'Etablissements de crédit';
  }
  return 'Autres expositions';
}

String _sectorForExposure(ExposureRecord item) {
  final normalized = _normalize(item.categoryLabel);
  if (normalized.contains('souverain') ||
      normalized.contains('organismes pub')) {
    return 'Secteur public';
  }
  if (normalized.contains('institution')) {
    return 'Interbancaire';
  }
  if (normalized.contains('entreprise')) {
    return 'Corporate';
  }
  if (normalized.contains('detail')) {
    return 'Retail';
  }
  if (normalized.contains('immo')) {
    return 'Immobilier';
  }
  if (normalized.contains('souffrance')) {
    return 'Défaut';
  }
  return item.categoryLabel.trim().isEmpty
      ? 'Non renseigné'
      : item.categoryLabel;
}

String _normalize(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ô', 'o')
      .replaceAll('û', 'u')
      .replaceAll('ç', 'c');
}

double? _snapshotRwaBefore(List<ExposureRecord> exposures, DateTime date) {
  final eligible = exposures
      .where((item) => DateUtils.dateOnly(item.analysisDate).isBefore(date))
      .toList(growable: false);
  if (eligible.isEmpty) {
    return null;
  }
  final snapshotDate = eligible
      .map((item) => DateUtils.dateOnly(item.analysisDate))
      .reduce((left, right) => left.isAfter(right) ? left : right);
  return eligible
      .where((item) => DateUtils.isSameDay(item.analysisDate, snapshotDate))
      .fold<double>(0, (sum, item) => sum + item.rwa);
}

double? _variation(double current, double? previous) {
  if (previous == null || previous <= 0) {
    return null;
  }
  return (current - previous) / previous;
}

List<String> _dominantFactors(
  _AgentRwaRow agent,
  List<_DominantEntityRow> topEntities,
  double totalGross,
) {
  final topFiveRwaShare = topEntities.fold<double>(
    0,
    (sum, item) => sum + item.share,
  );
  return [
    if (totalGross <= 0 || agent.exposure / totalGross >= 0.30)
      'Encours importants',
    if (agent.averageRw >= 0.75) 'Pondérations réglementaires élevées',
    if (topFiveRwaShare >= 0.45 || agent.count <= 5)
      'Concentration sectorielle',
    if (agent.crmCoverage < 0.25) 'Faible niveau de garanties',
    if (agent.defaultCount > 0 || agent.averageRw >= 1.0)
      'Risque intrinsèque élevé',
    if (agent.averageRw < 0.75 && agent.defaultCount == 0)
      'Risque pondéré principalement par le volume',
  ].take(5).toList(growable: false);
}

String _formatMoney(double value, {int maxDecimals = 1}) {
  final unit = PortfolioAmountUnitPreference.current;
  final absValue = value.abs();

  // When unit is billions (Md) and value < 1Md
  if (unit == PortfolioAmountUnit.billion && absValue > 0 && absValue < unit.divisor) {
    // Show in millions
    final millionDivisor = PortfolioAmountUnit.million.divisor;
    if (absValue >= millionDivisor) {
      final scaled = value / millionDivisor;
      return '${AppFormatters.decimalNumber(scaled, maxDecimals: maxDecimals)}${PortfolioAmountUnit.million.label}';
    }
    // Below 1M: show the full value
    return AppFormatters.decimalNumber(value, maxDecimals: 0);
  }

  return '${_formatMoneyValue(value, maxDecimals: maxDecimals)}${_formatMoneyUnit(value)}';
}

String _formatMoneyValue(double value, {int maxDecimals = 1}) {
  final unit = PortfolioAmountUnitPreference.current;
  return AppFormatters.decimalNumber(value / unit.divisor, maxDecimals: maxDecimals);
}

String _formatMoneyUnit(double value) {
  final unit = PortfolioAmountUnitPreference.current;
  return unit.label;
}

String _formatMoneyShortUnit(double value) {
  final unit = PortfolioAmountUnitPreference.current;
  return unit.label;
}

String _formatSignedPercent(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${AppFormatters.percent(value)}';
}

/// Formate un montant en millions avec signe explicite (les négatifs portent
/// déjà leur « - » via le formateur).
String _signedMillions(double value) {
  final formatted = _formatMoney(value, maxDecimals: 0);
  return value > 0 ? '+$formatted' : formatted;
}

class _TopExposuresChart extends StatelessWidget {
  const _TopExposuresChart({required this.top5, this.selectedIndex, this.onSelect});
  final List<_RealCounterparty> top5;
  final int? selectedIndex;
  final ValueChanged<int?>? onSelect;

  @override
  Widget build(BuildContext context) {
    if (top5.isEmpty) return const SizedBox();
    return BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barTouchData: BarTouchData(
            enabled: true,
            touchCallback: (FlTouchEvent event, barTouchResponse) {
              if (event.runtimeType.toString().contains('TapUp') &&
                  barTouchResponse != null &&
                  barTouchResponse.spot != null) {
                final index = barTouchResponse.spot!.touchedBarGroupIndex;
                if (onSelect != null) {
                  onSelect!(selectedIndex == index ? null : index);
                }
              }
            },
            touchTooltipData: BarTouchTooltipData(
              tooltipBorderRadius: BorderRadius.circular(5),
              fitInsideHorizontally: true,
              fitInsideVertically: false,
              getTooltipColor: (group) => _deepBlue,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${top5[groupIndex].name} : ',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
                  children: <TextSpan>[
                    TextSpan(
                      text: '${rod.toY.toInt()}%',
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w400, fontSize: 10),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < top5.length) {
                    return SideTitleWidget(
                      meta: meta,
                      space: 16,
                      angle: -math.pi / 8,
                      child: Text(
                        top5[index].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    );
                  }
                  return const SizedBox();
                },
                reservedSize: 140,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                interval: 25,
                getTitlesWidget: (value, meta) {
                  return SideTitleWidget(
                    meta: meta,
                    space: 8,
                    child: Text(
                      '${value.toInt()}%',
                      style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.bold),
                      maxLines: 1,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: const Border(
              bottom: BorderSide(color: _line, width: 1.5),
              left: BorderSide(color: _line, width: 1.5),
              top: BorderSide(color: _line, width: 0.3),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (value) {
              return const FlLine(color: _line, strokeWidth: 0.3);
            },
          ),
          barGroups: top5.asMap().entries.map((e) {
            final isSelected = e.key == selectedIndex;
            return BarChartGroupData(
              x: e.key,
              showingTooltipIndicators: isSelected ? [0] : [],
              barRods: [
                BarChartRodData(
                  toY: e.value.percentage * 100,
                  color: isSelected ? Colors.green : _blue700,
                  width: 32,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                ),
              ],
            );
          }).toList(),
        ),
    );
  }
}
