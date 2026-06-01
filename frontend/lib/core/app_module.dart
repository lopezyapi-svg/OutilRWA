import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// Ce fichier decrit les modules disponibles dans l'interface.
/// Enumération des modules disponibles dans l'application.
enum AppModule {
  vueEnsemble,
  dashboard,
  expositions,
  crm,
  horsBilan,
  garanties,
  defautsImpayes,
  concentrationCredit,
  reportingCredit,
  risqueMarche,
  risqueMarcheImport,
  risqueMarcheVar,
  risqueMarcheIndicateurs,
  risqueMarcheCourbeTaux,
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
      case AppModule.vueEnsemble:
        return 'Vue d\'ensemble';
      case AppModule.dashboard:
        return 'Dashboard';
      case AppModule.expositions:
        return 'Risque de crédit';
      case AppModule.crm:
        return 'CRM';
      case AppModule.horsBilan:
        return 'Hors bilan';
      case AppModule.garanties:
        return 'Garanties';
      case AppModule.defautsImpayes:
        return 'Défauts / Impayés';
      case AppModule.concentrationCredit:
        return 'Concentration';
      case AppModule.reportingCredit:
        return 'Reporting';
      case AppModule.risqueMarche:
        return 'Risque du Marché';
      case AppModule.risqueMarcheImport:
        return 'Import données';
      case AppModule.risqueMarcheVar:
        return 'VaR';
      case AppModule.risqueMarcheIndicateurs:
        return 'Indicateurs clés';
      case AppModule.risqueMarcheCourbeTaux:
        return 'Courbe des taux';
      case AppModule.risqueOperationnel:
        return 'Risque Opérationnel';
      case AppModule.analyse:
        return 'Analyse';
      case AppModule.stressTest:
        return 'Stress Test';
      case AppModule.icap:
        return 'ICAAP';
      case AppModule.capitalPlaning:
        return 'Capital Planning';
      case AppModule.referentiels:
        return 'Paramètres';
      case AppModule.rapports:
        return 'Rapports';
    }
  }

  String get subtitle {
    switch (this) {
      case AppModule.vueEnsemble:
        return 'Synthèse du module risque de crédit.';
      case AppModule.dashboard:
        return 'Pilotage global des encours, RWA, capital et couverture CRM.';
      case AppModule.expositions:
        return 'Saisie, import, edition et suivi detaille des expositions du portefeuille.';
      case AppModule.crm:
        return 'Techniques de réduction du risque de crédit, couvertures et scénarios CRM.';
      case AppModule.horsBilan:
        return 'Pilotage des engagements hors bilan, CCF, EAD et capital associé.';
      case AppModule.garanties:
        return 'Inventaire des garanties, couvertures et statuts relies aux expositions.';
      case AppModule.defautsImpayes:
        return 'Suivi des retards, incidents prudentiels et provisions estimées.';
      case AppModule.concentrationCredit:
        return 'Analyse des concentrations sectorielles, geographiques et des plus fortes expositions.';
      case AppModule.reportingCredit:
        return 'Exports et rapports de portefeuille, garanties et defauts.';
      case AppModule.risqueMarche:
        return 'Evaluation des tensions de marché et des risques associés au portefeuille.';
      case AppModule.risqueMarcheImport:
        return 'Importation des fichiers nécessaires aux calculs de risque de marché.';
      case AppModule.risqueMarcheVar:
        return 'Value at Risk.';
      case AppModule.risqueMarcheIndicateurs:
        return 'Synthèse des indicateurs clés du portefeuille de marché.';
      case AppModule.risqueMarcheCourbeTaux:
        return 'Courbes de taux UEMOA et CEMAC utilisées pour l’actualisation.';
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

  IconData get icon {
    switch (this) {
      case AppModule.vueEnsemble:
        return Icons.pie_chart_rounded;
      case AppModule.dashboard:
        return Icons.dashboard_rounded;
      case AppModule.expositions:
        return Icons.credit_card_rounded;
      case AppModule.crm:
        return Icons.verified_user_rounded;
      case AppModule.horsBilan:
        return Icons.file_copy_rounded;
      case AppModule.garanties:
        return Icons.verified_user_rounded;
      case AppModule.defautsImpayes:
        return Icons.warning_rounded;
      case AppModule.concentrationCredit:
        return Icons.center_focus_strong_rounded;
      case AppModule.reportingCredit:
        return Icons.summarize_rounded;
      case AppModule.risqueMarche:
        return Icons.show_chart_rounded;
      case AppModule.risqueMarcheImport:
        return CupertinoIcons.doc_text_fill;
      case AppModule.risqueMarcheVar:
        return Icons.multiline_chart_rounded;
      case AppModule.risqueMarcheIndicateurs:
        return CupertinoIcons.chart_bar_alt_fill;
      case AppModule.risqueMarcheCourbeTaux:
        return CupertinoIcons.waveform_path_ecg;
      case AppModule.risqueOperationnel:
        return Icons.shield_rounded;
      case AppModule.analyse:
        return Icons.analytics_rounded;
      case AppModule.stressTest:
        return Icons.speed_rounded;
      case AppModule.icap:
        return Icons.account_balance_rounded;
      case AppModule.capitalPlaning:
        return Icons.open_in_new_rounded;
      case AppModule.referentiels:
        return Icons.tune_rounded;
      case AppModule.rapports:
        return Icons.description_rounded;
    }
  }
}
