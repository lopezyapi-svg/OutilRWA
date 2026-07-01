// Ce fichier porte la racine de l'application et la navigation principale.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_module.dart';
import 'core/localization/app_language.dart';
import 'core/localization/app_localization.dart';
import 'core/services/rwa_api_service.dart';
import 'core/state/portfolio_amount_unit_scope.dart';
import 'core/state/portfolio_currency_scope.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/currency_conversion.dart';
import 'modules/analyse/screens/analyse_screen.dart';
import 'modules/capital_planing/screens/capital_planing_screen.dart';
import 'modules/concentration/screens/concentration_screen.dart';
import 'modules/crm/screens/crm_screen.dart';
import 'modules/dashboard/screens/dashboard_screen.dart';
import 'modules/defauts_impayes/screens/defauts_impayes_screen.dart';
import 'modules/expositions/screens/expositions_screen.dart';
import 'modules/garanties/screens/garanties_screen.dart';
import 'modules/hors_bilan/screens/hors_bilan_screen.dart';
import 'modules/icap/screens/icap_screen.dart';
import 'modules/icap/screens/icap_uemoa_cemac_screen.dart';
import 'modules/rapports/screens/rapports_screen.dart';
import 'modules/reporting_credit/screens/reporting_credit_screen.dart';
import 'modules/risque_credit_shared/services/credit_risk_submodules_service.dart';
import 'modules/risque_marche/screens/market_data_import_screen.dart';
import 'modules/risque_marche/screens/risque_marche_screen.dart';
import 'modules/risque_marche/services/market_data_import_store.dart';
import 'modules/risque_operationnel/screens/risque_operationnel_screen.dart';
import 'modules/rwa_engine/screens/rwa_engine_screen.dart';
import 'modules/stress_test/screens/stress_test_screen.dart';
import 'modules/vue_ensemble/screens/vue_ensemble_screen.dart';
import 'modules/welcome/screens/welcome_screen.dart';
import 'shared/widgets/app_shell.dart';

/// Widget racine qui pilote le thème et la navigation principale.
class RwaApp extends StatefulWidget {
  const RwaApp({super.key});

  @override
  State<RwaApp> createState() => _RwaAppState();
}

/// Etat interne qui mémorise le module courant et le mode de thème.
class _RwaAppState extends State<RwaApp> {
  final RwaApiService _api = RwaApiService(useMockData: false);
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final ValueNotifier<String> _portfolioDisplayCurrency = ValueNotifier<String>(
    'XOF',
  );
  final ValueNotifier<PortfolioAmountUnit> _portfolioAmountUnit =
      ValueNotifier<PortfolioAmountUnit>(
    PortfolioAmountUnit.billion,
  );
  final ValueNotifier<AppLanguage> _appLanguage = ValueNotifier<AppLanguage>(
    AppLanguage.francais,
  );
  AppModule _selectedModule = AppModule.vueEnsemble;
  ThemeMode _themeMode = ThemeMode.light;
  String _fontFamily = AppTheme.defaultFontFamily;
  Color _primaryColor = AppTheme.accent;
  bool _showWelcomeScreen = true;
  bool _isMarketImportDialogOpen = false;
  final PageStorageBucket _pageStorageBucket = PageStorageBucket();
  CreditRiskSubmodulesService? _creditRiskService;

  @override
  void initState() {
    super.initState();
    _creditRiskService = CreditRiskSubmodulesService(_api);
    AppLocalizations.setCurrentLanguage(_appLanguage.value);
    PortfolioAmountUnitPreference.current = _portfolioAmountUnit.value;
    _portfolioAmountUnit.addListener(_handleAmountUnitChanged);
    _appLanguage.addListener(_handleLanguageChanged);
    unawaited(MarketDataImportStore.instance.configureSqlBackend(_api));
  }

  @override
  void dispose() {
    _portfolioAmountUnit.removeListener(_handleAmountUnitChanged);
    _appLanguage.removeListener(_handleLanguageChanged);
    _portfolioDisplayCurrency.dispose();
    _portfolioAmountUnit.dispose();
    _appLanguage.dispose();
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: _appLanguage,
      builder: (context, appLanguage, _) {
        AppLocalizations.setCurrentLanguage(appLanguage);

        return AppLocalizationScope(
          notifier: _appLanguage,
          child: MaterialApp(
            navigatorKey: _navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'Risk management',
            locale: appLanguage.locale,
            supportedLocales: AppLanguage.values
                .map((language) => language.locale)
                .toList(growable: false),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: AppTheme.buildTheme(
              fontFamily: _fontFamily,
              accentColor: _primaryColor,
            ),
            darkTheme: AppTheme.buildDarkTheme(
              fontFamily: _fontFamily,
              accentColor: _primaryColor,
            ),
            themeMode: _themeMode,
            home: PortfolioCurrencyScope(
              notifier: _portfolioDisplayCurrency,
              child: PortfolioAmountUnitScope(
                notifier: _portfolioAmountUnit,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  child: _showWelcomeScreen
                      ? WelcomeScreen(
                          key: const ValueKey<String>('welcome-screen'),
                          onOpenHome: _openHome,
                        )
                      : AppShell(
                          selectedModule: _selectedModule,
                          onSelectModule: _selectModule,
                          onReturnToWelcome: _returnToWelcome,
                          themeMode: _themeMode,
                          onThemeModeChanged: (themeMode) =>
                              setState(() => _themeMode = themeMode),
                          portfolioDisplayCurrency:
                              _portfolioDisplayCurrency,
                          portfolioAmountUnit: _portfolioAmountUnit,
                          appLanguage: _appLanguage,
                          fontFamily: _fontFamily,
                          onFontFamilyChanged: (fontFamily) =>
                              setState(() => _fontFamily = fontFamily),
                          primaryColor: _primaryColor,
                          onPrimaryColorChanged: (primaryColor) =>
                              setState(() => _primaryColor = primaryColor),
                          child: _buildSelectedScreen(),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleLanguageChanged() {
    AppLocalizations.setCurrentLanguage(_appLanguage.value);
    if (!mounted) return;
    setState(() {});
  }

  void _handleAmountUnitChanged() {
    PortfolioAmountUnitPreference.current = _portfolioAmountUnit.value;
    if (!mounted) return;
    setState(() {});
  }

  void _selectModule(AppModule module) {
    if (module == AppModule.referentiels) {
      return;
    }
    if (module == AppModule.risqueMarcheImport) {
      _openMarketImportDialog();
      return;
    }
    if (module == _selectedModule) {
      return;
    }
    setState(() {
      _selectedModule = module;
    });
  }

  void _openHome() {
    setState(() {
      _selectedModule = AppModule.vueEnsemble;
      _showWelcomeScreen = false;
    });
  }

  void _returnToWelcome() {
    setState(() => _showWelcomeScreen = true);
  }

  Future<void> _openMarketImportDialog() async {
    if (_isMarketImportDialogOpen) {
      return;
    }
    if (_showWelcomeScreen) {
      setState(() {
        _showWelcomeScreen = false;
        _selectedModule = AppModule.risqueMarche;
      });
    }
    _isMarketImportDialogOpen = true;
    try {
      final navigatorContext = _navigatorKey.currentContext;
      if (navigatorContext != null) {
        await showMarketDataImportDialog(navigatorContext);
      }
    } finally {
      _isMarketImportDialogOpen = false;
    }
  }

  Widget _screenFor(AppModule module) {
    return switch (module) {
      AppModule.vueEnsemble => VueEnsembleScreen(
          api: _api,
          onNavigateToModule: _selectModule,
        ),
      AppModule.dashboardCredit => DashboardScreen(api: _api),
      AppModule.expositions => ExpositionsScreen(
          api: _api,
          displayCurrencyListenable: _portfolioDisplayCurrency,
        ),
      AppModule.rwaEngine => RwaEngineScreen(api: _api),
      AppModule.crm => CrmScreen(api: _api),
      AppModule.horsBilan => HorsBilanScreen(api: _api),
      AppModule.garanties => GarantiesScreen(api: _api),
      AppModule.defautsImpayes => DefautsImpayesScreen(api: _api),
      AppModule.concentrationCredit => ConcentrationScreen(api: _api),
      AppModule.reportingCredit => ReportingCreditScreen(api: _api),
      AppModule.risqueMarche => RisqueMarcheScreen(
          api: _api,
          view: MarketRiskView.dashboard,
        ),
      AppModule.risqueMarcheImport => RisqueMarcheScreen(api: _api),
      AppModule.risqueMarcheCalculPrudentiel => RisqueMarcheScreen(
          api: _api,
          view: MarketRiskView.calculPrudentiel,
        ),
      AppModule.risqueMarchePilotage => RisqueMarcheScreen(
          api: _api,
          view: MarketRiskView.pilotage,
        ),
      AppModule.risqueMarcheVar => RisqueMarcheScreen(
          api: _api,
          view: MarketRiskView.varRisk,
        ),
      AppModule.risqueMarcheCourbeTaux => RisqueMarcheScreen(
          api: _api,
          view: MarketRiskView.yieldCurves,
        ),
      AppModule.risqueMarcheIndicateurs => RisqueMarcheScreen(
          api: _api,
          view: MarketRiskView.indicators,
        ),
      AppModule.risqueMarcheAmortissementCrd => RisqueMarcheScreen(
          api: _api,
          view: MarketRiskView.amortizationCapital,
        ),
      AppModule.risqueOperationnel => RisqueOperationnelScreen(api: _api),
      AppModule.risqueOperationnelImport =>
        RisqueOperationnelScreen(api: _api, view: OperationalRiskView.registre),
      AppModule.risqueOperationnelIncidents => RisqueOperationnelScreen(
          api: _api,
          view: OperationalRiskView.incidents,
        ),
      AppModule.risqueOperationnelPertes => RisqueOperationnelScreen(
          api: _api,
          view: OperationalRiskView.pertes,
        ),
      AppModule.risqueOperationnelHistorique => RisqueOperationnelScreen(
          api: _api,
          view: OperationalRiskView.historique,
        ),
      AppModule.risqueOperationnelReporting => RisqueOperationnelScreen(
          api: _api,
          view: OperationalRiskView.reporting,
        ),
      AppModule.analyse => AnalyseScreen(api: _api),
      AppModule.stressTest => StressTestScreen(api: _api),
      AppModule.icaap => IcapScreen(api: _api),
      AppModule.icaapGouvernance => IcapScreen(
          api: _api,
          view: IcapView.gouvernance,
        ),
      AppModule.icaapAdeqCapital => IcapScreen(
          api: _api,
          view: IcapView.adeqCapital,
        ),
      AppModule.icaapRisquesP2 => IcapScreen(
          api: _api,
          view: IcapView.risquesP2,
        ),
      AppModule.icaapPlanification => IcapScreen(
          api: _api,
          view: IcapView.planification,
        ),
      AppModule.icaapStressTests => IcapScreen(
          api: _api,
          view: IcapView.stressTests,
        ),
      AppModule.icaapChecklist => IcapScreen(
          api: _api,
          view: IcapView.checklist,
        ),
      AppModule.icaapRapport => IcapScreen(
          api: _api,
          view: IcapView.rapport,
        ),
      AppModule.icaapUemoaCemac => const IcapUemoaCemacScreen(),
      AppModule.capitalPlaning => CapitalPlaningScreen(api: _api),
      AppModule.referentiels => _screenFor(AppModule.vueEnsemble),
      AppModule.rapports => RapportsScreen(api: _api),
    };
  }

  Widget _buildSelectedScreen() {
    return PageStorage(
      bucket: _pageStorageBucket,
      child: KeyedSubtree(
        key: PageStorageKey<String>(_selectedModule.name),
        child: _screenFor(_selectedModule),
      ),
    );
  }
}
