// Ce fichier porte la racine de l'application et la navigation principale.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_module.dart';
import 'core/localization/app_language.dart';
import 'core/localization/app_localization.dart';
import 'core/services/rwa_api_service.dart';
import 'core/state/portfolio_currency_scope.dart';
import 'core/theme/app_theme.dart';
import 'modules/crm/screens/crm_screen.dart';
import 'modules/dashboard/screens/dashboard_screen.dart';
import 'modules/donnees_marche/screens/donnees_marche_screen.dart';
import 'modules/echeanciers_flux/screens/echeanciers_flux_screen.dart';
import 'modules/expositions/screens/expositions_screen.dart';
import 'modules/referentiels/screens/referentiels_screen.dart';
import 'modules/simulation/screens/simulation_screen.dart';
import 'modules/stress_tests/screens/stress_tests_screen.dart';
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
  final ValueNotifier<String> _portfolioDisplayCurrency =
      ValueNotifier<String>('XOF');
  final ValueNotifier<AppLanguage> _appLanguage =
      ValueNotifier<AppLanguage>(AppLanguage.francais);
  AppModule _selectedModule = AppModule.dashboard;
  ThemeMode _themeMode = ThemeMode.light;
  final Map<AppModule, Widget> _screenCache = {};
  final Set<AppModule> _visitedModules = {AppModule.dashboard};

  @override
  void initState() {
    super.initState();
    AppLocalizations.setCurrentLanguage(_appLanguage.value);
    _appLanguage.addListener(_handleLanguageChanged);
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
            debugShowCheckedModeBanner: false,
            title: 'RWACalco',
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
              child: AppShell(
                api: _api,
                selectedModule: _selectedModule,
                onSelectModule: _selectModule,
                themeMode: _themeMode,
                onThemeModeChanged: (themeMode) =>
                    setState(() => _themeMode = themeMode),
                portfolioDisplayCurrency: _portfolioDisplayCurrency,
                appLanguage: _appLanguage,
                child: _buildSelectedScreen(),
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
      _visitedModules.add(_selectedModule);
    });
  }

  void _selectModule(AppModule module) {
    setState(() {
      _selectedModule = module;
      _visitedModules.add(module);
    });
  }

  Widget _screenFor(AppModule module) {
    return _screenCache.putIfAbsent(module, () {
      switch (module) {
        case AppModule.dashboard:
          return DashboardScreen(api: _api);
        case AppModule.inventairePortefeuille:
          return ExpositionsScreen(
            api: _api,
            displayCurrencyListenable: _portfolioDisplayCurrency,
          );
        case AppModule.donneesMarche:
          return const DonneesMarcheScreen();
        case AppModule.echeanciersFlux:
          return const EcheanciersFluxScreen();
        case AppModule.analyseRisques:
          return CrmScreen(api: _api);
        case AppModule.stressTests:
          return const StressTestsScreen();
        case AppModule.simulation:
          return const SimulationScreen();
        case AppModule.referentiels:
          return ReferentielsScreen(api: _api);
      }
    });
  }

  Widget _buildSelectedScreen() {
    final visibleModules = AppModule.values
        .where((module) => _visitedModules.contains(module))
        .toList(growable: false);
    return IndexedStack(
      index: visibleModules.indexOf(_selectedModule),
      children: [
        for (final module in visibleModules)
          KeyedSubtree(
            key: ValueKey(module),
            child: _screenFor(module),
          ),
      ],
    );
  }
}
