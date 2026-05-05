// Ce fichier decrit les modules disponibles dans l'interface.
/// Enumération des modules disponibles dans l'application.
enum AppModule {
  dashboard,
  inventairePortefeuille,
  donneesMarche,
  echeanciersFlux,
  analyseRisques,
  stressTests,
  simulation,
  referentiels,
}

/// Extension qui expose les titres et sous-titres de chaque module.
extension AppModuleLabel on AppModule {
  String get title {
    switch (this) {
      case AppModule.dashboard:
        return 'Dashboard';
      case AppModule.inventairePortefeuille:
        return 'Expositions';
      case AppModule.donneesMarche:
        return 'Données de Marché';
      case AppModule.echeanciersFlux:
        return 'Échéanciers & Flux';
      case AppModule.analyseRisques:
        return 'Analyse & Risques';
      case AppModule.stressTests:
        return 'Stress Tests';
      case AppModule.simulation:
        return 'Simulation';
      case AppModule.referentiels:
        return 'Référentiels';
    }
  }

  String get subtitle {
    switch (this) {
      case AppModule.dashboard:
        return 'Pilotage global des encours, RWA, capital et couverture CRM.';
      case AppModule.inventairePortefeuille:
        return 'Saisie, import, edition et suivi detaille des expositions du portefeuille.';
      case AppModule.donneesMarche:
        return 'Suivi des paramètres de marché utiles aux valorisations, stress et simulations.';
      case AppModule.echeanciersFlux:
        return 'Vision des flux attendus, maturités et échéanciers de portefeuille.';
      case AppModule.analyseRisques:
        return 'Analyse du risque, des garanties et des impacts RWA.';
      case AppModule.stressTests:
        return 'Stress tests prudentiels et sensibilités du portefeuille.';
      case AppModule.simulation:
        return 'Simulation de scénarios RWA et capital minimum.';
      case AppModule.referentiels:
        return 'Référentiels, tables RW, CCF et notations de calcul.';
    }
  }
}
