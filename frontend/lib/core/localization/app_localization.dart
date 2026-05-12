import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_language.dart';

class AppLocalizationScope
    extends InheritedNotifier<ValueNotifier<AppLanguage>> {
  const AppLocalizationScope({
    super.key,
    required ValueNotifier<AppLanguage> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AppLanguage of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppLocalizationScope>();
    return scope?.notifier?.value ?? AppLocalizations.currentLanguage;
  }

  static ValueNotifier<AppLanguage>? maybeNotifierOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppLocalizationScope>();
    return scope?.notifier;
  }
}

class AppLocalizations {
  AppLocalizations._();

  static AppLanguage _currentLanguage = AppLanguage.francais;

  static AppLanguage get currentLanguage => _currentLanguage;

  static bool get isEnglish => _currentLanguage == AppLanguage.anglais;

  static void setCurrentLanguage(AppLanguage language) {
    if (_currentLanguage == language &&
        Intl.defaultLocale == language.intlLocale) {
      return;
    }
    _currentLanguage = language;
    Intl.defaultLocale = language.intlLocale;
  }

  static String translate(
    String source, {
    AppLanguage? language,
    Map<String, Object?> args = const {},
  }) {
    final activeLanguage = language ?? _currentLanguage;
    final resolved = switch (activeLanguage) {
      AppLanguage.francais => _frenchTranslations[source] ?? source,
      AppLanguage.anglais => _englishTranslations[source] ?? source,
    };

    if (args.isEmpty) {
      return resolved;
    }

    var output = resolved;
    args.forEach((key, value) {
      output = output.replaceAll('{{$key}}', value?.toString() ?? '');
    });
    return output;
  }
}

extension AppLocalizationContext on BuildContext {
  AppLanguage get appLanguage => AppLocalizationScope.of(this);

  String tr(
    String source, {
    Map<String, Object?> args = const {},
  }) {
    return AppLocalizations.translate(
      source,
      language: appLanguage,
      args: args,
    );
  }
}

extension AppLocalizationString on String {
  String tr(
    BuildContext context, {
    Map<String, Object?> args = const {},
  }) {
    return context.tr(this, args: args);
  }
}

const Map<String, String> _englishTranslations = {
  'Dashboard': 'Dashboard',
  'Tableau de bord': 'Dashboard',
  'Expositions': 'Exposures',
  'Données de Marché': 'Market Data',
  'Données de mrché': 'Market Data',
  'Marché': 'Market',
  'Échéanciers & Flux': 'Schedules & Cash Flows',
  'Analyse & Risques': 'Analysis & Risk',
  'Stress Tests': 'Stress Tests',
  'Stress tests': 'Stress tests',
  'Simulation': 'Simulation',
  'Référentiels': 'Reference Data',
  'Referentiels': 'Reference Data',
  'Pilotage global des encours, RWA, capital et couverture CRM.':
      'Global monitoring of exposures, RWA, capital and CRM coverage.',
  'Saisie, import, edition et suivi detaille des expositions du portefeuille.':
      'Capture, import, editing and detailed monitoring of portfolio exposures.',
  'Suivi des paramètres de marché utiles aux valorisations, stress et simulations.':
      'Monitoring market parameters used for valuation, stress and simulations.',
  'Vision des flux attendus, maturités et échéanciers de portefeuille.':
      'View of expected cash flows, maturities and portfolio schedules.',
  'Analyse du risque, des garanties et des impacts RWA.':
      'Analysis of risk, collateral and RWA impacts.',
  'Stress tests prudentiels et sensibilités du portefeuille.':
      'Prudential stress tests and portfolio sensitivities.',
  'Simulation de scénarios RWA et capital minimum.':
      'Simulation of RWA scenarios and minimum capital.',
  'Référentiels, tables RW, CCF et notations de calcul.':
      'Reference data, RW tables, CCFs and rating grids.',
  'Navigation': 'Navigation',
  'Service': 'Service',
  'RWA Crédit': 'RWA Credit',
  'Outil de pilotage des fonds propres': 'Capital steering tool',
  'Passer en mode clair': 'Switch to light mode',
  'Passer en mode sombre': 'Switch to dark mode',
  "Devise d'affichage du portefeuille": 'Portfolio display currency',
  'XOF - FCFA BCEAO': 'XOF - BCEAO CFA franc',
  'XAF - FCFA BEAC': 'XAF - BEAC CFA franc',
  'EUR - Euro': 'EUR - Euro',
  'USD - Dollar americain': 'USD - US dollar',
  'Langue': 'Language',
  'Français': 'French',
  'Anglais': 'English',
  'Exporter': 'Export',
  'Nouvelle analyse': 'New analysis',
  'Portefeuille CRM': 'CRM portfolio',
  'Rechercher...': 'Search...',
  'RWA Avant': 'RWA before',
  'Avant mitigation': 'Before mitigation',
  'RWA Apres': 'RWA after',
  'Apres mitigation': 'After mitigation',
  'Couverture CRM': 'CRM coverage',
  'Moyenne portefeuille': 'Portfolio average',
  'Scenario': 'Scenario',
  'Aucun scenario CRM disponible.': 'No CRM scenario available.',
  'RW final {{value}}': 'Final RW {{value}}',
  'Emprunteur': 'Borrower',
  'Garant': 'Guarantor',
  'RW = {{value}}': 'RW = {{value}}',
  'ID': 'ID',
  'Couverture': 'Coverage',
  'RW Avant': 'RW Before',
  'RW Final': 'RW Final',
  'Economie Capital': 'Capital saving',
  'Tables de pondération, Credit Conversion Factors et notations de calcul.':
      'Weighting tables, Credit Conversion Factors and rating scales.',
  'Tables des Ponderations': 'Weight tables',
  'Segment': 'Segment',
  'Notation': 'Rating',
  'RW': 'RW',
  'Approche': 'Approach',
  'Tables des Credit Conversion Factors': 'Credit Conversion Factor tables',
  "Nature d'Engagement": 'Commitment type',
  'CCF': 'CCF',
  'Echelle des Notations': 'Rating scale',
  'Description': 'Description',
  'Suivi des taux, spreads, devises et paramètres externes utilisés dans les analyses.':
      'Monitoring rates, spreads, currencies and external parameters used in analysis.',
  'Indicateurs clés': 'Key indicators',
  'Courbe taux': 'Rate curve',
  'Point 10Y actualisé': 'Latest 10Y point',
  'Spread crédit': 'Credit spread',
  'Segment corporate': 'Corporate segment',
  'Taux spot': 'Spot rate',
  'Jeux de données suivis': 'Tracked datasets',
  'Courbes souveraines': 'Sovereign curves',
  'Disponible': 'Available',
  'Provider interne': 'Internal provider',
  'Spreads bancaires': 'Banking spreads',
  'Mis à jour': 'Updated',
  'Feed marché': 'Market feed',
  'FX & inflation': 'FX & inflation',
  'Banque centrale': 'Central bank',
  'Visualisation des maturités, remboursements, flux futurs et jalons du portefeuille.':
      'Visualization of maturities, repayments, future cash flows and portfolio milestones.',
  'Vue maturité': 'Maturity view',
  '0 - 3 mois': '0 - 3 months',
  '3 - 12 mois': '3 - 12 months',
  '1 - 5 ans': '1 - 5 years',
  '5 ans +': '5+ years',
  'Prochains flux': 'Upcoming cash flows',
  'Coupon obligataire': 'Bond coupon',
  'Amortissement prêt': 'Loan amortization',
  'Flux CRM attendu': 'Expected CRM flow',
  'Construction de scenarios RWA, CRM et capital minimum.':
      'Build RWA, CRM and minimum capital scenarios.',
  'Scenarios disponibles': 'Available scenarios',
  'Variation RW': 'RW variation',
  'Simuler une hausse ou baisse des ponderations.':
      'Simulate higher or lower risk weights.',
  'Effet CRM': 'CRM effect',
  'Tester une couverture garantie supplementaire.':
      'Test additional collateral coverage.',
  'Capital': 'Capital',
  'Mesurer l impact sur le capital minimum.':
      'Measure the impact on minimum capital.',
  'Sensibilites portefeuille sur notation, CCF, garanties et capital.':
      'Portfolio sensitivities on ratings, CCF, collateral and capital.',
  'Axes de stress': 'Stress axes',
  'Degradation notation': 'Rating downgrade',
  'Tester une migration adverse des contreparties.':
      'Test an adverse migration of counterparties.',
  'Hausse CCF': 'CCF increase',
  'Mesurer l effet des engagements hors bilan.':
      'Measure the effect of off-balance-sheet commitments.',
  'Choc capital': 'Capital shock',
  'Evaluer la sensibilite du ratio de solvabilite.':
      'Assess solvency ratio sensitivity.',
  'Choisir une date de reférence': 'Choose a reference date',
  'Dernière évaluation': 'Last valuation',
  'Vue synthèse du portefeuille, des RWA et du capital prudentiel.':
      'Summary view of the portfolio, RWA and prudential capital.',
  'Import Excel impossible': 'Excel import failed',
  'Feuilles manquantes': 'Missing sheets',
  'Colonnes manquantes': 'Missing columns',
  'Indicateurs manquants': 'Missing indicators',
  'Points à corriger': 'Items to fix',
  'Colonnes détectées dans le fichier': 'Columns detected in the file',
  'Feuilles détectées dans le fichier': 'Sheets detected in the file',
  'Noms de feuilles attendus': 'Expected sheet names',
  'Colonnes attendues par feuille': 'Expected columns by sheet',
  'Indicateurs attendus': 'Expected indicators',
  'Fermer': 'Close',
  'Exposition totale brute': 'Gross exposure',
  'Risque residuel': 'Residual risk',
  'Exposition brute - Garanties': 'Gross exposure - Guarantees',
  'RWA total': 'Total RWA',
  'Capital minimum requis': 'Minimum capital required',
  'Ratio de solvabilite': 'Solvency ratio',
  'Densité RWA': 'RWA density',
  'Taux de défaut': 'Default rate',
  'Encours de défaut / Exposition brute': 'Defaulted outstanding / Gross exposure',
  'Densité RWA du portefeuille': 'Portfolio RWA density',
  'RWA total / Exposition totale brute': 'Total RWA / Gross exposure',
  'RWA / Exposition brute': 'RWA / Gross exposure',
  'Risque faible': 'Low risk',
  'Risque moyen': 'Medium risk',
  'Profil de maturité des RWA': 'RWA maturity profile',
  "Vue prévisionnelle de l'amortissement et de la libération projetés des RWA.":
      'Forward view of projected amortization and RWA release.',
  'Monthly': 'Monthly',
  'Quarterly': 'Quarterly',
  'Yearly': 'Yearly',
  'Amortissement mensuel': 'Monthly amortization',
  'Projection': 'Projection',
  'Unité: {{value}}': 'Unit: {{value}}',
  'Encours RWA': 'Outstanding RWA',
  'RWA libéré cumulé': 'Cumulative released RWA',
  "Pic d'amort.": 'Peak amort.',
  'Horizon': 'Horizon',
  'milliards {{currency}}': 'billions {{currency}}',
  'millions {{currency}}': 'millions {{currency}}',
  'milliers {{currency}}': 'thousands {{currency}}',
  'Top 5 du RWA total par catégorie': 'Top 5 total RWA by category',
  'Top 5 de l\'exposition totale brute': 'Top 5 gross exposures',
  "Repartition de l'exposition par catégorie": 'Exposure breakdown by category',
  "Lecture directe de l'exposition brute et du RWA par segment d'exposition.":
      'Direct view of gross exposure and RWA by exposure segment.',
  'Répartition totale par type de CRM': 'Total breakdown by CRM type',
  'Attenuation du risque de crédit ( CRM )': 'Credit risk mitigation (CRM)',
  "Top 5 de l'encours total par pays UEMOA":
      'Top 5 total outstanding amounts by WAEMU country',
  "Lecture directe de l'encours total par pays UEMOA.":
      'Direct view of total outstanding amounts by WAEMU country.',
  'Qualité de crédit moyenne du portefeuille':
      'Average portfolio credit quality',
  'Vue dynamique de la qualité de crédit à travers le risque pondéré moyen':
      'Dynamic view of credit quality through average risk weighting',
  'Aucune catégorie disponible': 'No category available',
  'Qualité bonne': 'Good quality',
  'Qualité moyenne': 'Balanced quality',
  'Qualité élevée': 'High pressure',
  'Qualité excellente': 'Excellent quality',
  'Qualité faible': 'Weak quality',
  'Strong quality': 'Strong quality',
  'Balanced quality': 'Balanced quality',
  'Higher pressure': 'Higher pressure',
  'Faible': 'Low',
  'Moyen': 'Medium',
  'Élevé': 'High',
  'peu risqué': 'low risk',
  'normal': 'normal',
  'alerte': 'alert',
  'Risque faible (densité)': 'Low risk',
  'Risque moyen (densité)': 'Medium risk',
  'Risque élevé (densité)': 'High risk',
  'Risque élevé': 'High risk',
  'Interprétation': 'Interpretation',
  'Actuel': 'Current',
  'Astuce': 'Tip',
  'Contribution principale': 'Primary contribution',
  'Contribution notable': 'Notable contribution',
  'Contribution secondaire': 'Secondary contribution',
  "{{percent}} de l'encours total": '{{percent}} of total outstanding balance',
  'Org. publics': 'Public bodies',
  'Institutions fin.': 'Financial inst.',
  'Clientèle détail': 'Retail',
  'Immo R': 'Res. RE',
  'Immo C': 'Comm. RE',
  'En souffrance': 'Past due',
  'Le risque faible désigne un portefeuille dont la consommation en RWA reste modérée. Il traduit en général une qualité de crédit saine et une pression limitée sur le capital réglementaire.':
      'Low risk refers to a portfolio whose RWA consumption remains moderate. It usually reflects sound credit quality and limited pressure on regulatory capital.',
  'Maintenir la qualité des contreparties, préserver les garanties efficaces et suivre les concentrations par secteur.':
      'Maintain counterparty quality, preserve effective collateral, and monitor sector concentrations.',
  'Le risque moyen correspond à une situation équilibrée, mais plus sensible aux variations de qualité de crédit. Il nécessite une surveillance régulière car les RWA peuvent augmenter plus rapidement en cas de dégradation.':
      'Medium risk reflects a balanced situation, but one that is more sensitive to changes in credit quality. It requires regular monitoring because RWAs can rise faster in the event of deterioration.',
  'Renforcer le suivi des expositions sensibles, revoir les couvertures disponibles et anticiper les besoins en capital.':
      'Strengthen monitoring of sensitive exposures, review available coverage, and anticipate capital needs.',
  'Le risque élevé décrit un portefeuille plus exigeant en capital et plus exposé aux détériorations de notation. Il signale une vulnérabilité accrue et appelle une attention prioritaire sur les expositions concernées.':
      'High risk describes a portfolio that is more capital-intensive and more exposed to rating deterioration. It signals greater vulnerability and calls for priority attention on the exposures concerned.',
  'Prioriser les actions de réduction de RWA, sécuriser les expositions les plus lourdes et renforcer rapidement les mécanismes de couverture.':
      'Prioritize RWA reduction actions, secure the heaviest exposures, and quickly strengthen coverage mechanisms.',
  'souverains': 'sovereigns',
  'organismes pub. hors Adm c':
      'public-sector entities outside central administration',
  'Expositions sur les BMD': 'MDB exposures',
  'institutions financières': 'financial institutions',
  'entreprises': 'corporates',
  'clientèle de détail': 'retail',
  "prêts garantis par l'immo R": 'residential real-estate secured loans',
  "prêts garantis par l'immo C": 'commercial real-estate secured loans',
  'créances en souffrance': 'past-due exposures',
  'créances à risque élevé': 'high-risk exposures',
  'autres actifs': 'other assets',
  'Hors bilan': 'Off-balance sheet',
  'CRM financee': 'Funded CRM',
  'CRM non financee': 'Unfunded CRM',
  'Aucune': 'None',
  'Grille prudentielle de saisie, import, modification et suivi RWA avec zone UEMOA/CEMAC automatique.':
      'Prudential grid for data entry, import, updates and RWA monitoring with automatic UEMOA/CEMAC zoning.',
  'Ajouter une exposition': 'Add exposure',
  'Supprimer la sélection': 'Delete selection',
  'Importation...': 'Importing...',
  'Import': 'Import',
  'Export': 'Export',
  'Lignes': 'Rows',
  '{{count}} select.': '{{count}} selected',
  'Vue cour.': 'Current view',
  'Capital min.': 'Min. capital',
  'Exig. reg.': 'Reg. requirement',
  'Contrepartie': 'Counterparty',
  'Nom ou raison sociale': 'Name or legal entity',
  'Pays': 'Country',
  'Pays de résidence': 'Country of residence',
  'Catégorie': 'Category',
  'Toutes': 'All',
  'Zone': 'Zone',
  'Hors zone': 'Outside zone',
  'Type CRM': 'CRM type',
  'Exposition ajoutee.': 'Exposure added.',
  'Exposition mise a jour.': 'Exposure updated.',
  'Modifier l exposition': 'Edit exposure',
  'Ajouter': 'Add',
  'Mettre a jour': 'Update',
  'Suppression impossible:': 'Deletion failed:',
  'Confirmer la suppression': 'Confirm deletion',
  'Cette action supprimera l exposition selectionnee dans le tableau et dans la base locale.':
      'This action will delete the selected exposure from the table and the local database.',
  'Cette action supprimera les expositions selectionnees dans le tableau et dans la base locale.':
      'This action will delete the selected exposures from the table and the local database.',
  'Annuler': 'Cancel',
  'Supprimer': 'Delete',
  '{{count}} exposition(s) supprimee(s) du tableau et de la base locale.':
      '{{count}} exposure(s) deleted from the table and the local database.',
  '{{deleted}} exposition(s) supprimee(s). {{missing}} introuvable(s): {{ids}}.':
      '{{deleted}} exposure(s) deleted. {{missing}} missing: {{ids}}.',
  'Aucune suppression effectuee. IDs introuvables: {{ids}}.':
      'No deletion performed. Missing IDs: {{ids}}.',
  'Aucune exposition supprimee.': 'No exposure deleted.',
  'Vue exportee au format CSV dans le presse-papiers.':
      'View exported as CSV to the clipboard.',
  'Importer Excel/CSV': 'Import Excel/CSV',
  'Selectionnez un classeur .xlsx ou collez un CSV/TSV, verifiez les lignes detectees, puis validez l import.':
      'Select an .xlsx workbook or paste CSV/TSV content, review the detected rows, then confirm the import.',
  'Importation du fichier Excel en cours...':
      'Excel file import in progress...',
  'Importation des donnees en cours...': 'Data import in progress...',
  'Aucune ligne exploitable detectee dans ce classeur. Verifiez que le fichier utilise le modele Excel RWA avec la feuille "Template donnees".':
      'No usable row detected in this workbook. Make sure the file uses the RWA Excel template with the "Template donnees" sheet.',
  '{{count}} ligne(s) detectee(s) dans {{filename}}.':
      '{{count}} row(s) detected in {{filename}}.',
  'Apercu Excel impossible. Le fichier doit etre un .xlsx au format du modele RWA.':
      'Excel preview failed. The file must be an .xlsx using the RWA template format.',
  'Apercu Excel impossible: {{error}}': 'Excel preview failed: {{error}}',
  'Choisir un fichier .xlsx': 'Choose an .xlsx file',
  'CSV/TSV lu, mais aucune ligne exploitable detectee. Colonnes minimales: contrepartie, pays, categorie, notation, montant.':
      'CSV/TSV read, but no usable row detected. Minimum columns: counterparty, country, category, rating, amount.',
  'Lecture CSV/TSV impossible: {{error}}': 'CSV/TSV read failed: {{error}}',
  'Choisir un CSV/TSV': 'Choose a CSV/TSV file',
  '{{count}} ligne(s) detectee(s)': '{{count}} row(s) detected',
  '{{count}} ligne(s) detectee(s) dans le texte colle.':
      '{{count}} row(s) detected in the pasted text.',
  'id;contrepartie;pays;categorie;notation;montant;placement;type_engagement;crm;devise;couverture':
      'id;counterparty;country;category;rating;amount;booking;commitment_type;crm;currency;coverage',
  '{{imported}} ligne(s) importee(s), dont {{off_balance}} hors bilan.':
      '{{imported}} row(s) imported, including {{off_balance}} off-balance-sheet.',
  'Importation impossible: {{error}}': 'Import failed: {{error}}',
  'Importer': 'Import',
  'Excel': 'Excel',
  'CSV': 'CSV',
  '{{count}} exposition(s) importee(s) depuis {{filename}}.':
      '{{count}} exposure(s) imported from {{filename}}.',
  'Aucune exposition detectee dans le fichier selectionne.':
      'No exposure detected in the selected file.',
  'Apercu Excel': 'Excel preview',
  'Aucune ligne detectee. Verifiez les en-tetes: contrepartie, pays, categorie, notation, montant.':
      'No row detected. Check the headers: counterparty, country, category, rating, amount.',
  'Collez des donnees avec une ligne d en-tetes ou choisissez un fichier CSV/TSV pour afficher l apercu.':
      'Paste data with a header row or choose a CSV/TSV file to display the preview.',
  'Apercu CSV/TSV': 'CSV/TSV preview',
  'Fiche exposition': 'Exposure form',
  'CRM': 'CRM',
  'Commentaire': 'Comment',
  'RW brut': 'Gross RW',
  'EAD': 'EAD',
  'RW final': 'Final RW',
  'RWA': 'RWA',
  'Verifier les montants saisis.': 'Please verify the entered amounts.',
  'Echec de l enregistrement: {{error}}': 'Save failed: {{error}}',
  'LEADER DE L\'ALM EN AFRIQUE SUBSAHARIENNE': 'SUB-SAHARAN AFRICA ALM LEADER',
  'Recherche rapide': 'Quick search',
  'Erreur: {{error}}': 'Error: {{error}}',
  'Trajectoire RWA': 'RWA trajectory',
  'Cette période concentre la baisse la plus marquée de la trajectoire. Le stock RWA se détend plus vite, ce qui accélère la libération du capital réglementaire.':
      'This period concentrates the sharpest decline in the trajectory. The RWA stock eases faster, which accelerates regulatory capital release.',
  "A partir de ce point, la courbe devient prévisionnelle. La lecture doit être comprise comme une estimation du rythme futur d'amortissement et de relâchement des RWA.":
      'From this point onward, the curve becomes forward-looking. It should be read as an estimate of the future pace of amortization and RWA release.',
  "Ce point représente l'horizon de projection disponible dans le dashboard. Il permet d'estimer le niveau résiduel de RWA à la fin de la séquence observée.":
      'This point represents the projection horizon available in the dashboard. It helps estimate the residual RWA level at the end of the observed sequence.',
  'Rapport RWA importé avec succès (Attention indisponible pour le moment).':
      'RWA report successfully generated (feature temporarily unavailable).',
  'Nouvelle source importée: {{filename}}': 'New source imported: {{filename}}',
  'Import impossible: {{error}}': 'Import failed: {{error}}',
  'Merci de patienter pendant la mise à jour des données.':
      'Please wait while data is being updated.',
  'Edition prudente avec calcul automatique EAD, RW, RWA et capital dans la devise de saisie.':
      'Prudential editing with automatic EAD, RW, RWA and capital calculation in the input currency.',
  'Categorie prudentielle': 'Prudential category',
  'Montant brut': 'Gross amount',
  'Montant invalide': 'Invalid amount',
  'Devise': 'Currency',
  'Statut': 'Status',
  'Mode CRM': 'CRM mode',
  'Valeur du collateral': 'Collateral value',
  'Indice principal reconnu ?': 'Recognized main index?',
  'Obligation convertible': 'Convertible bond',
  "Choisissez Oui si l'obligation convertible reçue en garantie est incluse dans un indice principal reconnu.\nChoisissez Non dans le cas contraire.\nLa décote HC est de 20 % si Oui, contre 30 % si Non.":
      'Choose Yes if the convertible bond received as collateral is included in a recognized main index.\nChoose No otherwise.\nThe HC haircut is 20% for Yes, versus 30% for No.',
  'Type d emetteur': 'Issuer type',
  'Notation du collateral': 'Collateral rating',
  'Maturité': 'Maturity',
  'Maturité résiduelle': 'Residual maturity',
  'Hfx - Decote de change (%)': 'Hfx - FX haircut (%)',
  'Type de garantie': 'Guarantee type',
  'Nom du garant': 'Guarantor name',
  'Categorie du garant': 'Guarantor category',
  'Notation du garant': 'Guarantor rating',
  'Pourcentage de couverture': 'Coverage percentage',
  'Enregistrement...': 'Saving...',
  'Ajout de l exposition en cours...': 'Adding exposure...',
  'Mise à jour de l exposition en cours...': 'Updating exposure...',
  'Merci de patienter pendant l enregistrement.':
      'Please wait while the record is being saved.',
  'Champ requis': 'Required field',
  'Choisir une option': 'Choose an option',
  'Pourcentage invalide': 'Invalid percentage',
  'Nouvelle exposition': 'New exposure',
  'Enregistrer': 'Save',
  'Active': 'Active',
  'Echue': 'Expired',
  'En defaut': 'Defaulted',
  'Garantie etatique': 'Sovereign guarantee',
  'Assurance credit': 'Credit insurance',
  'Garantie bancaire': 'Bank guarantee',
  'souverain': 'sovereign',
  'autre': 'other',
  '<=1 an': '<=1 year',
  '1-3 ans': '1-3 years',
  '3-5 ans': '3-5 years',
  '5-10 ans': '5-10 years',
  '>10 ans': '>10 years',
  'Souverains': 'Sovereigns',
  'Organismes publics': 'Public-sector entities',
  'BMD': 'MDBs',
  'Institutions financieres': 'Financial institutions',
  'Entreprises': 'Corporates',
  'Clientele de detail': 'Retail clients',
  'Immobilier residentiel': 'Residential real estate',
  'Immobilier commercial': 'Commercial real estate',
  'Creances en souffrance': 'Past-due exposures',
  'Risque eleve': 'High-risk',
  'Créances à risque élevé': 'High-risk exposures',
  '(a) souverains': '(a) sovereigns',
  '(b) organismes pub. hors Adm c':
      '(b) public-sector entities outside central administration',
  '(c) Expositions sur les BMD': '(c) MDB exposures',
  '(d) institutions financieres': '(d) financial institutions',
  '(e) entreprises': '(e) corporates',
  '(f) clientele de detail': '(f) retail clients',
  "(g) prêts garantis par l'immo R":
      '(g) residential real-estate secured loans',
  "(h) prêts garantis par l'immo C": '(h) commercial real-estate secured loans',
  '(i) creances en souffrance': '(i) past-due exposures',
  '(j) creances a risque eleve': '(j) high-risk exposures',
  '(j) créances à risque élevé': '(j) high-risk exposures',
  '(k) autres actifs': '(k) other assets',
  '{{title}} - {{count}} ligne(s), affichage des {{preview}} premiere(s)':
      '{{title}} - {{count}} row(s), showing the first {{preview}}',
  'Infos calcul': 'Calculation info',
  'Categorie': 'Category',
  'Type spécifique d’exposition souveraine (le cas échéant)':
      'Specific type of sovereign exposure (if applicable)',
  'Cette exposition concerne-t-elle des souverains UEMOA/BCEAO ou leurs démembrements libellés et financés en FCFA, ou des institutions internationales ?':
      'Does this exposure concern UEMOA/BCEAO sovereigns or their entities denominated and funded in FCFA, or international institutions?',
  'Oui': 'Yes',
  'Non': 'No',
  'L’exposition respecte-t-elle les critères de classement en clientèle de détail ?':
      'Does the exposure meet the classification criteria for retail exposure?',
  'Destination : particulier ou PME/PMI': 'Destination: individual or SME',
  'Produits concernés : crédits CT/MT/LT, découverts, cartes de crédit, crédit-bail, facilités aux PME':
      'Relevant products: short/medium/long-term loans, overdrafts, credit cards, leasing and SME facilities',
  'Granularité : exposition ≤ 0,2 % du portefeuille retail global':
      'Granularity: exposure <= 0.2% of the overall retail portfolio',
  'Faible montant : encours agrégé par contrepartie ≤ 150 millions FCFA':
      'Low amount: aggregate outstanding per counterparty <= 150 million FCFA',
  'Consentement BIC : accord du client pour transmission des données au BIC':
      'Credit bureau consent: client approval for sharing data with the BIC',
  'En cas de défaut, l’exposition relève de la catégorie des expositions en défaut.':
      'If the exposure is in default, it must be treated under the defaulted exposures category.',
  'Les actions, obligations et créances hypothécaires bénéficiant d’un régime spécifique ne relèvent pas de la clientèle de détail.':
      'Equities, bonds and mortgage claims benefiting from a specific regime must not be treated as retail exposures.',
  'Cas spécifique concerné': 'Relevant specific case',
  'Selectionner un cas': 'Select a case',
  'Expositions sur États de l’UEMOA et démembrements libellées et financées en FCFA':
      'Exposures to WAEMU States and their subdivisions denominated and funded in FCFA',
  'Expositions sur BCEAO libellées et financées en FCFA':
      'Exposures to the BCEAO denominated and funded in FCFA',
  'UEMOA': 'WAEMU',
  'CEDEAO': 'ECOWAS',
  'UA': 'AU',
  'UE': 'EU',
  'ONU': 'UN',
  'BRI': 'BIS',
  'FMI': 'IMF',
  'BCE': 'ECB',
  'FGD-UMOA': 'FGD-WAEMU',
  'Aucun de ces cas': 'None of these cases',
  'Cas préférentiel 0 % (historique)':
      'Legacy 0% preferential case (historical)',
  'Notation de la catégorie': 'Category rating',
  'Notation externe de la catégorie': 'External category rating',
  'L’exposition concerne-t-elle une BMD répondant aux critères suivants ?':
      'Does this exposure concern an MDB meeting the following criteria?',
  'Notation élevée, soutien actionnarial fort, capital et liquidité solides, gestion des risques prudente.':
      'High rating, strong shareholder support, solid capital and liquidity, prudent risk management.',
  '(a) excellente notation long terme (majoritairement AAA)\n(b) actionnariat composé en grande partie de souverains ≥ AA- ou financement surtout par capital versé\n(c) fort soutien des actionnaires\n(d) niveau adéquat de capital et de liquidité\n(e) politiques de crédit et gestion des risques prudentes':
      '(a) excellent long-term rating (mostly AAA)\n(b) shareholding largely made up of sovereigns rated AA- or above, or financing mainly through paid-in capital\n(c) strong shareholder support\n(d) adequate capital and liquidity levels\n(e) prudent credit policies and risk management',
  'L’exposition concerne-t-elle une BMD des États de l’UEMOA libellée et financée en FCFA ?':
      'Does this exposure concern an MDB of WAEMU States denominated and funded in FCFA?',
  'La BMD respecte-t-elle les critères c), d) et e) ?':
      'Does the MDB meet criteria c), d) and e)?',
  'L’exposition concerne-t-elle l’une des institutions suivantes : BIRD, SFI, BAsD, BAD, BERD, BEI, FEI, BNI, BDC, BIsD, BDCE, AMGI ou BOAD libellée et financée en FCFA ?':
      'Does this exposure concern one of the following institutions denominated and funded in FCFA: IBRD, IFC, AfDB, ADB, EBRD, EIB, EIF, NIB, CDB, IsDB, ECDB, MIGA or BOAD?',
  "BIRD : Banque internationale pour la reconstruction et le développement\nSFI : Société financière internationale\nBAsD : Banque asiatique de développement\nBAD : Banque africaine de développement\nBERD : Banque européenne pour la reconstruction et le développement\nBEI : Banque européenne d'investissement\nFEI : Fonds européen d'investissement\nBNI : Banque nordique d'investissement\nBDC : Banque de développement des Caraïbes\nBIsD : Banque islamique de développement\nBDCE : Banque de développement des Caraïbes orientales\nAMGI : Agence multilatérale de garantie des investissements\nBOAD : Banque ouest-africaine de développement":
      'IBRD: International Bank for Reconstruction and Development\nIFC: International Finance Corporation\nAsDB: Asian Development Bank\nAfDB: African Development Bank\nEBRD: European Bank for Reconstruction and Development\nEIB: European Investment Bank\nEIF: European Investment Fund\nNIB: Nordic Investment Bank\nCDB: Caribbean Development Bank\nIsDB: Islamic Development Bank\nECDB: Eastern Caribbean Development Bank\nMIGA: Multilateral Investment Guarantee Agency\nBOAD: West African Development Bank',
  'Notation de la BMD': 'MDB rating',
  'Pondération automatique selon la notation sélectionnée.':
      'Automatic risk weight based on the selected rating.',
  "Banque hors UMOA soumise à des règles équivalentes à celles de l'UMOA":
      'Bank outside WAEMU subject to rules equivalent to those of WAEMU',
  'Banque en difficulté prudentielle': 'Bank in prudential difficulty',
  'Institution faisant partie des categories suivantes :':
      'Institution belonging to the following categories:',
  'Catégories concernées': 'Concerned categories',
  '(veuillez consulter le point infos pour en savoir plus)':
      '(please consult the info icon to learn more)',
  'Article 133': 'Article 133',
  'Article 134': 'Article 134',
  "(a) les entreprises du secteur bancaire\n(b) les services financiers des administrations de poste\n(c) les caisses nationales d'épargne\n(d) les autres institutions financières internationales.":
      '(a) banking sector firms\n(b) postal administration financial services\n(c) national savings institutions\n(d) other international financial institutions.',
  "Une pondération supérieure à 100 % est exigée lorsque le taux brut de dégradation du portefeuille entreprise dépasse sur deux trimestres consécutifs un seuil fixé par instruction de la BCEAO.\n\nUne pondération plus élevée est appliquée, lorsqu'une entreprise établie dans l'UMOA est soumise à une procédure de traitement prudentiel résultant de la production, par l'entreprise elle-même ou par son commissaire au compte, d'informations financières erronées.\n\n[[NOTE]]On entend par taux brut de dégradation du portefeuille, le rapport entre l'encours des créances en souffrance brutes telles que défini aux paragraphes 152 à 160 et le portefeuille de crédit brut de l'établissement. S'agissant des entreprises, le taux brut de dégradation du portefeuille est le rapport entre l'encours des créances en souffrance brutes enregistré au titre du portefeuille entreprises et l'encours total des crédits bruts octroyés à ce segment.":
      "A risk weight above 100% is required when the gross deterioration rate of the corporate portfolio exceeds, for two consecutive quarters, a threshold set by BCEAO instruction.\n\nA higher risk weight is applied when an undertaking established in WAEMU is subject to a prudential treatment procedure resulting from the production, by the undertaking itself or by its statutory auditor, of inaccurate financial information.\n\n[[NOTE]]The gross deterioration rate of the portfolio means the ratio between the outstanding amount of gross non-performing claims as defined in paragraphs 152 to 160 and the institution's gross credit portfolio. For corporates, it is the ratio between the outstanding amount of gross non-performing claims recorded for the corporate portfolio and the total outstanding amount of gross loans granted to that segment.",
  "Les expositions sur les entreprises d'investissement, autres que celles soumises à la loi uniforme portant réglementation bancaire doivent être pondérées, conformément aux règles afférentes aux créances sur les entreprises.\n\nEn outre, les expositions sur les entreprises non notées ne peuvent être affectées d’une pondération plus favorable que celle portant sur l’Etat dans lequel ces entreprises ont leur siège social.":
      'Exposures to investment firms, other than those subject to the uniform banking regulation law, must be risk-weighted in accordance with the rules applicable to claims on corporates.\n\nFurthermore, exposures to unrated corporates may not receive a more favorable risk weight than that applied to the State in which those corporates have their registered office.',
  'Le souverain est-il établi par les OCE ?':
      'Is the sovereign established by the OCEs?',
  'Sous-cas des souverains non notés': 'Unrated sovereign sub-case',
  'Le souverain est établi par les OCE':
      'The sovereign is established by the OCEs',
  'Si oui, la note OCE 0 à 7 détermine directement la pondération.':
      'If yes, the OCE score from 0 to 7 directly determines the risk weight.',
  'Échelle de 0 à 7': 'Scale from 0 to 7',
  'Pondération réglementaire': 'Regulatory risk weight',
  'Cas préférentiel historique à 0 % conservé.':
      'Historical 0% preferential case preserved.',
  'Cas prioritaire à 0 % appliqué : {{case}}':
      'Priority 0% case applied: {{case}}',
  'Pondération calculée selon la notation du souverain.':
      'Risk weight calculated from the sovereign rating.',
  'Pondération calculée selon la note OCE sélectionnée.':
      'Risk weight calculated from the selected OCE score.',
  'Souverain non noté hors OCE : la pondération standard de 100 % s\'applique.':
      'Unrated sovereign outside OCE: the standard 100% risk weight applies.',
  'Définition': 'Definition',
  'Précision': 'Note',
  'Exemples inclus': 'Included examples',
  'Type d’élément d’actif': 'Asset item type',
  'Les autres éléments d’actifs correspondent aux expositions non prises en compte dans les autres catégories prudentielles, hors éléments déjà déduits des fonds propres et hors expositions soumises à des exigences spécifiques.':
      'Other asset items correspond to exposures not captured in the other prudential categories, excluding items already deducted from own funds and exposures subject to specific requirements.',
  'Encaisse': 'Cash',
  'Valeurs assimilées à l’encaisse, y compris l’or':
      'Cash-equivalent items, including gold',
  'Valeurs à l’encaissement avec crédit immédiat':
      'Items for collection with immediate credit',
  'Participations non significatives non déduites des fonds propres':
      'Non-significant participations not deducted from own funds',
  'Immobilisations corporelles': 'Tangible fixed assets',
  'Autres actifs divers': 'Other miscellaneous assets',
  'Engagements en actions non déduits': 'Equity commitments not deducted',
  'Expositions sur entreprises financières non soumises à une réglementation équivalente UMOA':
      'Exposures to financial undertakings not subject to equivalent WAEMU regulation',
  'Autres éléments d’actifs non définis':
      'Other asset items not otherwise defined',
  'Participations significatives et impôts différés actifs non déduits':
      'Significant participations and deferred tax assets not deducted',
  'Expositions sur établissements non conformes aux ratios de solvabilité':
      'Exposures to institutions not compliant with solvency ratios',
  'comptes d’ordre, dépôts, débiteurs, FCP, stocks.':
      'memorandum accounts, deposits, debtors, mutual funds and inventories.',
  'hors engagements soumis à 250 % et hors actifs à risque élevé soumis à 150 %.':
      'excluding commitments subject to 250% and excluding high-risk assets subject to 150%.',
  'Niveau de risque hors bilan': 'Off-balance-sheet risk level',
  'Niveau de risque': 'Risk level',
  'Risque mineur': 'Minor risk',
  'Risque très élevé': 'Very high risk',
  'engagements révocables sans condition, à tout moment, sans préavis ou caducs automatiquement.':
      'unconditionally revocable commitments, cancellable at any time without notice, or commitments that lapse automatically.',
  'engagements ≤ 1 an non révocables sans condition ; lettres de crédit commerciales à court terme, crédits documentaires.':
      'commitments <= 1 year that are not unconditionally revocable; short-term commercial letters of credit and documentary credits.',
  'engagements > 1 an non révocables sans condition ; lettres de crédit documentaires non garanties par marchandises ; garanties de bonne exécution, de soumission, de tiers, crédits de confirmation.':
      'commitments > 1 year that are not unconditionally revocable; documentary letters of credit not guaranteed by goods; performance bonds, bid bonds, third-party guarantees and confirmation credits.',
  'facilités d’émission d’effets (FEE) et facilités de prise ferme renouvelables (FPR) ; substituts directs de crédit, garanties d’endettement, acceptations.':
      'note issuance facilities (NIFs) and revolving underwriting facilities (RUFs); direct credit substitutes, debt guarantees and acceptances.',
  'opérations assimilables à des pensions, repo ou prêts de titres ; cessions d’actifs avec recours, affacturage ou escompte ; engagements d’achat d’actifs à terme ; dépôts à terme contre terme ; fraction non versée d’actions ou titres partiellement libérés ; autres éléments hors bilan non classés.':
      'transactions similar to repos or securities lending; asset sales with recourse, factoring or discounting; forward asset purchase commitments; back-to-back term deposits; unpaid portion of shares or partially paid securities; other unclassified off-balance-sheet items.',
  'Le FCEC est déterminé automatiquement selon le niveau de risque hors bilan sélectionné.':
      'The CCF is determined automatically according to the selected off-balance-sheet risk level.',
  'Ponderation appliquee': 'Applied risk weight',
};

const Map<String, String> _frenchTranslations = {
  'Market Data': 'Données de Marché',
  'Market': 'Marché',
  'Schedules & Cash Flows': 'Échéanciers & Flux',
  'Analysis & Risk': 'Analyse & Risques',
  'Reference Data': 'Référentiels',
  'Portfolio display currency': "Devise d'affichage du portefeuille",
  'Switch to light mode': 'Passer en mode clair',
  'Switch to dark mode': 'Passer en mode sombre',
  'Language': 'Langue',
  'French': 'Français',
  'English': 'Anglais',
  'Export': 'Exporter',
  'New analysis': 'Nouvelle analyse',
  'Monthly': 'Mensuel',
  'Quarterly': 'Trimestriel',
  'Yearly': 'Annuel',
  'Strong quality': 'Qualité bonne',
  'Balanced quality': 'Qualité moyenne',
  'Higher pressure': 'Qualité élevée',
  'Risque faible (densité)': 'Risque faible',
  'Risque moyen (densité)': 'Risque moyen',
  'Risque élevé (densité)': 'Risque élevé',
  'Dashboard': 'Tableau de bord',
  'Exposures': 'Expositions',
};
