import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/simple_bar_chart.dart';
import '../../../shared/widgets/simple_donut_chart.dart';
import '../../risque_credit_shared/models/credit_risk_models.dart';
import '../../risque_credit_shared/services/credit_risk_submodules_service.dart';
import '../../risque_credit_shared/widgets/credit_data_table_card.dart';
import '../../risque_credit_shared/widgets/credit_module_toolbar.dart';
import '../../risque_credit_shared/widgets/credit_stat_card.dart';

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
  StreamSubscription<int>? _portfolioSubscription;

  String _selectedCountry = 'Tous';

  static const List<Color> _palette = [
    Color(0xFF234A84),
    Color(0xFF3A6FD3),
    Color(0xFF5B8FF5),
    Color(0xFF84A9FF),
    Color(0xFFB5C9FF),
  ];

  @override
  void initState() {
    super.initState();
    _service = CreditRiskSubmodulesService(widget.api);
    _future = _service.fetchConcentrationModule();
    _portfolioSubscription = widget.api.portfolioRefreshStream.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() => _future = _service.fetchConcentrationModule());
    });
  }

  @override
  void dispose() {
    _portfolioSubscription?.cancel();
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
        final countries = [
          'Tous',
          ...data.topExposures.map((item) => item.country).toSet(),
        ];
        final query = _searchController.text.trim().toLowerCase();

        final filteredTopExposures = data.topExposures.where((item) {
          final matchesSearch = query.isEmpty ||
              item.exposureId.toLowerCase().contains(query) ||
              item.counterpartyName.toLowerCase().contains(query) ||
              item.sector.toLowerCase().contains(query);
          final matchesCountry =
              _selectedCountry == 'Tous' || item.country == _selectedCountry;
          return matchesSearch && matchesCountry;
        }).toList(growable: false);

        final filteredSectors = data.sectorRows.where((item) {
          if (query.isEmpty) {
            return true;
          }
          return item.sector.toLowerCase().contains(query);
        }).toList(growable: false);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'Concentration',
                subtitle:
                    'Lecture sectorielle et portefeuille des expositions les plus contributrices, sans recréer les calculs RWA de la source.',
              ),
              const SizedBox(height: AppTheme.pageGap),
              _buildStatGrid(data),
              const SizedBox(height: AppTheme.pageGap),
              SectionCard(
                title: 'Répartition du portefeuille',
                child: Column(
                  children: [
                    CreditModuleToolbar(
                      searchController: _searchController,
                      searchHint:
                          'Rechercher un secteur, une exposition ou une contrepartie',
                      onSearchChanged: (_) => setState(() {}),
                      filters: [
                        _buildDropdown(
                          label: 'Pays',
                          value: _selectedCountry,
                          values: countries,
                          onChanged: (value) =>
                              setState(() => _selectedCountry = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 980;
                        final sectorChart = SectionCard(
                          title: 'Concentration sectorielle',
                          child: SimpleDonutChart(
                            entries: data.sectorDistribution.take(5).toList(),
                            palette: _palette,
                          ),
                        );
                        final countryChart = SectionCard(
                          title: 'Répartition géographique',
                          child: SizedBox(
                            height: 280,
                            child: SimpleBarChart(
                              entries: data.countryDistribution,
                              palette: _palette,
                            ),
                          ),
                        );

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: sectorChart),
                              const SizedBox(width: AppTheme.pageGap),
                              Expanded(child: countryChart),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            sectorChart,
                            const SizedBox(height: AppTheme.pageGap),
                            countryChart,
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.pageGap),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1080;
                  final sectorTable = CreditDataTableCard(
                    title: 'Concentration par secteur',
                    columns: const [
                      DataColumn(label: Text('Secteur')),
                      DataColumn(label: Text('Expositions')),
                      DataColumn(label: Text('Montant brut')),
                      DataColumn(label: Text('Part portefeuille')),
                    ],
                    rows: filteredSectors
                        .map(
                          (item) => DataRow(
                            cells: [
                              DataCell(Text(item.sector)),
                              DataCell(Text(item.exposureCount.toString())),
                              DataCell(Text(
                                  AppFormatters.currency(item.grossAmount))),
                              DataCell(Text(AppFormatters.percent(item.share))),
                            ],
                          ),
                        )
                        .toList(growable: false),
                  );
                  final exposureTable = CreditDataTableCard(
                    title: 'Top expositions',
                    columns: const [
                      DataColumn(label: Text('Exposition')),
                      DataColumn(label: Text('Contrepartie')),
                      DataColumn(label: Text('Pays')),
                      DataColumn(label: Text('Secteur')),
                      DataColumn(label: Text('Montant brut')),
                      DataColumn(label: Text('Part')),
                    ],
                    rows: filteredTopExposures
                        .map(
                          (item) => DataRow(
                            cells: [
                              DataCell(Text(item.exposureId)),
                              DataCell(Text(item.counterpartyName)),
                              DataCell(Text(item.country)),
                              DataCell(Text(item.sector)),
                              DataCell(Text(
                                  AppFormatters.currency(item.grossAmount))),
                              DataCell(Text(AppFormatters.percent(item.share))),
                            ],
                          ),
                        )
                        .toList(growable: false),
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: sectorTable),
                        const SizedBox(width: AppTheme.spacing),
                        Expanded(child: exposureTable),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      sectorTable,
                      const SizedBox(height: AppTheme.spacing),
                      exposureTable,
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatGrid(ConcentrationModuleData data) {
    final stats = [
      CreditStatCard(
        label: 'Portefeuille brut',
        value: AppFormatters.currency(data.summary.totalGross),
        helper: 'Base de lecture concentration',
        icon: Icons.account_balance_wallet_outlined,
        color: AppTheme.sidebarLight,
        lottieAsset: 'assets/lotties/rwa_dashboard.json',
      ),
      CreditStatCard(
        label: 'Top secteur',
        value: AppFormatters.percent(data.summary.topSectorShare),
        helper: 'Part du principal secteur',
        icon: Icons.pie_chart_outline_rounded,
        color: AppTheme.accent,
      ),
      CreditStatCard(
        label: 'Top 3 secteurs',
        value: AppFormatters.percent(data.summary.topThreeShare),
        helper: 'Poids des trois premiers',
        icon: Icons.stacked_bar_chart_rounded,
        color: AppTheme.warning,
      ),
      CreditStatCard(
        label: 'Indice HHI',
        value: data.summary.herfindahlIndex.toStringAsFixed(0),
        helper: '${data.summary.counterpartyCount} contreparties suivies',
        icon: Icons.blur_on_rounded,
        color: AppTheme.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 960
            ? 190.0
            : constraints.maxWidth >= 620
                ? ((constraints.maxWidth - AppTheme.spacing) / 2)
                    .clamp(0.0, 190.0)
                    .toDouble()
                : constraints.maxWidth;

        return Wrap(
          spacing: AppTheme.spacing,
          runSpacing: AppTheme.spacing,
          children: [
            for (final stat in stats)
              SizedBox(
                width: width,
                child: stat,
              ),
          ],
        );
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: values
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(growable: false),
        selectedItemBuilder: (context) => values
            .map(
              (item) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(growable: false),
        onChanged: (newValue) {
          if (newValue != null) {
            onChanged(newValue);
          }
        },
      ),
    );
  }
}
