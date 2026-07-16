import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../../expositions/models/exposition_models.dart';
import '../models/rwa_credit_analysis.dart';


const double _pageRadius = 3;
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
                child: switch (_selectedTab) {
                  0 => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                      child: _AnalysisRwaTab(analysis: analysis, view: view),
                    ),
                  1 => const SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(10, 10, 10, 12),
                      child: _RiskAppetiteTab(animation: AlwaysStoppedAnimation(1.0)),
                    ),
                  _ => const Padding(
                      padding: EdgeInsets.fromLTRB(10, 10, 10, 12),
                      child: _RegulatoryWeightingTab(),
                    ),
                },
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
        effectiveRows.fold<double>(0, (sum, item) => sum + item.grossAmountXof);
    final totalEad =
        effectiveRows.fold<double>(0, (sum, item) => sum + item.eadXof);
    final totalRwa =
        effectiveRows.fold<double>(0, (sum, item) => sum + item.rwaXof);
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
    exposure += item.grossAmountXof;
    ead += item.eadXof;
    rwa += item.rwaXof;
    coveredExposure += item.grossAmountXof * item.crmCoveragePercent.clamp(0, 1);
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
  var ead = 0.0;
  var rwa = 0.0;

  void add(ExposureRecord record) {
    exposure += record.grossAmountXof;
    ead += record.eadXof;
    rwa += record.rwaXof;
    if (sector == 'Non renseigné') {
      sector = _sectorForExposure(record);
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
    this.expandChild = false,
  });

  final String title;
  final Widget child;
  // Étire le contenu sur la hauteur disponible (requis quand le contenu gère
  // son propre défilement interne).
  final bool expandChild;

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
          if (expandChild) Expanded(child: child) else child,
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
            color: _isHovered ? Colors.indigo.withValues(alpha: 0.5) : _line,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.indigo.withValues(alpha: 0.05),
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
            Divider(height: 1, thickness: 1, color: _line.withValues(alpha: 0.6)),
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
        ],
      ),
    );
  }
}

enum _AgentSortKey {
  exposure,
  ead,
  rwa,
  weight,
  capital,
  contribution,
  variation,
}

const double _agentNumWidth = 120.0;

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

  double _valueFor(RwaCreditAgentRow row, _AgentSortKey key) {
    switch (key) {
      case _AgentSortKey.exposure:
        return row.exposureTotal;
      case _AgentSortKey.ead:
        return row.ead;
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
            _sortableHeader('Exposition totale', 14, _AgentSortKey.exposure),
            _separator(),
            _sortableHeader('EAD', 14, _AgentSortKey.ead,
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
                  _numericCell(_formatMoney(row.ead, maxDecimals: 0), 14,
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
    // La ventilation par contrepartie provient directement du backend
    // (RwaCreditAgentRow.counterparties) : montants déjà convertis en XOF et
    // part (share) sommant à 100 % au sein de l'agent. On n'agrège plus les
    // expositions brutes côté frontend, ce qui produisait des pourcentages
    // faussés dès qu'une catégorie contenait des devises étrangères.
    final allCounterparties = row.counterparties
        .map((cp) => _RealCounterparty(
              cp.name,
              cp.grossExposure,
              cp.exposure,
              cp.rwa,
              cp.capitalRequired,
              cp.share,
            ))
        .toList(growable: false)
      ..sort((a, b) => b.rwa.compareTo(a.rwa));

    showDialog(
      context: context,
      builder: (context) {
        bool showAll = false;
        int? selectedIndex;
        final leftTableCtrl = ScrollController();
        final rightTableCtrl = ScrollController();
        void syncTableScroll(ScrollController source, ScrollController target) {
          if (!source.hasClients || !target.hasClients) return;
          if ((target.offset - source.offset).abs() < 0.5) return;
          target.jumpTo(source.offset);
        }
        leftTableCtrl.addListener(() => syncTableScroll(leftTableCtrl, rightTableCtrl));
        rightTableCtrl.addListener(() => syncTableScroll(rightTableCtrl, leftTableCtrl));
        final headerStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            );
        return StatefulBuilder(
          builder: (context, setState) {
            final top5 = showAll ? allCounterparties : allCounterparties.take(5).toList();

            return Dialog(
              backgroundColor: Colors.white,
              alignment: Alignment.bottomCenter,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              child: Container(
                width: 1200,
                height: 500,
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
                      flex: 55,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: _line, width: 1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Material(
                          color: Colors.transparent,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              const double pctColWidth = 96;
                              const double headerHeight = 40;
                              const double rowHeight = 52;
                              const double totalHeight = 46;
                              Color rowBg(int i) => selectedIndex == i
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : (i % 2 == 0 ? Colors.white : const Color(0xFFF1F5F9));
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: math.max(804.0, constraints.maxWidth - pctColWidth),
                            child: Column(
                              children: [
                                Container(
                                  height: headerHeight,
                                  color: _deepBlue,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 4, child: Text('Contrepartie', style: headerStyle)),
                                      Expanded(flex: 2, child: Text('Exposition', style: headerStyle)),
                                      Expanded(flex: 2, child: Text('EAD', style: headerStyle)),
                                      Expanded(flex: 2, child: Text('RWA', style: headerStyle)),
                                      Expanded(flex: 2, child: Text('Cap. Requis', style: headerStyle)),
                                    ],
                                  ),
                                ),
                                Builder(
                                  builder: (context) {
                                    final rows = <Widget>[
                                      for (var i = 0; i < top5.length; i++)
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              selectedIndex = selectedIndex == i ? null : i;
                                            });
                                          },
                                          child: Container(
                                            height: rowHeight,
                                            decoration: BoxDecoration(
                                              color: rowBg(i),
                                              border: const Border(
                                                bottom: BorderSide(color: _line, width: 1),
                                              ),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 14),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 4,
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(right: 16.0),
                                                    child: Text(
                                                      top5[i].name,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: _ink,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    _formatMoney(top5[i].exposure, maxDecimals: 0),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: _deepBlue,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    _formatMoney(top5[i].ead, maxDecimals: 0),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: _deepBlue,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    _formatMoney(top5[i].rwa, maxDecimals: 0),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: _deepBlue,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    _formatMoney(top5[i].capitalRequired, maxDecimals: 0),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: _muted,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ];
                                    return Expanded(
                                      child: SingleChildScrollView(
                                        controller: leftTableCtrl,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: rows,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                Container(
                                  height: totalHeight,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1E3A5F),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
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
                                          _formatMoney(top5.fold<double>(0, (s, t) => s + t.exposure), maxDecimals: 0),
                                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          _formatMoney(top5.fold<double>(0, (s, t) => s + t.ead), maxDecimals: 0),
                                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          _formatMoney(top5.fold<double>(0, (s, t) => s + t.rwa), maxDecimals: 0),
                                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          _formatMoney(top5.fold<double>(0, (s, t) => s + t.capitalRequired), maxDecimals: 0),
                                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                color: Colors.white70,
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
                                  ),
                                  Container(
                                    width: pctColWidth,
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        left: BorderSide(color: _line, width: 1),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          height: headerHeight,
                                          width: double.infinity,
                                          color: _deepBlue,
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          child: Text('% RWA', style: headerStyle),
                                        ),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            controller: rightTableCtrl,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                for (var i = 0; i < top5.length; i++)
                                                  InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        selectedIndex = selectedIndex == i ? null : i;
                                                      });
                                                    },
                                                    child: Container(
                                                      height: rowHeight,
                                                      width: double.infinity,
                                                      decoration: BoxDecoration(
                                                        color: rowBg(i),
                                                        border: const Border(
                                                          bottom: BorderSide(color: _line, width: 1),
                                                        ),
                                                      ),
                                                      alignment: Alignment.centerRight,
                                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                                      child: Text(
                                                        AppFormatters.percent(top5[i].percentage),
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: _blue700,
                                                          fontWeight: FontWeight.w900,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Container(
                                          height: totalHeight,
                                          width: double.infinity,
                                          color: const Color(0xFF1E3A5F),
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          child: Text(
                                            AppFormatters.percent(top5.fold<double>(0, (s, t) => s + t.percentage)),
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
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    if (!showAll) const SizedBox(width: 32),
                    if (!showAll)
                      Expanded(
                        flex: 45,
                        child: Container(
                          padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: _line, width: 1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'PART DU RWA PAR CONTREPARTIE (%)',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: _blue700,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      letterSpacing: 0.3,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
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
                            ],
                          ),
                        ),
                      ),
                  ],
                );
                return rowContent;
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
            cell(14, _formatMoney(widget.totals.ead, maxDecimals: 0)),
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

class _RealCounterparty {
  final String name;
  final double exposure;
  final double ead;
  final double rwa;
  final double capitalRequired;
  final double percentage;

  _RealCounterparty(this.name, this.exposure, this.ead, this.rwa, this.capitalRequired, this.percentage);
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
      expandChild: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 1040;
          const diagram = _RegulatoryDiagram();
          const sidePanel = _RegulatorySidePanel();

          if (narrow) {
            return const SingleChildScrollView(
              child: Column(
                children: [
                  diagram,
                  SizedBox(height: 12),
                  sidePanel,
                ],
              ),
            );
          }

          // Chaque colonne défile indépendamment de l'autre.
          return const Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(child: diagram),
              ),
              SizedBox(width: 18),
              SizedBox(
                width: 330,
                child: SingleChildScrollView(child: sidePanel),
              ),
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
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_pageRadius),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MethodPhaseLabel('Phase 1 : Classification et mesure de l’exposition'),
          _MethodStep(
            index: '1',
            title: 'Catégorisation des expositions',
            description:
                'Affectation de chaque exposition (bilan et hors bilan) à l’une des 11 catégories réglementaires. La catégorie détermine la grille de pondération applicable.',
          ),
          _MethodStep(
            index: '2',
            title: 'Calcul de l’exposition en cas de défaut (EAD)',
            description:
                'Bilan : valeur comptable nette de provisions.\nHors bilan : ERC = Nominal × FCEC.\nEAD avant ARC = Exposition bilan + ERC hors bilan.',
          ),
          SizedBox(height: 6),
          _MethodPhaseLabel('Phase 2 : Pondération et atténuation du risque'),
          _MethodStep(
            index: '3',
            title: 'Détermination de la pondération applicable',
            description:
                'La pondération dépend uniquement de la catégorie d’exposition (étape 1) et de la qualité de crédit de la contrepartie, jamais du montant exposé.',
            child: _WeightSourceGrid(),
          ),
          _MethodStep(
            index: '4',
            title: 'Atténuation du risque de crédit (ARC)',
            description:
                'Ajustement selon la protection de crédit dont bénéficie l’exposition : le collatéral réduit l’EAD, la garantie substitue la pondération.',
            child: _CrmCaseList(),
          ),
          _MethodStep(
            index: '5',
            title: 'Calcul de l’APR de crédit',
            description:
                'APR = EAD × Pondération finale, après atténuation du risque de crédit.',
          ),
          SizedBox(height: 6),
          _MethodPhaseLabel('Phase 3 : Exigences prudentielles'),
          _MethodStep(
            index: '6',
            title: 'Exigences minimales de fonds propres',
            description:
                'Capital requis = APR × ratio minimal réglementaire (11,5 % coussin de conservation de 2,5 % inclus).',
          ),
          _MethodStep(
            index: '7',
            title: 'Ratio de solvabilité',
            description:
                'Fonds propres effectifs / (APR crédit + 12,5 × risque opérationnel + 12,5 × risque de marché)',
            emphasized: true,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _MethodPhaseLabel extends StatelessWidget {
  const _MethodPhaseLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 44, bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _muted,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _MethodStep extends StatelessWidget {
  const _MethodStep({
    required this.index,
    required this.title,
    required this.description,
    this.child,
    this.emphasized = false,
    this.isLast = false,
  });

  final String index;
  final String title;
  final String description;
  final Widget? child;
  final bool emphasized;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: emphasized ? _deepBlue : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _deepBlue, width: 1.4),
                  ),
                  child: Text(
                    index,
                    style: TextStyle(
                      color: emphasized ? Colors.white : _deepBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(width: 1.2, color: _line),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
                decoration: BoxDecoration(
                  color: emphasized ? _deepBlue : _soft,
                  borderRadius: BorderRadius.circular(1),
                  border: Border.all(
                    color: emphasized ? _deepBlue : _line,
                    width: 0.6,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x120A2540),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: emphasized ? Colors.white : _deepBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        description,
                        style: TextStyle(
                          color: emphasized
                              ? Colors.white.withValues(alpha: 0.88)
                              : _muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                      ),
                    ],
                    if (child != null) ...[
                      const SizedBox(height: 12),
                      child!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightSourceGrid extends StatelessWidget {
  const _WeightSourceGrid();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _WeightSourceTile(
                  'Coefficient forfaitaire',
                  'Pondération fixée par catégorie d’exposition',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _WeightSourceTile(
                  'Notations OEEC',
                  'S&P, Moody’s, Fitch, DBRS',
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _WeightSourceTile(
                  'Classification OCE',
                  'Consensus OCDE sur le risque pays',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _WeightSourceTile(
                  'Évaluations multiples',
                  'Deux notations : la plus élevée ; plus de deux : la plus élevée des deux plus basses',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CrmCaseList extends StatelessWidget {
  const _CrmCaseList();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeightSourceTile(
          'Sans CRM',
          'Aucun ajustement : RWA = EAD × pondération de la contrepartie.',
        ),
        SizedBox(height: 8),
        _WeightSourceTile(
          'CRM financée (approche globale)',
          'Le collatéral décoté (HC, Hfx) réduit l’exposition : EAD ajustée = max(0 ; EVA − CVA).',
        ),
        SizedBox(height: 8),
        _WeightSourceTile(
          'CRM non financée (substitution)',
          'RWA = part couverte × RW du garant + part non couverte × RW du débiteur.',
        ),
      ],
    );
  }
}

class _WeightSourceTile extends StatelessWidget {
  const _WeightSourceTile(this.title, this.detail);

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(1),
        border: Border.all(color: _line, width: 0.6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _deepBlue,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            style: const TextStyle(
              color: _muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _RegulatorySidePanel extends StatelessWidget {
  const _RegulatorySidePanel();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _SideTableCard(
          title: 'PONDÉRATIONS DU DISPOSITIF',
          columnLabel: 'Catégorie d’exposition',
          valueLabel: 'Pondération',
          rows: [
            _SideTableRow(
              'Souverains',
              '0 à 150 %',
              note: '0 % en FCFA : États UMOA, BCEAO',
            ),
            _SideTableRow(
              'Organismes publics',
              '20 à 150 %',
              note: '20 % si UMOA, en FCFA',
            ),
            _SideTableRow(
              'BMD',
              '0 à 150 %',
              note: '0 % pour les BMD éligibles',
            ),
            _SideTableRow(
              'Institutions financières',
              '20 à 150 %',
              note: 'Selon notation et maturité initiale',
            ),
            _SideTableRow(
              'Entreprises',
              '20 à 150 %',
              note: 'Selon notation ; 100 % si non notée',
            ),
            _SideTableRow(
              'Clientèle de détail',
              '75 %',
              note: 'Si critères d’éligibilité satisfaits',
            ),
            _SideTableRow(
              'Immobilier résidentiel',
              '35 %',
              note: '100 % si non éligible',
            ),
            _SideTableRow(
              'Immobilier commercial',
              '75 %',
              note: '100 % si non éligible',
            ),
            _SideTableRow(
              'Créances en souffrance',
              '100 à 150 %',
              note: '150 % si provisions < 20 %',
            ),
            _SideTableRow('Créances à risque élevé', '≥ 150 %'),
            _SideTableRow(
              'Autres actifs',
              '0 à 250 %',
              note: 'Selon la nature de l’actif',
            ),
          ],
        ),
        SizedBox(height: 14),
        _SideReferenceCard(
          title: 'RÉFÉRENCES RÉGLEMENTAIRES',
          entries: [
            _SideReferenceEntry(
              'Dispositif prudentiel UMOA (2016)',
              'Titre IV : exigences de fonds propres au titre du risque de crédit',
              url:
                  'https://www.bceao.int/sites/default/files/2017-11/_annexe_decision_013_24_06_2016-_bceao-dispositif_prudentiel_de_l_umoa-2016-1.pdf',
              linkLabel: 'Télécharger',
            ),
            _SideReferenceEntry(
              'Bâle II (BRI, juin 2006)',
              'Convergence internationale de la mesure et des normes de fonds propres',
              url: 'https://www.bis.org/publ/bcbs128.htm',
              linkLabel: 'Consulter',
            ),
            _SideReferenceEntry(
              'Bâle III (BRI, juin 2011)',
              'Dispositif réglementaire mondial de renforcement des banques',
              url: 'https://www.bis.org/publ/bcbs189.htm',
              linkLabel: 'Consulter',
            ),
            _SideReferenceEntry(
              'BCEAO et Commission Bancaire de l’UMOA',
              'Instructions et circulaires d’application',
              url: 'https://www.cb-umoa.org/fr/reglementation_prudentielle',
              linkLabel: 'Consulter',
            ),
          ],
        ),
      ],
    );
  }
}

class _SideTableRow {
  const _SideTableRow(this.label, this.value, {this.note});

  final String label;
  final String value;
  final String? note;
}

class _SideTableCard extends StatelessWidget {
  const _SideTableCard({
    required this.title,
    required this.columnLabel,
    required this.valueLabel,
    required this.rows,
  });

  final String title;
  final String columnLabel;
  final String valueLabel;
  final List<_SideTableRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_pageRadius),
        border: Border.all(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: _deepBlue,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    letterSpacing: 0.2,
                  ),
            ),
          ),
          Container(
            height: 34,
            color: _soft,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: double.infinity,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: _line, width: 0.8),
                    ),
                  ),
                  child: Text(
                    'N°',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _deepBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                        ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        columnLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _deepBlue,
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                            ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 112,
                  height: double.infinity,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: _line, width: 0.8),
                    ),
                  ),
                  child: Text(
                    valueLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _deepBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                        ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 48),
              color: i.isEven ? Colors.white : const Color(0xFFF6F8FB),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 36,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: _line, width: 0.8),
                        ),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: _deepBlue,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rows[i].label,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                            if (rows[i].note != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  rows[i].note!,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 112,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: _line, width: 0.8),
                        ),
                      ),
                      child: Text(
                        rows[i].value,
                        style: const TextStyle(
                          color: _deepBlue,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SideReferenceEntry {
  const _SideReferenceEntry(
    this.source,
    this.detail, {
    this.url,
    this.linkLabel = 'Consulter',
  });

  final String source;
  final String detail;
  final String? url;
  final String linkLabel;
}

class _SideReferenceCard extends StatelessWidget {
  const _SideReferenceCard({
    required this.title,
    required this.entries,
  });

  final String title;
  final List<_SideReferenceEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_pageRadius),
        border: Border.all(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: _deepBlue,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    letterSpacing: 0.2,
                  ),
            ),
          ),
          for (var i = 0; i < entries.length; i++)
            Container(
              width: double.infinity,
              height: 56,
              color: i.isEven ? Colors.white : const Color(0xFFF6F8FB),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entries[i].source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entries[i].detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (entries[i].url != null) ...[
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () {
                        launchUrl(
                          Uri.parse(entries[i].url!),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      child: Text(
                        entries[i].linkLabel,
                        style: const TextStyle(
                          color: _blue700,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                          decorationColor: _blue700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
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
      .fold<double>(0, (sum, item) => sum + item.rwaXof);
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
                      child: SizedBox(
                        width: 100,
                        child: Text(
                          top5[index].name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
                reservedSize: 80,
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
