"""Services métier du module FODEP.

Point d'attention central : ce module ne recalcule PAS le RWA crédit, marché
ou opérationnel — il les lit auprès des modules qui les calculent déjà
(``rwa_credit`` via les expositions, ``market``, ``risque_operationnel``),
exactement comme le fait ``dashboard.services.get_dashboard_snapshot``. Deux
moteurs de calcul du même chiffre serait une source de divergence, pas une
fonctionnalité.
"""

from __future__ import annotations

import json
import uuid
from datetime import datetime

from database.connection import database_manager

from app.dashboard.services import _normalize_row
from app.expositions.services import list_expositions
from app.fodep.calculations import (
    calculer_fonds_propres_detailles,
    calculer_ratios_solvabilite,
)
from app.fodep.dispru import FONDS_PROPRES_CODES
from app.fodep.models import (
    AprDetail,
    EtablissementView,
    FodepApercu,
    RatioDetail,
)
from app.market.services import resolve_market_capital
from app.risque_operationnel.services import calcul_aib as _calcul_aib_uemoa

POSTE_CODES: tuple[str, ...] = tuple(c.code.lower() for c in FONDS_PROPRES_CODES)


def _utcnow_iso() -> str:
    return datetime.utcnow().replace(microsecond=0).isoformat()


def obtenir_apr_total() -> AprDetail:
    """RWA total (EP08) = crédit + marché + opérationnel, réutilisés tels
    quels depuis les modules existants (aucun recalcul)."""

    with database_manager.read_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT * FROM risque_marche ORDER BY date_analyse DESC LIMIT 1"
        )
        rm_row = cursor.fetchone()
        rm_data = dict(rm_row) if rm_row else {}

    exposure_rows = [_normalize_row(item) for item in list_expositions()]
    rwa_credit = sum(float(row["rwa"]) for row in exposure_rows)
    rwa_marche = resolve_market_capital(rm_data)["rwa_marche"]
    rwa_operationnel = _calcul_aib_uemoa().apr_aib
    apr_total = rwa_credit + rwa_marche + rwa_operationnel

    return AprDetail(
        rwa_credit=round(rwa_credit, 2),
        rwa_marche=round(rwa_marche, 2),
        rwa_operationnel=round(rwa_operationnel, 2),
        apr_total=round(apr_total, 2),
    )


def _dernier_arrete() -> tuple[dict[str, float], str | None]:
    with database_manager.read_connection() as conn:
        row = conn.execute(
            "SELECT * FROM fodep_fonds_propres ORDER BY periode DESC LIMIT 1"
        ).fetchone()
    if row is None:
        return {}, None
    data = dict(row)
    periode = data.pop("periode", None)
    return {code: float(data.get(code, 0.0) or 0.0) for code in POSTE_CODES}, periode


def _prefill_depuis_modele_simplifie() -> dict[str, float]:
    """Reprend le modèle simplifié à 11 postes (`fonds_propres`, déjà utilisé
    par le tableau de bord) comme brouillon de départ pour les postes FODEP
    qui leur correspondent directement. Le reste (34 postes propres au détail
    réglementaire BCEAO) doit être complété manuellement — ce n'est qu'un
    point de départ, pas une équivalence garantie.
    """

    with database_manager.read_connection() as conn:
        row = conn.execute(
            "SELECT * FROM fonds_propres ORDER BY date_analyse DESC LIMIT 1"
        ).fetchone()
    simplifie = dict(row) if row else {}

    postes = {code: 0.0 for code in POSTE_CODES}
    # Correspondances directes uniquement (mapping honnête, pas une
    # équivalence réglementaire complète) :
    postes["fpi01"] = float(simplifie.get("capital_ordinaire", 0.0) or 0.0)
    postes["fpi04"] = float(simplifie.get("reserves", 0.0) or 0.0)
    postes["fpi05"] = float(simplifie.get("resultats_report", 0.0) or 0.0)
    postes["fpi06"] = float(simplifie.get("resultat_eligible", 0.0) or 0.0)
    # Les déductions CET1 simplifiées n'ont pas de correspondance ligne à
    # ligne dans le détail BCEAO (18 postes de déduction distincts) : on les
    # reporte sur FPI21 « Autres déductions » pour ne rien perdre du brouillon
    # existant, à ventiler ensuite.
    postes["fpi21"] = -abs(float(simplifie.get("deductions_prud_cet1", 0.0) or 0.0))
    postes["fpi23"] = float(simplifie.get("instruments_at1", 0.0) or 0.0)
    postes["fpi24"] = float(simplifie.get("primes_emission_at1", 0.0) or 0.0)
    postes["fpi27"] = -abs(float(simplifie.get("deductions_prud_at1", 0.0) or 0.0))
    postes["fpi30"] = float(simplifie.get("dettes_subordonnees_t2", 0.0) or 0.0)
    postes["fpi35"] = float(simplifie.get("provisions_generales_t2", 0.0) or 0.0)
    postes["pa158"] = -abs(float(simplifie.get("deductions_prud_t2", 0.0) or 0.0))
    return postes


def generer_apercu(periode: str | None = None) -> FodepApercu:
    if periode:
        with database_manager.read_connection() as conn:
            row = conn.execute(
                "SELECT * FROM fodep_fonds_propres WHERE periode = ?",
                (periode,),
            ).fetchone()
        source_prefill = False
        if row is None:
            postes = {code: 0.0 for code in POSTE_CODES}
            periode_effective = periode
        else:
            data = dict(row)
            postes = {code: float(data.get(code, 0.0) or 0.0) for code in POSTE_CODES}
            periode_effective = periode
    else:
        postes, periode_existante = _dernier_arrete()
        if periode_existante:
            source_prefill = False
            periode_effective = periode_existante
        else:
            # Rien de saisi encore côté FODEP : on propose un brouillon basé
            # sur le modèle simplifié existant, clairement signalé comme tel.
            postes = _prefill_depuis_modele_simplifie()
            source_prefill = True
            periode_effective = None

    totaux = calculer_fonds_propres_detailles(postes)
    apr = obtenir_apr_total()

    exposure_rows = [_normalize_row(item) for item in list_expositions()]
    total_expositions = sum(float(row["gross_amount"]) for row in exposure_rows)

    ratios_bruts = calculer_ratios_solvabilite(totaux, apr.apr_total, total_expositions)
    ratios = {k: RatioDetail(**v) for k, v in ratios_bruts.items()}

    return FodepApercu(
        periode=periode_effective,
        postes=postes,
        totaux=totaux,
        apr=apr,
        ratios=ratios,
        source_prefill=source_prefill,
    )


def enregistrer_fonds_propres(periode: str, postes: dict[str, float]) -> FodepApercu:
    valeurs = {code: float(postes.get(code, 0.0) or 0.0) for code in POSTE_CODES}
    maintenant = _utcnow_iso()

    with database_manager.transaction() as conn:
        existe = conn.execute(
            "SELECT id FROM fodep_fonds_propres WHERE periode = ?", (periode,)
        ).fetchone()
        colonnes = ", ".join(valeurs.keys())
        if existe:
            affectations = ", ".join(f"{code} = ?" for code in valeurs)
            conn.execute(
                f"UPDATE fodep_fonds_propres SET {affectations}, modifie_le = ? "
                "WHERE periode = ?",
                (*valeurs.values(), maintenant, periode),
            )
        else:
            placeholders = ", ".join("?" for _ in valeurs)
            conn.execute(
                f"INSERT INTO fodep_fonds_propres "
                f"(id, periode, {colonnes}, cree_le, modifie_le) "
                f"VALUES (?, ?, {placeholders}, ?, ?)",
                (str(uuid.uuid4()), periode, *valeurs.values(), maintenant, maintenant),
            )

    return generer_apercu(periode)


def obtenir_etablissement() -> EtablissementView:
    with database_manager.read_connection() as conn:
        row = conn.execute(
            "SELECT * FROM fodep_etablissement ORDER BY modifie_le DESC LIMIT 1"
        ).fetchone()
    if row is None:
        return EtablissementView(denomination="", code_bceao="")
    data = dict(row)
    return EtablissementView(
        denomination=data.get("denomination", ""),
        code_bceao=data.get("code_bceao", ""),
    )


def enregistrer_etablissement(denomination: str, code_bceao: str) -> EtablissementView:
    maintenant = _utcnow_iso()
    with database_manager.transaction() as conn:
        conn.execute(
            "DELETE FROM fodep_etablissement",
        )
        conn.execute(
            "INSERT INTO fodep_etablissement (id, denomination, code_bceao, modifie_le) "
            "VALUES (?, ?, ?, ?)",
            (str(uuid.uuid4()), denomination, code_bceao, maintenant),
        )
    return EtablissementView(denomination=denomination, code_bceao=code_bceao)


def enregistrer_import(nom_fichier: str, periode: str | None, postes: dict[str, float]) -> str:
    identifiant = str(uuid.uuid4())
    with database_manager.transaction() as conn:
        conn.execute(
            "INSERT INTO fodep_import (id, nom_fichier, periode, donnees_json, cree_le) "
            "VALUES (?, ?, ?, ?, ?)",
            (identifiant, nom_fichier, periode, json.dumps(postes), _utcnow_iso()),
        )
    return identifiant


def comparer_a_l_existant(postes_importes: dict[str, float]) -> dict[str, dict[str, float]]:
    """Écarts entre un FODEP importé et les postes actuellement enregistrés
    dans RisqueManagement, poste par poste (pour la revue « Analyser »)."""

    postes_actuels, _ = _dernier_arrete()
    ecarts: dict[str, dict[str, float]] = {}
    for code in POSTE_CODES:
        importe = float(postes_importes.get(code, 0.0) or 0.0)
        actuel = float(postes_actuels.get(code, 0.0) or 0.0)
        if abs(importe - actuel) > 0.005:
            ecarts[code] = {"importe": importe, "actuel": actuel, "ecart": round(importe - actuel, 2)}
    return ecarts
