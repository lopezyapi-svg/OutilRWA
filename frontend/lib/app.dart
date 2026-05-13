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
import 'modules/dashboard/screens/dashboard_screen.dart';
import 'modules/expositions/screens/expositions_screen.dart';
import 'modules/rapports/screens/rapports_screen.dart';
import 'modules/referentiels/screens/referentiels_screen.dart';
import 'modules/risque_marche/screens/risque_marche_screen.dart';
import 'modules/risque_operationnel/screens/risque_operationnel_screen.dart';
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
  final Set<AppModule> _visitedModules = {AppModule.dashboard};

  @override
  void initState() {
    super.initState();
    AppLocalizations.setCurrentLanguage(_appLanguage.value);
    _appLanguage.addListener(_handleLanguageChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_preloadPrimaryModules());
    });
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

  Future<void> _preloadPrimaryModules() async {
    _warmFuture(_api.fetchReferentiels());
    _warmFuture(_api.fetchExpositionsModule());
    _warmFuture(_api.fetchReports());
    _warmFuture(_api.fetchGlobalSearchCatalog());
  }

  void _warmFuture<T>(Future<T> future) {
    future.then<void>((_) {}, onError: (_) {
      // Le préchargement reste opportuniste et ne doit jamais bloquer l'UI.
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
        AppModule.referentiels => ReferentielsScreen(api: _api),
        AppModule.rapports => RapportsScreen(api: _api),
      };
    });
  }

  Widget _buildSelectedScreen() {
    final visibleModules = AppModule.values
        .where((module) => _visitedModules.contains(module))
        .toList(growable: false);

    return PageStorage(
      bucket: _pageStorageBucket,
      child: IndexedStack(
        index: visibleModules.indexOf(_selectedModule),
        children: [
          for (final module in visibleModules)
            KeyedSubtree(
              key: PageStorageKey<String>(module.name),
              child: _screenFor(module),
            ),
        ],
      ),
    );
  }
}
