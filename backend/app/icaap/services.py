"""Services métier du module ICAAP.

Lot L2 : gestion des exercices, de la cartographie des risques et lecture du
référentiel de paramètres prudentiels. Aucun calcul de capital économique ni
de stress ici — ils arrivent aux lots L3 / L4.

Comme le module ``fodep``, ce module ne recalcule aucun RWA. Les erreurs
métier sont levées ici (``IcaapIntrouvable`` / ``IcaapExerciceVerrouille``)
et traduites en codes HTTP par ``routes.py``.
"""

from __future__ import annotations

import json
import uuid
from datetime import datetime

from database.connection import database_manager

from app.icaap import calculations as calc
from app.icaap.models import (
    CapitalDispoUpdate,
    CapitalDispoView,
    CapitalEcoLigne,
    CapitalEcoRun,
    CorrelationEntry,
    CouvertureView,
    ExerciceCreate,
    ExerciceUpdate,
    ExerciceView,
    ParametreView,
    PlanActionEntry,
    PlanCapitalHypotheses,
    PlanCapitalLigne,
    PlanCapitalView,
    RisqueEntry,
    RisqueView,
    ScenarioEntry,
    ScenarioResultatLigne,
    ScenarioView,
)


class IcaapIntrouvable(LookupError):
    """Exercice ICAAP inexistant."""


class IcaapExerciceVerrouille(RuntimeError):
    """Tentative de modification d'un exercice qui n'est plus au statut
    « brouillon » : un exercice validé ou archivé est immuable."""


class IcaapScenarioIntrouvable(IcaapIntrouvable):
    """Scénario de stress inexistant."""


class IcaapDonneesManquantes(ValueError):
    """Un calcul demande une donnée qui n'a pas encore été renseignée
    (typiquement le capital interne disponible de l'exercice)."""


def _utcnow_iso() -> str:
    return datetime.utcnow().replace(microsecond=0).isoformat()


# --------------------------------------------------------------------------
# Exercices
# --------------------------------------------------------------------------
def _row_to_exercice(row) -> ExerciceView:
    data = dict(row)
    return ExerciceView(
        id=data["id"],
        annee=int(data["annee"]),
        date_arrete=data["date_arrete"],
        statut=data["statut"],
        auteur_id=data.get("auteur_id"),
        date_validation=data.get("date_validation"),
        opinion_executif=data.get("opinion_executif") or "",
        avis_deliberant=data.get("avis_deliberant") or "",
        commentaire=data.get("commentaire") or "",
        cree_le=data["cree_le"],
        modifie_le=data["modifie_le"],
    )


def lister_exercices(
    annee: int | None = None, statut: str | None = None
) -> list[ExerciceView]:
    clauses: list[str] = []
    params: list[object] = []
    if annee is not None:
        clauses.append("annee = ?")
        params.append(annee)
    if statut:
        clauses.append("statut = ?")
        params.append(statut)
    where = f" WHERE {' AND '.join(clauses)}" if clauses else ""
    with database_manager.read_connection() as conn:
        rows = conn.execute(
            f"SELECT * FROM icaap_exercice{where} "
            "ORDER BY annee DESC, cree_le DESC",
            params,
        ).fetchall()
    return [_row_to_exercice(r) for r in rows]


def obtenir_exercice(exercice_id: str) -> ExerciceView:
    with database_manager.read_connection() as conn:
        row = conn.execute(
            "SELECT * FROM icaap_exercice WHERE id = ?", (exercice_id,)
        ).fetchone()
    if row is None:
        raise IcaapIntrouvable(exercice_id)
    return _row_to_exercice(row)


def creer_exercice(
    payload: ExerciceCreate, *, auteur_id: str | None = None
) -> ExerciceView:
    identifiant = str(uuid.uuid4())
    horodatage = _utcnow_iso()
    with database_manager.transaction() as conn:
        conn.execute(
            """
            INSERT INTO icaap_exercice
                (id, annee, date_arrete, statut, auteur_id, commentaire,
                 cree_le, modifie_le)
            VALUES (?, ?, ?, 'brouillon', ?, ?, ?, ?)
            """,
            (
                identifiant,
                payload.annee,
                payload.date_arrete,
                auteur_id,
                payload.commentaire,
                horodatage,
                horodatage,
            ),
        )
        # Le gabarit de corrélations par défaut devient la matrice initiale,
        # éditable, de l'exercice.
        gabarit = conn.execute(
            "SELECT risque_a, risque_b, coefficient FROM icaap_correlation_defaut"
        ).fetchall()
        for ligne in gabarit:
            conn.execute(
                """
                INSERT INTO icaap_correlation
                    (id, exercice_id, risque_a, risque_b, coefficient, cree_le)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    str(uuid.uuid4()),
                    identifiant,
                    ligne["risque_a"],
                    ligne["risque_b"],
                    float(ligne["coefficient"]),
                    horodatage,
                ),
            )
    return obtenir_exercice(identifiant)


def mettre_a_jour_exercice(
    exercice_id: str, payload: ExerciceUpdate
) -> ExerciceView:
    courant = obtenir_exercice(exercice_id)
    if courant.statut != "brouillon":
        raise IcaapExerciceVerrouille(exercice_id)

    champs = {
        "date_arrete": payload.date_arrete,
        "opinion_executif": payload.opinion_executif,
        "avis_deliberant": payload.avis_deliberant,
        "commentaire": payload.commentaire,
    }
    a_ecrire = {cle: val for cle, val in champs.items() if val is not None}
    if not a_ecrire:
        return courant

    assignations = ", ".join(f"{cle} = ?" for cle in a_ecrire)
    valeurs = list(a_ecrire.values())
    valeurs.append(_utcnow_iso())
    valeurs.append(exercice_id)
    with database_manager.transaction() as conn:
        conn.execute(
            f"UPDATE icaap_exercice SET {assignations}, modifie_le = ? WHERE id = ?",
            valeurs,
        )
    return obtenir_exercice(exercice_id)


# --------------------------------------------------------------------------
# Cartographie des risques
# --------------------------------------------------------------------------
def _row_to_risque(row) -> RisqueView:
    data = dict(row)
    return RisqueView(
        id=data["id"],
        exercice_id=data["exercice_id"],
        categorie=data["categorie"],
        libelle=data.get("libelle") or "",
        pilier=int(data["pilier"]),
        methode=data["methode"],
        probabilite=int(data["probabilite"]),
        impact=int(data["impact"]),
        materialite=int(data["materialite"]),
        maitrise=data.get("maitrise") or "",
        commentaire=data.get("commentaire") or "",
        cree_le=data["cree_le"],
        modifie_le=data["modifie_le"],
    )


def _seuil_materialite_quanti() -> float:
    """Seuil probabilité x impact au-delà duquel un risque est traité en
    quantitatif. Lu dans le référentiel, valeur de repli 12."""

    with database_manager.read_connection() as conn:
        row = conn.execute(
            "SELECT valeur FROM icaap_parametre "
            "WHERE cle = 'seuil_materialite_quanti' "
            "ORDER BY date_effet DESC LIMIT 1"
        ).fetchone()
    return float(row["valeur"]) if row else 12.0


def lister_cartographie(exercice_id: str) -> list[RisqueView]:
    obtenir_exercice(exercice_id)  # 404 si l'exercice n'existe pas
    with database_manager.read_connection() as conn:
        rows = conn.execute(
            "SELECT * FROM icaap_risque WHERE exercice_id = ? "
            "ORDER BY materialite DESC, categorie",
            (exercice_id,),
        ).fetchall()
    return [_row_to_risque(r) for r in rows]


def enregistrer_cartographie(
    exercice_id: str, lignes: list[RisqueEntry]
) -> list[RisqueView]:
    """Remplace intégralement la cartographie de l'exercice.

    La matérialité est recalculée serveur (probabilité x impact) et la méthode
    est forcée à « quanti » au-delà du seuil, sauf choix explicite « quali »
    déjà porté par la ligne pour un risque non quantifiable (stratégie,
    réputation).
    """

    exercice = obtenir_exercice(exercice_id)
    if exercice.statut != "brouillon":
        raise IcaapExerciceVerrouille(exercice_id)

    seuil = _seuil_materialite_quanti()
    horodatage = _utcnow_iso()
    with database_manager.transaction() as conn:
        conn.execute(
            "DELETE FROM icaap_risque WHERE exercice_id = ?", (exercice_id,)
        )
        for ligne in lignes:
            materialite = ligne.probabilite * ligne.impact
            # Méthode explicite respectée ; sinon dérivée du seuil.
            methode = ligne.methode or (
                "quanti" if materialite >= seuil else "quali"
            )
            conn.execute(
                """
                INSERT INTO icaap_risque
                    (id, exercice_id, categorie, libelle, pilier, methode,
                     probabilite, impact, materialite, maitrise, commentaire,
                     cree_le, modifie_le)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    ligne.id or str(uuid.uuid4()),
                    exercice_id,
                    ligne.categorie,
                    ligne.libelle,
                    ligne.pilier,
                    methode,
                    ligne.probabilite,
                    ligne.impact,
                    materialite,
                    ligne.maitrise,
                    ligne.commentaire,
                    horodatage,
                    horodatage,
                ),
            )
    return lister_cartographie(exercice_id)


# --------------------------------------------------------------------------
# Référentiel de paramètres prudentiels
# --------------------------------------------------------------------------
def lister_parametres() -> list[ParametreView]:
    """Valeur en vigueur pour chaque clé : la ligne à la date d'effet la plus
    récente."""

    with database_manager.read_connection() as conn:
        rows = conn.execute(
            """
            SELECT p.cle, p.libelle, p.valeur, p.unite, p.date_effet, p.source
            FROM icaap_parametre p
            JOIN (
                SELECT cle, MAX(date_effet) AS date_effet
                FROM icaap_parametre GROUP BY cle
            ) d ON d.cle = p.cle AND d.date_effet = p.date_effet
            ORDER BY p.cle
            """
        ).fetchall()
    return [
        ParametreView(
            cle=r["cle"],
            libelle=r["libelle"],
            valeur=float(r["valeur"]),
            unite=r["unite"],
            date_effet=r["date_effet"],
            source=r["source"],
        )
        for r in rows
    ]


def _parametre(cle: str, defaut: float) -> float:
    with database_manager.read_connection() as conn:
        row = conn.execute(
            "SELECT valeur FROM icaap_parametre WHERE cle = ? "
            "ORDER BY date_effet DESC LIMIT 1",
            (cle,),
        ).fetchone()
    return float(row["valeur"]) if row else defaut


# --------------------------------------------------------------------------
# Capital interne disponible (photo figée dans l'exercice)
# --------------------------------------------------------------------------
def _row_to_capital_dispo(row) -> CapitalDispoView:
    d = dict(row)
    return CapitalDispoView(
        exercice_id=d["exercice_id"],
        cet1=float(d["cet1"]),
        at1=float(d["at1"]),
        t2=float(d["t2"]),
        deductions=float(d["deductions"]),
        rwa_pilier1_total=float(d["rwa_pilier1_total"]),
        source=d.get("source") or "",
        capital_interne_total=float(d["capital_interne_total"]),
        cree_le=d["cree_le"],
        modifie_le=d["modifie_le"],
    )


def obtenir_capital_dispo(exercice_id: str) -> CapitalDispoView | None:
    obtenir_exercice(exercice_id)
    with database_manager.read_connection() as conn:
        row = conn.execute(
            "SELECT * FROM icaap_capital_dispo WHERE exercice_id = ?",
            (exercice_id,),
        ).fetchone()
    return _row_to_capital_dispo(row) if row else None


def enregistrer_capital_dispo(
    exercice_id: str, payload: CapitalDispoUpdate
) -> CapitalDispoView:
    exercice = obtenir_exercice(exercice_id)
    if exercice.statut != "brouillon":
        raise IcaapExerciceVerrouille(exercice_id)

    total = (
        payload.cet1 + payload.at1 + payload.t2 - payload.deductions
    )
    horodatage = _utcnow_iso()
    with database_manager.transaction() as conn:
        existe = conn.execute(
            "SELECT id FROM icaap_capital_dispo WHERE exercice_id = ?",
            (exercice_id,),
        ).fetchone()
        if existe:
            conn.execute(
                """
                UPDATE icaap_capital_dispo
                SET cet1 = ?, at1 = ?, t2 = ?, deductions = ?,
                    capital_interne_total = ?, rwa_pilier1_total = ?,
                    source = ?, modifie_le = ?
                WHERE exercice_id = ?
                """,
                (
                    payload.cet1, payload.at1, payload.t2, payload.deductions,
                    total, payload.rwa_pilier1_total, payload.source,
                    horodatage, exercice_id,
                ),
            )
        else:
            conn.execute(
                """
                INSERT INTO icaap_capital_dispo
                    (id, exercice_id, cet1, at1, t2, deductions,
                     capital_interne_total, rwa_pilier1_total, source,
                     cree_le, modifie_le)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    str(uuid.uuid4()), exercice_id, payload.cet1, payload.at1,
                    payload.t2, payload.deductions, total,
                    payload.rwa_pilier1_total, payload.source,
                    horodatage, horodatage,
                ),
            )
    return obtenir_capital_dispo(exercice_id)  # type: ignore[return-value]


# --------------------------------------------------------------------------
# Matrice de corrélation
# --------------------------------------------------------------------------
def _paire_ordonnee(a: str, b: str) -> tuple[str, str]:
    return (a, b) if a <= b else (b, a)


def lister_correlations(exercice_id: str) -> list[CorrelationEntry]:
    obtenir_exercice(exercice_id)
    with database_manager.read_connection() as conn:
        rows = conn.execute(
            "SELECT risque_a, risque_b, coefficient FROM icaap_correlation "
            "WHERE exercice_id = ? ORDER BY risque_a, risque_b",
            (exercice_id,),
        ).fetchall()
    return [
        CorrelationEntry(
            risque_a=r["risque_a"],
            risque_b=r["risque_b"],
            coefficient=float(r["coefficient"]),
        )
        for r in rows
    ]


def enregistrer_correlations(
    exercice_id: str, lignes: list[CorrelationEntry]
) -> list[CorrelationEntry]:
    exercice = obtenir_exercice(exercice_id)
    if exercice.statut != "brouillon":
        raise IcaapExerciceVerrouille(exercice_id)

    horodatage = _utcnow_iso()
    vues: dict[tuple[str, str], float] = {}
    for ligne in lignes:
        a, b = _paire_ordonnee(ligne.risque_a.strip(), ligne.risque_b.strip())
        if a == b:
            continue  # diagonale implicite = 1
        vues[(a, b)] = float(ligne.coefficient)

    with database_manager.transaction() as conn:
        conn.execute(
            "DELETE FROM icaap_correlation WHERE exercice_id = ?", (exercice_id,)
        )
        for (a, b), coef in vues.items():
            conn.execute(
                """
                INSERT INTO icaap_correlation
                    (id, exercice_id, risque_a, risque_b, coefficient, cree_le)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (str(uuid.uuid4()), exercice_id, a, b, coef, horodatage),
            )
    return lister_correlations(exercice_id)


# --------------------------------------------------------------------------
# Moteur de capital économique
# --------------------------------------------------------------------------
def _besoin_pour_risque(
    risque: RisqueView, run: CapitalEcoRun, ratio_cible: float, addon_max: float
) -> tuple[str, float, dict[str, float]]:
    """Retourne (clé de corrélation, montant du besoin, hypothèses tracées)."""

    cle = calc.cle_correlation(risque.categorie)

    if risque.methode == "quali":
        montant = float(run.buffers_quali.get(cle, run.buffers_quali.get(risque.categorie, 0.0)))
        return cle, max(0.0, montant), {"buffer_forfaitaire": montant}

    if cle == "credit":
        montant = calc.besoin_pondere(run.rwa_credit, ratio_cible)
        return cle, montant, {"rwa_credit": run.rwa_credit, "ratio_cible_pct": ratio_cible}

    if cle == "marche":
        if run.exigence_marche is not None:
            return cle, max(0.0, run.exigence_marche), {"exigence_marche": run.exigence_marche}
        montant = calc.besoin_pondere(run.rwa_marche, ratio_cible)
        return cle, montant, {"rwa_marche": run.rwa_marche, "ratio_cible_pct": ratio_cible}

    if cle == "operationnel":
        if run.exigence_operationnel is not None:
            return cle, max(0.0, run.exigence_operationnel), {
                "exigence_operationnel": run.exigence_operationnel
            }
        montant = calc.besoin_pondere(run.rwa_operationnel, ratio_cible)
        return cle, montant, {
            "rwa_operationnel": run.rwa_operationnel, "ratio_cible_pct": ratio_cible
        }

    if cle == "taux":
        return cle, max(0.0, run.irrbb_impact_eve), {"irrbb_impact_eve": run.irrbb_impact_eve}

    if cle == "concentration":
        montant = calc.besoin_concentration(
            run.rwa_credit, ratio_cible, run.concentration_hhi, addon_max
        )
        return cle, montant, {
            "concentration_hhi": run.concentration_hhi,
            "addon_max_ratio": addon_max,
            "rwa_credit": run.rwa_credit,
        }

    if cle == "residuel":
        return cle, max(0.0, run.crm_residuel), {"crm_residuel": run.crm_residuel}

    # Famille non quantifiable par défaut : buffer forfaitaire éventuel.
    montant = float(run.buffers_quali.get(cle, 0.0))
    return cle, max(0.0, montant), {"buffer_forfaitaire": montant}


def calculer_capital_economique(
    exercice_id: str, run: CapitalEcoRun
) -> list[CapitalEcoLigne]:
    exercice = obtenir_exercice(exercice_id)
    if exercice.statut != "brouillon":
        raise IcaapExerciceVerrouille(exercice_id)

    risques = lister_cartographie(exercice_id)
    if not risques:
        raise IcaapDonneesManquantes(
            "La cartographie des risques est vide : renseignez-la avant de "
            "calculer le besoin en capital économique."
        )

    ratio_cible = (
        run.ratio_cible_pct
        if run.ratio_cible_pct is not None
        else _parametre("ratio_solvabilite_cible", 11.5)
    )
    addon_max = _parametre("addon_concentration_max", 0.15)
    horodatage = _utcnow_iso()

    lignes: list[CapitalEcoLigne] = []
    with database_manager.transaction() as conn:
        conn.execute(
            "DELETE FROM icaap_capital_eco WHERE exercice_id = ?", (exercice_id,)
        )
        for risque in risques:
            cle, montant, params = _besoin_pour_risque(
                risque, run, ratio_cible, addon_max
            )
            ligne_id = str(uuid.uuid4())
            conn.execute(
                """
                INSERT INTO icaap_capital_eco
                    (id, exercice_id, risque_id, categorie, methode,
                     parametres_json, montant_besoin, horizon_mois,
                     cree_le, modifie_le)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    ligne_id, exercice_id, risque.id, cle, risque.methode,
                    json.dumps(params), round(montant, 2), 12,
                    horodatage, horodatage,
                ),
            )
            lignes.append(
                CapitalEcoLigne(
                    id=ligne_id,
                    risque_id=risque.id,
                    categorie=risque.categorie,
                    cle_correlation=cle,
                    libelle=risque.libelle,
                    methode=risque.methode,
                    parametres=params,
                    montant_besoin=round(montant, 2),
                    horizon_mois=12,
                )
            )
    return lignes


def _lignes_capital_eco(exercice_id: str) -> list[CapitalEcoLigne]:
    with database_manager.read_connection() as conn:
        rows = conn.execute(
            """
            SELECT e.*, r.libelle AS risque_libelle, r.categorie AS risque_categorie
            FROM icaap_capital_eco e
            LEFT JOIN icaap_risque r ON r.id = e.risque_id
            WHERE e.exercice_id = ?
            ORDER BY e.montant_besoin DESC
            """,
            (exercice_id,),
        ).fetchall()
    lignes: list[CapitalEcoLigne] = []
    for r in rows:
        d = dict(r)
        try:
            params = json.loads(d.get("parametres_json") or "{}")
        except json.JSONDecodeError:
            params = {}
        lignes.append(
            CapitalEcoLigne(
                id=d["id"],
                risque_id=d.get("risque_id"),
                categorie=d.get("risque_categorie") or d["categorie"],
                cle_correlation=d["categorie"],
                libelle=d.get("risque_libelle") or "",
                methode=d.get("methode") or "",
                parametres={k: float(v) for k, v in params.items() if _num(v)},
                montant_besoin=float(d["montant_besoin"]),
                horizon_mois=int(d["horizon_mois"]),
            )
        )
    return lignes


def _num(valeur) -> bool:
    return isinstance(valeur, (int, float)) and not isinstance(valeur, bool)


def obtenir_couverture(exercice_id: str) -> CouvertureView:
    obtenir_exercice(exercice_id)
    lignes = _lignes_capital_eco(exercice_id)
    if not lignes:
        raise IcaapDonneesManquantes(
            "Aucun besoin en capital économique calculé : lancez d'abord le "
            "calcul (POST .../capital-economique)."
        )
    dispo = obtenir_capital_dispo(exercice_id)
    if dispo is None:
        raise IcaapDonneesManquantes(
            "Le capital interne disponible n'est pas renseigné pour cet exercice."
        )

    besoins: dict[str, float] = {}
    for ligne in lignes:
        besoins[ligne.cle_correlation] = besoins.get(ligne.cle_correlation, 0.0) + ligne.montant_besoin

    correlations = [
        (c.risque_a, c.risque_b, c.coefficient)
        for c in lister_correlations(exercice_id)
    ]
    somme = calc.somme_simple(besoins)
    diversifie = calc.agreger_par_correlation(besoins, correlations)
    # Filet de sécurité numérique : la diversification ne crée jamais de besoin.
    diversifie = min(diversifie, somme)

    capital = dispo.capital_interne_total
    ratio = (capital / diversifie * 100.0) if diversifie > 0 else float("inf")

    return CouvertureView(
        besoin_somme_simple=round(somme, 2),
        besoin_apres_diversification=round(diversifie, 2),
        benefice_diversification=round(somme - diversifie, 2),
        capital_interne_disponible=round(capital, 2),
        ratio_couverture=round(ratio, 2) if ratio != float("inf") else ratio,
        seuil_alerte=100.0,
        en_alerte=ratio < 100.0,
        detail_par_risque=lignes,
    )


# --------------------------------------------------------------------------
# Stress testing
# --------------------------------------------------------------------------
def _base_projection(exercice_id: str) -> tuple[float, float]:
    """Point de départ commun aux projections : (fonds propres, RWA) figés
    dans la photo capital interne de l'exercice."""

    dispo = obtenir_capital_dispo(exercice_id)
    if dispo is None:
        raise IcaapDonneesManquantes(
            "Le capital interne disponible n'est pas renseigné pour cet "
            "exercice : impossible de projeter."
        )
    if dispo.rwa_pilier1_total <= 0:
        raise IcaapDonneesManquantes(
            "Le RWA Pilier 1 total de la photo capital interne est nul : "
            "renseignez-le avant de lancer une projection."
        )
    return dispo.capital_interne_total, dispo.rwa_pilier1_total


def _row_to_scenario(row, resultats: list[ScenarioResultatLigne]) -> ScenarioView:
    d = dict(row)
    try:
        hypotheses = json.loads(d.get("hypotheses_json") or "{}")
    except json.JSONDecodeError:
        hypotheses = {}
    return ScenarioView(
        id=d["id"],
        exercice_id=d["exercice_id"],
        libelle=d.get("libelle") or "",
        type_scenario=d["type_scenario"],
        hypotheses={k: float(v) for k, v in hypotheses.items() if _num(v)},
        horizon_annees=int(d["horizon_annees"]),
        dernier_run_le=d.get("dernier_run_le"),
        resultats=resultats,
    )


def _resultats_scenario(conn, scenario_id: str) -> list[ScenarioResultatLigne]:
    rows = conn.execute(
        "SELECT annee_proj, rwa_projete, resultat_projete, "
        "fonds_propres_projetes, ratio_projete "
        "FROM icaap_scenario_resultat WHERE scenario_id = ? ORDER BY annee_proj",
        (scenario_id,),
    ).fetchall()
    return [
        ScenarioResultatLigne(
            annee_proj=int(r["annee_proj"]),
            rwa_projete=float(r["rwa_projete"]),
            resultat_projete=float(r["resultat_projete"]),
            fonds_propres_projetes=float(r["fonds_propres_projetes"]),
            ratio_projete=float(r["ratio_projete"]),
        )
        for r in rows
    ]


def lister_scenarios(exercice_id: str) -> list[ScenarioView]:
    obtenir_exercice(exercice_id)
    with database_manager.read_connection() as conn:
        rows = conn.execute(
            "SELECT * FROM icaap_scenario WHERE exercice_id = ? "
            "ORDER BY type_scenario, libelle",
            (exercice_id,),
        ).fetchall()
        return [
            _row_to_scenario(r, _resultats_scenario(conn, r["id"])) for r in rows
        ]


def obtenir_scenario(scenario_id: str) -> ScenarioView:
    with database_manager.read_connection() as conn:
        row = conn.execute(
            "SELECT * FROM icaap_scenario WHERE id = ?", (scenario_id,)
        ).fetchone()
        if row is None:
            raise IcaapScenarioIntrouvable(scenario_id)
        return _row_to_scenario(row, _resultats_scenario(conn, scenario_id))


def creer_scenario(exercice_id: str, payload: ScenarioEntry) -> ScenarioView:
    exercice = obtenir_exercice(exercice_id)
    if exercice.statut != "brouillon":
        raise IcaapExerciceVerrouille(exercice_id)

    identifiant = payload.id or str(uuid.uuid4())
    horodatage = _utcnow_iso()
    with database_manager.transaction() as conn:
        conn.execute(
            """
            INSERT INTO icaap_scenario
                (id, exercice_id, libelle, type_scenario, hypotheses_json,
                 horizon_annees, cree_le, modifie_le)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                identifiant, exercice_id, payload.libelle, payload.type_scenario,
                json.dumps(payload.hypotheses), payload.horizon_annees,
                horodatage, horodatage,
            ),
        )
    return obtenir_scenario(identifiant)


def supprimer_scenario(scenario_id: str) -> None:
    scenario = obtenir_scenario(scenario_id)
    exercice = obtenir_exercice(scenario.exercice_id)
    if exercice.statut != "brouillon":
        raise IcaapExerciceVerrouille(scenario.exercice_id)
    with database_manager.transaction() as conn:
        conn.execute("DELETE FROM icaap_scenario WHERE id = ?", (scenario_id,))


def executer_scenario(scenario_id: str) -> ScenarioView:
    scenario = obtenir_scenario(scenario_id)
    exercice = obtenir_exercice(scenario.exercice_id)
    if exercice.statut == "archive":
        raise IcaapExerciceVerrouille(scenario.exercice_id)

    fonds_propres_0, rwa_0 = _base_projection(scenario.exercice_id)
    lignes = calc.projeter_scenario(
        fonds_propres_0=fonds_propres_0,
        rwa_0=rwa_0,
        hypotheses=scenario.hypotheses,
        horizon_annees=scenario.horizon_annees,
    )
    horodatage = _utcnow_iso()
    with database_manager.transaction() as conn:
        conn.execute(
            "DELETE FROM icaap_scenario_resultat WHERE scenario_id = ?",
            (scenario_id,),
        )
        for ligne in lignes:
            conn.execute(
                """
                INSERT INTO icaap_scenario_resultat
                    (id, scenario_id, annee_proj, rwa_projete, resultat_projete,
                     fonds_propres_projetes, ratio_projete, cree_le)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    str(uuid.uuid4()), scenario_id, ligne["annee_proj"],
                    ligne["rwa_projete"], ligne["resultat_projete"],
                    ligne["fonds_propres_projetes"], ligne["ratio_projete"],
                    horodatage,
                ),
            )
        conn.execute(
            "UPDATE icaap_scenario SET dernier_run_le = ?, modifie_le = ? WHERE id = ?",
            (horodatage, horodatage, scenario_id),
        )
    return obtenir_scenario(scenario_id)


# --------------------------------------------------------------------------
# Planification du capital
# --------------------------------------------------------------------------
def obtenir_plan_capital(exercice_id: str) -> PlanCapitalView | None:
    obtenir_exercice(exercice_id)
    with database_manager.read_connection() as conn:
        rows = conn.execute(
            "SELECT * FROM icaap_plan_capital WHERE exercice_id = ? "
            "ORDER BY annee_proj",
            (exercice_id,),
        ).fetchall()
    if not rows:
        return None
    try:
        hypotheses = json.loads(dict(rows[0]).get("hypotheses_json") or "{}")
    except json.JSONDecodeError:
        hypotheses = {}
    trajectoire = [
        PlanCapitalLigne(
            annee_proj=int(r["annee_proj"]),
            rwa_projete=float(r["rwa_projete"]),
            resultat_mis_en_reserve=float(r["resultat_mis_en_reserve"]),
            distributions=float(r["distributions"]),
            fonds_propres_projetes=float(r["fonds_propres_projetes"]),
            ratio_projete=float(r["ratio_projete"]),
            coussin_entame=bool(r["coussin_entame"]),
        )
        for r in rows
    ]
    entame = next(
        (l.annee_proj for l in trajectoire if l.coussin_entame and l.annee_proj > 0),
        None,
    )
    return PlanCapitalView(
        exercice_id=exercice_id,
        hypotheses=PlanCapitalHypotheses(**hypotheses),
        trajectoire=trajectoire,
        annee_entame_coussin=entame,
    )


def calculer_plan_capital(
    exercice_id: str, hypotheses: PlanCapitalHypotheses
) -> PlanCapitalView:
    exercice = obtenir_exercice(exercice_id)
    if exercice.statut != "brouillon":
        raise IcaapExerciceVerrouille(exercice_id)

    fonds_propres_0, rwa_0 = _base_projection(exercice_id)
    horizon = int(_parametre("horizon_plan_capital_annees", 3.0))
    seuil_coussin = _parametre("ratio_solvabilite_min", 9.0) + _parametre(
        "coussin_conservation", 2.5
    )

    lignes, annee_entame = calc.projeter_plan_capital(
        fonds_propres_0=fonds_propres_0,
        rwa_0=rwa_0,
        croissance_encours_pct=hypotheses.croissance_encours_pct,
        marge_nette_pct=hypotheses.marge_nette_pct,
        cout_risque_pct=hypotheses.cout_risque_pct,
        taux_distribution_pct=hypotheses.taux_distribution_pct,
        horizon_annees=horizon,
        seuil_coussin_pct=seuil_coussin,
    )
    horodatage = _utcnow_iso()
    payload_json = hypotheses.model_dump_json()
    with database_manager.transaction() as conn:
        conn.execute(
            "DELETE FROM icaap_plan_capital WHERE exercice_id = ?", (exercice_id,)
        )
        for ligne in lignes:
            conn.execute(
                """
                INSERT INTO icaap_plan_capital
                    (id, exercice_id, annee_proj, hypotheses_json, rwa_projete,
                     resultat_mis_en_reserve, distributions,
                     fonds_propres_projetes, ratio_projete, coussin_entame,
                     cree_le)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    str(uuid.uuid4()), exercice_id, ligne["annee_proj"],
                    payload_json, ligne["rwa_projete"],
                    ligne["resultat_mis_en_reserve"], ligne["distributions"],
                    ligne["fonds_propres_projetes"], ligne["ratio_projete"],
                    1 if ligne["coussin_entame"] else 0, horodatage,
                ),
            )
    return PlanCapitalView(
        exercice_id=exercice_id,
        hypotheses=hypotheses,
        trajectoire=[PlanCapitalLigne(**l) for l in lignes],
        annee_entame_coussin=annee_entame,
    )


# --------------------------------------------------------------------------
# Plan d'action
# --------------------------------------------------------------------------
def lister_plan_action(exercice_id: str) -> list[PlanActionEntry]:
    obtenir_exercice(exercice_id)
    with database_manager.read_connection() as conn:
        rows = conn.execute(
            "SELECT id, constat, action, responsable, echeance, statut "
            "FROM icaap_plan_action WHERE exercice_id = ? "
            "ORDER BY (statut = 'clos'), echeance",
            (exercice_id,),
        ).fetchall()
    return [
        PlanActionEntry(
            id=r["id"],
            constat=r["constat"] or "",
            action=r["action"] or "",
            responsable=r["responsable"] or "",
            echeance=r["echeance"],
            statut=r["statut"],
        )
        for r in rows
    ]


def enregistrer_plan_action(
    exercice_id: str, lignes: list[PlanActionEntry]
) -> list[PlanActionEntry]:
    exercice = obtenir_exercice(exercice_id)
    if exercice.statut != "brouillon":
        raise IcaapExerciceVerrouille(exercice_id)

    horodatage = _utcnow_iso()
    with database_manager.transaction() as conn:
        conn.execute(
            "DELETE FROM icaap_plan_action WHERE exercice_id = ?", (exercice_id,)
        )
        for ligne in lignes:
            conn.execute(
                """
                INSERT INTO icaap_plan_action
                    (id, exercice_id, constat, action, responsable, echeance,
                     statut, cree_le, modifie_le)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    ligne.id or str(uuid.uuid4()), exercice_id, ligne.constat,
                    ligne.action, ligne.responsable, ligne.echeance,
                    ligne.statut, horodatage, horodatage,
                ),
            )
    return lister_plan_action(exercice_id)
