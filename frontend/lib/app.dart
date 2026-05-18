// Ce fichier porte la racine de l'application et la navigation principale.
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
import 'modules/dashboard/screens/dashboard_screen.dart';
import 'modules/expositions/screens/expositions_screen.dart';
import 'modules/icap/screens/icap_screen.dart';
import 'modules/rapports/screens/rapports_screen.dart';
import 'modules/referentiels/screens/referentiels_screen.dart';
import 'modules/risque_marche/screens/risque_marche_screen.dart';
import 'modules/risque_operationnel/screens/risque_operationnel_screen.dart';
import 'modules/stress_test/screens/stress_test_screen.dart';
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
  final ValueNotifier<String> _portfolioDisplayCurrency = ValueNotifier<String>(
    'XOF',
  );
  final ValueNotifier<AppLanguage> _appLanguage = ValueNotifier<AppLanguage>(
    AppLanguage.francais,
  );
  AppModule _selectedModule = AppModule.dashboard;
  ThemeMode _themeMode = ThemeMode.light;
  final PageStorageBucket _pageStorageBucket = PageStorageBucket();
  final Map<AppModule, Widget> _screenCache = {};

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
    });
  }

  void _selectModule(AppModule module) {
    if (module == _selectedModule) {
      return;
    }
    setState(() {
      _selectedModule = module;
    });
  }

  Widget _screenFor(AppModule module) {
    return _screenCache.putIfAbsent(module, () {
      return switch (module) {
        AppModule.dashboard => DashboardScreen(api: _api),
        AppModule.expositions => ExpositionsScreen(
            api: _api,
            displayCurrencyListenable: _portfolioDisplayCurrency,
          ),
        AppModule.risqueMarche => RisqueMarcheScreen(api: _api),
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
