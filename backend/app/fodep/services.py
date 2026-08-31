"""Services métier du module FODEP.

Point d'attention central : ce module ne recalcule PAS le RWA crédit, marché
ou opérationnel - il les lit auprès des modules qui les calculent déjà
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
    calculer_exposition_levier,
    calculer_fonds_propres_detailles,
    calculer_limites_operations,
    calculer_produit_brut,
    calculer_ratios_solvabilite,
)
from app.fodep.dispru import FONDS_PROPRES_CODES
from app.fodep.models import (
    AprDetail,
    AttestationUpdate,
    AttestationView,
    EtablissementView,
    FodepApercu,
    ParticipationEntry,
    RatioDetail,
)
from app.market.services import resolve_market_capital
from app.risque_operationnel.services import calcul_aib as _calcul_aib_uemoa

POSTE_CODES: tuple[str, ...] = tuple(c.code.lower() for c in FONDS_PROPRES_CODES)
LIMITES_POSTE_CODES: tuple[str, ...] = tuple(
    c.code.lower() for c in FONDS_PROPRES_CODES if c.groupe == "LIMITES"
)

# Unité de tenue des montants FODEP : millions de FCFA. Les postes saisis, les
# totaux fonds propres et les ratios sont exprimés dans cette unité.
#
# L'APR (RWA crédit / marché / opérationnel) et les expositions brutes repris
# des autres modules restent tenus en FCFA dans l'objet renvoyé à l'IHM (qui
# les divise elle-même pour l'affichage). On ne les ramène en millions QUE
# pour les confronter aux fonds propres : calcul des ratios de solvabilité et
# écriture dans le classeur officiel. Sans cela, ratio = 40 759 / 730e9 ≈ 0.
FODEP_UNITE_DIVISEUR = 1_000_000.0


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
    réglementaire BCEAO) doit être complété manuellement - ce n'est qu'un
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


def _normaliser_periode(periode: str | None) -> str | None:
    """Ramène une date d'arrêté au format ISO AAAA-MM-JJ.

    Les périodes déjà enregistrées ne sont pas toutes ISO (saisie libre
    historique au format JJ-MM-AAAA) : comparer ces chaînes telles quelles
    aux intervalles de validité donnerait un ordre lexicographique faux.
    """

    if not periode:
        return None
    texte = periode.strip()
    for gabarit in ("%Y-%m-%d", "%d-%m-%Y", "%d/%m/%Y", "%Y/%m/%d"):
        try:
            return datetime.strptime(texte, gabarit).date().isoformat()
        except ValueError:
            continue
    return None


def resoudre_seuils(periode: str | None) -> dict[str, float]:
    """Seuils prudentiels en vigueur à la date d'arrêté.

    La notice impose que le niveau à respecter soit paramétré par date
    d'arrêté et jamais figé dans le code : cette résolution lit la table
    ``fodep_seuil_prudentiel`` et retient, pour chaque norme, la ligne dont
    l'intervalle de validité contient la période demandée.

    Sans période exploitable (brouillon non daté, ou date au format non
    reconnu), les seuils les plus récents s'appliquent - c'est le seul choix
    qui ne suppose pas une date.
    """

    reference = _normaliser_periode(periode)
    with database_manager.read_connection() as conn:
        if reference:
            rows = conn.execute(
                "SELECT code, seuil FROM fodep_seuil_prudentiel "
                "WHERE date_debut <= ? AND (date_fin IS NULL OR date_fin >= ?) "
                "ORDER BY code, date_debut",
                (reference, reference),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT code, seuil FROM fodep_seuil_prudentiel "
                "WHERE date_fin IS NULL ORDER BY code, date_debut"
            ).fetchall()

    # ORDER BY date_debut : sur un intervalle recouvrant, la ligne la plus
    # récemment entrée en vigueur l'emporte.
    return {row["code"]: float(row["seuil"]) for row in rows}


def lister_participations(periode: str | None) -> list[ParticipationEntry]:
    with database_manager.read_connection() as conn:
        if periode:
            rows = conn.execute(
                "SELECT * FROM fodep_participation WHERE periode = ? ORDER BY denomination_emettrice",
                (periode,),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM fodep_participation ORDER BY denomination_emettrice"
            ).fetchall()
    return [
        ParticipationEntry(
            id=row["id"],
            denomination_emettrice=row["denomination_emettrice"],
            capital_emettrice=float(row["capital_emettrice"]),
            montant_net=float(row["montant_net"]),
        )
        for row in rows
    ]


def enregistrer_participations(periode: str, lignes: list[ParticipationEntry]) -> list[ParticipationEntry]:
    """Remplace l'intégralité du registre pour la période donnée - même
    logique « tout ou rien » que ``enregistrer_fonds_propres`` : le registre
    est petit et la ré-saisie complète évite de gérer des diffs ligne à
    ligne côté client."""

    maintenant = _utcnow_iso()
    with database_manager.transaction() as conn:
        conn.execute("DELETE FROM fodep_participation WHERE periode = ?", (periode,))
        for ligne in lignes:
            conn.execute(
                "INSERT INTO fodep_participation "
                "(id, periode, denomination_emettrice, capital_emettrice, montant_net, cree_le, modifie_le) "
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                (
                    str(uuid.uuid4()),
                    periode,
                    ligne.denomination_emettrice.strip(),
                    ligne.capital_emettrice,
                    ligne.montant_net,
                    maintenant,
                    maintenant,
                ),
            )
    return lister_participations(periode)


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
    seuils = resoudre_seuils(periode_effective)

    # Limites sur opérations (RA006-RA011) : calculées sur les fonds propres
    # AVANT déduction des excédents qu'elles produisent elles-mêmes - l'une
    # des deux conventions explicitement admises par la notice technique
    # pour trancher la circularité entre ces limites et le CET1 (§ boucle de
    # calcul, EP34-EP39), l'autre étant une résolution itérative jugée
    # disproportionnée pour un écart de second ordre.
    participations = (
        [p.model_dump() for p in lister_participations(periode_effective)]
        if periode_effective
        else []
    )
    a_des_donnees_registre = bool(participations) or any(
        postes.get(code, 0.0) for code in LIMITES_POSTE_CODES
    )
    ratios_limites, excedents = calculer_limites_operations(
        postes, participations, t1=totaux["fpi29"], fpe=totaux["fpi41"], seuils=seuils
    )
    if a_des_donnees_registre:
        postes = {**postes, **excedents}
        totaux = calculer_fonds_propres_detailles(postes)

    # EP21 (produit brut) et EP33 (briques d'exposition du levier) : totaux
    # dérivés des postes saisis, jamais saisis eux-mêmes.
    totaux.update(calculer_produit_brut(postes))
    levier = calculer_exposition_levier(postes)
    totaux.update(levier)

    apr = obtenir_apr_total()

    # Dénominateur du ratio de levier : l'exposition totale de l'EP33 quand
    # elle est renseignée - c'est l'assiette que la notice prescrit - sinon
    # repli sur la somme des expositions brutes du portefeuille.
    exposure_rows = [_normalize_row(item) for item in list_expositions()]
    # Ratios confrontés aux fonds propres (millions) : APR et assiette de
    # levier ramenés en millions.
    apr_total_millions = apr.apr_total / FODEP_UNITE_DIVISEUR
    total_expositions = (
        levier["rl015"]
        if levier["rl015"] > 0
        else sum(float(row["gross_amount"]) for row in exposure_rows) / FODEP_UNITE_DIVISEUR
    )

    ratios_bruts = calculer_ratios_solvabilite(
        totaux, apr_total_millions, total_expositions, seuils
    )
    ratios = {k: RatioDetail(**v) for k, v in ratios_bruts.items()}
    if a_des_donnees_registre:
        ratios.update({k: RatioDetail(**v) for k, v in ratios_limites.items()})

    return FodepApercu(
        periode=periode_effective,
        postes=postes,
        totaux=totaux,
        apr=apr,
        ratios=ratios,
        source_prefill=source_prefill,
    )


def enregistrer_fonds_propres(periode: str, postes: dict[str, float]) -> FodepApercu:
    periode = _normaliser_periode(periode) or periode
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


# ── Attestation de déclaration prudentielle ─────────────────────────────────
# Le corps de l'attestation par défaut reprend fidèlement les exigences de la
# notice technique BCEAO / DISPRU : l'établissement atteste, sur l'honneur, la
# sincérité et l'exactitude de la déclaration.

def obtenir_attestation() -> AttestationView:
    """Renvoie l'attestation enregistrée, ou un jeu de valeurs par défaut si rien n'a encore été saisi."""
    with database_manager.read_connection() as conn:
        # Check if table exists because we might be running right after a migration failure
        try:
            row = conn.execute(
                "SELECT * FROM fodep_attestation ORDER BY modifie_le DESC LIMIT 1"
            ).fetchone()
        except Exception:
            row = None

    if row is None:
        return AttestationView(
            rens_prenoms_nom="", rens_fonction="", rens_telephone="", rens_poste="", rens_email="",
            trans_prenoms_nom="", trans_fonction="", trans_telephone="", trans_poste="", trans_email="",
            certif_nous_1="", certif_nous_2="",
            sign1_code="", sign1_fonction="", sign1_date="", sign1_image="",
            sign2_code="", sign2_fonction="", sign2_date="", sign2_image=""
        )

    data = dict(row)
    return AttestationView(
        rens_prenoms_nom=data.get("rens_prenoms_nom", "") or "",
        rens_fonction=data.get("rens_fonction", "") or "",
        rens_telephone=data.get("rens_telephone", "") or "",
        rens_poste=data.get("rens_poste", "") or "",
        rens_email=data.get("rens_email", "") or "",
        trans_prenoms_nom=data.get("trans_prenoms_nom", "") or "",
        trans_fonction=data.get("trans_fonction", "") or "",
        trans_telephone=data.get("trans_telephone", "") or "",
        trans_poste=data.get("trans_poste", "") or "",
        trans_email=data.get("trans_email", "") or "",
        certif_nous_1=data.get("certif_nous_1", "") or "",
        certif_nous_2=data.get("certif_nous_2", "") or "",
        sign1_code=data.get("sign1_code", "") or "",
        sign1_fonction=data.get("sign1_fonction", "") or "",
        sign1_date=data.get("sign1_date", "") or "",
        sign1_image=data.get("sign1_image", "") or "",
        sign2_code=data.get("sign2_code", "") or "",
        sign2_fonction=data.get("sign2_fonction", "") or "",
        sign2_date=data.get("sign2_date", "") or "",
        sign2_image=data.get("sign2_image", "") or "",
    )


def enregistrer_attestation(payload: AttestationUpdate, *, periode: str | None = None) -> AttestationView:
    """Enregistre l'attestation type de l'établissement selon le modèle BCEAO."""
    maintenant = _utcnow_iso()
    with database_manager.transaction() as conn:
        # Create table if it doesn't exist just to be safe during migration
        conn.execute("DELETE FROM fodep_attestation")
        conn.execute(
            "INSERT INTO fodep_attestation ("
            "id, rens_prenoms_nom, rens_fonction, rens_telephone, rens_poste, rens_email, "
            "trans_prenoms_nom, trans_fonction, trans_telephone, trans_poste, trans_email, "
            "certif_nous_1, certif_nous_2, "
            "sign1_code, sign1_fonction, sign1_date, sign1_image, "
            "sign2_code, sign2_fonction, sign2_date, sign2_image, "
            "cree_le, modifie_le) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                str(uuid.uuid4()),
                payload.rens_prenoms_nom.strip(), payload.rens_fonction.strip(), payload.rens_telephone.strip(), payload.rens_poste.strip(), payload.rens_email.strip(),
                payload.trans_prenoms_nom.strip(), payload.trans_fonction.strip(), payload.trans_telephone.strip(), payload.trans_poste.strip(), payload.trans_email.strip(),
                payload.certif_nous_1.strip(), payload.certif_nous_2.strip(),
                payload.sign1_code.strip(), payload.sign1_fonction.strip(), payload.sign1_date.strip(), payload.sign1_image,
                payload.sign2_code.strip(), payload.sign2_fonction.strip(), payload.sign2_date.strip(), payload.sign2_image,
                maintenant, maintenant
            ),
        )

    return obtenir_attestation()


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
