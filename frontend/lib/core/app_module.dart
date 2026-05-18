// Ce fichier decrit les modules disponibles dans l'interface.
/// Enumération des modules disponibles dans l'application.
enum AppModule {
  dashboard,
  expositions,
  risqueMarche,
  risqueOperationnel,
  analyse,
  stressTest,
  icap,
  capitalPlaning,
  referentiels,
  rapports,
}

/// Extension qui expose les titres et sous-titres de chaque module.
extension AppModuleLabel on AppModule {
  String get title {
    switch (this) {
      case AppModule.dashboard:
        return 'Dashboard';
      case AppModule.expositions:
        return 'Risque de crédit';
      case AppModule.risqueMarche:
        return 'Risque de marché';
      case AppModule.risqueOperationnel:
        return 'Risque opérationnel';
      case AppModule.analyse:
        return 'Analyse';
      case AppModule.stressTest:
        return 'Stress test';
      case AppModule.icap:
        return 'ICAP';
      case AppModule.capitalPlaning:
        return 'Capital planing';
      case AppModule.referentiels:
        return 'Référentiels';
      case AppModule.rapports:
        return 'Rapports';
    }
  }

  String get subtitle {
    switch (this) {
      case AppModule.dashboard:
        return 'Pilotage global des encours, RWA, capital et couverture CRM.';
      case AppModule.expositions:
        return 'Saisie, import, edition et suivi detaille des expositions du portefeuille.';
      case AppModule.risqueMarche:
        return 'Evaluation des tensions de marché et des risques associés au portefeuille.';
      case AppModule.risqueOperationnel:
        return 'Cartographie des risques operationnels et des controles internes.';
      case AppModule.analyse:
        return 'Conseils et recommandations basés sur les expositions et les risques.';
      case AppModule.stressTest:
        return 'Simulation de chocs et scénarios adverses sur le portefeuille et le capital.';
      case AppModule.icap:
        return 'Evaluation interne de l’adéquation du capital et des besoins de solvabilité.';
      case AppModule.capitalPlaning:
        return 'Projection du capital, des besoins prudentiels et des marges de manoeuvre.';
      case AppModule.referentiels:
        return 'Référentiels, tables RW, CCF et notations de calcul.';
      case AppModule.rapports:
        return 'Generation de rapports de synthese, details et exports metier.';
    }
  }
}
