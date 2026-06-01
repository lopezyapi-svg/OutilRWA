// Ce fichier porte la racine de l'application et la navigation principale.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_module.dart';
import 'core/localization/app_language.dart';
import 'core/localization/app_localization.dart';
import 'core/services/rwa_api_service.dart';
import 'core/state/portfolio_currency_scope.dart';
import 'core/theme/app_theme.dart';
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
import 'modules/rapports/screens/rapports_screen.dart';
import 'modules/referentiels/screens/referentiels_screen.dart';
import 'modules/reporting_credit/screens/reporting_credit_screen.dart';
import 'modules/risque_marche/screens/market_data_import_screen.dart';
import 'modules/risque_marche/screens/risque_marche_screen.dart';
import 'modules/risque_marche/services/market_data_import_store.dart';
import 'modules/risque_operationnel/screens/risque_operationnel_screen.dart';
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
  final ValueNotifier<AppLanguage> _appLanguage = ValueNotifier<AppLanguage>(
    AppLanguage.francais,
  );
  AppModule _selectedModule = AppModule.vueEnsemble;
  ThemeMode _themeMode = ThemeMode.light;
  bool _showWelcomeScreen = true;
  bool _isMarketImportDialogOpen = false;
  final PageStorageBucket _pageStorageBucket = PageStorageBucket();
  final Map<AppModule, Widget> _screenCache = {};

  @override
  void initState() {
    super.initState();
    AppLocalizations.setCurrentLanguage(_appLanguage.value);
    _appLanguage.addListener(_handleLanguageChanged);
    unawaited(MarketDataImportStore.instance.configureSqlBackend(_api));
  }

  @override
  void dispose() {
    _appLanguage.removeListener(_handleLanguageChanged);
    _portfolioDisplayCurrency.dispose();
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
            theme: AppTheme.buildTheme(),
            darkTheme: AppTheme.buildDarkTheme(),
            themeMode: _themeMode,
            home: PortfolioCurrencyScope(
              notifier: _portfolioDisplayCurrency,
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
                        key: const ValueKey<String>('app-shell'),
                        selectedModule: _selectedModule,
                        onSelectModule: _selectModule,
                        onReturnToWelcome: _returnToWelcome,
                        themeMode: _themeMode,
                        onThemeModeChanged: (themeMode) =>
                            setState(() => _themeMode = themeMode),
                        portfolioDisplayCurrency: _portfolioDisplayCurrency,
                        appLanguage: _appLanguage,
                        child: _buildSelectedScreen(),
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
    setState(() {
      _screenCache.clear();
    });
  }

  void _selectModule(AppModule module) {
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
    return _screenCache.putIfAbsent(module, () {
      return switch (module) {
        AppModule.vueEnsemble => VueEnsembleScreen(api: _api),
        AppModule.dashboard => DashboardScreen(api: _api),
        AppModule.expositions => ExpositionsScreen(
            api: _api,
            displayCurrencyListenable: _portfolioDisplayCurrency,
          ),
        AppModule.crm => CrmScreen(api: _api),
        AppModule.horsBilan => HorsBilanScreen(api: _api),
        AppModule.garanties => GarantiesScreen(api: _api),
        AppModule.defautsImpayes => DefautsImpayesScreen(api: _api),
        AppModule.concentrationCredit => ConcentrationScreen(api: _api),
        AppModule.reportingCredit => ReportingCreditScreen(api: _api),
        AppModule.risqueMarche => RisqueMarcheScreen(api: _api),
        AppModule.risqueMarcheImport => RisqueMarcheScreen(api: _api),
        AppModule.risqueMarcheVar => RisqueMarcheScreen(
            api: _api,
            view: MarketRiskView.varRisk,
          ),
        AppModule.risqueMarcheIndicateurs => RisqueMarcheScreen(
            api: _api,
            view: MarketRiskView.indicators,
          ),
        AppModule.risqueMarcheCourbeTaux => RisqueMarcheScreen(
            api: _api,
            view: MarketRiskView.yieldCurves,
          ),
        AppModule.risqueOperationnel => RisqueOperationnelScreen(api: _api),
        AppModule.analyse => AnalyseScreen(api: _api),
        AppModule.stressTest => StressTestScreen(api: _api),
        AppModule.icap => IcapScreen(api: _api),
        AppModule.capitalPlaning => CapitalPlaningScreen(api: _api),
        AppModule.referentiels => ReferentielsScreen(api: _api),
        AppModule.rapports => RapportsScreen(api: _api),
      };
    });
  }

  Widget _buildSelectedScreen() {
    return PageStorage(
      bucket: _pageStorageBucket,
      // On ne garde plus tous les ecrans visites dans le layout pour eviter
      // que la sidebar ou le shell relancent leur recalcul a chaque animation.
      child: KeyedSubtree(
        key: PageStorageKey<String>(_selectedModule.name),
        child: _screenFor(_selectedModule),
      ),
    );
  }
}
