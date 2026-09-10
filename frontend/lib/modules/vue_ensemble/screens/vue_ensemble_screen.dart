import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/app_module.dart';
import '../../../core/localization/app_localization.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/state/portfolio_currency_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../dashboard/widgets/dashboard_general_header.dart';
import '../../dashboard/widgets/dashboard_ratios_row.dart';
import '../../dashboard/widgets/dashboard_capital_requis.dart';
import '../../dashboard/widgets/dashboard_fonds_propres.dart';
import '../../dashboard/widgets/dashboard_fonds_propres_dialog.dart';
import '../../dashboard/widgets/dashboard_rwa_donut.dart';
import '../../dashboard/widgets/dashboard_rwa_secteur_table.dart';
import '../../dashboard/widgets/dashboard_grands_risques_summary.dart';
import '../../dashboard/widgets/dashboard_top10_risques_table.dart';

bool _isDashboardDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _dashboardBackgroundFor(BuildContext context) =>
    _isDashboardDark(context) ? const Color(0xFF0B1220) : const Color(0xFFF6F7F9);

Color _dashboardTextFor(BuildContext context) =>
    _isDashboardDark(context) ? const Color(0xFFF2F6FF) : AppTheme.text;

class VueEnsembleScreen extends StatefulWidget {
  const VueEnsembleScreen({
    super.key,
    required this.api,
    this.onNavigateToModule,
  });

  final RwaApiService api;
  final ValueChanged<AppModule>? onNavigateToModule;

  @override
  State<VueEnsembleScreen> createState() => _VueEnsembleScreenState();
}

class _VueEnsembleScreenState extends State<VueEnsembleScreen> {
  late Future<DashboardSnapshot> _future;
  StreamSubscription<int>? _portfolioRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _future = _loadDashboard();
    _portfolioRefreshSubscription =
        widget.api.portfolioRefreshStream.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _future = _loadDashboard();
      });
    });
  }

  void _refresh() {
    setState(() {
      _future = widget.api.fetchDashboard(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _portfolioRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<DashboardSnapshot> _loadDashboard() {
    return widget.api.fetchDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ColoredBox(
            color: _dashboardBackgroundFor(context),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snapshot.hasError) {
          return ColoredBox(
            color: _dashboardBackgroundFor(context),
            child: Center(
              child: Text(
                context.tr(
                  'Erreur: {{error}}',
                  args: {'error': snapshot.error},
                ),
                style: TextStyle(color: _dashboardTextFor(context)),
              ),
            ),
          );
        }

        return _ExecutiveDashboard(
          data: snapshot.data!,
          onRefresh: _refresh,
          onNavigateToModule: widget.onNavigateToModule,
          api: widget.api,
        );
      },
    );
  }
}

class _ExecutiveDashboard extends StatelessWidget {
  const _ExecutiveDashboard({
    required this.data,
    required this.onRefresh,
    this.onNavigateToModule,
    required this.api,
  });

  final DashboardSnapshot data;
  final VoidCallback onRefresh;
  final ValueChanged<AppModule>? onNavigateToModule;
  final RwaApiService api;

  @override
  Widget build(BuildContext context) {
    final currency = PortfolioCurrencyScope.maybeOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(color: _dashboardBackgroundFor(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardGeneralHeader(
            onRefresh: onRefresh,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                
                final kpiRatios = DashboardRatiosRow(data: data);
                final capitalRequis = DashboardCapitalRequis(currency: currency, data: data);
                final fondsPropres = DashboardFondsPropres(
                  currency: currency,
                  data: data,
                  onEdit: () async {
                    final saved = await DashboardFondsPropresDialog.show(
                      context,
                      api,
                      data.fondsPropres,
                    );
                    if (saved) {
                      onRefresh();
                    }
                  },
                );
                final rwaDonut = DashboardRwaDonut(currency: currency, data: data);
                final rwaSecteurTable = DashboardRwaSecteurChart(currency: currency, data: data);
                final top10Table = DashboardTop10RisquesTable(currency: currency, exposures: data.top10Exposures ?? const [], allExposures: data.grandsRisques);
                final top10Chart = DashboardGrandsRisquesSummary(
                  currency: currency,
                  exposures: data.grandsRisques,
                );
                List<Widget> children;

                if (width >= 750) {
                  children = [
                    kpiRatios,
                    const SizedBox(height: 16),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 45, child: capitalRequis),
                          const SizedBox(width: 16),
                          Expanded(flex: 55, child: fondsPropres),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 35, child: rwaDonut),
                          const SizedBox(width: 16),
                          Expanded(flex: 65, child: rwaSecteurTable),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 60, child: top10Table),
                          const SizedBox(width: 16),
                          Expanded(flex: 40, child: top10Chart),
                        ],
                      ),
                    ),
                  ];
                } else {
                  children = [
                    kpiRatios,
                    const SizedBox(height: 16),
                    capitalRequis,
                    const SizedBox(height: 16),
                    fondsPropres,
                    const SizedBox(height: 16),
                    rwaDonut,
                    const SizedBox(height: 16),
                    rwaSecteurTable,
                    const SizedBox(height: 16),
                    top10Table,
                    const SizedBox(height: 16),
                    top10Chart,
                  ];
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
