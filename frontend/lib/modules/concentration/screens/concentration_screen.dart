import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_conversion.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/section_card.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../risque_credit_shared/models/credit_risk_models.dart';
import '../../risque_credit_shared/services/credit_risk_submodules_service.dart';
import '../../risque_credit_shared/widgets/credit_data_table_card.dart';

const double _umoaCet1Minimum = 0.05;
const double _umoaTier1Minimum = 0.06;
const double _umoaSolvencyMinimum = 0.09;
const double _umoaConservationBuffer = 0.025;
const double _umoaCet1Target = _umoaCet1Minimum + _umoaConservationBuffer;
const double _umoaTier1Target = _umoaTier1Minimum + _umoaConservationBuffer;
const double _umoaSolvencyTarget =
    _umoaSolvencyMinimum + _umoaConservationBuffer;
const double _umoaLeverageMinimum = 0.03;
const int _counterpartyTopCount = 10;
const int _issuerResidenceCountryTopCount = 10;
const int _concentrationViewModelVersion = 5;
const double _concentrationRadius = 2;
const List<String> _counterpartyRatingOrder = [
  'AAA',
  'AA+',
  'AA',
  'AA-',
  'A+',
  'A',
  'A-',
  'BBB+',
  'BBB',
  'BBB-',
  'BB+',
  'BB',
  'BB-',
  'B+',
  'B',
  'B-',
  '< B-',
  'Non noté',
];

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
  int _selectedPortfolioTab = 0;

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
              child: _selectedPortfolioTab == 3
                  ? Padding(
                      padding: const EdgeInsets.all(AppTheme.pagePadding),
                      child: SizedBox.expand(child: _buildRwaAnalysis(view)),
                    )
                  : Scrollbar(
                      controller: _contentScrollController,
                      child: SingleChildScrollView(
                        controller: _contentScrollController,
                        padding: const EdgeInsets.all(AppTheme.pagePadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _selectedPortfolioTab == 0
                              ? [
                                  _buildCounterpartyAndGeographyRow(view),
                                  const SizedBox(height: AppTheme.pageGap),
                                  _buildQualityAndWeightsRow(view),
                                ]
                              : _selectedPortfolioTab == 1
                                  ? [
                                      _buildAlertsWorkspace(view),
                                    ]
                                  : [
                                      _buildPrudentialRequirements(view),
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

  void _selectPortfolioTab(int index) {
    if (_selectedPortfolioTab == index) {
      return;
    }
    setState(() => _selectedPortfolioTab = index);
    if (_contentScrollController.hasClients) {
      _contentScrollController.jumpTo(0);
    }
  }

  Widget _buildFixedTopBar(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Theme.of(context).cardColor,
        elevation: 2,
        shadowColor: const Color(0x1A0F172A),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Portefeuille',
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
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
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                  ),
                ],
              ),
            ),
            _PortfolioTabNavigation(
              selectedIndex: _selectedPortfolioTab,
              onChanged: _selectPortfolioTab,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterpartyAndGeographyRow(_ConcentrationViewModel view) {
    const minRowWidth = 980.0;
    const rowHeight = 286.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        Widget content(double width) {
          return SizedBox(
            width: width,
            height: rowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildTopCounterparties(view)),
                const SizedBox(width: AppTheme.pageGap),
                Expanded(child: _buildSectorAndGeography(view)),
              ],
            ),
          );
        }

        final row = constraints.maxWidth >= minRowWidth
            ? content(constraints.maxWidth)
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: content(minRowWidth),
              );

        return SizedBox(
          height: rowHeight,
          child: row,
        );
      },
    );
  }

  Widget _buildSectorAndGeography(_ConcentrationViewModel view) {
    return _IssuerResidenceCountryCard(
      countryRows: view.countryDistribution
          .take(_issuerResidenceCountryTopCount)
          .toList(),
      zoneRows: view.regionDistribution,
    );
  }

  Widget _buildTopCounterparties(_ConcentrationViewModel view) {
    final visibleRows =
        view.counterpartyRows.take(_counterpartyTopCount).toList();

    return _TopCounterpartyExposureCard(rows: visibleRows);
  }

  Widget _buildPrudentialAndWeights(_ConcentrationViewModel view) {
    return _RiskWeightDistributionCard(
      rows: view.riskWeightRows,
      ratingRows: view.ratingDistribution,
    );
  }

  Widget _buildQualityAndWeightsRow(_ConcentrationViewModel view) {
    const minRowWidth = 980.0;
    const rowHeight = 360.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        Widget content(double width) {
          return SizedBox(
            width: width,
            height: rowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildQuality(view)),
                const SizedBox(width: AppTheme.pageGap),
                Expanded(child: _buildPrudentialAndWeights(view)),
              ],
            ),
          );
        }

        final row = constraints.maxWidth >= minRowWidth
            ? content(constraints.maxWidth)
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: content(minRowWidth),
              );

        return SizedBox(height: rowHeight, child: row);
      },
    );
  }

  Widget _buildRwaAnalysis(_ConcentrationViewModel view) {
    return _RwaExposureTableCard(
      rows: view.exposureDetails,
      totalRwa: view.totalRwa,
    );
  }

  Widget _buildAlertsWorkspace(_ConcentrationViewModel view) {
    return _ConcentrationAlertsWorkspace(view: view);
  }

  Widget _buildPrudentialRequirements(_ConcentrationViewModel view) {
    return _PrudentialRequirementsPanel(view: view);
  }

  Widget _buildQuality(_ConcentrationViewModel view) {
    return SectionCard(
      title: 'Qualité du portefeuille',
      titleStyle: const TextStyle(
        color: AppColors.concentrationDark,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      child: _QualityGrid(quality: view.quality),
    );
  }

  _ConcentrationViewModel _viewFor(ConcentrationModuleData data) {
    final key = [
      _concentrationViewModelVersion,
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

class _PortfolioTabNavigation extends StatelessWidget {
  const _PortfolioTabNavigation({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const _items = [
    'Visualisation d’indicateurs',
    'Alertes & décisions',
    'Exigences prudentielles',
    'Tableau des données',
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
            for (var index = 0; index < _items.length; index++)
              _PortfolioTabButton(
                label: _items[index],
                selected: selectedIndex == index,
                onTap: () => onChanged(index),
              ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioTabButton extends StatelessWidget {
  const _PortfolioTabButton({
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
        ? AppColors.concentrationDeeper
        : AppColors.concentrationDeeper.withValues(alpha: 0.76);

    return SizedBox(
      width: label.startsWith('Visualisation')
          ? 198
          : label.startsWith('Alertes')
              ? 172
              : label.startsWith('Tableau')
                  ? 172
                  : 190,
      height: double.infinity,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.concentrationDeeper.withValues(alpha: 0.06),
        highlightColor: AppColors.concentrationDeeper.withValues(alpha: 0.035),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.concentrationDeeper : Colors.transparent,
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

class _ConcentrationViewModel {
  const _ConcentrationViewModel({
    required this.totalGross,
    required this.totalEad,
    required this.totalRwa,
    required this.totalCapital,
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
    required this.exposureDetails,
    required this.sectorDistribution,
    required this.countryDistribution,
    required this.regionDistribution,
    required this.ratingDistribution,
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
    final totalCapital =
        details.fold<double>(0.0, (sum, item) => sum + item.capital);
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
    final exposureDetails = [...details]
      ..sort((left, right) => right.rwa.compareTo(left.rwa));
    final rwaSectorRows = [...sectorRows]
      ..sort((left, right) => right.rwa.compareTo(left.rwa));
    final riskWeightRows = _riskWeightRows(
      riskWeightGroups,
      totalEad,
      totalRwa,
    )..sort((left, right) => left.weight.compareTo(right.weight));
    final ratingDistribution = _ratingDistribution(details, totalGross);
    final hhi = _hhi(counterpartyRows.map((item) => item.share));
    final trends = _trends(details);

    return _ConcentrationViewModel(
      totalGross: totalGross,
      totalEad: totalEad,
      totalRwa: totalRwa,
      totalCapital: totalCapital,
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
      exposureDetails: exposureDetails,
      sectorDistribution: _distribution(
        sectorRows.map((item) => (item.sector, item.grossAmount, item.share)),
      ),
      countryDistribution: _distribution(
        countryRows.map(
          (item) => (item.label, item.grossAmount, item.portfolioShare),
        ),
      ),
      regionDistribution: _distribution(
        regionRows.map(
          (item) => (item.label, item.grossAmount, item.portfolioShare),
        ),
      ),
      ratingDistribution: ratingDistribution,
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
  final double totalCapital;
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
  final List<ConcentrationExposureDetail> exposureDetails;
  final List<DistributionEntry> sectorDistribution;
  final List<DistributionEntry> countryDistribution;
  final List<DistributionEntry> regionDistribution;
  final List<DistributionEntry> ratingDistribution;
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

List<DistributionEntry> _ratingDistribution(
  List<ConcentrationExposureDetail> details,
  double totalGross,
) {
  final totals = <String, double>{
    for (final rating in _counterpartyRatingOrder) rating: 0.0,
  };
  for (final item in details) {
    final rating = _normalizedRatingBucket(item.rating);
    totals.update(
      rating,
      (value) => value + item.grossAmount,
      ifAbsent: () => item.grossAmount,
    );
  }

  return [
    for (final rating in _counterpartyRatingOrder)
      DistributionEntry(
        label: rating,
        amount: totals[rating] ?? 0.0,
        percentage:
            totalGross == 0 ? 0.0 : (totals[rating] ?? 0.0) / totalGross,
      ),
  ];
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
    (sum, item) => sum + item.pd * item.ead,
  );
  final weightedLgd = details.fold<double>(
    0.0,
    (sum, item) => sum + item.lgd * item.ead,
  );
  final estimatedProvision = defaultRows.fold<double>(
    0.0,
    (sum, item) => sum + item.estimatedProvision,
  );
  final nplTrend =
      trends.length < 2 ? 0.0 : trends.last.npl - trends[trends.length - 2].npl;

  return PortfolioQualitySummary(
    nplRatio: totalGross == 0 ? 0.0 : defaultGross / totalGross,
    defaultRate: details.isEmpty ? 0.0 : defaultRows.length / details.length,
    defaultGross: defaultGross,
    riskCoverage: defaultGross == 0 ? 0.0 : estimatedProvision / defaultGross,
    averagePd: totalEad == 0 ? 0.0 : weightedPd / totalEad,
    averageLgd: totalEad == 0 ? 0.0 : weightedLgd / totalEad,
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

String _normalizedRatingBucket(String rating) {
  final raw = rating.trim();
  if (raw.isEmpty || raw == '-') {
    return 'Non noté';
  }

  var normalized = raw
      .toUpperCase()
      .replaceAll('É', 'E')
      .replaceAll('È', 'E')
      .replaceAll('Ê', 'E')
      .replaceAll('Ë', 'E')
      .replaceAll('À', 'A')
      .replaceAll('Â', 'A')
      .replaceAll('Î', 'I')
      .replaceAll('Ï', 'I')
      .replaceAll('Ô', 'O')
      .replaceAll('Û', 'U')
      .replaceAll('Ù', 'U')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (normalized == 'NON NOTE' ||
      normalized == 'NON NOTEE' ||
      normalized == 'NON RENSEIGNE' ||
      normalized == 'NR' ||
      normalized == 'N/R' ||
      normalized == 'ND' ||
      normalized == 'N.D.' ||
      normalized == 'N/A') {
    return 'Non noté';
  }

  normalized = normalized.replaceAll(' ', '');
  if (normalized == '<B-' || normalized.startsWith('CCC')) {
    return '< B-';
  }
  if (normalized == 'CC' ||
      normalized == 'C' ||
      normalized == 'D' ||
      normalized == 'SD') {
    return '< B-';
  }
  if (normalized.contains('/')) {
    for (final part in normalized.split('/')) {
      final bucket = _normalizedRatingBucket(part);
      if (bucket != 'Non noté' && bucket != '< B-') {
        return bucket;
      }
    }
    return '< B-';
  }

  for (final rating in _counterpartyRatingOrder) {
    if (normalized == rating.replaceAll(' ', '').toUpperCase()) {
      return rating;
    }
  }

  return 'Non noté';
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

String _amountMd(double value, {int maxDecimals = 1}) {
  final scaled = value / PortfolioAmountUnitPreference.current.divisor;
  final decimals = maxDecimals.clamp(0, 5);

  if (scaled == 0) {
    return '0';
  }

  if (decimals > 0) {
    final precisionFloor = math.pow(10, -decimals).toDouble();
    if (scaled.abs() < precisionFloor) {
      final minimumLabel = '0,${''.padLeft(decimals - 1, '0')}1';
      return scaled.isNegative ? '-$minimumLabel' : '< $minimumLabel';
    }
  }

  return _formatFullFrenchNumber(scaled, decimals);
}

String _amountUnitLabel() => PortfolioAmountUnitPreference.current.label;

String _amountUnitFcfaLabel() => '${_amountUnitLabel()} FCFA';

String _formatFullFrenchNumber(double value, int decimals) {
  final fixed = value.abs().toStringAsFixed(decimals);
  final trimmed = decimals == 0
      ? fixed
      : fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  final parts = trimmed.split('.');
  final integer = parts.first;
  final decimal = parts.length > 1 ? parts[1] : '';
  final groups = <String>[];

  for (var end = integer.length; end > 0; end -= 3) {
    final start = math.max(0, end - 3);
    groups.insert(0, integer.substring(start, end));
  }

  final sign = value.isNegative ? '-' : '';
  final integerLabel = groups.isEmpty ? '0' : groups.join(' ');
  return decimal.isEmpty ? '$sign$integerLabel' : '$sign$integerLabel,$decimal';
}

class _RwaExposureColumnSpec {
  const _RwaExposureColumnSpec(
    this.label,
    this.width, {
    this.align = TextAlign.left,
  });

  final String label;
  final double width;
  final TextAlign align;

  _RwaExposureColumnSpec copyWith({double? width}) {
    return _RwaExposureColumnSpec(
      label,
      width ?? this.width,
      align: align,
    );
  }
}

const List<_RwaExposureColumnSpec> _rwaExposureColumns = [
  _RwaExposureColumnSpec('ID exposition', 118),
  _RwaExposureColumnSpec('Contrepartie', 230),
  _RwaExposureColumnSpec('Catégorie', 160),
  _RwaExposureColumnSpec('Pays', 120),
  _RwaExposureColumnSpec('EAD', 132, align: TextAlign.right),
  _RwaExposureColumnSpec('RWA', 132, align: TextAlign.right),
  _RwaExposureColumnSpec('Pondération', 122, align: TextAlign.center),
  _RwaExposureColumnSpec('Couverture CRM', 144, align: TextAlign.center),
  _RwaExposureColumnSpec('Contribution RWA', 164),
];

class _RwaExposureTableCard extends StatefulWidget {
  const _RwaExposureTableCard({
    required this.rows,
    required this.totalRwa,
  });

  final List<ConcentrationExposureDetail> rows;
  final double totalRwa;

  @override
  State<_RwaExposureTableCard> createState() => _RwaExposureTableCardState();
}

class _RwaExposureTableCardState extends State<_RwaExposureTableCard> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  String? _selectedRowId;
  var _sortColumnIndex = 5;
  var _sortAscending = false;

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final sortedRows = _sortedRows(rows);

    return SectionCard(
      title: '',
      child: rows.isEmpty
          ? const _EmptyInline(
              message:
                  'Aucune exposition RWA disponible sur le périmètre filtré.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RwaExposureSummaryStrip(
                  rows: rows,
                  totalRwa: widget.totalRwa,
                ),
                const SizedBox(height: 6),
                const _RwaAmountUnitLegend(),
                const SizedBox(height: 6),
                Expanded(child: _buildTable(context, sortedRows)),
              ],
            ),
    );
  }

  List<ConcentrationExposureDetail> _sortedRows(
    List<ConcentrationExposureDetail> rows,
  ) {
    final sortedRows = rows.toList(growable: false);
    sortedRows.sort((left, right) {
      final comparison = _compareRows(left, right, _sortColumnIndex);
      if (comparison != 0) {
        return _sortAscending ? comparison : -comparison;
      }
      return _compareText(left.id, right.id);
    });
    return sortedRows;
  }

  int _compareRows(
    ConcentrationExposureDetail left,
    ConcentrationExposureDetail right,
    int columnIndex,
  ) {
    return switch (columnIndex) {
      0 => _compareText(left.id, right.id),
      1 => _compareText(left.counterpartyName, right.counterpartyName),
      2 => _compareText(left.prudentialCategory, right.prudentialCategory),
      3 => _compareText(left.country, right.country),
      4 => left.ead.compareTo(right.ead),
      5 => left.rwa.compareTo(right.rwa),
      6 => left.riskWeight.compareTo(right.riskWeight),
      7 => left.crmCoverageRatio.compareTo(right.crmCoverageRatio),
      8 => _rwaContribution(left).compareTo(_rwaContribution(right)),
      _ => 0,
    };
  }

  int _compareText(String left, String right) {
    return left.toLowerCase().compareTo(right.toLowerCase());
  }

  double _rwaContribution(ConcentrationExposureDetail row) {
    if (widget.totalRwa <= 0) return 0;
    return row.rwa / widget.totalRwa;
  }

  void _sortByColumn(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = !_isNumericRwaColumn(columnIndex);
      }
    });

    if (_verticalController.hasClients) {
      _verticalController.jumpTo(0);
    }
  }

  bool _isNumericRwaColumn(int columnIndex) {
    return switch (columnIndex) {
      4 || 5 || 6 || 7 || 8 => true,
      _ => false,
    };
  }

  List<_RwaExposureColumnSpec> _expandedColumnsForWidth(
    double availableWidth,
    int fixedColumnIndex,
    List<int> scrollableColumnIndexes,
  ) {
    final fixedWidth = _rwaExposureColumns[fixedColumnIndex].width;
    final scrollableViewport = math.max(0.0, availableWidth - fixedWidth);
    final baseScrollableWidth = scrollableColumnIndexes.fold<double>(
      0.0,
      (sum, index) => sum + _rwaExposureColumns[index].width,
    );

    if (scrollableViewport <= baseScrollableWidth || baseScrollableWidth <= 0) {
      return _rwaExposureColumns;
    }

    final extraWidth = scrollableViewport - baseScrollableWidth;
    return List<_RwaExposureColumnSpec>.generate(
      _rwaExposureColumns.length,
      (index) {
        final column = _rwaExposureColumns[index];
        if (!scrollableColumnIndexes.contains(index)) {
          return column;
        }
        final ratio = column.width / baseScrollableWidth;
        return column.copyWith(width: column.width + extraWidth * ratio);
      },
      growable: false,
    );
  }

  Widget _buildTable(
    BuildContext context,
    List<ConcentrationExposureDetail> rows,
  ) {
    const headerHeight = 38.0;
    const rowHeight = 45.0;
    final bodyHeight = rows.length <= 7 ? rows.length * rowHeight : 306.0;
    final tableHeight = headerHeight + bodyHeight;
    const leftColumnIndex = 0;
    final scrollableColumnIndexes = List<int>.generate(
      _rwaExposureColumns.length - 1,
      (index) => index + 1,
      growable: false,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveColumns = _expandedColumnsForWidth(
          constraints.maxWidth,
          leftColumnIndex,
          scrollableColumnIndexes,
        );
        final scrollableColumns = scrollableColumnIndexes
            .map((index) => effectiveColumns[index])
            .toList(growable: false);
        final scrollableWidth = scrollableColumns.fold<double>(
          0.0,
          (sum, column) => sum + column.width,
        );
        final fixedWidth = effectiveColumns[leftColumnIndex].width;
        final centerViewportWidth =
            math.max(0.0, constraints.maxWidth - fixedWidth);
        final needsHorizontalScroll = scrollableWidth > centerViewportWidth;

        return Container(
          height: tableHeight,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(_concentrationRadius),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RwaExposurePinnedColumn(
                rows: rows,
                columns: effectiveColumns,
                columnIndex: leftColumnIndex,
                totalRwa: widget.totalRwa,
                verticalController: _verticalController,
                headerHeight: headerHeight,
                rowHeight: rowHeight,
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                onSort: _sortByColumn,
                selectedRowId: _selectedRowId,
                onRowSelected: _selectRow,
              ),
              Expanded(
                child: Scrollbar(
                  controller: _horizontalController,
                  thumbVisibility: needsHorizontalScroll,
                  notificationPredicate: (notification) =>
                      notification.metrics.axis == Axis.horizontal,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: scrollableWidth,
                      height: tableHeight,
                      child: Column(
                        children: [
                          _RwaExposureTableHeader(
                            columns: scrollableColumns,
                            columnIndexes: scrollableColumnIndexes,
                            sortColumnIndex: _sortColumnIndex,
                            sortAscending: _sortAscending,
                            onSort: _sortByColumn,
                          ),
                          Expanded(
                            child: Scrollbar(
                              controller: _verticalController,
                              thumbVisibility: rows.length > 7,
                              notificationPredicate: (notification) =>
                                  notification.metrics.axis == Axis.vertical,
                              child: ListView.builder(
                                controller: _verticalController,
                                physics: const ClampingScrollPhysics(),
                                itemExtent: rowHeight,
                                itemCount: rows.length,
                                itemBuilder: (context, index) {
                                  return _RwaExposureDataRow(
                                    row: rows[index],
                                    index: index,
                                    totalRwa: widget.totalRwa,
                                    columns: effectiveColumns,
                                    columnIndexes: scrollableColumnIndexes,
                                    selected: _selectedRowId == rows[index].id,
                                    onSelected: _selectRow,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectRow(ConcentrationExposureDetail row) {
    if (_selectedRowId == row.id) return;
    setState(() => _selectedRowId = row.id);
  }
}

class _RwaExposureSummaryStrip extends StatelessWidget {
  const _RwaExposureSummaryStrip({
    required this.rows,
    required this.totalRwa,
  });

  final List<ConcentrationExposureDetail> rows;
  final double totalRwa;

  @override
  Widget build(BuildContext context) {
    final totalEad = rows.fold<double>(0.0, (sum, item) => sum + item.ead);
    final averageRiskWeight = totalEad <= 0 ? 0.0 : totalRwa / totalEad;
    final topExposure = rows.first;
    final topShare =
        totalRwa <= 0 ? 0.0 : (topExposure.rwa / totalRwa).clamp(0.0, 1.0);
    final defaultCount = rows.where((item) => item.isDefault).length;
    final tiles = [
      _RwaSummaryTile(
        label: 'RWA total',
        value: _amountMd(totalRwa),
        caption: 'capital consommé',
        color: AppTheme.accent,
      ),
      _RwaSummaryTile(
        label: 'EAD total',
        value: _amountMd(totalEad),
        caption: 'base exposée',
        color: AppTheme.success,
      ),
      _RwaSummaryTile(
        label: 'RW moyen',
        value: AppFormatters.percent(averageRiskWeight),
        caption: 'pondération moyenne',
        color: _riskWeightColor(averageRiskWeight),
      ),
      _RwaSummaryTile(
        label: 'Plus fort contributeur',
        value: AppFormatters.percent(topShare.toDouble()),
        caption: topExposure.counterpartyName,
        color: AppTheme.warning,
      ),
      _RwaSummaryTile(
        label: 'Défauts',
        value: '$defaultCount',
        caption: 'expositions marquées',
        color: defaultCount > 0 ? AppTheme.danger : AppTheme.success,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          AppTheme.accent.withValues(alpha: 0.035),
          Theme.of(context).cardColor,
        ),
        borderRadius: BorderRadius.circular(_concentrationRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 6.0;
          if (constraints.maxWidth >= 760) {
            return Row(
              children: [
                for (var index = 0; index < tiles.length; index++) ...[
                  Expanded(child: tiles[index]),
                  if (index != tiles.length - 1) const SizedBox(width: gap),
                ],
              ],
            );
          }

          final tileWidth = (constraints.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final tile in tiles)
                SizedBox(
                  width: tileWidth,
                  child: tile,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RwaSummaryTile extends StatelessWidget {
  const _RwaSummaryTile({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  final String label;
  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final surface = Color.alphaBlend(
      color.withValues(alpha: 0.022),
      Theme.of(context).cardColor,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_concentrationRadius),
        border: Border.all(
          color: color.withValues(alpha: 0.34),
          width: 0.85,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.muted,
                  fontSize: 10.2,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
          ),
        ],
      ),
    );
  }
}

class _RwaAmountUnitLegend extends StatelessWidget {
  const _RwaAmountUnitLegend();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: AppColors.concentrationPrimary,
          borderRadius: BorderRadius.circular(_concentrationRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.concentrationPrimary.withValues(alpha: 0.16),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.number,
              size: 12,
              color: Colors.white,
            ),
            const SizedBox(width: 5),
            Text(
              'Montants en ${_amountUnitFcfaLabel()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontSize: 10.4,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RwaExposureTableHeader extends StatelessWidget {
  const _RwaExposureTableHeader({
    required this.columns,
    required this.columnIndexes,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
  });

  final List<_RwaExposureColumnSpec> columns;
  final List<int> columnIndexes;
  final int sortColumnIndex;
  final bool sortAscending;
  final ValueChanged<int> onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      color: AppTheme.sidebarLight,
      child: Row(
        children: [
          for (var index = 0; index < columns.length; index++)
            _RwaExposureHeaderCell(
              column: columns[index],
              columnIndex: columnIndexes[index],
              sorted: sortColumnIndex == columnIndexes[index],
              ascending: sortAscending,
              onSort: onSort,
            ),
        ],
      ),
    );
  }
}

class _RwaExposureHeaderCell extends StatelessWidget {
  const _RwaExposureHeaderCell({
    required this.column,
    required this.columnIndex,
    required this.sorted,
    required this.ascending,
    required this.onSort,
  });

  final _RwaExposureColumnSpec column;
  final int columnIndex;
  final bool sorted;
  final bool ascending;
  final ValueChanged<int> onSort;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: column.width,
      height: double.infinity,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSort(columnIndex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: sorted
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: sorted
                      ? Colors.white.withValues(alpha: 0.78)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: _headerAlignment(column.align),
                  child: Padding(
                    padding: EdgeInsets.only(right: sorted ? 12 : 0),
                    child: Text(
                      column.label,
                      textAlign: column.align,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontSize: 11.2,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                            height: 1,
                          ),
                    ),
                  ),
                ),
                if (sorted)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      ascending
                          ? CupertinoIcons.chevron_up
                          : CupertinoIcons.chevron_down,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Alignment _headerAlignment(TextAlign align) {
  return switch (align) {
    TextAlign.right || TextAlign.end => Alignment.centerRight,
    TextAlign.center || TextAlign.justify => Alignment.center,
    _ => Alignment.centerLeft,
  };
}

class _RwaExposurePinnedColumn extends StatelessWidget {
  const _RwaExposurePinnedColumn({
    required this.rows,
    required this.columns,
    required this.columnIndex,
    required this.totalRwa,
    required this.verticalController,
    required this.headerHeight,
    required this.rowHeight,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
    required this.selectedRowId,
    required this.onRowSelected,
  });

  final List<ConcentrationExposureDetail> rows;
  final List<_RwaExposureColumnSpec> columns;
  final int columnIndex;
  final double totalRwa;
  final ScrollController verticalController;
  final double headerHeight;
  final double rowHeight;
  final int sortColumnIndex;
  final bool sortAscending;
  final ValueChanged<int> onSort;
  final String? selectedRowId;
  final ValueChanged<ConcentrationExposureDetail> onRowSelected;

  @override
  Widget build(BuildContext context) {
    final column = columns[columnIndex];
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.76);
    final shadowColor = const Color(0xFF0F172A).withValues(alpha: 0.08);
    final pinnedRows = Column(
      children: List.generate(
        rows.length,
        (index) => SizedBox(
          height: rowHeight,
          child: _RwaExposureDataRow(
            row: rows[index],
            index: index,
            totalRwa: totalRwa,
            columns: columns,
            columnIndexes: [columnIndex],
            selected: selectedRowId == rows[index].id,
            onSelected: onRowSelected,
            showSelectionStripe: true,
          ),
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          right: BorderSide(color: dividerColor),
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SizedBox(
        width: column.width,
        child: Column(
          children: [
            SizedBox(
              height: headerHeight,
              child: _RwaExposureTableHeader(
                columns: [column],
                columnIndexes: [columnIndex],
                sortColumnIndex: sortColumnIndex,
                sortAscending: sortAscending,
                onSort: onSort,
              ),
            ),
            Expanded(
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: verticalController,
                  builder: (context, child) {
                    final offset = verticalController.hasClients
                        ? verticalController.offset
                        : 0.0;
                    return Transform.translate(
                      offset: Offset(0, -offset),
                      child: child,
                    );
                  },
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: SizedBox(
                      height: rows.length * rowHeight,
                      child: pinnedRows,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RwaExposureDataRow extends StatefulWidget {
  const _RwaExposureDataRow({
    required this.row,
    required this.index,
    required this.totalRwa,
    required this.columns,
    required this.columnIndexes,
    required this.selected,
    required this.onSelected,
    this.showSelectionStripe = false,
  });

  final ConcentrationExposureDetail row;
  final int index;
  final double totalRwa;
  final List<_RwaExposureColumnSpec> columns;
  final List<int> columnIndexes;
  final bool selected;
  final ValueChanged<ConcentrationExposureDetail> onSelected;
  final bool showSelectionStripe;

  @override
  State<_RwaExposureDataRow> createState() => _RwaExposureDataRowState();
}

class _RwaExposureDataRowState extends State<_RwaExposureDataRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final rwaShare = widget.totalRwa <= 0
        ? 0.0
        : (row.rwa / widget.totalRwa).clamp(0.0, 1.0).toDouble();
    final riskColor = _riskWeightColor(row.riskWeight);
    final baseColor = widget.selected
        ? AppTheme.accent.withValues(alpha: 0.12)
        : widget.index.isEven
            ? Theme.of(context).cardColor
            : Color.alphaBlend(
                AppTheme.accent.withValues(alpha: 0.025),
                Theme.of(context).cardColor,
              );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = true); }),

      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = false); }),

      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSelected(row),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: _hovered && !widget.selected
                ? Color.alphaBlend(
                    AppTheme.accent.withValues(alpha: 0.055),
                    Theme.of(context).cardColor,
                  )
                : baseColor,
          ),
          foregroundDecoration: BoxDecoration(
            border: Border(
              left: widget.selected && widget.showSelectionStripe
                  ? const BorderSide(color: AppTheme.accent, width: 2.5)
                  : BorderSide.none,
              bottom: BorderSide(
                color: widget.selected
                    ? AppTheme.accent.withValues(alpha: 0.26)
                    : Theme.of(context).dividerColor.withValues(alpha: 0.72),
              ),
            ),
          ),
          child: Row(
            children: [
              for (final columnIndex in widget.columnIndexes)
                _buildCell(
                  context,
                  columnIndex,
                  row,
                  rwaShare,
                  riskColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    int columnIndex,
    ConcentrationExposureDetail row,
    double rwaShare,
    Color riskColor,
  ) {
    final spec = widget.columns[columnIndex];
    return switch (columnIndex) {
      0 => _RwaTextCell(
          spec: spec,
          child: Text(
            row.id,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.text,
                  fontSize: 12,
                  fontFamily: AppTheme.dataFontFamily,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
        ),
      1 => _RwaTextCell(
          spec: spec,
          child: Text(
            row.counterpartyName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      2 => _RwaTextCell(
          spec: spec,
          child: Text(
            row.prudentialCategory,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      3 => _RwaTextCell(
          spec: spec,
          child: Text(
            row.country,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      4 => _RwaTextCell(
          spec: spec,
          child: _RwaAmountText(
            label: _amountMd(row.ead, maxDecimals: 5),
            color: AppTheme.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      5 => _RwaTextCell(
          spec: spec,
          child: _RwaAmountText(
            label: _amountMd(row.rwa, maxDecimals: 5),
            color: AppTheme.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
      6 => _RwaTextCell(
          spec: spec,
          child: Align(
            alignment: Alignment.center,
            child: _RwaBadge(
              label: AppFormatters.percent(row.riskWeight),
              color: riskColor,
            ),
          ),
        ),
      7 => _RwaTextCell(
          spec: spec,
          child: Align(
            alignment: Alignment.center,
            child: _RwaBadge(
              label: AppFormatters.percent(row.crmCoverageRatio),
              color: _crmCoverageColor(row.crmCoverageRatio),
            ),
          ),
        ),
      8 => _RwaTextCell(
          spec: spec,
          child: _RwaShareCell(share: rwaShare),
        ),
      _ => _RwaTextCell(
          spec: spec,
          child: const SizedBox.shrink(),
        ),
    };
  }
}

class _RwaTextCell extends StatelessWidget {
  const _RwaTextCell({
    required this.spec,
    required this.child,
  });

  final _RwaExposureColumnSpec spec;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: spec.width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: DefaultTextStyle.merge(
          textAlign: spec.align,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
          child: child,
        ),
      ),
    );
  }
}

class _RwaAmountText extends StatelessWidget {
  const _RwaAmountText({
    required this.label,
    required this.color,
    required this.fontWeight,
  });

  final String label;
  final Color color;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          label,
          maxLines: 1,
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontSize: 12,
                fontWeight: fontWeight,
                height: 1,
              ),
        ),
      ),
    );
  }
}

class _RwaShareCell extends StatelessWidget {
  const _RwaShareCell({required this.share});

  final double share;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppFormatters.percent(share),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.text,
                fontSize: 11.6,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(_concentrationRadius),
          child: Stack(
            children: [
              Container(
                height: 4,
                color: AppTheme.border.withValues(alpha: 0.72),
              ),
              FractionallySizedBox(
                widthFactor: share.clamp(0.0, 1.0).toDouble(),
                child: Container(
                  height: 4,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Color _crmCoverageColor(double value) {
  if (value >= 0.50) return AppTheme.success;
  if (value > 0) return AppColors.qualityAverage;
  return AppTheme.muted;
}

class _RwaBadge extends StatelessWidget {
  const _RwaBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 58),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(_concentrationRadius),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: 10.4,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
      ),
    );
  }
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
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _RiskWeightLegend extends StatelessWidget {
  const _RiskWeightLegend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RiskWeightLegendItem(label: 'EAD', color: AppColors.riskWeightGreen),
        SizedBox(width: 10),
        _RiskWeightLegendItem(label: 'RWA', color: AppColors.riskWeightDark),
      ],
    );
  }
}

class _RiskWeightLegendItem extends StatelessWidget {
  const _RiskWeightLegendItem({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(_concentrationRadius),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
        ),
      ],
    );
  }
}

enum _GeographyCardMode { countries, zones }

class _IssuerResidenceCountryCard extends StatefulWidget {
  const _IssuerResidenceCountryCard({
    required this.countryRows,
    required this.zoneRows,
  });

  final List<DistributionEntry> countryRows;
  final List<DistributionEntry> zoneRows;

  @override
  State<_IssuerResidenceCountryCard> createState() =>
      _IssuerResidenceCountryCardState();
}

class _IssuerResidenceCountryCardState
    extends State<_IssuerResidenceCountryCard> {
  var _mode = _GeographyCardMode.zones;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppTheme.darkBorder : AppTheme.border;
    final showingCountries = _mode == _GeographyCardMode.countries;
    final title = showingCountries
        ? 'Top 10 des pays de résidence émetteurs'
        : 'Concentration géographique';

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.concentrationPrimary,
                          fontSize: 13.4,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                _GeoCardModeSelector(
                  mode: _mode,
                  onChanged: (mode) => setState(() => _mode = mode),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Divider(color: border),
            const SizedBox(height: 7),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                child: showingCountries
                    ? _IssuerResidenceCountryBars(
                        key: const ValueKey('countries'),
                        rows: widget.countryRows,
                      )
                    : _ZoneDistributionView(
                        key: const ValueKey('zones'),
                        rows: widget.zoneRows,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeoCardModeSelector extends StatelessWidget {
  const _GeoCardModeSelector({
    required this.mode,
    required this.onChanged,
  });

  final _GeographyCardMode mode;
  final ValueChanged<_GeographyCardMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ModeSwitchGroup(
      items: [
        _ModeSwitchItem(
          label: 'Pays',
          icon: CupertinoIcons.flag,
          selected: mode == _GeographyCardMode.countries,
          onTap: () => onChanged(_GeographyCardMode.countries),
        ),
        _ModeSwitchItem(
          label: 'Zones',
          icon: CupertinoIcons.globe,
          selected: mode == _GeographyCardMode.zones,
          onTap: () => onChanged(_GeographyCardMode.zones),
        ),
      ],
    );
  }
}

class _ModeSwitchGroup extends StatelessWidget {
  const _ModeSwitchGroup({required this.items});

  final List<_ModeSwitchItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _ModeSwitchButton(item: items[index]),
          if (index != items.length - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _ModeSwitchItem {
  const _ModeSwitchItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
}

class _ModeSwitchButton extends StatelessWidget {
  const _ModeSwitchButton({required this.item});

  final _ModeSwitchItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.selected ? Colors.white : AppColors.concentrationPrimary;
    final background = item.selected
        ? AppColors.concentrationPrimary
        : AppColors.concentrationPrimary.withValues(alpha: 0.065);

    return Tooltip(
      message: item.label,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(_concentrationRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(_concentrationRadius),
            border: Border.all(
              color: item.selected
                  ? AppColors.concentrationPrimary
                  : AppColors.concentrationPrimary.withValues(alpha: 0.26),
            ),
            boxShadow: item.selected
                ? [
                    BoxShadow(
                      color: AppColors.concentrationPrimary.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 12, color: color),
              const SizedBox(width: 5),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IssuerResidenceCountryBars extends StatelessWidget {
  const _IssuerResidenceCountryBars({
    super.key,
    required this.rows,
  });

  final List<DistributionEntry> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyInline();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final rowHeight = constraints.maxHeight / rows.length;
        return Column(
          children: List.generate(rows.length, (index) {
            final row = rows[index];
            return SizedBox(
              height: rowHeight,
              child: _HorizontalShareRow(
                label: row.label,
                share: row.percentage,
                labelWidth: 124,
                color: AppColors.concentrationPrimary,
              ),
            );
          }),
        );
      },
    );
  }
}

class _ZoneDistributionView extends StatelessWidget {
  const _ZoneDistributionView({
    super.key,
    required this.rows,
  });

  final List<DistributionEntry> rows;

  @override
  Widget build(BuildContext context) {
    final entries = _standardZoneEntries(rows);
    final activeEntries = entries
        .where((item) => item.amount > 0 || item.percentage > 0)
        .toList(growable: false);
    if (activeEntries.isEmpty) {
      return const _EmptyInline(
        message: 'Aucune répartition par zone disponible.',
      );
    }

    final dominant = activeEntries.reduce(
      (left, right) => right.percentage > left.percentage ? right : left,
    );
    final colors = [for (final entry in entries) _geoZoneColor(entry.label)];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        final donutSize = math.min(
          compact ? 116.0 : 132.0,
          math.max(96.0, constraints.maxHeight - 12),
        );
        final legendWidth = compact ? 142.0 : 170.0;
        final metricsWidth = compact ? 104.0 : 118.0;
        final contentWidth = donutSize + legendWidth + metricsWidth + 42;

        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: math.min(constraints.maxWidth, contentWidth),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: donutSize,
                  child: Center(
                    child: _ZoneDonutChart(
                      entries: activeEntries,
                      colors: [
                        for (final entry in activeEntries)
                          _geoZoneColor(entry.label),
                      ],
                      size: donutSize,
                      dominant: dominant,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                SizedBox(
                  width: legendWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var index = 0; index < entries.length; index++)
                        _ZoneLegendRow(
                          entry: entries[index],
                          color: colors[index],
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: metricsWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ZoneMetricTile(
                        label: 'Zone dominante',
                        value: dominant.label,
                        color: _geoZoneColor(dominant.label),
                        emphasize: true,
                      ),
                      const SizedBox(height: 7),
                      _ZoneMetricTile(
                        label: 'Part zone',
                        value: AppFormatters.percent(dominant.percentage),
                        color: _geoZoneColor(dominant.label),
                      ),
                      const SizedBox(height: 7),
                      _ZoneMetricTile(
                        label: 'Exp. zone dominante',
                        value:
                            '${_amountMd(dominant.amount)} ${_amountUnitLabel()}',
                        color: AppColors.riskWeightDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ZoneDonutChart extends StatelessWidget {
  const _ZoneDonutChart({
    required this.entries,
    required this.colors,
    required this.size,
    required this.dominant,
  });

  final List<DistributionEntry> entries;
  final List<Color> colors;
  final double size;
  final DistributionEntry dominant;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _ZoneDonutPainter(entries: entries, colors: colors),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppFormatters.percent(dominant.percentage),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _geoZoneColor(dominant.label),
                      fontSize: size < 120 ? 12.5 : 14,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Dominant',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.muted,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZoneDonutPainter extends CustomPainter {
  const _ZoneDonutPainter({
    required this.entries,
    required this.colors,
  });

  final List<DistributionEntry> entries;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final totalShare =
        entries.fold<double>(0.0, (sum, item) => sum + item.percentage);
    final strokeWidth = size.shortestSide * 0.24;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    paint.color = AppColors.riskWeightTrack.withValues(alpha: 0.72);
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2, false, paint);

    var startAngle = -math.pi / 2;
    for (var index = 0; index < entries.length; index++) {
      final share = totalShare <= 0
          ? 0.0
          : (entries[index].percentage / totalShare).clamp(0.0, 1.0);
      final sweepAngle = share * math.pi * 2;
      if (sweepAngle <= 0) continue;
      paint.color = colors[index % colors.length];
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _ZoneDonutPainter oldDelegate) {
    return oldDelegate.entries != entries || oldDelegate.colors != colors;
  }
}

class _ZoneLegendRow extends StatelessWidget {
  const _ZoneLegendRow({
    required this.entry,
    required this.color,
  });

  final DistributionEntry entry;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(_concentrationRadius),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.text,
                    fontSize: 11.4,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            AppFormatters.percent(entry.percentage),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontSize: 11.2,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
        ],
      ),
    );
  }
}

class _ZoneMetricTile extends StatelessWidget {
  const _ZoneMetricTile({
    required this.label,
    required this.value,
    required this.color,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: emphasize ? 0.12 : 0.075),
        borderRadius: BorderRadius.circular(_concentrationRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.muted,
                  fontSize: 8.4,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontSize: emphasize ? 14.2 : 13.2,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
        ],
      ),
    );
  }
}

List<DistributionEntry> _standardZoneEntries(List<DistributionEntry> rows) {
  const labels = ['UEMOA', 'CEMAC', 'Hors zone'];
  final amounts = <String, double>{
    for (final label in labels) label: 0.0,
  };
  final percentages = <String, double>{
    for (final label in labels) label: 0.0,
  };

  for (final row in rows) {
    final label = _standardZoneLabel(row.label);
    amounts[label] = (amounts[label] ?? 0.0) + row.amount;
    percentages[label] = (percentages[label] ?? 0.0) + row.percentage;
  }

  return [
    for (final label in labels)
      DistributionEntry(
        label: label,
        amount: amounts[label] ?? 0.0,
        percentage: percentages[label] ?? 0.0,
      ),
  ];
}

String _standardZoneLabel(String label) {
  final normalized = label.toLowerCase();
  if (normalized.contains('cemac')) {
    return 'CEMAC';
  }
  if (normalized.contains('uemoa')) {
    return 'UEMOA';
  }
  return 'Hors zone';
}

Color _geoZoneColor(String label) {
  return switch (_standardZoneLabel(label)) {
    'UEMOA' => AppColors.zoneUemoa,
    'CEMAC' => AppColors.zoneCemac,
    _ => AppColors.zoneOutside,
  };
}

class _TopCounterpartyExposureCard extends StatelessWidget {
  const _TopCounterpartyExposureCard({required this.rows});

  final List<ConcentrationExposureRow> rows;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppTheme.darkBorder : AppTheme.border;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 10 des contreparties les plus exposées',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.concentrationPrimary,
                    fontSize: 13.4,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
            ),
            const SizedBox(height: 7),
            Divider(color: border),
            const SizedBox(height: 7),
            Expanded(
              child: _CounterpartyBars(rows: rows),
            ),
          ],
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final rowHeight = constraints.maxHeight / rows.length;
        return Column(
          children: List.generate(rows.length, (index) {
            final row = rows[index];
            return SizedBox(
              height: rowHeight,
              child: _HorizontalShareRow(
                label: row.counterpartyName,
                share: row.share,
                labelWidth: 158,
                color: AppColors.counterpartyBlue,
                valueColor: AppColors.counterpartyBlue,
              ),
            );
          }),
        );
      },
    );
  }
}

class _HorizontalShareRow extends StatefulWidget {
  const _HorizontalShareRow({
    required this.label,
    required this.share,
    required this.labelWidth,
    required this.color,
    this.valueColor,
  });

  final String label;
  final double share;
  final double labelWidth;
  final Color color;
  final Color? valueColor;

  @override
  State<_HorizontalShareRow> createState() => _HorizontalShareRowState();
}

class _HorizontalShareRowState extends State<_HorizontalShareRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final baseShare = widget.share.clamp(0.0, 1.0).toDouble();
    final animatedShare =
        (_hovered ? baseShare * 1.045 : baseShare).clamp(0.0, 1.0).toDouble();
    final labelColor =
        _hovered ? AppTheme.text : AppTheme.text.withValues(alpha: 0.92);
    final valueColor =
        _hovered ? widget.color : widget.valueColor ?? AppColors.concentrationDark;
    final barHeight = _hovered ? 13.0 : 11.0;

    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = true); }),

      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = false); }),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Row(
          children: [
            SizedBox(
              width: widget.labelWidth,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: labelColor,
                          fontSize: 11.4,
                          fontWeight:
                              _hovered ? FontWeight.w700 : FontWeight.w600,
                          height: 1,
                        ) ??
                    TextStyle(
                      color: labelColor,
                      fontSize: 11.4,
                      fontWeight: _hovered ? FontWeight.w700 : FontWeight.w600,
                      height: 1,
                    ),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: animatedShare),
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                builder: (context, widthFactor, _) {
                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        height: barHeight,
                        color: widget.color.withValues(
                          alpha: _hovered ? 0.14 : 0.09,
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: widthFactor,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          height: barHeight,
                          color: widget.color.withValues(
                            alpha: _hovered ? 1 : 0.94,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 56,
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: valueColor.withValues(alpha: _hovered ? 0.14 : 0.09),
                    borderRadius: BorderRadius.circular(_concentrationRadius),
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: valueColor,
                              fontSize: 11.2,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ) ??
                        TextStyle(
                          color: valueColor,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                    child: Text(
                      AppFormatters.percent(widget.share),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RiskWeightCardMode { weights, ratings }

class _RiskWeightDistributionCard extends StatefulWidget {
  const _RiskWeightDistributionCard({
    required this.rows,
    required this.ratingRows,
  });

  final List<RiskWeightBucketRow> rows;
  final List<DistributionEntry> ratingRows;

  @override
  State<_RiskWeightDistributionCard> createState() =>
      _RiskWeightDistributionCardState();
}

class _RiskWeightDistributionCardState
    extends State<_RiskWeightDistributionCard> {
  var _mode = _RiskWeightCardMode.weights;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? AppTheme.darkBorder : AppTheme.border;
    final showingWeights = _mode == _RiskWeightCardMode.weights;
    final title = showingWeights
        ? 'Répartition des pondérations'
        : 'Notations des contreparties';

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.concentrationDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (showingWeights) const _RiskWeightLegend(),
                const SizedBox(width: 8),
                _RiskWeightCardModeSelector(
                  mode: _mode,
                  onChanged: (mode) => setState(() => _mode = mode),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: dividerColor),
            const SizedBox(height: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                child: showingWeights
                    ? _RiskWeightChart(
                        key: const ValueKey('risk-weight-view'),
                        rows: widget.rows,
                      )
                    : _CounterpartyRatingBars(
                        key: const ValueKey('rating-view'),
                        rows: widget.ratingRows,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskWeightCardModeSelector extends StatelessWidget {
  const _RiskWeightCardModeSelector({
    required this.mode,
    required this.onChanged,
  });

  final _RiskWeightCardMode mode;
  final ValueChanged<_RiskWeightCardMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ModeSwitchGroup(
      items: [
        _ModeSwitchItem(
          label: 'Pondérations',
          icon: CupertinoIcons.percent,
          selected: mode == _RiskWeightCardMode.weights,
          onTap: () => onChanged(_RiskWeightCardMode.weights),
        ),
        _ModeSwitchItem(
          label: 'Notations',
          icon: CupertinoIcons.shield_lefthalf_fill,
          selected: mode == _RiskWeightCardMode.ratings,
          onTap: () => onChanged(_RiskWeightCardMode.ratings),
        ),
      ],
    );
  }
}

class _CounterpartyRatingBars extends StatelessWidget {
  const _CounterpartyRatingBars({
    super.key,
    required this.rows,
  });

  final List<DistributionEntry> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyInline();
    }

    final activeRows = rows
        .where((item) => item.amount > 0 || item.percentage > 0)
        .toList(growable: false);
    final dominant = activeRows.isEmpty
        ? null
        : activeRows.reduce(
            (left, right) => right.percentage > left.percentage ? right : left,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RatingSummaryBand(dominant: dominant),
        const SizedBox(height: 7),
        Expanded(child: _RatingBarStrip(rows: rows)),
      ],
    );
  }
}

class _RatingSummaryBand extends StatelessWidget {
  const _RatingSummaryBand({required this.dominant});

  final DistributionEntry? dominant;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.concentrationPrimary;
    final rating = dominant?.label ?? 'N/D';
    final share =
        dominant == null ? '' : AppFormatters.percent(dominant!.percentage);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.055),
          Theme.of(context).cardColor,
        ),
        borderRadius: BorderRadius.circular(_concentrationRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(_concentrationRadius),
            ),
            child: const Icon(
              CupertinoIcons.shield_lefthalf_fill,
              size: 13,
              color: accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lecture notation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.7,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Notation dominante $rating',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.text,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                ),
              ],
            ),
          ),
          if (share.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              share,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingBarStrip extends StatelessWidget {
  const _RatingBarStrip({required this.rows});

  final List<DistributionEntry> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final tight = constraints.maxWidth < 520;
        final gap = tight ? 2.0 : 4.0;
        final availableCellWidth =
            (constraints.maxWidth - gap * (rows.length - 1)) / rows.length;
        final barWidth = tight
            ? 6.0
            : compact
                ? 8.0
                : 10.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              Expanded(
                child: _RatingBarColumn(
                  entry: rows[index],
                  barWidth: barWidth,
                  compact: availableCellWidth < 36,
                ),
              ),
              if (index != rows.length - 1) SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}

class _RatingBarColumn extends StatefulWidget {
  const _RatingBarColumn({
    required this.entry,
    required this.barWidth,
    required this.compact,
  });

  final DistributionEntry entry;
  final double barWidth;
  final bool compact;

  @override
  State<_RatingBarColumn> createState() => _RatingBarColumnState();
}

class _RatingBarColumnState extends State<_RatingBarColumn> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final share = widget.entry.percentage.clamp(0.0, 1.0).toDouble();
    final fill = share;
    final color = _ratingGradeColor(widget.entry.label);

    return Tooltip(
      message: [
        widget.entry.label,
        'Part portefeuille : ${AppFormatters.percent(share)}',
        'Encours : ${_amountMd(widget.entry.amount)} ${_amountUnitFcfaLabel()}',
      ].join('\n'),
      waitDuration: const Duration(milliseconds: 240),
      showDuration: const Duration(seconds: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      preferBelow: false,
      decoration: BoxDecoration(
        color: const Color(0xFF101828),
        borderRadius: BorderRadius.circular(_concentrationRadius),
        border: Border.all(color: color.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 10.4,
        fontWeight: FontWeight.w700,
        height: 1.28,
      ),
      child: MouseRegion(
        onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = true); }),

        onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = false); }),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: 11,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  AppFormatters.percent(share),
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color.withValues(alpha: _hovered ? 1 : 0.92),
                        fontSize: _hovered ? 8.1 : 7.7,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: widget.barWidth,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.riskWeightTrack,
                          borderRadius:
                              BorderRadius.circular(_concentrationRadius),
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: fill),
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return FractionallySizedBox(
                            heightFactor: value,
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: color.withValues(
                                  alpha: _hovered ? 1 : 0.92,
                                ),
                                borderRadius: BorderRadius.circular(
                                  _concentrationRadius,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 12,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.entry.label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.text.withValues(alpha: 0.88),
                        fontSize: widget.compact ? 7.3 : 8.1,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskWeightChart extends StatelessWidget {
  const _RiskWeightChart({
    super.key,
    required this.rows,
  });

  final List<RiskWeightBucketRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyInline();
    }

    final sortedRows = rows.toList(growable: false)
      ..sort((left, right) => left.weight.compareTo(right.weight));
    final totalEad =
        sortedRows.fold<double>(0.0, (sum, item) => sum + item.ead);
    final totalRwa =
        sortedRows.fold<double>(0.0, (sum, item) => sum + item.rwa);
    final averageRiskWeight = totalEad == 0 ? 0.0 : totalRwa / totalEad;
    final dominantRwa = sortedRows.reduce(
      (left, right) => right.rwaShare > left.rwaShare ? right : left,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        const gap = 8.0;
        final cardWidth = math.max(
          compact ? 132.0 : 156.0,
          (constraints.maxWidth - gap * (sortedRows.length - 1)) /
              sortedRows.length,
        );
        final contentWidth =
            cardWidth * sortedRows.length + gap * (sortedRows.length - 1);

        final bucketCards = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < sortedRows.length; index++) ...[
              SizedBox(
                width: cardWidth,
                child: _RiskWeightBucketCard(
                  row: sortedRows[index],
                  isDominant: sortedRows[index] == dominantRwa,
                ),
              ),
              if (index != sortedRows.length - 1)
                SizedBox(
                  width: gap,
                  child: Center(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: AppTheme.border.withValues(alpha: 0.75),
                    ),
                  ),
                ),
            ],
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RiskWeightSummaryBand(
              averageRiskWeight: averageRiskWeight,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: LayoutBuilder(
                builder: (context, bucketConstraints) {
                  if (contentWidth > constraints.maxWidth) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: SizedBox(
                        width: contentWidth,
                        height: bucketConstraints.maxHeight,
                        child: bucketCards,
                      ),
                    );
                  }
                  return bucketCards;
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RiskWeightSummaryBand extends StatelessWidget {
  const _RiskWeightSummaryBand({
    required this.averageRiskWeight,
  });

  final double averageRiskWeight;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.panelAccent;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.055),
          Theme.of(context).cardColor,
        ),
        borderRadius: BorderRadius.circular(_concentrationRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(_concentrationRadius),
            ),
            child: const Icon(
              CupertinoIcons.chart_bar_alt_fill,
              size: 13,
              color: accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lecture capital',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.7,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Pondération moyenne ${AppFormatters.percent(averageRiskWeight)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.text,
                        fontWeight: FontWeight.w700,
                        height: 1,
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

class _RiskWeightBucketCard extends StatefulWidget {
  const _RiskWeightBucketCard({
    required this.row,
    required this.isDominant,
  });

  final RiskWeightBucketRow row;
  final bool isDominant;

  @override
  State<_RiskWeightBucketCard> createState() => _RiskWeightBucketCardState();
}

class _RiskWeightBucketCardState extends State<_RiskWeightBucketCard> {
  @override
  Widget build(BuildContext context) {
    const accent = AppColors.panelAccent;
    final eadShare = widget.row.portfolioShare;
    final rwaShare = widget.row.rwaShare;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(_concentrationRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.row.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.text,
                                  fontSize: 13.6,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _riskWeightTone(widget.row.weight),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.text.withValues(alpha: 0.68),
                        fontSize: 8.2,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _RiskWeightShareMeter(
                    label: 'EAD',
                    share: eadShare,
                    amount: widget.row.ead,
                    shareLabel: 'Part portefeuille',
                    color: AppColors.riskWeightGreen,
                    valueColor: AppColors.riskWeightText,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _RiskWeightShareMeter(
                    label: 'RWA',
                    share: rwaShare,
                    amount: widget.row.rwa,
                    shareLabel: 'Part RWA',
                    color: AppColors.riskWeightDark,
                    valueColor: AppColors.riskWeightDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          _RiskWeightAmountLine(
            ead: widget.row.ead,
            rwa: widget.row.rwa,
            color: accent,
          ),
        ],
      ),
    );
  }
}

class _RiskWeightAmountLine extends StatelessWidget {
  const _RiskWeightAmountLine({
    required this.ead,
    required this.rwa,
    required this.color,
  });

  final double ead;
  final double rwa;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_amountMd(ead)} ${_amountUnitLabel()}',
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.text.withValues(alpha: 0.72),
                    fontSize: 8.4,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
        Icon(
          CupertinoIcons.arrow_right,
          size: 10,
          color: color.withValues(alpha: 0.72),
        ),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '${_amountMd(rwa)} ${_amountUnitLabel()}',
              maxLines: 1,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontSize: 8.4,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RiskWeightShareMeter extends StatefulWidget {
  const _RiskWeightShareMeter({
    required this.label,
    required this.share,
    required this.amount,
    required this.shareLabel,
    required this.color,
    required this.valueColor,
  });

  final String label;
  final double share;
  final double amount;
  final String shareLabel;
  final Color color;
  final Color valueColor;

  @override
  State<_RiskWeightShareMeter> createState() => _RiskWeightShareMeterState();
}

class _RiskWeightShareMeterState extends State<_RiskWeightShareMeter> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final heightFactor = widget.share.clamp(0.0, 1.0).toDouble();

    return Tooltip(
      message: [
        widget.label,
        '${widget.shareLabel.replaceFirst('Part ', '')} : ${AppFormatters.percent(widget.share)}',
        'Encours : ${_amountMd(widget.amount)} ${_amountUnitFcfaLabel()}',
      ].join('\n'),
      waitDuration: const Duration(milliseconds: 220),
      showDuration: const Duration(seconds: 4),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      margin: const EdgeInsets.symmetric(horizontal: 18),
      preferBelow: false,
      verticalOffset: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF101828),
        borderRadius: BorderRadius.circular(_concentrationRadius),
        border: Border.all(color: widget.color.withValues(alpha: 0.46)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 10.4,
        fontWeight: FontWeight.w700,
        height: 1.28,
      ),
      child: MouseRegion(
        onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = true); }),

        onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = false); }),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: widget.valueColor.withValues(
                          alpha: _hovered ? 1 : 0.92,
                        ),
                        fontSize: _hovered ? 8.4 : 8,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ) ??
                  TextStyle(
                    color: widget.valueColor
                        .withValues(alpha: _hovered ? 1 : 0.92),
                    fontSize: _hovered ? 8.4 : 8,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
              child: Text(
                AppFormatters.percent(widget.share),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 30,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: heightFactor),
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    builder: (context, fillFactor, _) {
                      return Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _hovered
                                  ? widget.color.withValues(alpha: 0.13)
                                  : AppColors.riskWeightTrack,
                              borderRadius:
                                  BorderRadius.circular(_concentrationRadius),
                            ),
                          ),
                          FractionallySizedBox(
                            heightFactor: fillFactor,
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    widget.color.withValues(
                                      alpha: _hovered ? 1 : 0.96,
                                    ),
                                    widget.color.withValues(
                                      alpha: _hovered ? 0.92 : 0.78,
                                    ),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  _concentrationRadius,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _ratingGradeColor(String rating) {
  if (rating == 'AAA' || rating.startsWith('AA') || rating.startsWith('A')) {
    return AppColors.ratingInvestment;
  }
  if (rating.startsWith('BBB') || rating.startsWith('BB')) {
    return AppColors.concentrationPrimary;
  }
  if (rating.startsWith('B')) {
    return AppColors.riskWeightDark;
  }
  return AppTheme.muted;
}

Color _riskWeightColor(double weight) {
  if (weight <= 0.001) {
    return const Color(0xFF0F9F6E);
  }
  if (weight <= 0.20) {
    return const Color(0xFF0EA5E9);
  }
  if (weight <= 0.50) {
    return const Color(0xFF4F46E5);
  }
  if (weight <= 0.75) {
    return const Color(0xFFF59E0B);
  }
  if (weight <= 1.0) {
    return const Color(0xFF7C3AED);
  }
  return const Color(0xFFE11D48);
}

String _riskWeightTone(double weight) {
  if (weight <= 0.001) {
    return 'Exposition neutralisée';
  }
  if (weight <= 0.20) {
    return 'Faible consommation';
  }
  if (weight <= 0.50) {
    return 'Risque modéré';
  }
  if (weight <= 0.75) {
    return 'Transition à suivre';
  }
  if (weight <= 1.0) {
    return 'Pondération standard';
  }
  return 'Capital intensif';
}

class _ConcentrationAlertsWorkspace extends StatelessWidget {
  const _ConcentrationAlertsWorkspace({required this.view});

  final _ConcentrationViewModel view;

  @override
  Widget build(BuildContext context) {
    final alerts = view.alerts;

    return Semantics(
      label: 'Alertes et décisions, ${alerts.length} signaux analysés',
      child: _AlertsKpiInfographic(
        alerts: alerts,
        view: view,
      ),
    );
  }
}

List<ConcentrationAlert> _rankedAlerts(List<ConcentrationAlert> alerts) {
  return alerts.toList(growable: false)
    ..sort(
      (left, right) =>
          _severityRank(right.severity).compareTo(_severityRank(left.severity)),
    );
}

String _selectedAlertHeaderTitle(ConcentrationAlert? alert) {
  if (alert == null) {
    return 'Aucune alerte active';
  }
  return _compactAlertHeaderTitle(alert.message);
}

String _compactAlertHeaderTitle(String message) {
  return message
      .replaceAll('des fonds propres estimés', 'des fonds propres')
      .replaceAll(RegExp(r'\.$'), '')
      .trim();
}

List<List<String>> _alertKpiNarratives(
  ConcentrationAlert? alert,
  _ConcentrationViewModel view,
) {
  if (alert == null) {
    return _AlertNarrativeSet.noActiveSignal(view).cards;
  }

  return _AlertNarrativeSet.fromAlert(alert, view).cards;
}

enum _AlertSeverityBand { critical, intermediate, watch }

_AlertSeverityBand _alertSeverityBand(ConcentrationAlert alert) {
  return switch (alert.severity.toLowerCase()) {
    'élevé' || 'eleve' => _AlertSeverityBand.critical,
    'moyen' => _AlertSeverityBand.intermediate,
    _ => _AlertSeverityBand.watch,
  };
}

String _alertSeverityBandLabel(_AlertSeverityBand band) {
  return switch (band) {
    _AlertSeverityBand.critical => 'critique',
    _AlertSeverityBand.intermediate => 'intermédiaire',
    _AlertSeverityBand.watch => 'sous surveillance',
  };
}

String _alertSignalSubject(ConcentrationAlert alert) {
  final compact = _compactAlertHeaderTitle(alert.message);
  final match = RegExp(
    r'^(.*?)\s+(atteint|présente|presente|concentre)\b',
    caseSensitive: false,
  ).firstMatch(compact);
  if (match == null) {
    return compact;
  }
  final subject = match.group(1)?.trim();
  if (subject == null || subject.isEmpty) {
    return alert.level;
  }
  return subject;
}

class _AlertNarrativeSet {
  const _AlertNarrativeSet({
    required this.signal,
    required this.risk,
    required this.impact,
    required this.decision,
    required this.action,
    required this.control,
  });

  factory _AlertNarrativeSet.noActiveSignal(_ConcentrationViewModel view) {
    return _AlertNarrativeSet(
      signal: [
        'La situation observée : aucun seuil de concentration ne déclenche d’alerte active.',
        'La base analysée : le portefeuille porte un EAD de ${_amountMdFcfa(view.totalEad)} et un RWA de ${_amountMdFcfa(view.totalRwa)}.',
        'La granularité du portefeuille : ${view.counterpartyRows.length} contreparties sont suivies avec un HHI de ${view.hhi.toStringAsFixed(0)}.',
      ],
      risk: [
        'La lecture du risque : les seuils internes restent dans une zone de surveillance normale.',
        'La qualité crédit : le NPL ressort à ${AppFormatters.percent(view.quality.nplRatio)} et la PD moyenne atteint ${AppFormatters.percent(view.quality.averagePd)}.',
        'Le cadre prudentiel : le pilotage des concentrations reste aligné avec les principes de revue interne.',
      ],
      impact: [
        'L’impact portefeuille : la diversification demeure compatible avec les limites suivies.',
        'L’impact sur le capital : la consommation de RWA ne crée pas de pression immédiate identifiée.',
        'La résilience attendue : les nouvelles entrées doivent continuer à préserver la dispersion du risque.',
      ],
      decision: [
        'La décision de comité : les limites actuelles et les seuils de vigilance peuvent être conservés.',
        'L’orientation de gestion : les dossiers qui améliorent la granularité doivent rester prioritaires.',
        'La règle d’arbitrage : toute variation anormale d’EAD ou de RWA doit être documentée.',
      ],
      action: [
        'La production nouvelle : l’octroi peut se poursuivre sous contrôle des limites internes.',
        'La gestion des garanties : les sûretés reconnues doivent rester traçables et opposables.',
        'La qualité des données : les ratings, statuts et garanties doivent être revus périodiquement.',
      ],
      control: [
        'Le rythme de contrôle : une revue doit être réalisée à chaque clôture portefeuille.',
        'Les indicateurs suivis : le HHI, le top contrepartie, le top secteur, le top pays et le RWA doivent rester visibles.',
        'La preuve de gouvernance : l’historique des arbitrages et validations doit être conservé.',
      ],
    );
  }

  factory _AlertNarrativeSet.fromAlert(
    ConcentrationAlert alert,
    _ConcentrationViewModel view,
  ) {
    final band = _alertSeverityBand(alert);
    final key = alert.level.toLowerCase();
    return switch (key) {
      'client' => _clientNarrative(alert, view, band),
      'secteur' => _sectorNarrative(alert, view, band),
      'pays' => _countryNarrative(alert, view, band),
      'rwa' => _rwaNarrative(alert, view, band),
      'hhi' => _hhiNarrative(alert, view, band),
      'croissance' => _growthNarrative(alert, view, band),
      _ => _genericNarrative(alert, view, band),
    };
  }

  final List<String> signal;
  final List<String> risk;
  final List<String> impact;
  final List<String> decision;
  final List<String> action;
  final List<String> control;

  List<List<String>> get cards => [
        _compactAlertCard(signal),
        _compactAlertCard(risk),
        _compactAlertCard(impact),
        _compactAlertCard(decision),
        _compactAlertCard(action),
        _compactAlertCard(control),
      ];
}

List<String> _compactAlertCard(List<String> items) {
  return items
      .map(_compactAlertNarrative)
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _compactAlertNarrative(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return '';
  }

  final colonIndex = normalized.indexOf(':');
  if (colonIndex <= 0) {
    return _normalizeAlertNarrativeValue(normalized);
  }

  final label = _compactAlertNarrativeLabel(
    normalized.substring(0, colonIndex).trim(),
  );
  final value = _normalizeAlertNarrativeValue(
    normalized.substring(colonIndex + 1).trim(),
  );
  return '$label: $value';
}

String _compactAlertNarrativeLabel(String label) {
  final key = label.toLowerCase().replaceAll('’', "'");
  const labels = {
    'la situation observée': 'Situation',
    'la base analysée': 'Base',
    'la lecture du risque': 'Risque',
    'la qualité crédit': 'Qualité',
    "l'impact portefeuille": 'Portefeuille',
    "l'impact sur le capital": 'Capital',
    'la décision de comité': 'Comité',
    "l'orientation de gestion": 'Orientation',
    'la production nouvelle': 'Production',
    'la gestion des garanties': 'Garanties',
    'le rythme de contrôle': 'Rythme',
    'les indicateurs suivis': 'Indicateurs',
    'la contrepartie concernée': 'Contrepartie',
    "l'exposition mesurée": 'Exposition',
    'la gravité observée': 'Gravité',
    'la lecture prudentielle': 'Lecture',
    'la perte potentielle': 'Perte',
    'le comité risque': 'Comité',
    "l'arbitrage attendu": 'Arbitrage',
    'la limite opérationnelle': 'Limite',
    'les sûretés mobilisables': 'Sûretés',
    'le secteur concerné': 'Secteur',
    "la base d'exposition": 'Exposition',
    'le choc métier': 'Choc',
    'le pays concerné': 'Pays',
    'le scénario pays': 'Scénario',
    'le rwa concentré': 'RWA',
    'l’exposition dominante': 'Exposition',
    "l'indice hhi": 'HHI',
    'la croissance observée': 'Croissance',
    'la base de comparaison': 'Comparaison',
    'le signal détecté': 'Signal',
  };

  final mapped = labels[key];
  if (mapped != null) {
    return mapped;
  }

  return label.replaceFirst(RegExp(r"^(La|Le|Les|L’|L')\s+"), '').trim();
}

String _normalizeAlertNarrativeValue(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

_AlertNarrativeSet _clientNarrative(
  ConcentrationAlert alert,
  _ConcentrationViewModel view,
  _AlertSeverityBand band,
) {
  final row = _matchingCounterparty(alert, view) ??
      (view.counterpartyRows.isEmpty ? null : view.counterpartyRows.first);
  final name = row?.counterpartyName ?? _alertSignalSubject(alert);
  final details = _detailsForCounterparty(view, name);
  final ownFundsEstimate = view.totalRwa * 0.08 * 1.42;
  final ownFundsRatio = row == null || ownFundsEstimate <= 0
      ? 0.0
      : row.grossAmount / ownFundsEstimate;
  final defaultCount = details.where((item) => item.isDefault).length;
  final crmCoverage = _weightedCrmCoverage(details);
  final rating = _dominantRating(details);

  return _AlertNarrativeSet(
    signal: [
      'La contrepartie concernée : $name représente ${row == null ? 'N/D' : AppFormatters.percent(row.share)} du portefeuille brut.',
      'L’exposition mesurée : son EAD atteint ${_amountMdFcfa(row?.ead ?? 0)}, son RWA atteint ${_amountMdFcfa(row?.rwa ?? 0)} et son RW moyen ressort à ${AppFormatters.percent(row?.averageRiskWeight ?? 0)}.',
      'L’origine du signal : le ratio single-name atteint ${AppFormatters.percent(ownFundsRatio)} des fonds propres estimés.',
    ],
    risk: [
      'La gravité observée : le niveau est ${_alertSeverityBandLabel(band)} parce qu’une seule signature domine le risque.',
      'La lecture prudentielle : une grande exposition doit être suivie dès qu’elle dépasse 10 % des fonds propres.',
      'Les facteurs aggravants : le rating dominant est $rating, la couverture atteint ${AppFormatters.percent(crmCoverage)} et $defaultCount défaut(s) sont recensés.',
    ],
    impact: [
      'La perte potentielle : une défaillance de $name affaiblirait directement la granularité du portefeuille.',
      'L’impact sur le capital : cette exposition mobilise environ ${_amountMdFcfa((row?.rwa ?? 0) * 0.08)} de capital indicatif.',
      'L’effet portefeuille : la marge de diversification dépendra de la réduction nette ou du renforcement des sûretés.',
    ],
    decision: [
      'Le comité risque : il doit acter ${_decisionTempo(band)} sur la limite client et les dépassements.',
      'L’arbitrage attendu : la banque doit réduire, couvrir ou syndiquer l’exposition avant tout nouveau ticket.',
      'La condition d’acceptation : l’exposition doit être validée avec un EAD, un RWA, un rating et des garanties à jour.',
    ],
    action: [
      'La limite opérationnelle : il faut appliquer ${_primaryMeasure(band)} sur les nouvelles expositions non couvertes.',
      'Les sûretés mobilisables : les garanties éligibles, le collatéral ou l’engagement de sortie doivent être renforcés.',
      'Le plan d’exécution : un calendrier daté doit être fixé si le ratio reste au-dessus du seuil interne.',
    ],
    control: [
      'Le rythme de contrôle : ${_controlCadence(band)} doit couvrir l’exposition nette et les garanties.',
      'Les indicateurs suivis : le ratio fonds propres, l’EAD, le RWA, le RW moyen et la couverture CRM doivent être rapprochés.',
      'La preuve de décision : chaque action doit être tracée jusqu’au retour sous seuil ou jusqu’à la validation du comité.',
    ],
  );
}

_AlertNarrativeSet _sectorNarrative(
  ConcentrationAlert alert,
  _ConcentrationViewModel view,
  _AlertSeverityBand band,
) {
  final row = _matchingSector(alert, view) ??
      (view.sectorRows.isEmpty ? null : view.sectorRows.first);
  final sector = row?.sector ?? _alertSignalSubject(alert);

  return _AlertNarrativeSet(
    signal: [
      'Le secteur concerné : le secteur $sector représente ${AppFormatters.percent(row?.share ?? 0)} du portefeuille.',
      'La base d’exposition : ce secteur regroupe ${row?.exposureCount ?? 0} exposition(s), avec un EAD de ${_amountMdFcfa(row?.ead ?? 0)} et un RWA de ${_amountMdFcfa(row?.rwa ?? 0)}.',
      'L’origine du signal : la concentration métier dépasse le seuil interne de diversification.',
    ],
    risk: [
      'La gravité observée : le niveau est ${_alertSeverityBandLabel(band)} en raison d’une corrélation sectorielle accrue.',
      'La lecture prudentielle : le Pilier 2 impose de suivre les concentrations sectorielles et géographiques.',
      'La sensibilité mesurée : le RW moyen atteint ${AppFormatters.percent(row?.averageRiskWeight ?? 0)} et la part RWA ressort à ${AppFormatters.percent(row?.rwaShare ?? 0)}.',
    ],
    impact: [
      'Le choc métier : une dégradation du secteur toucherait plusieurs contreparties liées.',
      'L’impact sur le capital : environ ${_amountMdFcfa((row?.rwa ?? 0) * 0.08)} de capital indicatif dépend de ce secteur.',
      'L’effet portefeuille : la diversification réelle baissera si les nouvelles entrées restent corrélées.',
    ],
    decision: [
      'Le comité risque : il doit acter ${_decisionTempo(band)} sur le plafond sectoriel et la production nouvelle.',
      'L’arbitrage attendu : les nouvelles entrées doivent être réorientées vers des secteurs moins corrélés.',
      'La condition d’acceptation : seuls les dossiers qui améliorent le mix de risque doivent être privilégiés.',
    ],
    action: [
      'Le plafond opérationnel : il faut appliquer ${_primaryMeasure(band)} aux nouveaux tickets du secteur $sector.',
      'La sélection des dossiers : les contreparties mieux notées, garanties ou moins consommatrices de RWA doivent être prioritaires.',
      'Le plan d’exécution : une limite sectorielle et un plan de réallocation doivent être matérialisés.',
    ],
    control: [
      'Le rythme de contrôle : ${_controlCadence(band)} doit suivre le poids sectoriel et les nouvelles entrées.',
      'Les indicateurs suivis : la part brute, la part RWA, le RW moyen et le nombre d’expositions doivent être rapprochés.',
      'La preuve de gouvernance : les arbitrages de comité et les validations d’exception doivent être conservés.',
    ],
  );
}

_AlertNarrativeSet _countryNarrative(
  ConcentrationAlert alert,
  _ConcentrationViewModel view,
  _AlertSeverityBand band,
) {
  final row = _matchingCountry(alert, view) ??
      (view.countryRows.isEmpty ? null : view.countryRows.first);
  final country = row?.label ?? _alertSignalSubject(alert);

  return _AlertNarrativeSet(
    signal: [
      'Le pays concerné : le pays $country concentre ${AppFormatters.percent(row?.portfolioShare ?? 0)} du portefeuille.',
      'La base d’exposition : cette juridiction porte ${row?.exposureCount ?? 0} exposition(s), avec un EAD de ${_amountMdFcfa(row?.ead ?? 0)} et un RWA de ${_amountMdFcfa(row?.rwa ?? 0)}.',
      'L’origine du signal : l’exposition géographique dépasse le seuil pays suivi en interne.',
    ],
    risk: [
      'La gravité observée : le niveau est ${_alertSeverityBandLabel(band)} parce que plusieurs expositions dépendent d’une même juridiction.',
      'La lecture prudentielle : la concentration géographique fait partie des risques à piloter dans la revue interne.',
      'La sensibilité mesurée : le RW moyen atteint ${AppFormatters.percent(row?.averageRiskWeight ?? 0)} et la part RWA ressort à ${AppFormatters.percent(row?.rwaShare ?? 0)}.',
    ],
    impact: [
      'Le scénario pays : un choc souverain ou macroéconomique pourrait se transmettre aux contreparties locales.',
      'L’impact sur le capital : environ ${_amountMdFcfa((row?.rwa ?? 0) * 0.08)} de capital indicatif est exposé à ce pays.',
      'L’effet portefeuille : la diversification baissera si la croissance reste concentrée sur $country.',
    ],
    decision: [
      'Le comité risque : il doit acter ${_decisionTempo(band)} sur le plafond pays et le stress souverain.',
      'L’arbitrage attendu : les entrées non compensées par d’autres juridictions doivent être limitées.',
      'La condition d’acceptation : l’effet pays doit être documenté avant toute nouvelle exposition significative.',
    ],
    action: [
      'Le plafond pays : il faut appliquer ${_primaryMeasure(band)} aux nouveaux dossiers.',
      'Le stress souverain : l’EAD, le RWA et les défauts doivent être testés sous scénario défavorable.',
      'Le plan d’exécution : la production doit être rééquilibrée vers des pays moins concentrés.',
    ],
    control: [
      'Le rythme de contrôle : ${_controlCadence(band)} doit suivre le poids pays et les expositions associées.',
      'Les indicateurs suivis : la part portefeuille, la part RWA, le RW moyen et les nouveaux engagements doivent être rapprochés.',
      'La preuve de gouvernance : la validation risque, le stress test et la décision de limite doivent être tracés.',
    ],
  );
}

_AlertNarrativeSet _rwaNarrative(
  ConcentrationAlert alert,
  _ConcentrationViewModel view,
  _AlertSeverityBand band,
) {
  final rows = view.rwaCounterpartyRows.take(5).toList(growable: false);
  final topFiveRwa = rows.fold<double>(0.0, (sum, item) => sum + item.rwa);
  final share = view.totalRwa <= 0 ? 0.0 : topFiveRwa / view.totalRwa;
  final leader = rows.isEmpty ? null : rows.first;

  return _AlertNarrativeSet(
    signal: [
      'Le RWA concentré : les ${rows.length} premières contreparties portent ${AppFormatters.percent(share)} du RWA total.',
      'L’exposition dominante : ${leader?.counterpartyName ?? 'N/D'} porte à elle seule ${_amountMdFcfa(leader?.rwa ?? 0)} de RWA.',
      'L’origine du signal : le capital réglementaire est concentré sur un nombre réduit d’expositions.',
    ],
    risk: [
      'La gravité observée : le niveau est ${_alertSeverityBandLabel(band)} parce que la consommation de capital dépend de peu d’expositions.',
      'La lecture prudentielle : les RWA doivent rester traçables par exposition et par facteur de risque.',
      'La sensibilité mesurée : le top 5 porte ${_amountMdFcfa(topFiveRwa)} sur un RWA total de ${_amountMdFcfa(view.totalRwa)}.',
    ],
    impact: [
      'L’impact sur le capital : environ ${_amountMdFcfa(topFiveRwa * 0.08)} de capital indicatif dépend du top 5.',
      'L’effet portefeuille : une erreur de rating, de pondération ou de garantie pèserait fortement sur le ratio.',
      'La résilience attendue : l’effet de diversification restera faible si les expositions RWA restent dominantes.',
    ],
    decision: [
      'Le comité risque : il doit acter ${_decisionTempo(band)} sur les expositions les plus consommatrices de capital.',
      'L’arbitrage attendu : les ratings, les garanties reconnues et le rendement prudentiel doivent être revus.',
      'La condition d’acceptation : les actifs qui réduisent le RWA sans déplacer le risque doivent être prioritaires.',
    ],
    action: [
      'L’optimisation RWA : il faut appliquer ${_primaryMeasure(band)} aux expositions dominantes.',
      'Les leviers disponibles : le collatéral éligible, les sûretés opposables, les garanties ou la réduction nette doivent être étudiés.',
      'Le plan d’exécution : les actions doivent être classées par gain RWA, coût commercial et délai.',
    ],
    control: [
      'Le rythme de contrôle : ${_controlCadence(band)} doit suivre le top 5 RWA et les changements de pondération.',
      'Les indicateurs suivis : le RWA, l’EAD, le RW moyen, le rating, la garantie et la contribution au capital doivent être rapprochés.',
      'La preuve de calcul : le résultat avant et après arbitrage prudentiel doit être conservé.',
    ],
  );
}

_AlertNarrativeSet _hhiNarrative(
  ConcentrationAlert alert,
  _ConcentrationViewModel view,
  _AlertSeverityBand band,
) {
  return _AlertNarrativeSet(
    signal: [
      'L’indice HHI : il atteint ${view.hhi.toStringAsFixed(0)} et traduit une granularité ${view.hhiBadge.toLowerCase()}.',
      'La base analysée : le portefeuille contient ${view.counterpartyRows.length} contreparties suivies.',
      'L’origine du signal : les grandes expositions portent un poids élevé, notamment ${view.topCounterpartyName}.',
    ],
    risk: [
      'La gravité observée : le niveau est ${_alertSeverityBandLabel(band)} parce que la diversification globale se dégrade.',
      'La lecture prudentielle : le capital standard ne capture pas toujours toute la vulnérabilité des portefeuilles peu granulaires.',
      'La sensibilité mesurée : la première contrepartie pèse ${AppFormatters.percent(view.topCounterpartyShare)} et le premier secteur pèse ${AppFormatters.percent(view.topSectorShare)}.',
    ],
    impact: [
      'L’effet portefeuille : la résilience baisse si plusieurs grands débiteurs se dégradent en même temps.',
      'L’impact sur le capital : le RWA total de ${_amountMdFcfa(view.totalRwa)} dépend d’une base peu dispersée.',
      'Le pilotage attendu : une limite de concentration complète doit compléter le suivi du RWA.',
    ],
    decision: [
      'Le comité risque : il doit acter ${_decisionTempo(band)} sur le seuil HHI et l’appétit de concentration.',
      'L’arbitrage attendu : les grandes expositions doivent être abaissées ou les limites d’entrée doivent être renforcées.',
      'La condition d’acceptation : le top 10 ne doit pas augmenter sans compensation de diversification.',
    ],
    action: [
      'La diversification attendue : il faut appliquer ${_primaryMeasure(band)} aux plus fortes expositions.',
      'Les leviers disponibles : les nouveaux noms, la syndication, les remboursements ciblés ou les garanties renforcées doivent être utilisés.',
      'Le plan d’exécution : une trajectoire de baisse graduelle du HHI doit être suivie.',
    ],
    control: [
      'Le rythme de contrôle : ${_controlCadence(band)} doit suivre le HHI et le poids des grandes expositions.',
      'Les indicateurs suivis : le HHI, le top 1, le top 3, le top secteur, le top pays et le RWA concentré doivent être rapprochés.',
      'La preuve de gouvernance : les décisions qui améliorent ou dégradent la granularité doivent être tracées.',
    ],
  );
}

_AlertNarrativeSet _growthNarrative(
  ConcentrationAlert alert,
  _ConcentrationViewModel view,
  _AlertSeverityBand band,
) {
  final previous =
      view.trends.length < 2 ? null : view.trends[view.trends.length - 2];
  final current = view.trends.isEmpty ? null : view.trends.last;
  final growth = previous == null || previous.ead <= 0 || current == null
      ? 0.0
      : (current.ead - previous.ead) / previous.ead;

  return _AlertNarrativeSet(
    signal: [
      'La croissance observée : l’EAD progresse de ${AppFormatters.percent(growth)} sur la dernière période.',
      'La base de comparaison : l’EAD courant atteint ${_amountMdFcfa(current?.ead ?? view.totalEad)} contre ${_amountMdFcfa(previous?.ead ?? 0)} sur la période précédente.',
      'L’origine du signal : les engagements augmentent rapidement avant la stabilisation complète des limites.',
    ],
    risk: [
      'La gravité observée : le niveau est ${_alertSeverityBandLabel(band)} parce que la dynamique d’entrée accélère.',
      'La lecture prudentielle : la revue interne doit prévenir l’accumulation rapide de risques corrélés.',
      'La sensibilité mesurée : le RWA courant atteint ${_amountMdFcfa(current?.rwa ?? view.totalRwa)} et le NPL ressort à ${AppFormatters.percent(current?.npl ?? view.quality.nplRatio)}.',
    ],
    impact: [
      'L’effet portefeuille : la croissance peut masquer une concentration client, secteur ou pays.',
      'L’impact sur le capital : la consommation de RWA augmente si les nouveaux dossiers sont fortement pondérés.',
      'La qualité d’entrée : le rating, la PD, la LGD et les garanties doivent être contrôlés avant l’extension.',
    ],
    decision: [
      'Le comité risque : il doit acter ${_decisionTempo(band)} sur les nouveaux tickets et la qualité d’entrée.',
      'L’arbitrage attendu : seuls les flux qui respectent les limites et le rendement RWA doivent être acceptés.',
      'La condition d’acceptation : chaque hausse doit être rattachée à une origine client, secteur, pays ou produit.',
    ],
    action: [
      'La production nouvelle : il faut appliquer ${_primaryMeasure(band)} aux engagements non validés.',
      'Le contrôle préalable : le rating, les garanties, le statut défaut et l’effet RWA doivent être vérifiés avant tirage.',
      'Le plan d’exécution : les nouveaux dossiers qui dégradent les concentrations existantes doivent être isolés.',
    ],
    control: [
      'Le rythme de contrôle : ${_controlCadence(band)} doit suivre les entrées, les sorties et les variations de RWA.',
      'Les indicateurs suivis : la croissance EAD, la variation RWA, le NPL, le HHI et la concentration par segment doivent être rapprochés.',
      'La preuve de gouvernance : le rapprochement entre les flux commerciaux et les limites de risque doit être conservé.',
    ],
  );
}

_AlertNarrativeSet _genericNarrative(
  ConcentrationAlert alert,
  _ConcentrationViewModel view,
  _AlertSeverityBand band,
) {
  return _AlertNarrativeSet(
    signal: [
      'Le signal détecté : ${_compactAlertHeaderTitle(alert.message)}.',
      'La base analysée : le portefeuille porte un EAD de ${_amountMdFcfa(view.totalEad)} et un RWA de ${_amountMdFcfa(view.totalRwa)}.',
      'L’origine probable : ${alert.recommendation}',
    ],
    risk: [
      'La gravité observée : le niveau est ${_alertSeverityBandLabel(band)} selon le seuil détecté.',
      'La lecture du risque : le signal doit être rapproché des limites internes et du capital mobilisé.',
      'Le cadre prudentiel : le pilotage des expositions concentrées doit rester documenté.',
    ],
    impact: [
      'L’effet portefeuille : l’impact sur la diversification, la qualité et le capital doit être vérifié.',
      'L’impact sur le capital : la contribution RWA liée au signal doit être isolée.',
      'La qualité crédit : la PD, la LGD, les défauts et les garanties disponibles doivent être rapprochés.',
    ],
    decision: [
      'Le comité risque : il doit acter ${_decisionTempo(band)} avec une justification documentée.',
      'L’arbitrage attendu : l’exposition doit être réduite, couverte ou acceptée sous condition.',
      'La condition d’acceptation : l’exposition ne doit pas être étendue sans validation risque.',
    ],
    action: [
      'La mesure opérationnelle : il faut appliquer ${_primaryMeasure(band)} jusqu’à stabilisation.',
      'Les leviers disponibles : la limite, la garantie, le rating, l’échéancier ou la réduction nette doivent être examinés.',
      'Le plan d’exécution : un responsable et une date cible doivent être définis.',
    ],
    control: [
      'Le rythme de contrôle : ${_controlCadence(band)} doit suivre le signal et les seuils.',
      'Les indicateurs suivis : l’exposition résiduelle, le RWA, les garanties et la décision comité doivent être rapprochés.',
      'La preuve de gouvernance : la décision et le retour sous seuil doivent être conservés.',
    ],
  );
}

ConcentrationExposureRow? _matchingCounterparty(
  ConcentrationAlert alert,
  _ConcentrationViewModel view,
) {
  final messageKey = _alertSearchKey(alert.message);
  final subjectKey = _alertSearchKey(_alertSignalSubject(alert));
  for (final row in view.counterpartyRows) {
    final rowKey = _alertSearchKey(row.counterpartyName);
    if (messageKey.contains(rowKey) ||
        subjectKey.contains(rowKey) ||
        rowKey.contains(subjectKey)) {
      return row;
    }
  }
  return null;
}

SectorConcentrationRow? _matchingSector(
  ConcentrationAlert alert,
  _ConcentrationViewModel view,
) {
  final messageKey = _alertSearchKey(alert.message);
  final subjectKey = _alertSearchKey(_alertSignalSubject(alert));
  for (final row in view.sectorRows) {
    final rowKey = _alertSearchKey(row.sector);
    if (messageKey.contains(rowKey) ||
        subjectKey.contains(rowKey) ||
        rowKey.contains(subjectKey)) {
      return row;
    }
  }
  return null;
}

ConcentrationBreakdownRow? _matchingCountry(
  ConcentrationAlert alert,
  _ConcentrationViewModel view,
) {
  final messageKey = _alertSearchKey(alert.message);
  final subjectKey = _alertSearchKey(_alertSignalSubject(alert));
  for (final row in view.countryRows) {
    final rowKey = _alertSearchKey(row.label);
    if (messageKey.contains(rowKey) ||
        subjectKey.contains(rowKey) ||
        rowKey.contains(subjectKey)) {
      return row;
    }
  }
  return null;
}

List<ConcentrationExposureDetail> _detailsForCounterparty(
  _ConcentrationViewModel view,
  String counterpartyName,
) {
  final key = _alertSearchKey(counterpartyName);
  return view.exposureDetails
      .where((item) => _alertSearchKey(item.counterpartyName) == key)
      .toList(growable: false);
}

double _weightedCrmCoverage(List<ConcentrationExposureDetail> details) {
  final totalEad = details.fold<double>(0.0, (sum, item) => sum + item.ead);
  if (totalEad <= 0) {
    return 0;
  }
  return details.fold<double>(
        0.0,
        (sum, item) => sum + item.crmCoverageRatio * item.ead,
      ) /
      totalEad;
}

String _dominantRating(List<ConcentrationExposureDetail> details) {
  if (details.isEmpty) {
    return 'N/D';
  }
  final totals = <String, double>{};
  for (final item in details) {
    totals.update(
      item.rating,
      (value) => value + item.ead,
      ifAbsent: () => item.ead,
    );
  }
  final sorted = totals.entries.toList()
    ..sort((left, right) => right.value.compareTo(left.value));
  return sorted.first.key;
}

String _amountMdFcfa(double value) {
  return '${_amountMd(value)} ${_amountUnitFcfaLabel()}';
}

String _alertSearchKey(String value) {
  return value
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('ô', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _decisionTempo(_AlertSeverityBand band) {
  return switch (band) {
    _AlertSeverityBand.critical => 'une décision immédiate',
    _AlertSeverityBand.intermediate => 'une décision de réduction progressive',
    _AlertSeverityBand.watch => 'une surveillance renforcée',
  };
}

String _primaryMeasure(_AlertSeverityBand band) {
  return switch (band) {
    _AlertSeverityBand.critical => 'le blocage des hausses non couvertes',
    _AlertSeverityBand.intermediate =>
      'le conditionnement des nouvelles entrées',
    _AlertSeverityBand.watch => 'le maintien sous seuil de vigilance',
  };
}

String _controlCadence(_AlertSeverityBand band) {
  return switch (band) {
    _AlertSeverityBand.critical => 'un suivi hebdomadaire',
    _AlertSeverityBand.intermediate => 'un suivi mensuel',
    _AlertSeverityBand.watch => 'une revue à chaque clôture',
  };
}

class _KpiInfographicStep {
  const _KpiInfographicStep({
    required this.title,
    required this.color,
    required this.icon,
  });

  final String title;
  final Color color;
  final IconData icon;
}

const List<_KpiInfographicStep> _alertsKpiSteps = [
  _KpiInfographicStep(
    title: 'SIGNAL',
    color: Color(0xFF263B52),
    icon: CupertinoIcons.exclamationmark_shield_fill,
  ),
  _KpiInfographicStep(
    title: 'RISQUE',
    color: Color(0xFFFF8500),
    icon: CupertinoIcons.gauge,
  ),
  _KpiInfographicStep(
    title: 'IMPACT',
    color: Color(0xFF94D600),
    icon: CupertinoIcons.chart_bar_alt_fill,
  ),
  _KpiInfographicStep(
    title: 'DÉCISION',
    color: Color(0xFF11B9B7),
    icon: CupertinoIcons.flag,
  ),
  _KpiInfographicStep(
    title: 'ACTION',
    color: Color(0xFF38A4E8),
    icon: CupertinoIcons.checkmark_rectangle,
  ),
  _KpiInfographicStep(
    title: 'CONTRÔLE',
    color: Color(0xFFB300C8),
    icon: CupertinoIcons.shield_lefthalf_fill,
  ),
];

class _AlertsKpiInfographic extends StatefulWidget {
  const _AlertsKpiInfographic({
    required this.alerts,
    required this.view,
  });

  final List<ConcentrationAlert> alerts;
  final _ConcentrationViewModel view;

  @override
  State<_AlertsKpiInfographic> createState() => _AlertsKpiInfographicState();
}

class _AlertsKpiInfographicState extends State<_AlertsKpiInfographic> {
  var _selectedAlertIndex = 0;

  @override
  void didUpdateWidget(covariant _AlertsKpiInfographic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedAlertIndex >= widget.alerts.length) {
      _selectedAlertIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rankedAlerts = _rankedAlerts(widget.alerts);
    final safeSelectedIndex = rankedAlerts.isEmpty
        ? 0
        : math.min(_selectedAlertIndex, rankedAlerts.length - 1);
    final selectedAlert =
        rankedAlerts.isEmpty ? null : rankedAlerts[safeSelectedIndex];
    final alertTitle = _selectedAlertHeaderTitle(selectedAlert);
    final narratives = _alertKpiNarratives(selectedAlert, widget.view);

    return LayoutBuilder(
      builder: (context, constraints) {
        const minWidth = 900.0;
        const infographicHeight = 440.0;
        final width = math.max(minWidth, constraints.maxWidth);
        final surface = Theme.of(context).cardColor;

        final content = SizedBox(
          width: width,
          height: infographicHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(_concentrationRadius),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF111827).withValues(alpha: 0.055),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: _AlertsKpiInfographicCanvas(
              width: width,
              alertCount: widget.alerts.length,
              alertTitle: alertTitle,
              alerts: rankedAlerts,
              selectedAlertIndex: safeSelectedIndex,
              onAlertSelected: (index) {
                if (index == _selectedAlertIndex) {
                  return;
                }
                setState(() => _selectedAlertIndex = index);
              },
              narratives: narratives,
            ),
          ),
        );

        if (constraints.maxWidth >= minWidth) {
          return content;
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: content,
        );
      },
    );
  }
}

class _AlertsKpiInfographicCanvas extends StatelessWidget {
  const _AlertsKpiInfographicCanvas({
    required this.width,
    required this.alertCount,
    required this.alertTitle,
    required this.alerts,
    required this.selectedAlertIndex,
    required this.onAlertSelected,
    required this.narratives,
  });

  final double width;
  final int alertCount;
  final String alertTitle;
  final List<ConcentrationAlert> alerts;
  final int selectedAlertIndex;
  final ValueChanged<int> onAlertSelected;
  final List<List<String>> narratives;

  @override
  Widget build(BuildContext context) {
    const headerHeight = 82.0;
    const headerGap = 8.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        children: [
          Center(
            child: _KpiHeaderBadge(
              width: math.min(520.0, width - 72),
              height: headerHeight,
              title: 'Alertes ($alertCount)',
              subtitle: alertTitle,
              alerts: alerts,
              selectedAlertIndex: selectedAlertIndex,
              onAlertSelected: onAlertSelected,
            ),
          ),
          const SizedBox(height: headerGap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0;
                    index < _alertsKpiSteps.length;
                    index++) ...[
                  Expanded(
                    child: _KpiStepCard(
                      step: _alertsKpiSteps[index],
                      narrativeItems: narratives[index],
                      index: index < 3 ? index + 1 : index - 2,
                    ),
                  ),
                  if (index == 2)
                    const _AlertGroupDivider(topExtension: headerGap)
                  else if (index != _alertsKpiSteps.length - 1)
                    const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertGroupDivider extends StatelessWidget {
  const _AlertGroupDivider({required this.topExtension});

  final double topExtension;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFE11D48);

    return SizedBox(
      width: 26,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: Offset(0, -topExtension),
              child: SizedBox(
                width: 2.4,
                height: constraints.maxHeight + topExtension,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(_concentrationRadius),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _KpiStepCard extends StatefulWidget {
  const _KpiStepCard({
    required this.step,
    required this.narrativeItems,
    required this.index,
  });

  final _KpiInfographicStep step;
  final List<String> narrativeItems;
  final int index;

  @override
  State<_KpiStepCard> createState() => _KpiStepCardState();
}

class _KpiStepCardState extends State<_KpiStepCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final surface = Color.alphaBlend(
      step.color.withValues(alpha: _hovered ? 0.075 : 0.048),
      Theme.of(context).cardColor,
    );

    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = true); }),

      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = false); }),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(_concentrationRadius),
          border: Border.all(
            color: step.color.withValues(alpha: _hovered ? 0.34 : 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: step.color.withValues(alpha: _hovered ? 0.14 : 0.06),
              blurRadius: _hovered ? 14 : 9,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 31,
                  height: 31,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: step.color,
                    borderRadius: BorderRadius.circular(_concentrationRadius),
                  ),
                  child: Icon(
                    step.icon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.text,
                          fontSize: 12.7,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                  ),
                ),
                Text(
                  widget.index.toString().padLeft(2, '0'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: step.color.withValues(alpha: 0.82),
                        fontSize: 10.2,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(_concentrationRadius),
                ),
                child: _KpiNarrativeList(
                  items: widget.narrativeItems,
                  color: step.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiNarrativeList extends StatelessWidget {
  const _KpiNarrativeList({
    required this.items,
    required this.color,
  });

  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = SizedBox(
          width: constraints.maxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _KpiNarrativeBullet(
                  text: items[index],
                  color: color,
                ),
                if (index != items.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        );

        return Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: content,
          ),
        );
      },
    );
  }
}

class _KpiNarrativeBullet extends StatelessWidget {
  const _KpiNarrativeBullet({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colonIndex = text.indexOf(':');
    final hasLabel = colonIndex > 0;
    final label = hasLabel ? text.substring(0, colonIndex).trimRight() : '';
    final value = hasLabel ? text.substring(colonIndex + 1).trimLeft() : text;
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.text.withValues(alpha: 0.76),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.12,
          letterSpacing: 0,
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5.2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1.5),
            ),
            child: const SizedBox(width: 5.5, height: 5.5),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            textAlign: TextAlign.start,
            softWrap: true,
            text: TextSpan(
              style: baseStyle,
              children: [
                if (hasLabel)
                  TextSpan(
                    text: '$label:\n',
                    style: baseStyle?.copyWith(
                      color: AppTheme.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiHeaderBadge extends StatelessWidget {
  const _KpiHeaderBadge({
    required this.width,
    required this.height,
    required this.title,
    required this.subtitle,
    required this.alerts,
    required this.selectedAlertIndex,
    required this.onAlertSelected,
  });

  final double width;
  final double height;
  final String title;
  final String subtitle;
  final List<ConcentrationAlert> alerts;
  final int selectedAlertIndex;
  final ValueChanged<int> onAlertSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFDFDFD),
              Color(0xFFEDEDED),
            ],
          ),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: AppColors.alertCritical,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFF43113),
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                height: 0.95,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF4B5563),
                    fontSize: 10.6,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1,
                  ),
            ),
            if (alerts.length > 1) ...[
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: SizedBox(
                      height: 16,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: Row(
                          children: [
                            for (var index = 0;
                                index < alerts.length;
                                index++) ...[
                              _KpiAlertSelectorChip(
                                alert: alerts[index],
                                index: index,
                                selected: index == selectedAlertIndex,
                                onSelected: onAlertSelected,
                              ),
                              if (index < alerts.length - 1)
                                const SizedBox(width: 4),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KpiAlertSelectorChip extends StatelessWidget {
  const _KpiAlertSelectorChip({
    required this.alert,
    required this.index,
    required this.selected,
    required this.onSelected,
  });

  final ConcentrationAlert alert;
  final int index;
  final bool selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? const Color(0xFFF43113) : _severityColor(alert.severity);

    return Tooltip(
      richMessage: _alertSelectorTooltipMessage(alert, index, color),
      waitDuration: const Duration(milliseconds: 220),
      showDuration: const Duration(seconds: 6),
      constraints: const BoxConstraints(maxWidth: 330),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      margin: const EdgeInsets.symmetric(horizontal: 18),
      preferBelow: false,
      verticalOffset: 14,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(_concentrationRadius),
        border: Border.all(color: color.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? color : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: selected ? 0.0 : 0.58),
              ),
            ),
            child: Text(
              '${index + 1}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? Colors.white : color,
                    fontSize: 8.1,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

InlineSpan _alertSelectorTooltipMessage(
  ConcentrationAlert alert,
  int index,
  Color color,
) {
  final title = _compactAlertHeaderTitle(alert.message);
  final severity = alert.severity.trim().isEmpty ? 'Signal' : alert.severity;
  final scope = alert.level.trim().isEmpty ? 'Concentration' : alert.level;

  return TextSpan(
    style: const TextStyle(
      color: Colors.white,
      fontSize: 10.4,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    children: [
      TextSpan(
        text: 'Alerte ${(index + 1).toString().padLeft(2, '0')}\n',
        style: TextStyle(
          color: color,
          fontSize: 11.8,
          fontWeight: FontWeight.w900,
          height: 1.2,
        ),
      ),
      TextSpan(
        text: '$severity • $scope\n',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.72),
          fontSize: 9.6,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
      const TextSpan(text: '\n'),
      TextSpan(
        text: title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.6,
          fontWeight: FontWeight.w800,
          height: 1.32,
        ),
      ),
    ],
  );
}

// ignore: unused_element
class _LegacyConcentrationAlertsWorkspace extends StatelessWidget {
  const _LegacyConcentrationAlertsWorkspace({required this.view});

  final _ConcentrationViewModel view;

  @override
  Widget build(BuildContext context) {
    final alerts = view.alerts;
    final highCount =
        alerts.where((item) => item.severity.toLowerCase() == 'élevé').length;
    final mediumCount =
        alerts.where((item) => item.severity.toLowerCase() == 'moyen').length;
    final dominantAlert = alerts.isEmpty ? null : alerts.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AlertsDecisionHero(
          alertCount: alerts.length,
          highCount: highCount,
          mediumCount: mediumCount,
          dominantAlert: dominantAlert,
          topCounterpartyName: view.topCounterpartyName,
          topCounterpartyShare: view.topCounterpartyShare,
          topSectorLabel: view.topSectorLabel,
          topSectorShare: view.topSectorShare,
          hhi: view.hhi,
          hhiBadge: view.hhiBadge,
        ),
        const SizedBox(height: AppTheme.pageGap),
        _AlertPriorityPanel(alerts: alerts),
        const SizedBox(height: AppTheme.pageGap),
        _AlertDetailTable(alerts: alerts),
      ],
    );
  }
}

class _AlertsDecisionHero extends StatelessWidget {
  const _AlertsDecisionHero({
    required this.alertCount,
    required this.highCount,
    required this.mediumCount,
    required this.dominantAlert,
    required this.topCounterpartyName,
    required this.topCounterpartyShare,
    required this.topSectorLabel,
    required this.topSectorShare,
    required this.hhi,
    required this.hhiBadge,
  });

  final int alertCount;
  final int highCount;
  final int mediumCount;
  final ConcentrationAlert? dominantAlert;
  final String topCounterpartyName;
  final double topCounterpartyShare;
  final String topSectorLabel;
  final double topSectorShare;
  final double hhi;
  final String hhiBadge;

  @override
  Widget build(BuildContext context) {
    final severityColor = highCount > 0
        ? AppTheme.danger
        : mediumCount > 0
            ? AppTheme.warning
            : AppTheme.success;
    final title = alertCount == 0
        ? 'Aucune alerte active'
        : highCount > 0
            ? '$highCount alerte(s) prioritaire(s)'
            : '$mediumCount point(s) de vigilance';
    final body = dominantAlert?.message ??
        'Le portefeuille ne présente pas de signal de concentration nécessitant une décision immédiate.';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          severityColor.withValues(alpha: 0.045),
          Theme.of(context).cardColor,
        ),
        borderRadius: BorderRadius.circular(_concentrationRadius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(_concentrationRadius),
            ),
            child: Icon(
              CupertinoIcons.exclamationmark_shield_fill,
              color: severityColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pilotage des concentrations',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                ),
                const SizedBox(height: 7),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              _AlertHeroMetric(
                label: 'Alertes',
                value: '$alertCount',
                color: severityColor,
              ),
              _AlertHeroMetric(
                label: 'Top client',
                value: AppFormatters.percent(topCounterpartyShare),
                detail: topCounterpartyName,
                color: AppTheme.accent,
              ),
              _AlertHeroMetric(
                label: 'Top secteur',
                value: AppFormatters.percent(topSectorShare),
                detail: topSectorLabel,
                color: AppTheme.warning,
              ),
              _AlertHeroMetric(
                label: 'HHI',
                value: hhi.toStringAsFixed(0),
                detail: hhiBadge,
                color: _hhiColor(hhi),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertHeroMetric extends StatelessWidget {
  const _AlertHeroMetric({
    required this.label,
    required this.value,
    required this.color,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 126,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(_concentrationRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrudentialRequirementsPanel extends StatelessWidget {
  const _PrudentialRequirementsPanel({required this.view});

  final _ConcentrationViewModel view;

  @override
  Widget build(BuildContext context) {
    final metrics = _prudentialMetricSpecs(view);
    final minimumMargin = metrics
        .map((item) => item.margin)
        .whereType<double>()
        .fold<double?>(null, (current, item) {
      if (current == null) {
        return item;
      }
      return item < current ? item : current;
    });
    final statusColor = minimumMargin == null || minimumMargin >= 0
        ? AppTheme.success
        : AppTheme.danger;

    return LayoutBuilder(
      builder: (context, constraints) {
        const minWidth = 900.0;
        const panelHeight = 400.0;
        final width = math.max(minWidth, constraints.maxWidth);

        final content = SizedBox(
          width: width,
          height: panelHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(_concentrationRadius),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF111827).withValues(alpha: 0.055),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                children: [
                  Center(
                    child: _PrudentialHeaderBadge(
                      width: math.min(540.0, width - 72),
                      title: 'Exigences prudentielles',
                      statusColor: statusColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var index = 0;
                            index < metrics.length;
                            index++) ...[
                          Expanded(
                            child: _PrudentialMetricCard(
                              metric: metrics[index],
                              index: index + 1,
                            ),
                          ),
                          if (index == 2)
                            const SizedBox(width: 26)
                          else if (index != metrics.length - 1)
                            const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        if (constraints.maxWidth >= minWidth) {
          return content;
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: content,
        );
      },
    );
  }
}

class _PrudentialMetricSpec {
  const _PrudentialMetricSpec({
    required this.title,
    required this.currentLabel,
    required this.thresholdLabel,
    required this.color,
    required this.icon,
    this.thresholdValue,
    this.margin,
    this.description,
  });

  final String title;
  final String currentLabel;
  final String thresholdLabel;
  final String? thresholdValue;
  final Color color;
  final IconData icon;
  final double? margin;
  final String? description;

  bool get compliant => margin == null || margin! >= 0;
}

List<_PrudentialMetricSpec> _prudentialMetricSpecs(
  _ConcentrationViewModel view,
) {
  final riskWeightedAssets = view.totalRwa;
  final exposureMeasure = view.totalEad > 0 ? view.totalEad : view.totalGross;
  final regulatoryCapital = view.totalCapital;
  final cet1 =
      riskWeightedAssets <= 0 ? 0.0 : regulatoryCapital / riskWeightedAssets;
  final tier1 = cet1;
  final solvency = cet1;
  final leverage =
      exposureMeasure <= 0 ? 0.0 : regulatoryCapital / exposureMeasure;
  final conservationBuffer =
      (cet1 - _umoaCet1Minimum).clamp(0.0, double.infinity);

  final trackedMargins = [
    cet1 - _umoaCet1Target,
    tier1 - _umoaTier1Target,
    solvency - _umoaSolvencyTarget,
    leverage - _umoaLeverageMinimum,
    conservationBuffer - _umoaConservationBuffer,
  ];
  final complianceMargin = trackedMargins.reduce(math.min);

  return [
    _PrudentialMetricSpec(
      title: 'CET1',
      currentLabel: AppFormatters.percent(cet1),
      thresholdLabel: 'Seuil à respecter',
      thresholdValue: '7,5 %',
      margin: cet1 - _umoaCet1Target,
      color: AppColors.prudentialCapital,
      icon: CupertinoIcons.shield_fill,
      description:
          'Mesure le noyau dur absorbant les pertes; une marge positive protège la banque avant tension.',
    ),
    _PrudentialMetricSpec(
      title: 'Tier 1',
      currentLabel: AppFormatters.percent(tier1),
      thresholdLabel: 'Seuil à respecter',
      thresholdValue: '8,5 %',
      margin: tier1 - _umoaTier1Target,
      color: AppColors.prudentialTier,
      icon: CupertinoIcons.layers_alt_fill,
      description:
          'Élargit la lecture du capital de base; une faiblesse signale un besoin de renfort ou de baisse RWA.',
    ),
    _PrudentialMetricSpec(
      title: 'Ratio de Solvabilité Global',
      currentLabel: AppFormatters.percent(solvency),
      thresholdLabel: 'Seuil à respecter',
      thresholdValue: '11,5 %',
      margin: solvency - _umoaSolvencyTarget,
      color: AppColors.prudentialSolvency,
      icon: CupertinoIcons.gauge,
      description:
          'Couvre l’ensemble des risques pondérés; c’est le repère central de conformité prudentielle.',
    ),
    _PrudentialMetricSpec(
      title: 'Ratio de Levier',
      currentLabel: AppFormatters.percent(leverage),
      thresholdLabel: 'Norme minimale UMOA',
      thresholdValue: '3 %',
      margin: leverage - _umoaLeverageMinimum,
      color: AppColors.prudentialLeverage,
      icon: CupertinoIcons.arrow_up_right_circle_fill,
      description:
          'Contrôle l’exposition sans pondération, utile quand le bilan grossit malgré des actifs peu risqués.',
    ),
    _PrudentialMetricSpec(
      title: 'Coussin de Conservation',
      currentLabel: AppFormatters.percent(conservationBuffer),
      thresholdLabel: 'Exigence du régulateur',
      thresholdValue: '2,5 %',
      margin: conservationBuffer - _umoaConservationBuffer,
      color: AppColors.prudentialBuffer,
      icon: CupertinoIcons.lock_shield_fill,
      description:
          'Réserve destinée à absorber les chocs sans passer sous les minima réglementaires.',
    ),
    _PrudentialMetricSpec(
      title: 'Marge de Conformité',
      currentLabel:
          '${complianceMargin >= 0 ? '+' : '-'}${_pointsLabel(complianceMargin.abs())}',
      thresholdLabel: 'Écart minimum aux exigences UMOA',
      margin: complianceMargin,
      color: complianceMargin >= 0
          ? AppColors.prudentialTier
          : AppColors.prudentialCompliance,
      icon: complianceMargin >= 0
          ? CupertinoIcons.check_mark_circled_solid
          : CupertinoIcons.exclamationmark_shield_fill,
      description:
          'Retient le ratio le plus fragile; c’est le premier point à corriger pour rester conforme.',
    ),
  ];
}

class _PrudentialHeaderBadge extends StatelessWidget {
  const _PrudentialHeaderBadge({
    required this.width,
    required this.title,
    required this.statusColor,
  });

  final double width;
  final String title;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 58,
      padding: const EdgeInsets.fromLTRB(18, 9, 18, 9),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(48),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.30),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.concentrationDeeper,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
          ),
        ],
      ),
    );
  }
}

class _PrudentialMetricCard extends StatefulWidget {
  const _PrudentialMetricCard({
    required this.metric,
    required this.index,
  });

  final _PrudentialMetricSpec metric;
  final int index;

  @override
  State<_PrudentialMetricCard> createState() => _PrudentialMetricCardState();
}

class _PrudentialMetricCardState extends State<_PrudentialMetricCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final metric = widget.metric;
    final statusColor = metric.compliant ? AppTheme.success : AppTheme.danger;
    final surface = Color.alphaBlend(
      metric.color.withValues(alpha: _hovered ? 0.052 : 0.028),
      Theme.of(context).cardColor,
    );
    final detailChildren = <Widget>[
      _PrudentialCardLine(
        color: metric.color,
        label: metric.thresholdLabel,
        value: metric.thresholdValue,
      ),
      if (metric.margin != null) ...[
        const SizedBox(height: 9),
        _PrudentialCardLine(
          color: statusColor,
          label: 'Écart',
          value:
              '${metric.margin! >= 0 ? '+' : '-'}${_pointsLabel(metric.margin!.abs())}',
        ),
      ],
      if (metric.description != null) ...[
        const SizedBox(height: 12),
        _PrudentialInsightText(
          color: metric.color,
          text: metric.description!,
        ),
      ],
    ];

    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = true); }),

      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = false); }),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(_concentrationRadius),
          border: Border.all(
            color: metric.color.withValues(alpha: _hovered ? 0.28 : 0.14),
          ),
          boxShadow: [
            BoxShadow(
              color: metric.color.withValues(alpha: _hovered ? 0.11 : 0.035),
              blurRadius: _hovered ? 14 : 9,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 31,
                  height: 31,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: metric.color,
                    borderRadius: BorderRadius.circular(_concentrationRadius),
                  ),
                  child: Icon(
                    metric.icon,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    metric.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.text,
                          fontSize: 10.6,
                          fontWeight: FontWeight.w900,
                          height: 1.04,
                        ),
                  ),
                ),
                Text(
                  widget.index.toString().padLeft(2, '0'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: metric.color.withValues(alpha: 0.82),
                        fontSize: 8.8,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(_concentrationRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 38,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            metric.currentLabel,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  color: metric.color,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  height: 0.95,
                                  letterSpacing: 0,
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 44),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, detailConstraints) {
                          return FittedBox(
                            alignment: Alignment.topLeft,
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: detailConstraints.maxWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: detailChildren,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrudentialCardLine extends StatelessWidget {
  const _PrudentialCardLine({
    required this.color,
    required this.label,
    this.value,
  });

  final Color color;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final safeValue = value?.replaceAll(' ', '\u00A0');

    return RichText(
      textAlign: TextAlign.start,
      softWrap: true,
      text: TextSpan(
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.text.withValues(alpha: 0.78),
              fontSize: 10.7,
              fontWeight: FontWeight.w600,
              height: 1.16,
            ),
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (value != null)
            TextSpan(
              text: '\u00A0: $safeValue',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}

class _PrudentialInsightText extends StatelessWidget {
  const _PrudentialInsightText({
    required this.color,
    required this.text,
  });

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.start,
      softWrap: true,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppTheme.text.withValues(alpha: 0.74),
            fontSize: 10.5,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
            height: 1.22,
            decoration: TextDecoration.none,
            decorationColor: color.withValues(alpha: 0.45),
          ),
    );
  }
}

String _pointsLabel(double value) {
  return '${(value * 100).toStringAsFixed(1).replaceAll('.', ',')} pt${value >= 0.02 ? 's' : ''}';
}

class _AlertPriorityPanel extends StatelessWidget {
  const _AlertPriorityPanel({required this.alerts});

  final List<ConcentrationAlert> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const SectionCard(
        title: 'Décisions à suivre',
        trailing: _UnitLabel('0 signal'),
        child: _EmptyInline(),
      );
    }

    final sorted = alerts.toList(growable: false)
      ..sort((left, right) => _severityRank(right.severity)
          .compareTo(_severityRank(left.severity)));

    return SectionCard(
      title: 'Décisions à suivre',
      trailing: _UnitLabel('${alerts.length} signal(s)'),
      child: Column(
        children: [
          for (var index = 0; index < sorted.take(3).length; index++)
            _AlertDecisionRow(alert: sorted[index], rank: index + 1),
        ],
      ),
    );
  }
}

class _AlertDecisionRow extends StatelessWidget {
  const _AlertDecisionRow({
    required this.alert,
    required this.rank,
  });

  final ConcentrationAlert alert;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(alert.severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(_concentrationRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(_concentrationRadius),
            ),
            child: Text(
              '$rank',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _SeverityBadge(label: alert.severity),
                    const SizedBox(width: 8),
                    Text(
                      alert.level,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  alert.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.text,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.recommendation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
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

class _AlertDetailTable extends StatelessWidget {
  const _AlertDetailTable({required this.alerts});

  final List<ConcentrationAlert> alerts;

  @override
  Widget build(BuildContext context) {
    return CreditDataTableCard(
      title: 'Détail des alertes',
      emptyMessage: 'Aucune alerte active sur le périmètre filtré.',
      columns: const [
        DataColumn(label: Text('Priorité')),
        DataColumn(label: Text('Niveau')),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Signal')),
        DataColumn(label: Text('Action recommandée')),
      ],
      rows: alerts
          .map(
            (item) => DataRow(
              cells: [
                DataCell(_SeverityBadge(label: item.severity)),
                DataCell(Text(item.level)),
                DataCell(Text(AppFormatters.shortDate(item.date))),
                DataCell(Text(item.message)),
                DataCell(Text(item.recommendation)),
              ],
            ),
          )
          .toList(growable: false),
    );
  }
}

int _severityRank(String severity) {
  return switch (severity.toLowerCase()) {
    'élevé' || 'eleve' => 3,
    'moyen' => 2,
    _ => 1,
  };
}

Color _severityColor(String severity) {
  return switch (severity.toLowerCase()) {
    'élevé' || 'eleve' => AppTheme.danger,
    'moyen' => AppTheme.warning,
    _ => AppTheme.success,
  };
}

Color _hhiColor(double hhi) {
  if (hhi > 2500) return AppTheme.danger;
  if (hhi > 1800) return AppTheme.warning;
  return AppTheme.success;
}

class _QualityGrid extends StatelessWidget {
  const _QualityGrid({required this.quality});

  final PortfolioQualitySummary quality;

  @override
  Widget build(BuildContext context) {
    final items = [
      _QualityMetricSpec(
        label: 'NPL',
        value: AppFormatters.percent(quality.nplRatio),
        caption: 'créances sensibles',
        icon: CupertinoIcons.exclamationmark_octagon_fill,
        color: AppColors.qualityExcellent,
        progress: (quality.nplRatio / 0.10).clamp(0.02, 1.0),
        role:
            'Mesure la part des encours non performants dans le portefeuille.',
        formula: 'NPL = encours brut en défaut / encours brut total.',
        methodology:
            'On filtre les expositions en défaut, on somme leur encours brut, puis on rapporte ce montant au total brut.',
        analysisTitle: 'Qualité observée',
        analysis: quality.nplRatio <= 0.02
            ? 'NPL à ${AppFormatters.percent(quality.nplRatio)} : le portefeuille ne présente quasiment pas de créances sensibles.'
            : 'NPL à ${AppFormatters.percent(quality.nplRatio)} : présence de créances sensibles à suivre de près.',
        interpretationTitle: 'Lecture crédit',
        interpretation:
            'Un NPL bas confirme une qualité de crédit saine; une hausse signalerait une migration vers des actifs non performants.',
        impactTitle: 'Pression portefeuille',
        impact:
            'Pression limitée sur les provisions et le capital tant que ce ratio reste contenu.',
      ),
      _QualityMetricSpec(
        label: 'Défaut',
        value: AppFormatters.percent(quality.defaultRate),
        caption: 'défauts observés',
        icon: CupertinoIcons.xmark_shield_fill,
        color: AppColors.qualityGood,
        progress: (quality.defaultRate / 0.08).clamp(0.02, 1.0),
        role: 'Mesure la fréquence des expositions marquées en défaut.',
        formula:
            'Taux de défaut = nombre d’expositions en défaut / nombre total d’expositions.',
        methodology:
            'On compte les expositions en défaut, puis on divise par le nombre total d’expositions du périmètre.',
        analysisTitle: 'Défauts constatés',
        analysis: quality.defaultRate <= 0.005
            ? 'Défaut à ${AppFormatters.percent(quality.defaultRate)} : aucun défaut significatif observé sur le périmètre.'
            : 'Défaut à ${AppFormatters.percent(quality.defaultRate)} : des défauts matérialisés pèsent sur la qualité du portefeuille.',
        interpretationTitle: 'Signal de rupture',
        interpretation:
            'Le taux de défaut mesure la rupture de paiement effective, plus sévère qu’un simple signal de fragilité.',
        impactTitle: 'Effet pertes attendues',
        impact:
            'Influence directe sur les pertes attendues, les provisions et les priorités de recouvrement.',
      ),
      _QualityMetricSpec(
        label: 'Encours défaut',
        value: _amountMd(quality.defaultGross),
        caption: 'montant exposé',
        icon: CupertinoIcons.creditcard_fill,
        color: AppColors.qualityAverage,
        progress: quality.defaultGross > 0 ? 0.66 : 0.02,
        role: 'Indique le stock monétaire déjà classé en défaut.',
        formula:
            'Encours défaut = somme des encours bruts des expositions en défaut.',
        methodology:
            'On conserve uniquement les expositions en défaut et on additionne leurs montants bruts.',
        analysisTitle: 'Stock exposé',
        analysis: quality.defaultGross <= 0
            ? 'Encours défaut à ${_amountMd(quality.defaultGross)} ${_amountUnitLabel()} : aucun montant exposé en défaut.'
            : 'Encours défaut à ${_amountMd(quality.defaultGross)} ${_amountUnitLabel()} : montant déjà classé en défaut.',
        interpretationTitle: 'Traitement requis',
        interpretation:
            'Cet indicateur matérialise le stock à traiter par recouvrement, restructuration ou provisionnement.',
        impactTitle: 'Consommation capital',
        impact:
            'Plus il augmente, plus il dégrade la qualité des actifs et mobilise du capital.',
      ),
      _QualityMetricSpec(
        label: 'PD moyenne',
        value: AppFormatters.percent(quality.averagePd),
        caption: 'probabilité défaut',
        icon: CupertinoIcons.percent,
        color: AppColors.qualityFair,
        progress: (quality.averagePd / 0.10).clamp(0.02, 1.0),
        role: 'Estime le risque moyen de défaut futur du portefeuille.',
        formula: 'PD moyenne = somme(PD x EAD) / somme(EAD).',
        methodology:
            'Chaque PD est pondérée par l’EAD; les expositions importantes influencent davantage la moyenne.',
        analysisTitle: 'Risque anticipé',
        analysis: quality.averagePd <= 0.03
            ? 'PD moyenne à ${AppFormatters.percent(quality.averagePd)} : probabilité de défaut globalement modérée.'
            : 'PD moyenne à ${AppFormatters.percent(quality.averagePd)} : risque de défaut attendu plus sensible.',
        interpretationTitle: 'Projection défaut',
        interpretation:
            'La PD anticipe le risque futur avant même l’apparition de défauts comptables.',
        impactTitle: 'Pilotage du coût du risque',
        impact:
            'Elle pilote le coût du risque prévisionnel et le niveau de surveillance des contreparties.',
      ),
      _QualityMetricSpec(
        label: 'LGD moyenne',
        value: AppFormatters.percent(quality.averageLgd),
        caption: 'perte en cas défaut',
        icon: CupertinoIcons.chart_bar_fill,
        color: AppColors.qualityPoor,
        progress: quality.averageLgd.clamp(0.02, 1.0),
        role:
            'Mesure la perte moyenne attendue si une contrepartie fait défaut.',
        formula: 'LGD moyenne = somme(LGD x EAD) / somme(EAD).',
        methodology:
            'On pondère chaque LGD par l’EAD afin de refléter le poids réel de chaque exposition.',
        analysisTitle: 'Perte potentielle',
        analysis: quality.averageLgd <= 0.45
            ? 'LGD moyenne à ${AppFormatters.percent(quality.averageLgd)} : perte estimée en cas de défaut relativement maîtrisée.'
            : 'LGD moyenne à ${AppFormatters.percent(quality.averageLgd)} : perte potentielle élevée en cas de défaut.',
        interpretationTitle: 'Qualité des sûretés',
        interpretation:
            'Elle reflète la qualité des garanties, du recouvrement et de la séniorité des expositions.',
        impactTitle: 'Sensibilité aux défauts',
        impact:
            'En cas de défaut, environ ${AppFormatters.percent(quality.averageLgd)} de l’exposition peut peser sur les pertes.',
      ),
      _QualityMetricSpec(
        label: 'Couverture risque',
        value: AppFormatters.percent(quality.riskCoverage),
        caption: 'provisions / défauts',
        icon: CupertinoIcons.shield_lefthalf_fill,
        color: AppColors.success,
        progress: (quality.riskCoverage.clamp(0.0, 1.25) / 1.25).toDouble(),
        role:
            'Évalue la capacité des provisions à absorber les encours en défaut.',
        formula:
            'Couverture risque = provisions estimées / encours brut en défaut.',
        methodology:
            'On additionne les provisions estimées des expositions en défaut, puis on les rapporte à leur encours brut.',
        analysisTitle: 'Niveau de protection',
        analysis: quality.riskCoverage < 0
            ? 'Couverture risque à ${AppFormatters.percent(quality.riskCoverage)} : ratio atypique ou défavorable à investiguer.'
            : quality.riskCoverage < 1
                ? 'Couverture risque à ${AppFormatters.percent(quality.riskCoverage)} : les provisions ne couvrent pas entièrement les défauts.'
                : 'Couverture risque à ${AppFormatters.percent(quality.riskCoverage)} : coussin de provisions confortable.',
        interpretationTitle: 'Capacité d’absorption',
        interpretation:
            'Ce ratio indique la capacité des provisions à absorber les défauts observés.',
        impactTitle: 'Effort de provisionnement',
        impact:
            'Une couverture insuffisante augmente la sensibilité aux pertes et peut exiger un effort de provisionnement.',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final tileWidth = (constraints.maxWidth - gap) / 2;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: tileWidth,
                height: 88,
                child: _QualityMetricCard(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _QualityMetricSpec {
  const _QualityMetricSpec({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
    required this.progress,
    required this.role,
    required this.formula,
    required this.methodology,
    required this.analysisTitle,
    required this.analysis,
    required this.interpretationTitle,
    required this.interpretation,
    required this.impactTitle,
    required this.impact,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
  final double progress;
  final String role;
  final String formula;
  final String methodology;
  final String analysisTitle;
  final String analysis;
  final String interpretationTitle;
  final String interpretation;
  final String impactTitle;
  final String impact;
}

class _QualityMetricCard extends StatefulWidget {
  const _QualityMetricCard({required this.item});

  final _QualityMetricSpec item;

  @override
  State<_QualityMetricCard> createState() => _QualityMetricCardState();
}

class _QualityMetricCardState extends State<_QualityMetricCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.text;
    final mutedColor = isDark ? AppTheme.darkMuted : AppTheme.muted;
    final surfaceColor = _hovered && !isDark
        ? const Color(0xFFF8FAFC)
        : Theme.of(context).cardColor;
    final trackColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);

    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = true); }),

      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = false); }),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        padding: const EdgeInsets.fromLTRB(9, 7, 9, 6),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(_concentrationRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovered ? 0.11 : 0.055),
              blurRadius: _hovered ? 18 : 10,
              offset: Offset(0, _hovered ? 8 : 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Tooltip(
                  richMessage: _tooltipMessage(item),
                  waitDuration: const Duration(milliseconds: 220),
                  showDuration: const Duration(seconds: 6),
                  constraints: const BoxConstraints(maxWidth: 360),
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  preferBelow: false,
                  verticalOffset: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF101828),
                    borderRadius: BorderRadius.circular(_concentrationRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(_concentrationRadius),
                      boxShadow: _hovered
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(item.icon, color: Colors.white, size: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: item.color,
                          fontSize: 11.8,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    item.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: textColor,
                          fontSize: 18.8,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              item.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor,
                    fontSize: 9.8,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(_concentrationRadius),
              child: LinearProgressIndicator(
                value: item.progress.clamp(0.0, 1.0),
                minHeight: 3.5,
                backgroundColor: trackColor,
                valueColor: AlwaysStoppedAnimation<Color>(
                  item.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InlineSpan _tooltipMessage(_QualityMetricSpec item) {
    const baseStyle = TextStyle(
      color: Colors.white,
      fontSize: 10.1,
      fontWeight: FontWeight.w600,
      height: 1.36,
    );
    const subtitleStyle = TextStyle(
      color: Color(0xFFCBD5E1),
      fontSize: 9.7,
      fontWeight: FontWeight.w700,
      height: 1.35,
    );
    const labelStyle = TextStyle(
      color: Color(0xFF93C5FD),
      fontSize: 10.2,
      fontWeight: FontWeight.w800,
      height: 1.35,
    );
    const formulaStyle = TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 10.1,
      fontWeight: FontWeight.w800,
      height: 1.36,
    );
    final titleStyle = TextStyle(
      color: item.color,
      fontSize: 11.4,
      fontWeight: FontWeight.w900,
      height: 1.22,
    );

    return TextSpan(
      style: baseStyle,
      children: [
        TextSpan(text: item.label, style: titleStyle),
        TextSpan(text: '\n${item.caption}\n\n', style: subtitleStyle),
        const TextSpan(text: 'Rôle\n', style: labelStyle),
        TextSpan(text: item.role),
        const TextSpan(text: '\n\nFormule\n', style: labelStyle),
        TextSpan(text: item.formula, style: formulaStyle),
        const TextSpan(text: '\n\nDémarche\n', style: labelStyle),
        TextSpan(text: item.methodology),
        TextSpan(text: '\n\n${item.analysisTitle}\n', style: labelStyle),
        TextSpan(text: item.analysis),
        TextSpan(text: '\n\n${item.interpretationTitle}\n', style: labelStyle),
        TextSpan(text: item.interpretation),
        TextSpan(text: '\n\n${item.impactTitle}\n', style: labelStyle),
        TextSpan(text: item.impact),
      ],
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
        borderRadius: BorderRadius.circular(_concentrationRadius),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _EmptyInline extends StatelessWidget {
  const _EmptyInline({
    this.message = 'Aucune donnée disponible pour les filtres sélectionnés.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(_concentrationRadius),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
