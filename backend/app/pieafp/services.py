"""Services du module PIEAFP (Pilier 2 / ICAAP)."""

from __future__ import annotations

from datetime import datetime, date

from database.connection import database_manager, utcnow_iso

from .models import (
    AutreRisque,
    AutreRisqueCreate,
    AutreRisqueUpdate,
    ChecklistItem,
    ChecklistUpdate,
    ConcentrationAxis,
    ConcentrationBar,
    ConcentrationResult,
    GouvernanceResult,
    IrrbbResult,
    IrrbbTrancheResult,
    IrrbbTranche,
    IrrbbUpdate,
    ModuleStatus,
    PieafpDashboard,
    PieafpRapport,
    PlanificationAnnee,
    PlanificationAnneeUpdate,
    PlanificationResult,
    ScenarioStress,
    ScenarioStressCreate,
    ScenarioStressUpdate,
    StressImpact,
)


# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

def _risque_niveau(score: int) -> str:
    if score <= 4:
        return "Faible"
    if score <= 9:
        return "Modéré"
    if score <= 16:
        return "Élevé"
    return "Critique"


def _hhi_niveau(hhi: float) -> str:
    if hhi < 1000:
        return "Faible"
    if hhi < 1800:
        return "Modéré"
    return "Élevé"


def _get_current_fp_total(conn) -> float:
    row = conn.execute(
        """SELECT capital_ordinaire + reserves + resultats_report + resultat_eligible
                - deductions_prud_cet1 + instruments_at1 + primes_emission_at1
                - deductions_prud_at1 + dettes_subordonnees_t2 + provisions_generales_t2
                - deductions_prud_t2 AS total_fp
           FROM fonds_propres
           ORDER BY date_analyse DESC
           LIMIT 1"""
    ).fetchone()
    return float(row["total_fp"]) if row and row["total_fp"] is not None else 0.0


def _get_current_rwa_totals(conn) -> dict[str, float]:
    """Retourne rwa_credit, rwa_marche (approx), rwa_op (approx), rwa_total."""
    # RWA crédit depuis expositions
    rwa_credit = conn.execute(
        "SELECT COALESCE(SUM(rwa), 0) AS s FROM expositions WHERE statut = 'Active'"
    ).fetchone()["s"] or 0.0

    # RWA marché — approximatif depuis risque_marche (8% × position nette)
    row_m = conn.execute(
        "SELECT COALESCE(position_nette_change, 0) AS p FROM risque_marche ORDER BY date_analyse DESC LIMIT 1"
    ).fetchone()
    rwa_marche = float(row_m["p"]) if row_m and row_m["p"] else 0.0

    # RWA opérationnel — depuis BIC (OFR × 12,5) si disponible
    row_op = conn.execute(
        """SELECT COALESCE(pnb, 0) AS pnb FROM op_risk_financial_inputs
           ORDER BY annee DESC LIMIT 1"""
    ).fetchone()
    if row_op and row_op["pnb"]:
        rwa_op = float(row_op["pnb"]) * 0.15 * 12.5
    else:
        row_ro = conn.execute(
            """SELECT COALESCE(produit_brut_annee_1, 0) + COALESCE(produit_brut_annee_2, 0)
                      + COALESCE(produit_brut_annee_3, 0) AS somme
               FROM risque_operationnel ORDER BY date_analyse DESC LIMIT 1"""
        ).fetchone()
        pnb_moy = float(row_ro["somme"]) / 3 if row_ro and row_ro["somme"] else 0.0
        rwa_op = pnb_moy * 0.15 * 12.5

    rwa_total = rwa_credit + rwa_marche + rwa_op
    return {"credit": rwa_credit, "marche": rwa_marche, "op": rwa_op, "total": rwa_total}


# ──────────────────────────────────────────────────────────────────────────────
# CONCENTRATION (Module 1.2)
# ──────────────────────────────────────────────────────────────────────────────

def get_concentration() -> ConcentrationResult:
    with database_manager.transaction() as conn:
        fp_total = _get_current_fp_total(conn)

        rows = conn.execute(
            """SELECT e.ead, c.categorie_standard AS secteur, c.pays, e.contrepartie_id, c.nom
               FROM expositions e
               JOIN contreparties c ON c.id = e.contrepartie_id
               WHERE e.statut = 'Active' AND e.ead > 0"""
        ).fetchall()

        if not rows:
            return ConcentrationResult(
                total_ead=0, total_fp=fp_total, nb_contreparties=0,
                cr10_pct=0, grands_risques_nb=0, axes=[],
            )

        total_ead = sum(float(r["ead"]) for r in rows)
        nb_ctp = len({r["contrepartie_id"] for r in rows})

        # Top 10 EAD par contrepartie pour CR10
        ctp_ead: dict[str, float] = {}
        for r in rows:
            ctp_ead[r["contrepartie_id"]] = ctp_ead.get(r["contrepartie_id"], 0.0) + float(r["ead"])
        top10_sum = sum(sorted(ctp_ead.values(), reverse=True)[:10])
        cr10_pct = (top10_sum / fp_total * 100) if fp_total > 0 else 0.0
        grands_risques = sum(1 for v in ctp_ead.values() if fp_total > 0 and v / fp_total > 0.25)

        def compute_axis(key_fn, label: str) -> ConcentrationAxis:
            groups: dict[str, float] = {}
            for r in rows:
                k = key_fn(r)
                groups[k] = groups.get(k, 0.0) + float(r["ead"])
            hhi = sum((v / total_ead) ** 2 * 10_000 for v in groups.values()) if total_ead > 0 else 0.0
            sorted_g = sorted(groups.items(), key=lambda x: x[1], reverse=True)[:10]
            bars = [ConcentrationBar(label=k, ead=v, pct=v / total_ead * 100 if total_ead > 0 else 0.0)
                    for k, v in sorted_g]
            return ConcentrationAxis(axe=label, hhi=round(hhi, 1), niveau=_hhi_niveau(hhi), top_bars=bars)

        axes = [
            compute_axis(lambda r: r["secteur"] or "Non classé", "Secteur"),
            compute_axis(lambda r: r["pays"] or "Non spécifié", "Pays"),
            compute_axis(lambda r: r["nom"] or r["contrepartie_id"], "Contrepartie"),
        ]

        return ConcentrationResult(
            total_ead=total_ead,
            total_fp=fp_total,
            nb_contreparties=nb_ctp,
            cr10_pct=round(cr10_pct, 2),
            grands_risques_nb=grands_risques,
            axes=axes,
        )


# ──────────────────────────────────────────────────────────────────────────────
# IRRBB (Module 1.6)
# ──────────────────────────────────────────────────────────────────────────────

def get_irrbb(choc_bp: int = 200) -> IrrbbResult:
    with database_manager.transaction() as conn:
        fp_total = _get_current_fp_total(conn)
        rows = conn.execute(
            "SELECT * FROM pieafp_irrbb_echeancier ORDER BY ordre"
        ).fetchall()

        choc_rate = choc_bp / 10_000  # en décimal
        tranches: list[IrrbbTrancheResult] = []
        gap_total = 0.0
        delta_nii_total = 0.0

        for r in rows:
            gap = float(r["encours_actifs"]) - float(r["encours_passifs"])
            dur = float(r["duration_annees"])
            delta_nii = gap * choc_rate * dur
            gap_total += gap
            delta_nii_total += delta_nii
            tranches.append(IrrbbTrancheResult(
                tranche=r["tranche"],
                ordre=int(r["ordre"]),
                encours_actifs=float(r["encours_actifs"]),
                encours_passifs=float(r["encours_passifs"]),
                taux_actifs_pct=float(r["taux_actifs_pct"]),
                taux_passifs_pct=float(r["taux_passifs_pct"]),
                duration_annees=float(r["duration_annees"]),
                gap=gap,
                delta_nii_200bp=delta_nii,
            ))

        delta_pct_fp = (abs(delta_nii_total) / fp_total * 100) if fp_total > 0 else 0.0
        if delta_pct_fp < 5:
            niveau = "Faible"
        elif delta_pct_fp < 15:
            niveau = "Modéré"
        else:
            niveau = "Élevé"

        return IrrbbResult(
            choc_bp=choc_bp,
            tranches=tranches,
            gap_total=gap_total,
            delta_nii_200bp=delta_nii_total,
            delta_nii_pct_fp=round(delta_pct_fp, 2),
            niveau_risque=niveau,
        )


def update_irrbb_tranche(tranche: str, data: IrrbbUpdate) -> IrrbbTranche:
    with database_manager.transaction() as conn:
        conn.execute(
            """UPDATE pieafp_irrbb_echeancier
               SET encours_actifs = ?, encours_passifs = ?,
                   taux_actifs_pct = ?, taux_passifs_pct = ?,
                   modifie_le = ?
               WHERE tranche = ?""",
            (data.encours_actifs, data.encours_passifs,
             data.taux_actifs_pct, data.taux_passifs_pct,
             utcnow_iso(), tranche),
        )
        row = conn.execute(
            "SELECT * FROM pieafp_irrbb_echeancier WHERE tranche = ?", (tranche,)
        ).fetchone()
        if not row:
            raise ValueError(f"Tranche '{tranche}' introuvable")
        return IrrbbTranche(
            tranche=row["tranche"],
            ordre=int(row["ordre"]),
            encours_actifs=float(row["encours_actifs"]),
            encours_passifs=float(row["encours_passifs"]),
            taux_actifs_pct=float(row["taux_actifs_pct"]),
            taux_passifs_pct=float(row["taux_passifs_pct"]),
            duration_annees=float(row["duration_annees"]),
        )


# ──────────────────────────────────────────────────────────────────────────────
# AUTRES RISQUES (Module 1.8)
# ──────────────────────────────────────────────────────────────────────────────

def _row_to_autre_risque(r) -> AutreRisque:
    score = int(r["probabilite"]) * int(r["impact"])
    return AutreRisque(
        id=int(r["id"]),
        libelle=r["libelle"],
        categorie=r["categorie"],
        probabilite=int(r["probabilite"]),
        impact=int(r["impact"]),
        score=score,
        niveau=_risque_niveau(score),
        description=r["description"] or "",
        mesures=r["mesures"] or "",
        date_evaluation=r["date_evaluation"] or "",
        cree_le=r["cree_le"] or "",
    )


def list_autres_risques() -> list[AutreRisque]:
    with database_manager.transaction() as conn:
        rows = conn.execute(
            "SELECT * FROM pieafp_autres_risques ORDER BY probabilite * impact DESC, id"
        ).fetchall()
        return [_row_to_autre_risque(r) for r in rows]


def create_autre_risque(data: AutreRisqueCreate) -> AutreRisque:
    with database_manager.transaction() as conn:
        conn.execute(
            """INSERT INTO pieafp_autres_risques
               (libelle, categorie, probabilite, impact, description, mesures, date_evaluation, cree_le)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            (data.libelle, data.categorie, data.probabilite, data.impact,
             data.description, data.mesures, data.date_evaluation, utcnow_iso()),
        )
        row = conn.execute(
            "SELECT * FROM pieafp_autres_risques WHERE id = last_insert_rowid()"
        ).fetchone()
        return _row_to_autre_risque(row)


def update_autre_risque(id_: int, data: AutreRisqueUpdate) -> AutreRisque:
    with database_manager.transaction() as conn:
        row = conn.execute(
            "SELECT * FROM pieafp_autres_risques WHERE id = ?", (id_,)
        ).fetchone()
        if not row:
            raise ValueError(f"Risque {id_} introuvable")
        updated = {
            "libelle": data.libelle if data.libelle is not None else row["libelle"],
            "categorie": data.categorie if data.categorie is not None else row["categorie"],
            "probabilite": data.probabilite if data.probabilite is not None else row["probabilite"],
            "impact": data.impact if data.impact is not None else row["impact"],
            "description": data.description if data.description is not None else row["description"],
            "mesures": data.mesures if data.mesures is not None else row["mesures"],
            "date_evaluation": data.date_evaluation if data.date_evaluation is not None else row["date_evaluation"],
        }
        conn.execute(
            """UPDATE pieafp_autres_risques SET libelle=?, categorie=?, probabilite=?,
               impact=?, description=?, mesures=?, date_evaluation=? WHERE id=?""",
            (updated["libelle"], updated["categorie"], updated["probabilite"],
             updated["impact"], updated["description"], updated["mesures"],
             updated["date_evaluation"], id_),
        )
        row2 = conn.execute("SELECT * FROM pieafp_autres_risques WHERE id = ?", (id_,)).fetchone()
        return _row_to_autre_risque(row2)


def delete_autre_risque(id_: int) -> None:
    with database_manager.transaction() as conn:
        conn.execute("DELETE FROM pieafp_autres_risques WHERE id = ?", (id_,))


# ──────────────────────────────────────────────────────────────────────────────
# PLANIFICATION (Module 2)
# ──────────────────────────────────────────────────────────────────────────────

def _compute_planif_annee(r) -> PlanificationAnnee:
    rwa_total = (float(r["rwa_credit_projete"]) + float(r["rwa_marche_projete"])
                 + float(r["rwa_op_projete"]))
    fp_requis = rwa_total * 0.08 + float(r["addon_pilier2"])
    fp_dispo = float(r["fp_disponibles"])
    coussin = fp_dispo - fp_requis
    ratio = (fp_dispo / rwa_total * 100) if rwa_total > 0 else 0.0
    return PlanificationAnnee(
        annee=int(r["annee"]),
        fp_disponibles=fp_dispo,
        rwa_credit_projete=float(r["rwa_credit_projete"]),
        rwa_marche_projete=float(r["rwa_marche_projete"]),
        rwa_op_projete=float(r["rwa_op_projete"]),
        rwa_total_projete=rwa_total,
        resultat_net_projete=float(r["resultat_net_projete"]),
        dividendes_projetes=float(r["dividendes_projetes"]),
        emission_capital=float(r["emission_capital"]),
        addon_pilier2=float(r["addon_pilier2"]),
        fp_requis=fp_requis,
        coussin=coussin,
        ratio_solvabilite_pct=round(ratio, 2),
    )


def get_planification() -> PlanificationResult:
    with database_manager.transaction() as conn:
        rows = conn.execute(
            "SELECT * FROM pieafp_planification ORDER BY annee"
        ).fetchall()

        # Si vide, on pré-peuple 3 ans à partir de l'année courante avec les données réelles
        if not rows:
            rwa = _get_current_rwa_totals(conn)
            fp = _get_current_fp_total(conn)
            current_year = date.today().year
            annees_data = []
            for i in range(3):
                yr = current_year + i
                growth = 1.05 ** i
                conn.execute(
                    """INSERT OR IGNORE INTO pieafp_planification
                       (annee, fp_disponibles, rwa_credit_projete, rwa_marche_projete,
                        rwa_op_projete, resultat_net_projete, dividendes_projetes,
                        emission_capital, addon_pilier2, modifie_le)
                       VALUES (?, ?, ?, ?, ?, 0, 0, 0, 0, ?)""",
                    (yr, round(fp * growth, 0),
                     round(rwa["credit"] * growth, 0),
                     round(rwa["marche"] * growth, 0),
                     round(rwa["op"] * growth, 0),
                     utcnow_iso()),
                )
            rows = conn.execute(
                "SELECT * FROM pieafp_planification ORDER BY annee"
            ).fetchall()

        return PlanificationResult(annees=[_compute_planif_annee(r) for r in rows])


def upsert_planification_annee(annee: int, data: PlanificationAnneeUpdate) -> PlanificationAnnee:
    with database_manager.transaction() as conn:
        conn.execute(
            """INSERT INTO pieafp_planification
               (annee, fp_disponibles, rwa_credit_projete, rwa_marche_projete,
                rwa_op_projete, resultat_net_projete, dividendes_projetes,
                emission_capital, addon_pilier2, modifie_le)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
               ON CONFLICT(annee) DO UPDATE SET
                   fp_disponibles = excluded.fp_disponibles,
                   rwa_credit_projete = excluded.rwa_credit_projete,
                   rwa_marche_projete = excluded.rwa_marche_projete,
                   rwa_op_projete = excluded.rwa_op_projete,
                   resultat_net_projete = excluded.resultat_net_projete,
                   dividendes_projetes = excluded.dividendes_projetes,
                   emission_capital = excluded.emission_capital,
                   addon_pilier2 = excluded.addon_pilier2,
                   modifie_le = excluded.modifie_le""",
            (annee, data.fp_disponibles, data.rwa_credit_projete, data.rwa_marche_projete,
             data.rwa_op_projete, data.resultat_net_projete, data.dividendes_projetes,
             data.emission_capital, data.addon_pilier2, utcnow_iso()),
        )
        row = conn.execute(
            "SELECT * FROM pieafp_planification WHERE annee = ?", (annee,)
        ).fetchone()
        return _compute_planif_annee(row)


# ──────────────────────────────────────────────────────────────────────────────
# SCENARIOS STRESS (Module 3)
# ──────────────────────────────────────────────────────────────────────────────

def _row_to_scenario(r) -> ScenarioStress:
    return ScenarioStress(
        id=int(r["id"]),
        nom=r["nom"],
        description=r["description"] or "",
        type_scenario=r["type_scenario"],
        choc_rwa_credit_pct=float(r["choc_rwa_credit_pct"]),
        choc_rwa_marche_pct=float(r["choc_rwa_marche_pct"]),
        choc_rwa_op_pct=float(r["choc_rwa_op_pct"]),
        choc_perte_nette=float(r["choc_perte_nette"]),
        actif=bool(r["actif"]),
        cree_le=r["cree_le"] or "",
    )


def list_scenarios() -> list[ScenarioStress]:
    with database_manager.transaction() as conn:
        rows = conn.execute(
            "SELECT * FROM pieafp_scenarios_stress ORDER BY id"
        ).fetchall()
        return [_row_to_scenario(r) for r in rows]


def create_scenario(data: ScenarioStressCreate) -> ScenarioStress:
    with database_manager.transaction() as conn:
        conn.execute(
            """INSERT INTO pieafp_scenarios_stress
               (nom, description, type_scenario, choc_rwa_credit_pct, choc_rwa_marche_pct,
                choc_rwa_op_pct, choc_perte_nette, cree_le)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            (data.nom, data.description, data.type_scenario,
             data.choc_rwa_credit_pct, data.choc_rwa_marche_pct,
             data.choc_rwa_op_pct, data.choc_perte_nette, utcnow_iso()),
        )
        row = conn.execute(
            "SELECT * FROM pieafp_scenarios_stress WHERE id = last_insert_rowid()"
        ).fetchone()
        return _row_to_scenario(row)


def update_scenario(id_: int, data: ScenarioStressUpdate) -> ScenarioStress:
    with database_manager.transaction() as conn:
        row = conn.execute(
            "SELECT * FROM pieafp_scenarios_stress WHERE id = ?", (id_,)
        ).fetchone()
        if not row:
            raise ValueError(f"Scénario {id_} introuvable")
        conn.execute(
            """UPDATE pieafp_scenarios_stress SET
               nom = COALESCE(?, nom),
               description = COALESCE(?, description),
               type_scenario = COALESCE(?, type_scenario),
               choc_rwa_credit_pct = COALESCE(?, choc_rwa_credit_pct),
               choc_rwa_marche_pct = COALESCE(?, choc_rwa_marche_pct),
               choc_rwa_op_pct = COALESCE(?, choc_rwa_op_pct),
               choc_perte_nette = COALESCE(?, choc_perte_nette),
               actif = COALESCE(?, actif)
               WHERE id = ?""",
            (data.nom, data.description, data.type_scenario,
             data.choc_rwa_credit_pct, data.choc_rwa_marche_pct,
             data.choc_rwa_op_pct, data.choc_perte_nette,
             int(data.actif) if data.actif is not None else None,
             id_),
        )
        r2 = conn.execute(
            "SELECT * FROM pieafp_scenarios_stress WHERE id = ?", (id_,)
        ).fetchone()
        return _row_to_scenario(r2)


def delete_scenario(id_: int) -> None:
    with database_manager.transaction() as conn:
        conn.execute("DELETE FROM pieafp_scenarios_stress WHERE id = ?", (id_,))


def calcul_stress(id_: int) -> StressImpact:
    with database_manager.transaction() as conn:
        row = conn.execute(
            "SELECT * FROM pieafp_scenarios_stress WHERE id = ?", (id_,)
        ).fetchone()
        if not row:
            raise ValueError(f"Scénario {id_} introuvable")
        scenario = _row_to_scenario(row)

        fp_base = _get_current_fp_total(conn)
        rwa = _get_current_rwa_totals(conn)

        rwa_credit_s = rwa["credit"] * (1 + scenario.choc_rwa_credit_pct / 100)
        rwa_marche_s = rwa["marche"] * (1 + scenario.choc_rwa_marche_pct / 100)
        rwa_op_s = rwa["op"] * (1 + scenario.choc_rwa_op_pct / 100)
        rwa_total_s = rwa_credit_s + rwa_marche_s + rwa_op_s
        fp_s = fp_base - scenario.choc_perte_nette

        ratio_base = (fp_base / rwa["total"] * 100) if rwa["total"] > 0 else 0.0
        ratio_s = (fp_s / rwa_total_s * 100) if rwa_total_s > 0 else 0.0
        var_bp = (ratio_s - ratio_base) * 100  # en points de base

        return StressImpact(
            scenario=scenario,
            rwa_credit_base=rwa["credit"],
            rwa_marche_base=rwa["marche"],
            rwa_op_base=rwa["op"],
            rwa_total_base=rwa["total"],
            fp_base=fp_base,
            ratio_base_pct=round(ratio_base, 2),
            rwa_credit_stresse=rwa_credit_s,
            rwa_marche_stresse=rwa_marche_s,
            rwa_op_stresse=rwa_op_s,
            rwa_total_stresse=rwa_total_s,
            fp_stresse=fp_s,
            ratio_stresse_pct=round(ratio_s, 2),
            variation_ratio_bp=round(var_bp, 1),
            solvable_apres_stress=ratio_s >= 8.0,
        )


# ──────────────────────────────────────────────────────────────────────────────
# GOUVERNANCE / CHECKLIST (Module 4)
# ──────────────────────────────────────────────────────────────────────────────

def _row_to_checklist(r) -> ChecklistItem:
    return ChecklistItem(
        id=int(r["id"]),
        element=r["element"],
        categorie=r["categorie"],
        statut=r["statut"],
        date_revue=r["date_revue"] or "",
        responsable=r["responsable"] or "",
        note=r["note"] or "",
    )


def get_gouvernance() -> GouvernanceResult:
    with database_manager.transaction() as conn:
        rows = conn.execute(
            "SELECT * FROM pieafp_gouvernance_checklist ORDER BY categorie, id"
        ).fetchall()
        items = [_row_to_checklist(r) for r in rows]
        nb_conforme = sum(1 for i in items if i.statut == "Conforme")
        nb_en_cours = sum(1 for i in items if i.statut == "En cours")
        nb_a_faire = sum(1 for i in items if i.statut == "A faire")
        nb_na = sum(1 for i in items if i.statut == "Non applicable")
        applicable = len(items) - nb_na
        taux = (nb_conforme / applicable * 100) if applicable > 0 else 0.0
        return GouvernanceResult(
            items=items,
            nb_conforme=nb_conforme,
            nb_en_cours=nb_en_cours,
            nb_a_faire=nb_a_faire,
            nb_na=nb_na,
            taux_conformite_pct=round(taux, 1),
        )


def update_checklist_item(id_: int, data: ChecklistUpdate) -> ChecklistItem:
    with database_manager.transaction() as conn:
        conn.execute(
            """UPDATE pieafp_gouvernance_checklist
               SET statut = ?, date_revue = ?, responsable = ?, note = ?
               WHERE id = ?""",
            (data.statut, data.date_revue, data.responsable, data.note, id_),
        )
        row = conn.execute(
            "SELECT * FROM pieafp_gouvernance_checklist WHERE id = ?", (id_,)
        ).fetchone()
        if not row:
            raise ValueError(f"Item {id_} introuvable")
        return _row_to_checklist(row)


# ──────────────────────────────────────────────────────────────────────────────
# DASHBOARD PIEAFP
# ──────────────────────────────────────────────────────────────────────────────

def get_pieafp_dashboard() -> PieafpDashboard:
    with database_manager.transaction() as conn:
        fp_total = _get_current_fp_total(conn)
        rwa = _get_current_rwa_totals(conn)
        ratio = (fp_total / rwa["total"] * 100) if rwa["total"] > 0 else 0.0

    # Concentration
    try:
        conc = get_concentration()
        if conc.axes:
            hhi_max = max(a.hhi for a in conc.axes)
            conc_statut = "Attention" if hhi_max >= 1800 else ("Attention" if hhi_max >= 1000 else "OK")
            conc_val = f"HHI max : {int(hhi_max):,}"
        else:
            conc_statut = "A compléter"
            conc_val = "Aucune donnée"
    except Exception:
        conc_statut = "A compléter"
        conc_val = "—"

    # IRRBB
    try:
        irrbb = get_irrbb()
        irrbb_statut = "Attention" if irrbb.niveau_risque == "Élevé" else (
            "OK" if irrbb.niveau_risque == "Faible" else "Attention"
        )
        irrbb_val = f"ΔNII : {irrbb.delta_nii_pct_fp:.1f}% FP"
    except Exception:
        irrbb_statut = "A compléter"
        irrbb_val = "—"

    # Autres risques
    try:
        autres = list_autres_risques()
        nb_critique = sum(1 for r in autres if r.niveau == "Critique")
        autres_statut = "Attention" if nb_critique > 0 else ("OK" if autres else "A compléter")
        autres_val = f"{len(autres)} risques identifiés"
    except Exception:
        autres_statut = "A compléter"
        autres_val = "—"

    # Planification
    try:
        planif = get_planification()
        ratios = [a.ratio_solvabilite_pct for a in planif.annees if a.rwa_total_projete > 0]
        min_ratio = min(ratios) if ratios else 0.0
        planif_statut = "Attention" if min_ratio < 10 else "OK"
        planif_val = f"Ratio min : {min_ratio:.1f}%"
    except Exception:
        planif_statut = "A compléter"
        planif_val = "—"

    # Stress tests
    try:
        scenarios = list_scenarios()
        actifs = [s for s in scenarios if s.actif]
        stress_statut = "OK" if actifs else "A compléter"
        stress_val = f"{len(actifs)} scénario(s) actif(s)"
    except Exception:
        stress_statut = "A compléter"
        stress_val = "—"

    # Gouvernance
    try:
        gouv = get_gouvernance()
        gouv_statut = "OK" if gouv.taux_conformite_pct >= 80 else (
            "Attention" if gouv.taux_conformite_pct >= 50 else "A compléter"
        )
        gouv_val = f"Conformité : {gouv.taux_conformite_pct:.0f}%"
    except Exception:
        gouv_statut = "A compléter"
        gouv_val = "—"

    modules = [
        ModuleStatus(code="credit", libelle="Risque de crédit",
                     statut="OK" if rwa["credit"] > 0 else "A compléter",
                     valeur_cle=f"RWA : {rwa['credit'] / 1e9:.1f} Mds" if rwa["credit"] >= 1e9 else f"RWA : {rwa['credit']:,.0f}",
                     detail="Données issues du portefeuille Pilier 1"),
        ModuleStatus(code="concentration", libelle="Risque de concentration",
                     statut=conc_statut, valeur_cle=conc_val,
                     detail="HHI par secteur, pays et contrepartie"),
        ModuleStatus(code="residuel", libelle="Risque résiduel CRM",
                     statut="OK" if rwa["credit"] > 0 else "A compléter",
                     valeur_cle="Issu du Pilier 1",
                     detail="Risque résiduel lié aux techniques CRM"),
        ModuleStatus(code="op", libelle="Risque opérationnel",
                     statut="OK" if rwa["op"] > 0 else "A compléter",
                     valeur_cle=f"OFR : {rwa['op'] / 12.5 / 1e6:.0f} M",
                     detail="Approche BIC (CRR3) — ILM = 1"),
        ModuleStatus(code="marche", libelle="Risque de marché",
                     statut="OK" if rwa["marche"] > 0 else "A compléter",
                     valeur_cle=f"Position nette : {rwa['marche']:,.0f}",
                     detail="Position nette de change"),
        ModuleStatus(code="irrbb", libelle="Risque de taux (IRRBB)",
                     statut=irrbb_statut, valeur_cle=irrbb_val,
                     detail="Gap de repricing — choc +200pb"),
        ModuleStatus(code="autres", libelle="Autres risques Pilier 2",
                     statut=autres_statut, valeur_cle=autres_val,
                     detail="Matrice qualitative probabilité × impact"),
        ModuleStatus(code="liquidite", libelle="Risque de liquidité",
                     statut="N/A", valeur_cle="Non couvert",
                     detail="Hors périmètre — données indisponibles"),
    ]

    return PieafpDashboard(
        fp_total=fp_total,
        rwa_total=rwa["total"],
        ratio_solvabilite_pct=round(ratio, 2),
        modules=modules,
    )


# ──────────────────────────────────────────────────────────────────────────────
# RAPPORT PIEAFP
# ──────────────────────────────────────────────────────────────────────────────

def get_rapport() -> PieafpRapport:
    with database_manager.transaction() as conn:
        fp_total = _get_current_fp_total(conn)
        rwa = _get_current_rwa_totals(conn)
        ratio = (fp_total / rwa["total"] * 100) if rwa["total"] > 0 else 0.0

    return PieafpRapport(
        date_rapport=datetime.now().strftime("%Y-%m-%d"),
        fp_total=fp_total,
        rwa_total=rwa["total"],
        ratio_solvabilite_pct=round(ratio, 2),
        concentration=get_concentration(),
        irrbb=get_irrbb(),
        autres_risques=list_autres_risques(),
        planification=get_planification(),
        gouvernance=get_gouvernance(),
    )
