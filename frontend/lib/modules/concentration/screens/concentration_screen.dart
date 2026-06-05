import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/section_card.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../risque_credit_shared/models/credit_risk_models.dart';
import '../../risque_credit_shared/services/credit_risk_submodules_service.dart';
import '../../risque_credit_shared/widgets/credit_data_table_card.dart';

const Color _primaryBarColor = Color(0xFF2563EB);

class ConcentrationScreen extends StatefulWidget {
  const ConcentrationScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<ConcentrationScreen> createState() => _ConcentrationScreenState();
}

class _ConcentrationScreenState extends State<ConcentrationScreen> {
  late final CreditRiskSubmodulesService _service;
  late Future<ConcentrationModuleData> _future;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _contentScrollController = ScrollController();
  final Map<String, _ConcentrationViewModel> _viewCache = {};
  StreamSubscription<int>? _portfolioSubscription;

  final String _selectedPeriod = '12M';
  final String _selectedCountry = 'Tous';
  final String _selectedRegion = 'Tous';
  final String _selectedSector = 'Tous';
  final String _selectedSegment = 'Tous';
  final String _selectedRating = 'Tous';
  final String _selectedStatus = 'Tous';
  final String _selectedDefault = 'Tous';
  final String _selectedGuarantee = 'Tous';
  int _topLimit = 10;

  @override
  void initState() {
    super.initState();
    _service = CreditRiskSubmodulesService(widget.api);
    _future = _service.fetchConcentrationModule();
    _portfolioSubscription = widget.api.portfolioRefreshStream.listen((_) {
      if (!mounted) {
        return;
      }
      _refresh();
    });
  }

  @override
  void dispose() {
    _portfolioSubscription?.cancel();
    _contentScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ConcentrationModuleData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final data = snapshot.data!;
        final view = _viewFor(data);

        return Column(
          children: [
            _buildFixedTopBar(context),
            Expanded(
              child: Scrollbar(
                controller: _contentScrollController,
                child: SingleChildScrollView(
                  controller: _contentScrollController,
                  padding: const EdgeInsets.all(AppTheme.pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectorAndGeography(view),
                      const SizedBox(height: AppTheme.pageGap),
                      _buildTopCounterparties(view),
                      const SizedBox(height: AppTheme.pageGap),
                      _buildPrudentialAndWeights(view),
                      const SizedBox(height: AppTheme.pageGap),
                      _buildRwaAnalysis(view),
                      const SizedBox(height: AppTheme.pageGap),
                      _buildQuality(view),
                      const SizedBox(height: AppTheme.pageGap),
                      _buildAlerts(view),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFixedTopBar(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Theme.of(context).cardColor,
        elevation: 2,
        shadowColor: const Color(0x1A0F172A),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Portefeuille',
                  textAlign: TextAlign.left,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.text,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lecture des expositions, concentrations et signaux de vigilance.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectorAndGeography(_ConcentrationViewModel view) {
    return SectionCard(
      title: 'Répartition géographique',
      trailing: _UnitLabel('${view.countryRows.length} pays'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HorizontalMetricBars(
            rows: view.countryDistribution.take(8).toList(),
            color: _primaryBarColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTopCounterparties(_ConcentrationViewModel view) {
    final visibleRows = view.counterpartyRows.take(_topLimit).toList();

    return SectionCard(
      title: 'Top contreparties',
      trailing: _TopLimitSelector(
        value: _topLimit,
        onChanged: (value) => setState(() => _topLimit = value),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bars = _CounterpartyBars(rows: visibleRows.take(8).toList());
          return bars;
        },
      ),
    );
  }

  Widget _buildPrudentialAndWeights(_ConcentrationViewModel view) {
    return SectionCard(
      title: 'Répartition des pondérations',
      trailing: const _UnitLabel('EAD / RWA'),
      child: _RiskWeightChart(rows: view.riskWeightRows),
    );
  }

  Widget _buildRwaAnalysis(_ConcentrationViewModel view) {
    return _buildRwaCounterpartyTable(
      view.rwaCounterpartyRows.take(10).toList(),
    );
  }

  Widget _buildQuality(_ConcentrationViewModel view) {
    return SectionCard(
      title: 'Qualité du portefeuille',
      trailing: const _UnitLabel('Indicateurs filtrés'),
      child: _QualityGrid(quality: view.quality),
    );
  }

  Widget _buildAlerts(_ConcentrationViewModel view) {
    return CreditDataTableCard(
      title: 'Alertes de concentration',
      emptyMessage: 'Aucune alerte active sur le périmètre filtré.',
      columns: const [
        DataColumn(label: Text('Niveau')),
        DataColumn(label: Text('Gravité')),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Signal')),
        DataColumn(label: Text('Recommandation')),
      ],
      rows: view.alerts
          .map(
            (item) => DataRow(
              cells: [
                DataCell(Text(item.level)),
                DataCell(_SeverityBadge(label: item.severity)),
                DataCell(Text(AppFormatters.shortDate(item.date))),
                DataCell(Text(item.message)),
                DataCell(Text(item.recommendation)),
              ],
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildRwaCounterpartyTable(List<ConcentrationExposureRow> rows) {
    return CreditDataTableCard(
      title: 'Top contreparties consommatrices de RWA',
      columns: const [
        DataColumn(label: Text('Contrepartie')),
        DataColumn(label: Text('Segment')),
        DataColumn(label: Text('RWA')),
        DataColumn(label: Text('RW moyen')),
        DataColumn(label: Text('Part portefeuille')),
      ],
      rows: rows
          .map(
            (item) => DataRow(
              cells: [
                DataCell(Text(item.counterpartyName)),
                DataCell(Text(item.segment)),
                DataCell(Text(_amountMd(item.rwa))),
                DataCell(Text(AppFormatters.percent(item.averageRiskWeight))),
                DataCell(Text(AppFormatters.percent(item.share))),
              ],
            ),
          )
          .toList(growable: false),
    );
  }

  _ConcentrationViewModel _viewFor(ConcentrationModuleData data) {
    final key = [
      identityHashCode(data),
      _searchController.text.trim().toLowerCase(),
      _selectedPeriod,
      _selectedCountry,
      _selectedRegion,
      _selectedSector,
      _selectedSegment,
      _selectedRating,
      _selectedStatus,
      _selectedDefault,
      _selectedGuarantee,
    ].join('|');

    return _viewCache.putIfAbsent(
      key,
      () => _ConcentrationViewModel.fromDetails(_filteredDetails(data)),
    );
  }

  List<ConcentrationExposureDetail> _filteredDetails(
    ConcentrationModuleData data,
  ) {
    if (data.exposureDetails.isEmpty) {
      return const <ConcentrationExposureDetail>[];
    }

    final latest = data.exposureDetails
        .map((item) => item.analysisDate)
        .reduce((left, right) => left.isAfter(right) ? left : right);
    final cutoff = _periodCutoff(_selectedPeriod, latest);
    final query = _searchController.text.trim().toLowerCase();

    return data.exposureDetails.where((item) {
      final matchesQuery = query.isEmpty ||
          item.id.toLowerCase().contains(query) ||
          item.counterpartyName.toLowerCase().contains(query) ||
          item.country.toLowerCase().contains(query) ||
          item.region.toLowerCase().contains(query) ||
          item.sector.toLowerCase().contains(query) ||
          item.rating.toLowerCase().contains(query);
      final matchesDate = !item.analysisDate.isBefore(cutoff);
      final matchesCountry =
          _selectedCountry == 'Tous' || item.country == _selectedCountry;
      final matchesRegion =
          _selectedRegion == 'Tous' || item.region == _selectedRegion;
      final matchesSector =
          _selectedSector == 'Tous' || item.sector == _selectedSector;
      final matchesSegment =
          _selectedSegment == 'Tous' || item.segment == _selectedSegment;
      final matchesRating =
          _selectedRating == 'Tous' || item.rating == _selectedRating;
      final matchesStatus =
          _selectedStatus == 'Tous' || item.status == _selectedStatus;
      final matchesDefault = _selectedDefault == 'Tous' ||
          (_selectedDefault == 'Oui' && item.isDefault) ||
          (_selectedDefault == 'Non' && !item.isDefault);
      final matchesGuarantee = _selectedGuarantee == 'Tous' ||
          (_selectedGuarantee == 'Oui' && item.hasGuarantee) ||
          (_selectedGuarantee == 'Non' && !item.hasGuarantee);

      return matchesQuery &&
          matchesDate &&
          matchesCountry &&
          matchesRegion &&
          matchesSector &&
          matchesSegment &&
          matchesRating &&
          matchesStatus &&
          matchesDefault &&
          matchesGuarantee;
    }).toList(growable: false);
  }

  DateTime _periodCutoff(String period, DateTime latest) {
    return switch (period) {
      '1M' => DateTime(latest.year, latest.month - 1, latest.day),
      '3M' => DateTime(latest.year, latest.month - 3, latest.day),
      '6M' => DateTime(latest.year, latest.month - 6, latest.day),
      'YTD' => DateTime(latest.year),
      _ => DateTime(latest.year, latest.month - 12, latest.day),
    };
  }

  void _refresh() {
    setState(() {
      _viewCache.clear();
      _future = _service.fetchConcentrationModule();
    });
  }
}

class _ConcentrationViewModel {
  const _ConcentrationViewModel({
    required this.totalGross,
    required this.totalEad,
    required this.totalRwa,
    required this.hhi,
    required this.hhiBadge,
    required this.topSectorLabel,
    required this.topSectorShare,
    required this.topCounterpartyName,
    required this.topCounterpartyShare,
    required this.sectorRows,
    required this.countryRows,
    required this.regionRows,
    required this.prudentialRows,
    required this.riskWeightRows,
    required this.rwaSectorRows,
    required this.counterpartyRows,
    required this.rwaCounterpartyRows,
    required this.sectorDistribution,
    required this.countryDistribution,
    required this.quality,
    required this.trends,
    required this.alerts,
  });

  factory _ConcentrationViewModel.fromDetails(
    List<ConcentrationExposureDetail> details,
  ) {
    final totalGross =
        details.fold<double>(0.0, (sum, item) => sum + item.grossAmount);
    final totalEad = details.fold<double>(0.0, (sum, item) => sum + item.ead);
    final totalRwa = details.fold<double>(0.0, (sum, item) => sum + item.rwa);
    final sectorGroups = _groupDetails(details, (item) => item.sector);
    final countryGroups = _groupDetails(details, (item) => item.country);
    final regionGroups = _groupDetails(details, (item) => item.region);
    final prudentialGroups =
        _groupDetails(details, (item) => item.prudentialCategory);
    final counterpartyGroups =
        _groupDetails(details, (item) => item.counterpartyName);
    final riskWeightGroups =
        _groupDetails(details, (item) => _riskWeightBucket(item.riskWeight));

    final sectorRows = _sectorRows(sectorGroups, totalGross, totalRwa)
      ..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final countryRows = _breakdownRows(
      countryGroups,
      'Pays',
      totalGross,
      totalRwa,
    )..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final regionRows = _breakdownRows(
      regionGroups,
      'Région',
      totalGross,
      totalRwa,
    )..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final prudentialRows = _breakdownRows(
      prudentialGroups,
      'Catégorie prudentielle',
      totalGross,
      totalRwa,
    )..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final counterpartyRows = _counterpartyRows(counterpartyGroups, totalGross)
      ..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));
    final rwaCounterpartyRows = [...counterpartyRows]
      ..sort((left, right) => right.rwa.compareTo(left.rwa));
    final rwaSectorRows = [...sectorRows]
      ..sort((left, right) => right.rwa.compareTo(left.rwa));
    final riskWeightRows = _riskWeightRows(
      riskWeightGroups,
      totalEad,
      totalRwa,
    )..sort((left, right) => left.weight.compareTo(right.weight));
    final hhi = _hhi(counterpartyRows.map((item) => item.share));
    final trends = _trends(details);

    return _ConcentrationViewModel(
      totalGross: totalGross,
      totalEad: totalEad,
      totalRwa: totalRwa,
      hhi: hhi,
      hhiBadge: _hhiBadge(hhi),
      topSectorLabel: sectorRows.isEmpty ? 'N/D' : sectorRows.first.sector,
      topSectorShare: sectorRows.isEmpty ? 0.0 : sectorRows.first.share,
      topCounterpartyName: counterpartyRows.isEmpty
          ? 'N/D'
          : counterpartyRows.first.counterpartyName,
      topCounterpartyShare:
          counterpartyRows.isEmpty ? 0.0 : counterpartyRows.first.share,
      sectorRows: sectorRows,
      countryRows: countryRows,
      regionRows: regionRows,
      prudentialRows: prudentialRows,
      riskWeightRows: riskWeightRows,
      rwaSectorRows: rwaSectorRows,
      counterpartyRows: counterpartyRows,
      rwaCounterpartyRows: rwaCounterpartyRows,
      sectorDistribution: _distribution(
        sectorRows.map((item) => (item.sector, item.grossAmount, item.share)),
      ),
      countryDistribution: _distribution(
        countryRows.map(
          (item) => (item.label, item.grossAmount, item.portfolioShare),
        ),
      ),
      quality: _quality(details, totalGross, totalEad, trends),
      trends: trends,
      alerts: _alerts(
        latestDate: _latestDate(details),
        totalRwa: totalRwa,
        hhi: hhi,
        sectorRows: sectorRows,
        counterpartyRows: counterpartyRows,
        countryRows: countryRows,
        rwaCounterpartyRows: rwaCounterpartyRows,
        trends: trends,
      ),
    );
  }

  final double totalGross;
  final double totalEad;
  final double totalRwa;
  final double hhi;
  final String hhiBadge;
  final String topSectorLabel;
  final double topSectorShare;
  final String topCounterpartyName;
  final double topCounterpartyShare;
  final List<SectorConcentrationRow> sectorRows;
  final List<ConcentrationBreakdownRow> countryRows;
  final List<ConcentrationBreakdownRow> regionRows;
  final List<ConcentrationBreakdownRow> prudentialRows;
  final List<RiskWeightBucketRow> riskWeightRows;
  final List<SectorConcentrationRow> rwaSectorRows;
  final List<ConcentrationExposureRow> counterpartyRows;
  final List<ConcentrationExposureRow> rwaCounterpartyRows;
  final List<DistributionEntry> sectorDistribution;
  final List<DistributionEntry> countryDistribution;
  final PortfolioQualitySummary quality;
  final List<ConcentrationTrendPoint> trends;
  final List<ConcentrationAlert> alerts;
}

class _DetailAccumulator {
  _DetailAccumulator(this.label);

  final Object label;
  var exposureCount = 0;
  var grossAmount = 0.0;
  var ead = 0.0;
  var rwa = 0.0;
  var sector = 'Non renseigné';
  var country = 'Non renseigné';

  void add(ConcentrationExposureDetail item) {
    exposureCount += 1;
    grossAmount += item.grossAmount;
    ead += item.ead;
    rwa += item.rwa;
    if (sector == 'Non renseigné' || sector.isEmpty) {
      sector = item.sector;
    }
    if (country == 'Non renseigné' || country.isEmpty) {
      country = item.country;
    }
  }

  double get averageRiskWeight => ead == 0 ? 0.0 : rwa / ead;
}

Map<Object, _DetailAccumulator> _groupDetails(
  List<ConcentrationExposureDetail> details,
  Object Function(ConcentrationExposureDetail item) keyOf,
) {
  final groups = <Object, _DetailAccumulator>{};
  for (final item in details) {
    final key = keyOf(item);
    groups.putIfAbsent(key, () => _DetailAccumulator(key)).add(item);
  }
  return groups;
}

List<SectorConcentrationRow> _sectorRows(
  Map<Object, _DetailAccumulator> groups,
  double totalGross,
  double totalRwa,
) {
  return groups.values
      .map(
        (item) => SectorConcentrationRow(
          sector: item.label.toString(),
          exposureCount: item.exposureCount,
          grossAmount: item.grossAmount,
          ead: item.ead,
          rwa: item.rwa,
          averageRiskWeight: item.averageRiskWeight,
          rwaShare: totalRwa == 0 ? 0.0 : item.rwa / totalRwa,
          share: totalGross == 0 ? 0.0 : item.grossAmount / totalGross,
        ),
      )
      .toList(growable: false);
}

List<ConcentrationBreakdownRow> _breakdownRows(
  Map<Object, _DetailAccumulator> groups,
  String group,
  double totalGross,
  double totalRwa,
) {
  return groups.values
      .map(
        (item) => ConcentrationBreakdownRow(
          label: item.label.toString(),
          group: group,
          exposureCount: item.exposureCount,
          grossAmount: item.grossAmount,
          ead: item.ead,
          rwa: item.rwa,
          averageRiskWeight: item.averageRiskWeight,
          portfolioShare: totalGross == 0 ? 0.0 : item.grossAmount / totalGross,
          rwaShare: totalRwa == 0 ? 0.0 : item.rwa / totalRwa,
        ),
      )
      .toList(growable: false);
}

List<ConcentrationExposureRow> _counterpartyRows(
  Map<Object, _DetailAccumulator> groups,
  double totalGross,
) {
  return groups.values
      .map(
        (item) => ConcentrationExposureRow(
          exposureId: '${item.exposureCount} dossier(s)',
          counterpartyName: item.label.toString(),
          country: item.country,
          sector: item.sector,
          segment: item.sector,
          grossAmount: item.grossAmount,
          ead: item.ead,
          rwa: item.rwa,
          averageRiskWeight: item.averageRiskWeight,
          share: totalGross == 0 ? 0.0 : item.grossAmount / totalGross,
        ),
      )
      .toList(growable: false);
}

List<RiskWeightBucketRow> _riskWeightRows(
  Map<Object, _DetailAccumulator> groups,
  double totalEad,
  double totalRwa,
) {
  return groups.entries
      .map(
        (entry) => RiskWeightBucketRow(
          label: _riskWeightBucketLabel(entry.key as double),
          weight: entry.key as double,
          exposureCount: entry.value.exposureCount,
          ead: entry.value.ead,
          rwa: entry.value.rwa,
          portfolioShare: totalEad == 0 ? 0.0 : entry.value.ead / totalEad,
          rwaShare: totalRwa == 0 ? 0.0 : entry.value.rwa / totalRwa,
        ),
      )
      .toList(growable: false);
}

List<DistributionEntry> _distribution(
  Iterable<(String, double, double)> rows,
) {
  return rows
      .map(
        (item) => DistributionEntry(
          label: item.$1,
          amount: item.$2,
          percentage: item.$3,
        ),
      )
      .toList(growable: false);
}

PortfolioQualitySummary _quality(
  List<ConcentrationExposureDetail> details,
  double totalGross,
  double totalEad,
  List<ConcentrationTrendPoint> trends,
) {
  final defaultRows = details.where((item) => item.isDefault).toList();
  final defaultGross =
      defaultRows.fold<double>(0.0, (sum, item) => sum + item.grossAmount);
  final weightedPd = details.fold<double>(
    0.0,
    (sum, item) => sum + _pdFromRating(item.rating) * item.grossAmount,
  );
  final weightedLgd = details.fold<double>(
    0.0,
    (sum, item) => sum + _lgdFromDetail(item) * item.grossAmount,
  );
  final nplTrend =
      trends.length < 2 ? 0.0 : trends.last.npl - trends[trends.length - 2].npl;

  return PortfolioQualitySummary(
    nplRatio: totalGross == 0 ? 0.0 : defaultGross / totalGross,
    defaultRate: details.isEmpty ? 0.0 : defaultRows.length / details.length,
    defaultGross: defaultGross,
    riskCoverage: totalGross == 0 ? 0.0 : (totalGross - totalEad) / totalGross,
    averagePd: totalGross == 0 ? 0.0 : weightedPd / totalGross,
    averageLgd: totalGross == 0 ? 0.0 : weightedLgd / totalGross,
    nplTrend: nplTrend,
    defaultTrend: nplTrend,
    coverageTrend: 0.0,
  );
}

List<ConcentrationTrendPoint> _trends(
  List<ConcentrationExposureDetail> details,
) {
  final groups = <DateTime, List<ConcentrationExposureDetail>>{};
  for (final item in details) {
    final key = DateTime(item.analysisDate.year, item.analysisDate.month);
    groups.putIfAbsent(key, () => <ConcentrationExposureDetail>[]).add(item);
  }
  final dates = groups.keys.toList()..sort();

  return [
    for (final date in dates)
      ConcentrationTrendPoint(
        label: _monthLabel(date),
        date: date,
        ead: groups[date]!.fold<double>(0.0, (sum, item) => sum + item.ead),
        rwa: groups[date]!.fold<double>(0.0, (sum, item) => sum + item.rwa),
        npl: _nplRatio(groups[date]!),
        hhi: _hhiForDetails(groups[date]!),
      ),
  ];
}

List<ConcentrationAlert> _alerts({
  required DateTime latestDate,
  required double totalRwa,
  required double hhi,
  required List<SectorConcentrationRow> sectorRows,
  required List<ConcentrationExposureRow> counterpartyRows,
  required List<ConcentrationBreakdownRow> countryRows,
  required List<ConcentrationExposureRow> rwaCounterpartyRows,
  required List<ConcentrationTrendPoint> trends,
}) {
  final alerts = <ConcentrationAlert>[];
  final ownFundsEstimate = totalRwa * 0.08 * 1.42;

  if (sectorRows.isNotEmpty && sectorRows.first.share > 0.25) {
    alerts.add(
      ConcentrationAlert(
        level: 'Secteur',
        severity: sectorRows.first.share > 0.40 ? 'Élevé' : 'Moyen',
        date: latestDate,
        message:
            '${sectorRows.first.sector} concentre ${AppFormatters.percent(sectorRows.first.share)} du portefeuille.',
        recommendation:
            'Revoir les limites sectorielles et arbitrer les nouvelles entrées.',
      ),
    );
  }
  if (counterpartyRows.isNotEmpty && ownFundsEstimate > 0) {
    final ratio = counterpartyRows.first.grossAmount / ownFundsEstimate;
    if (ratio > 0.10) {
      alerts.add(
        ConcentrationAlert(
          level: 'Client',
          severity: ratio > 0.25 ? 'Élevé' : 'Moyen',
          date: latestDate,
          message:
              '${counterpartyRows.first.counterpartyName} atteint ${AppFormatters.percent(ratio)} des fonds propres estimés.',
          recommendation:
              'Contrôler la limite single-name, les garanties et les sûretés mobilisables.',
        ),
      );
    }
  }
  if (hhi > 1800) {
    alerts.add(
      ConcentrationAlert(
        level: 'HHI',
        severity: hhi > 2500 ? 'Élevé' : 'Moyen',
        date: latestDate,
        message: 'Indice HHI à ${hhi.toStringAsFixed(0)}.',
        recommendation:
            'Diversifier le portefeuille ou renforcer les seuils internes.',
      ),
    );
  }
  if (countryRows.isNotEmpty && countryRows.first.portfolioShare > 0.25) {
    alerts.add(
      ConcentrationAlert(
        level: 'Pays',
        severity: countryRows.first.portfolioShare > 0.40 ? 'Élevé' : 'Moyen',
        date: latestDate,
        message:
            '${countryRows.first.label} représente ${AppFormatters.percent(countryRows.first.portfolioShare)} du portefeuille.',
        recommendation:
            'Tester les limites pays et les scénarios de stress souverain.',
      ),
    );
  }
  if (rwaCounterpartyRows.isNotEmpty && totalRwa > 0) {
    final topFiveRwa = rwaCounterpartyRows
        .take(5)
        .fold<double>(0.0, (sum, item) => sum + item.rwa);
    final share = topFiveRwa / totalRwa;
    if (share > 0.40) {
      alerts.add(
        ConcentrationAlert(
          level: 'RWA',
          severity: share > 0.60 ? 'Élevé' : 'Moyen',
          date: latestDate,
          message:
              '${AppFormatters.percent(share)} du RWA est porté par moins de 5 contreparties.',
          recommendation:
              'Prioriser les revues de rating, garanties et arbitrages RWA.',
        ),
      );
    }
  }
  if (trends.length >= 2 && trends[trends.length - 2].ead > 0) {
    final growth = (trends.last.ead - trends[trends.length - 2].ead) /
        trends[trends.length - 2].ead;
    if (growth > 0.15) {
      alerts.add(
        ConcentrationAlert(
          level: 'Croissance',
          severity: growth > 0.30 ? 'Élevé' : 'Moyen',
          date: latestDate,
          message:
              'Croissance EAD de ${AppFormatters.percent(growth)} sur la dernière période.',
          recommendation:
              'Vérifier les nouveaux engagements et leur consommation RWA.',
        ),
      );
    }
  }

  return alerts;
}

DateTime _latestDate(List<ConcentrationExposureDetail> details) {
  if (details.isEmpty) {
    return DateTime.now();
  }
  return details
      .map((item) => item.analysisDate)
      .reduce((left, right) => left.isAfter(right) ? left : right);
}

double _hhi(Iterable<double> shares) {
  return shares.fold<double>(
    0.0,
    (sum, share) => sum + math.pow(share * 100, 2).toDouble(),
  );
}

double _hhiForDetails(List<ConcentrationExposureDetail> details) {
  final totalGross =
      details.fold<double>(0.0, (sum, item) => sum + item.grossAmount);
  if (totalGross == 0) {
    return 0.0;
  }
  final totals = <String, double>{};
  for (final item in details) {
    totals.update(
      item.counterpartyName,
      (value) => value + item.grossAmount,
      ifAbsent: () => item.grossAmount,
    );
  }
  return _hhi(totals.values.map((amount) => amount / totalGross));
}

String _hhiBadge(double hhi) {
  if (hhi >= 1800) {
    return 'Élevé';
  }
  if (hhi >= 1000) {
    return 'Moyen';
  }
  return 'Faible';
}

double _riskWeightBucket(double weight) {
  const buckets = <double>[0.0, 0.20, 0.50, 0.75, 1.0, 1.50];
  return buckets.reduce(
    (closest, bucket) =>
        (weight - bucket).abs() < (weight - closest).abs() ? bucket : closest,
  );
}

String _riskWeightBucketLabel(double weight) {
  return '${(weight * 100).round()} %';
}

double _nplRatio(List<ConcentrationExposureDetail> details) {
  final totalGross =
      details.fold<double>(0.0, (sum, item) => sum + item.grossAmount);
  if (totalGross == 0) {
    return 0.0;
  }
  final defaultGross = details
      .where((item) => item.isDefault)
      .fold<double>(0.0, (sum, item) => sum + item.grossAmount);
  return defaultGross / totalGross;
}

double _pdFromRating(String rating) {
  final normalized = rating.toUpperCase();
  if (normalized.contains('AAA') || normalized == 'AA') {
    return 0.0005;
  }
  if (normalized == 'A') {
    return 0.0015;
  }
  if (normalized == 'BBB') {
    return 0.006;
  }
  if (normalized.contains('BB') || normalized.contains('B')) {
    return 0.025;
  }
  return 0.045;
}

double _lgdFromDetail(ConcentrationExposureDetail detail) {
  if (detail.isDefault) {
    return detail.hasGuarantee ? 0.55 : 0.75;
  }
  return detail.hasGuarantee ? 0.38 : 0.58;
}

String _monthLabel(DateTime date) {
  const months = [
    'Janv.',
    'Févr.',
    'Mars',
    'Avr.',
    'Mai',
    'Juin',
    'Juil.',
    'Août',
    'Sept.',
    'Oct.',
    'Nov.',
    'Déc.',
  ];
  return months[date.month - 1];
}

String _amountMd(double value) {
  final scaled = value / 1000000000;
  if (scaled.abs() >= 1000) {
    return AppFormatters.compactNumber(scaled);
  }
  return scaled.toStringAsFixed(1).replaceAll('.', ',');
}

class _UnitLabel extends StatelessWidget {
  const _UnitLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppTheme.muted,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _HorizontalMetricBars extends StatelessWidget {
  const _HorizontalMetricBars({
    required this.rows,
    required this.color,
  });

  final List<DistributionEntry> rows;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyInline();
    }

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    row.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 12,
                        color: color.withValues(alpha: 0.10),
                      ),
                      FractionallySizedBox(
                        widthFactor: row.percentage.clamp(0.0, 1.0),
                        child: Container(height: 12, color: color),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 64,
                  child: Text(
                    AppFormatters.percent(row.percentage),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TopLimitSelector extends StatelessWidget {
  const _TopLimitSelector({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        for (final option in const [10, 20, 50])
          _ModeButton(
            label: 'Top $option',
            selected: value == option,
            onTap: () => onChanged(option),
          ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: selected ? AppTheme.accent : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? Colors.white : AppTheme.text,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _CounterpartyBars extends StatelessWidget {
  const _CounterpartyBars({required this.rows});

  final List<ConcentrationExposureRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyInline();
    }

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 170,
                  child: Text(
                    row.counterpartyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 11,
                        color: _primaryBarColor.withValues(alpha: 0.10),
                      ),
                      FractionallySizedBox(
                        widthFactor: row.share.clamp(0.0, 1.0),
                        child: Container(
                          height: 11,
                          color: _primaryBarColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 58,
                  child: Text(
                    AppFormatters.percent(row.share),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RiskWeightChart extends StatelessWidget {
  const _RiskWeightChart({required this.rows});

  final List<RiskWeightBucketRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyInline();
    }

    return SizedBox(
      height: 250,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final row in rows)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      AppFormatters.percent(row.portfolioShare),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: row.portfolioShare.clamp(0.06, 1.0),
                          child: Container(color: _primaryBarColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      row.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${row.exposureCount}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w600,
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

class _QualityGrid extends StatelessWidget {
  const _QualityGrid({required this.quality});

  final PortfolioQualitySummary quality;

  @override
  Widget build(BuildContext context) {
    final items = [
      _QualityItem(
        label: 'NPL Ratio',
        value: AppFormatters.percent(quality.nplRatio),
        trend: quality.nplTrend,
      ),
      _QualityItem(
        label: 'Taux de défaut',
        value: AppFormatters.percent(quality.defaultRate),
        trend: quality.defaultTrend,
      ),
      _QualityItem(
        label: 'Encours en défaut',
        value: _amountMd(quality.defaultGross),
        trend: quality.nplTrend,
      ),
      _QualityItem(
        label: 'Couverture du risque',
        value: AppFormatters.percent(quality.riskCoverage),
        trend: quality.coverageTrend,
      ),
      _QualityItem(
        label: 'PD moyenne',
        value: AppFormatters.percent(quality.averagePd),
        trend: quality.defaultTrend,
      ),
      _QualityItem(
        label: 'LGD moyenne',
        value: AppFormatters.percent(quality.averageLgd),
        trend: quality.coverageTrend,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 560
            ? (constraints.maxWidth - AppTheme.spacing) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: AppTheme.spacing,
          runSpacing: AppTheme.spacing,
          children: [
            for (final item in items) SizedBox(width: width, child: item),
          ],
        );
      },
    );
  }
}

class _QualityItem extends StatelessWidget {
  const _QualityItem({
    required this.label,
    required this.value,
    required this.trend,
  });

  final String label;
  final String value;
  final double trend;

  @override
  Widget build(BuildContext context) {
    final icon = trend > 0.0001
        ? '↑'
        : trend < -0.0001
            ? '↓'
            : '=';
    final color = trend > 0.0001
        ? AppTheme.danger
        : trend < -0.0001
            ? AppTheme.success
            : AppTheme.muted;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
          Text(
            icon,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = label == 'Élevé'
        ? AppTheme.danger
        : label == 'Moyen'
            ? AppTheme.warning
            : AppTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _EmptyInline extends StatelessWidget {
  const _EmptyInline();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        'Aucune donnée disponible pour les filtres sélectionnés.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
