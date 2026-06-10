// Modèles Dart du module Risque Opérationnel.

// ─── Incidents ────────────────────────────────────────────────────────────────

class RoIncident {
  const RoIncident({
    required this.id,
    required this.reference,
    required this.dateOccurrence,
    required this.description,
    required this.ligneMetier,
    required this.typeEvenement,
    required this.causeRacine,
    required this.perteBrute,
    required this.perteRecuperee,
    required this.perteNette,
    required this.statut,
    required this.significatif,
    required this.creeLe,
    required this.modifieLe,
  });

  final String id;
  final String reference;
  final String dateOccurrence;
  final String description;
  final String ligneMetier;
  final String typeEvenement;
  final String causeRacine;
  final double perteBrute;
  final double perteRecuperee;
  final double perteNette;
  final String statut;
  final bool significatif;
  final String creeLe;
  final String modifieLe;

  factory RoIncident.fromJson(Map<String, dynamic> j) => RoIncident(
        id: j['id'] as String,
        reference: j['reference'] as String,
        dateOccurrence: j['date_occurrence'] as String,
        description: j['description'] as String,
        ligneMetier: j['ligne_metier'] as String,
        typeEvenement: j['type_evenement'] as String,
        causeRacine: j['cause_racine'] as String? ?? '',
        perteBrute: (j['perte_brute'] as num?)?.toDouble() ?? 0,
        perteRecuperee: (j['perte_recuperee'] as num?)?.toDouble() ?? 0,
        perteNette: (j['perte_nette'] as num?)?.toDouble() ?? 0,
        statut: j['statut'] as String,
        significatif: j['significatif'] as bool? ?? false,
        creeLe: j['cree_le'] as String? ?? '',
        modifieLe: j['modifie_le'] as String? ?? '',
      );
}

// ─── KRI ──────────────────────────────────────────────────────────────────────

class RoKriDefinition {
  const RoKriDefinition({
    required this.id,
    required this.nom,
    required this.unite,
    required this.formule,
    required this.seuilAlerte,
    required this.seuilCritique,
    required this.sens,
    required this.frequence,
  });

  final String id;
  final String nom;
  final String unite;
  final String formule;
  final double seuilAlerte;
  final double seuilCritique;
  final String sens;
  final String frequence;

  factory RoKriDefinition.fromJson(Map<String, dynamic> j) => RoKriDefinition(
        id: j['id'] as String,
        nom: j['nom'] as String,
        unite: j['unite'] as String,
        formule: j['formule'] as String? ?? '',
        seuilAlerte: (j['seuil_alerte'] as num).toDouble(),
        seuilCritique: (j['seuil_critique'] as num).toDouble(),
        sens: j['sens'] as String,
        frequence: j['frequence'] as String,
      );
}

class RoKriValeur {
  const RoKriValeur({
    required this.id,
    required this.kriId,
    required this.dateMesure,
    required this.valeur,
    required this.commentaire,
    required this.creeLe,
  });

  final String id;
  final String kriId;
  final String dateMesure;
  final double valeur;
  final String commentaire;
  final String creeLe;

  factory RoKriValeur.fromJson(Map<String, dynamic> j) => RoKriValeur(
        id: j['id'] as String,
        kriId: j['kri_id'] as String,
        dateMesure: j['date_mesure'] as String,
        valeur: (j['valeur'] as num).toDouble(),
        commentaire: j['commentaire'] as String? ?? '',
        creeLe: j['cree_le'] as String? ?? '',
      );
}

class RoKriView {
  const RoKriView({
    required this.definition,
    required this.derniereValeur,
    required this.derniereDate,
    required this.statut,
    required this.historique,
  });

  final RoKriDefinition definition;
  final double? derniereValeur;
  final String? derniereDate;
  final String statut; // 'normal' | 'alerte' | 'critique' | 'non_renseigne'
  final List<RoKriValeur> historique;

  factory RoKriView.fromJson(Map<String, dynamic> j) => RoKriView(
        definition: RoKriDefinition.fromJson(j['definition'] as Map<String, dynamic>),
        derniereValeur: (j['derniere_valeur'] as num?)?.toDouble(),
        derniereDate: j['derniere_date'] as String?,
        statut: j['statut'] as String,
        historique: (j['historique'] as List<dynamic>)
            .map((e) => RoKriValeur.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class RoKriModuleData {
  const RoKriModuleData({required this.kriList, required this.kriHorsSeuil});

  final List<RoKriView> kriList;
  final int kriHorsSeuil;

  factory RoKriModuleData.fromJson(Map<String, dynamic> j) => RoKriModuleData(
        kriList: (j['kri_list'] as List<dynamic>)
            .map((e) => RoKriView.fromJson(e as Map<String, dynamic>))
            .toList(),
        kriHorsSeuil: j['kri_hors_seuil'] as int? ?? 0,
      );
}

// ─── Risques ──────────────────────────────────────────────────────────────────

class RoRisque {
  const RoRisque({
    required this.id,
    required this.nom,
    required this.categorie,
    required this.ligneMetier,
    required this.probabilite,
    required this.impact,
    required this.niveauBrut,
    required this.controleExistant,
    required this.efficaciteControle,
    required this.niveauResiduel,
    required this.niveauLabel,
    required this.planActionRef,
    required this.creeLe,
    required this.modifieLe,
  });

  final String id;
  final String nom;
  final String categorie;
  final String ligneMetier;
  final int probabilite;
  final int impact;
  final int niveauBrut;
  final String controleExistant;
  final int efficaciteControle;
  final double niveauResiduel;
  final String niveauLabel;
  final String planActionRef;
  final String creeLe;
  final String modifieLe;

  factory RoRisque.fromJson(Map<String, dynamic> j) => RoRisque(
        id: j['id'] as String,
        nom: j['nom'] as String,
        categorie: j['categorie'] as String,
        ligneMetier: j['ligne_metier'] as String,
        probabilite: j['probabilite'] as int,
        impact: j['impact'] as int,
        niveauBrut: j['niveau_brut'] as int,
        controleExistant: j['controle_existant'] as String? ?? '',
        efficaciteControle: j['efficacite_controle'] as int,
        niveauResiduel: (j['niveau_residuel'] as num).toDouble(),
        niveauLabel: j['niveau_label'] as String,
        planActionRef: j['plan_action_ref'] as String? ?? '',
        creeLe: j['cree_le'] as String? ?? '',
        modifieLe: j['modifie_le'] as String? ?? '',
      );
}

// ─── Contrôles ────────────────────────────────────────────────────────────────

class RoControle {
  const RoControle({
    required this.id,
    required this.reference,
    required this.perimetre,
    required this.typeControle,
    required this.frequence,
    required this.dateDernierTest,
    required this.prochaineDate,
    required this.resultat,
    required this.tauxConformite,
    required this.pointsConformes,
    required this.pointsControles,
    required this.nonConformites,
    required this.validateur,
    required this.creeLe,
    required this.modifieLe,
  });

  final String id;
  final String reference;
  final String perimetre;
  final String typeControle;
  final String frequence;
  final String dateDernierTest;
  final String prochaineDate;
  final String resultat;
  final double tauxConformite;
  final int pointsConformes;
  final int pointsControles;
  final String nonConformites;
  final String validateur;
  final String creeLe;
  final String modifieLe;

  factory RoControle.fromJson(Map<String, dynamic> j) => RoControle(
        id: j['id'] as String,
        reference: j['reference'] as String,
        perimetre: j['perimetre'] as String,
        typeControle: j['type_controle'] as String,
        frequence: j['frequence'] as String,
        dateDernierTest: j['date_dernier_test'] as String? ?? '',
        prochaineDate: j['prochaine_date'] as String? ?? '',
        resultat: j['resultat'] as String,
        tauxConformite: (j['taux_conformite'] as num?)?.toDouble() ?? 0,
        pointsConformes: j['points_conformes'] as int? ?? 0,
        pointsControles: j['points_controles'] as int? ?? 0,
        nonConformites: j['non_conformites'] as String? ?? '',
        validateur: j['validateur'] as String? ?? '',
        creeLe: j['cree_le'] as String? ?? '',
        modifieLe: j['modifie_le'] as String? ?? '',
      );
}

// ─── Plans d'actions ──────────────────────────────────────────────────────────

class RoPlan {
  const RoPlan({
    required this.id,
    required this.reference,
    required this.titre,
    required this.description,
    required this.typeAction,
    required this.source,
    required this.sourceRef,
    required this.responsable,
    required this.dateDebut,
    required this.dateEcheance,
    required this.joursRestants,
    required this.priorite,
    required this.statut,
    required this.avancement,
    required this.enRetard,
    required this.creeLe,
    required this.modifieLe,
  });

  final String id;
  final String reference;
  final String titre;
  final String description;
  final String typeAction;
  final String source;
  final String sourceRef;
  final String responsable;
  final String dateDebut;
  final String dateEcheance;
  final int joursRestants;
  final String priorite;
  final String statut;
  final int avancement;
  final bool enRetard;
  final String creeLe;
  final String modifieLe;

  factory RoPlan.fromJson(Map<String, dynamic> j) => RoPlan(
        id: j['id'] as String,
        reference: j['reference'] as String,
        titre: j['titre'] as String,
        description: j['description'] as String? ?? '',
        typeAction: j['type_action'] as String,
        source: j['source'] as String,
        sourceRef: j['source_ref'] as String? ?? '',
        responsable: j['responsable'] as String? ?? '',
        dateDebut: j['date_debut'] as String? ?? '',
        dateEcheance: j['date_echeance'] as String? ?? '',
        joursRestants: j['jours_restants'] as int? ?? 0,
        priorite: j['priorite'] as String,
        statut: j['statut'] as String,
        avancement: j['avancement'] as int? ?? 0,
        enRetard: j['en_retard'] as bool? ?? false,
        creeLe: j['cree_le'] as String? ?? '',
        modifieLe: j['modifie_le'] as String? ?? '',
      );
}

// ─── Historique ───────────────────────────────────────────────────────────────

class RoHistorique {
  const RoHistorique({
    required this.id,
    required this.dateEvenement,
    required this.utilisateur,
    required this.menu,
    required this.typeAction,
    required this.element,
    required this.ancienneValeur,
    required this.nouvelleValeur,
    required this.commentaire,
  });

  final int id;
  final String dateEvenement;
  final String utilisateur;
  final String menu;
  final String typeAction;
  final String element;
  final String ancienneValeur;
  final String nouvelleValeur;
  final String commentaire;

  factory RoHistorique.fromJson(Map<String, dynamic> j) => RoHistorique(
        id: j['id'] as int,
        dateEvenement: j['date_evenement'] as String,
        utilisateur: j['utilisateur'] as String? ?? 'Système',
        menu: j['menu'] as String,
        typeAction: j['type_action'] as String,
        element: j['element'] as String? ?? '',
        ancienneValeur: j['ancienne_valeur'] as String? ?? '',
        nouvelleValeur: j['nouvelle_valeur'] as String? ?? '',
        commentaire: j['commentaire'] as String? ?? '',
      );
}

// ─── Dashboard ────────────────────────────────────────────────────────────────

class RoDashboardWidget1 {
  const RoDashboardWidget1({
    required this.exigenceFondsPropres,
    required this.aprRisqueOp,
    required this.statutReglementaire,
  });

  final double exigenceFondsPropres;
  final double aprRisqueOp;
  final String statutReglementaire;

  factory RoDashboardWidget1.fromJson(Map<String, dynamic> j) =>
      RoDashboardWidget1(
        exigenceFondsPropres: (j['exigence_fonds_propres'] as num).toDouble(),
        aprRisqueOp: (j['apr_risque_op'] as num).toDouble(),
        statutReglementaire: j['statut_reglementaire'] as String,
      );
}

class RoDashboardWidget2 {
  const RoDashboardWidget2({
    required this.totalIncidentsMois,
    required this.pertesNettesMois,
    required this.incidentsNonClos,
    required this.evolutionPertesPct,
  });

  final int totalIncidentsMois;
  final double pertesNettesMois;
  final int incidentsNonClos;
  final double? evolutionPertesPct;

  factory RoDashboardWidget2.fromJson(Map<String, dynamic> j) =>
      RoDashboardWidget2(
        totalIncidentsMois: j['total_incidents_mois'] as int? ?? 0,
        pertesNettesMois: (j['pertes_nettes_mois'] as num?)?.toDouble() ?? 0,
        incidentsNonClos: j['incidents_non_clos'] as int? ?? 0,
        evolutionPertesPct: (j['evolution_pertes_pct'] as num?)?.toDouble(),
      );
}

class RoDashboardWidget3 {
  const RoDashboardWidget3({
    required this.actionsEnRetard,
    required this.controlesNonConformes,
    required this.kriHorsSeuil,
  });

  final int actionsEnRetard;
  final int controlesNonConformes;
  final int kriHorsSeuil;

  factory RoDashboardWidget3.fromJson(Map<String, dynamic> j) =>
      RoDashboardWidget3(
        actionsEnRetard: j['actions_en_retard'] as int? ?? 0,
        controlesNonConformes: j['controles_non_conformes'] as int? ?? 0,
        kriHorsSeuil: j['kri_hors_seuil'] as int? ?? 0,
      );
}

class RoEvolutionPoint {
  const RoEvolutionPoint({
    required this.mois,
    required this.perteBrute,
    required this.perteNette,
  });

  final String mois;
  final double perteBrute;
  final double perteNette;

  factory RoEvolutionPoint.fromJson(Map<String, dynamic> j) => RoEvolutionPoint(
        mois: j['mois'] as String,
        perteBrute: (j['perte_brute'] as num?)?.toDouble() ?? 0,
        perteNette: (j['perte_nette'] as num?)?.toDouble() ?? 0,
      );
}

class RoRepartitionItem {
  const RoRepartitionItem({required this.label, required this.valeur});

  final String label;
  final int valeur;

  factory RoRepartitionItem.fromJson(Map<String, dynamic> j) =>
      RoRepartitionItem(
        label: j['label'] as String,
        valeur: j['valeur'] as int? ?? 0,
      );
}

class RoDashboardData {
  const RoDashboardData({
    required this.widget1,
    required this.widget2,
    required this.widget3,
    required this.evolutionPertes,
    required this.repartitionLigneMetier,
    required this.repartitionType,
  });

  final RoDashboardWidget1 widget1;
  final RoDashboardWidget2 widget2;
  final RoDashboardWidget3 widget3;
  final List<RoEvolutionPoint> evolutionPertes;
  final List<RoRepartitionItem> repartitionLigneMetier;
  final List<RoRepartitionItem> repartitionType;

  factory RoDashboardData.fromJson(Map<String, dynamic> j) => RoDashboardData(
        widget1: RoDashboardWidget1.fromJson(j['widget1'] as Map<String, dynamic>),
        widget2: RoDashboardWidget2.fromJson(j['widget2'] as Map<String, dynamic>),
        widget3: RoDashboardWidget3.fromJson(j['widget3'] as Map<String, dynamic>),
        evolutionPertes: (j['evolution_pertes'] as List<dynamic>)
            .map((e) => RoEvolutionPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        repartitionLigneMetier: (j['repartition_ligne_metier'] as List<dynamic>)
            .map((e) => RoRepartitionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        repartitionType: (j['repartition_type'] as List<dynamic>)
            .map((e) => RoRepartitionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
