"""Calculs du module ICAAP — fonctions pures, sans accès base.

Lot L3 : besoin en capital économique par risque et agrégation par matrice
de corrélation. Aucun RWA n'est recalculé ici ; le moteur combine des
montants fournis en entrée.
"""

from __future__ import annotations

import math

import numpy as np

# Familles de risques reconnues par la matrice de corrélation. Toute
# catégorie de la cartographie est ramenée à l'une d'elles (sinon « autre »,
# non corrélée).
CLES_CORRELATION: tuple[str, ...] = (
    "credit",
    "marche",
    "operationnel",
    "taux",
    "concentration",
    "residuel",
    "liquidite",
    "strategie",
    "reputation",
)

_SYNONYMES: dict[str, str] = {
    "credit": "credit",
    "risque de credit": "credit",
    "contrepartie": "credit",
    "marche": "marche",
    "risque de marche": "marche",
    "operationnel": "operationnel",
    "risque operationnel": "operationnel",
    "taux": "taux",
    "irrbb": "taux",
    "risque de taux": "taux",
    "taux du portefeuille bancaire": "taux",
    "concentration": "concentration",
    "risque de concentration": "concentration",
    "grands risques": "concentration",
    "residuel": "residuel",
    "risque residuel": "residuel",
    "crm": "residuel",
    "residuel crm": "residuel",
    "liquidite": "liquidite",
    "risque de liquidite": "liquidite",
    "strategie": "strategie",
    "strategique": "strategie",
    "risque strategique": "strategie",
    "reputation": "reputation",
    "reputationnel": "reputation",
    "risque de reputation": "reputation",
}


def _sans_accents(texte: str) -> str:
    table = str.maketrans("àâäéèêëîïôöùûüç", "aaaeeeeiioouuuc")
    return texte.lower().strip().translate(table)


def cle_correlation(categorie: str) -> str:
    """Ramène une catégorie de cartographie à une famille de risques."""

    brut = _sans_accents(categorie)
    if brut in _SYNONYMES:
        return _SYNONYMES[brut]
    for motif, cle in _SYNONYMES.items():
        if motif in brut:
            return cle
    return "autre"


def besoin_pondere(rwa: float, ratio_cible_pct: float) -> float:
    """Besoin = RWA x ratio cible (crédit, marché ou opérationnel repris des
    RWA Pilier 1 faute d'exigence explicite)."""

    return max(0.0, rwa) * max(0.0, ratio_cible_pct) / 100.0


def besoin_concentration(
    rwa_credit: float,
    ratio_cible_pct: float,
    hhi: float,
    addon_max_ratio: float,
) -> float:
    """Add-on de concentration = HHI borné par l'add-on maximal, appliqué au
    besoin en capital crédit."""

    base = besoin_pondere(rwa_credit, ratio_cible_pct)
    taux = min(max(0.0, hhi), max(0.0, addon_max_ratio))
    return base * taux


def somme_simple(besoins: dict[str, float]) -> float:
    """Borne haute : aucun bénéfice de diversification."""

    return float(sum(max(0.0, v) for v in besoins.values()))


def agreger_par_correlation(
    besoins: dict[str, float],
    correlations: list[tuple[str, str, float]],
) -> float:
    """Besoin global = racine( r^T . C . r ).

    ``besoins`` : montant par famille de risques. ``correlations`` : coefficients
    hors diagonale (l'ordre de la paire n'importe pas). Diagonale = 1. Une paire
    absente vaut 0. Le résultat ne peut pas dépasser la somme simple.
    """

    cles = sorted(k for k, v in besoins.items() if v and v > 0)
    if not cles:
        return 0.0
    if len(cles) == 1:
        return float(besoins[cles[0]])

    index = {cle: i for i, cle in enumerate(cles)}
    r = np.array([float(besoins[cle]) for cle in cles], dtype=float)
    C = np.eye(len(cles))
    for a, b, coef in correlations:
        if a in index and b in index and a != b:
            coef = max(-1.0, min(1.0, float(coef)))
            C[index[a], index[b]] = coef
            C[index[b], index[a]] = coef

    variance = float(r @ C @ r)
    if variance <= 0.0:
        return 0.0
    return math.sqrt(variance)


# --------------------------------------------------------------------------
# Stress testing
# --------------------------------------------------------------------------
def _ratio(fonds_propres: float, rwa: float) -> float:
    return (fonds_propres / rwa * 100.0) if rwa > 0 else 0.0


def projeter_scenario(
    *,
    fonds_propres_0: float,
    rwa_0: float,
    hypotheses: dict[str, float],
    horizon_annees: int,
) -> list[dict[str, float]]:
    """Projette RWA, résultat, fonds propres et ratio de solvabilité sous choc.

    Hypothèses reconnues (toutes optionnelles, défaut 0) :
      pnb_annuel, charges_annuelles, cout_risque_annuel  — compte de résultat
        de référence (année 0) ;
      taux_impot_pct (défaut 30), taux_distribution_pct (défaut 0) ;
      choc_pnb_pct, choc_cout_risque_pct, choc_rwa_pct  — chocs relatifs
        appliqués et composés chaque année ;
      choc_fonds_propres_abs  — perte exceptionnelle, imputée l'année 1.

    L'année 0 (situation de départ) figure en tête de la liste renvoyée.
    """

    h = hypotheses
    pnb0 = h.get("pnb_annuel", 0.0)
    charges = h.get("charges_annuelles", 0.0)
    cr0 = h.get("cout_risque_annuel", 0.0)
    taux_impot = h.get("taux_impot_pct", 30.0) / 100.0
    taux_distrib = h.get("taux_distribution_pct", 0.0) / 100.0
    choc_pnb = h.get("choc_pnb_pct", 0.0)
    choc_cr = h.get("choc_cout_risque_pct", 0.0)
    choc_rwa = h.get("choc_rwa_pct", 0.0)
    perte_exceptionnelle = h.get("choc_fonds_propres_abs", 0.0)

    lignes: list[dict[str, float]] = [
        {
            "annee_proj": 0,
            "rwa_projete": round(rwa_0, 2),
            "resultat_projete": 0.0,
            "fonds_propres_projetes": round(fonds_propres_0, 2),
            "ratio_projete": round(_ratio(fonds_propres_0, rwa_0), 2),
        }
    ]

    rwa = rwa_0
    fonds_propres = fonds_propres_0
    for annee in range(1, max(1, horizon_annees) + 1):
        rwa = rwa * (1.0 + choc_rwa)
        pnb = pnb0 * (1.0 + choc_pnb)
        cout_risque = cr0 * (1.0 + choc_cr)
        resultat_avant_impot = pnb - charges - cout_risque
        if resultat_avant_impot > 0:
            resultat_net = resultat_avant_impot * (1.0 - taux_impot)
        else:
            resultat_net = resultat_avant_impot  # pas d'économie d'impôt
        mise_en_reserve = resultat_net * (1.0 - taux_distrib)
        fonds_propres = fonds_propres + mise_en_reserve
        if annee == 1:
            fonds_propres -= perte_exceptionnelle

        lignes.append(
            {
                "annee_proj": annee,
                "rwa_projete": round(rwa, 2),
                "resultat_projete": round(resultat_net, 2),
                "fonds_propres_projetes": round(fonds_propres, 2),
                "ratio_projete": round(_ratio(fonds_propres, rwa), 2),
            }
        )
    return lignes


# --------------------------------------------------------------------------
# Planification du capital
# --------------------------------------------------------------------------
def projeter_plan_capital(
    *,
    fonds_propres_0: float,
    rwa_0: float,
    croissance_encours_pct: float,
    marge_nette_pct: float,
    cout_risque_pct: float,
    taux_distribution_pct: float,
    horizon_annees: int,
    seuil_coussin_pct: float,
) -> tuple[list[dict[str, float]], int | None]:
    """Projection déterministe du capital sur l'horizon prudentiel.

    Renvoie (trajectoire, première année où le ratio passe sous
    ``seuil_coussin_pct`` — minimum réglementaire + coussin de conservation —
    ou None). L'année 0 figure en tête.
    """

    croissance = croissance_encours_pct / 100.0
    marge = marge_nette_pct / 100.0
    cout = cout_risque_pct / 100.0
    distrib = taux_distribution_pct / 100.0

    lignes: list[dict[str, float]] = [
        {
            "annee_proj": 0,
            "rwa_projete": round(rwa_0, 2),
            "resultat_mis_en_reserve": 0.0,
            "distributions": 0.0,
            "fonds_propres_projetes": round(fonds_propres_0, 2),
            "ratio_projete": round(_ratio(fonds_propres_0, rwa_0), 2),
            "coussin_entame": _ratio(fonds_propres_0, rwa_0) < seuil_coussin_pct,
        }
    ]

    rwa = rwa_0
    fonds_propres = fonds_propres_0
    annee_entame: int | None = None
    for annee in range(1, max(1, horizon_annees) + 1):
        rwa = rwa * (1.0 + croissance)
        resultat = rwa * (marge - cout)
        distributions = max(0.0, resultat) * distrib
        mise_en_reserve = resultat - distributions
        fonds_propres = fonds_propres + mise_en_reserve
        ratio = _ratio(fonds_propres, rwa)
        entame = ratio < seuil_coussin_pct
        if entame and annee_entame is None:
            annee_entame = annee

        lignes.append(
            {
                "annee_proj": annee,
                "rwa_projete": round(rwa, 2),
                "resultat_mis_en_reserve": round(mise_en_reserve, 2),
                "distributions": round(distributions, 2),
                "fonds_propres_projetes": round(fonds_propres, 2),
                "ratio_projete": round(ratio, 2),
                "coussin_entame": entame,
            }
        )
    return lignes, annee_entame
