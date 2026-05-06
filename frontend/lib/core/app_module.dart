// Ce fichier decrit les modules disponibles dans l'interface.
/// Enumération des modules disponibles dans l'application.
enum AppModule {
  dashboard,
  expositions,
  horsBilan,
  crm,
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
        return 'Expositions';
      case AppModule.horsBilan:
        return 'Hors Bilan';
      case AppModule.crm:
        return 'CRM';
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
      case AppModule.horsBilan:
        return 'Gestion des engagements hors bilan avec application des CCF et calcul des RWA.';
      case AppModule.crm:
        return 'Analyse des garanties, mitigations et impacts sur les RWA.';
      case AppModule.referentiels:
        return 'Référentiels, tables RW, CCF et notations de calcul.';
      case AppModule.rapports:
        return 'Generation de rapports de synthese, details et exports metier.';
    }
  }
}
