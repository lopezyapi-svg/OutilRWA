"\"\"Module de calcul des ratios réglementaires stricts (Dispositif Prudentiel BCEAO)."""

from typing import Any

# ============================================================================
# CONSTANTES REGLEMENTAIRES UMOA / BALE III (Titre III & X)
# ============================================================================
MIN_CET1_RATIO = 0.05       # 5% (§91a)
MIN_TIER1_RATIO = 0.06      # 6% (§91b)
MIN_SOLVENCY_RATIO = 0.09   # 9% - minimum SANS coussin (§91c ; exigence globale avec coussin = 11,5 %)
MIN_LEVERAGE_RATIO = 0.03   # 3%

# Coussin de conservation (Titre III, section IV, Paragraphe 92)
CONSERVATION_BUFFER = 0.025 # 2.5%

# Multiplicateur réglementaire des exigences de fonds propres marché et
# opérationnel dans l'assiette du ratio de solvabilité (§90) :
# Ratio = FP / (APR crédit + 12,5 × risque op + 12,5 × risque marché).
RWA_MULTIPLIER = 11.111111

# Exigence de fonds propres pour risque de change : 8 % de la position nette
# globale en devises (§417).
FX_CAPITAL_CHARGE_RATE = 0.08


def calculate_fonds_propres(fp_data: dict[str, float]) -> dict[str, float]:
    """
    Calcule les Fonds Propres selon le Titre II du dispositif prudentiel BCEAO.
    """
    cet1 = (
        fp_data.get("capital_ordinaire", 0.0) +
        fp_data.get("reserves", 0.0) +
        fp_data.get("resultats_report", 0.0) +
        fp_data.get("resultat_eligible", 0.0) -
        fp_data.get("deductions_prud_cet1", 0.0)
    )
    cet1 = max(0.0, cet1)

    at1 = (
        fp_data.get("instruments_at1", 0.0) +
        fp_data.get("primes_emission_at1", 0.0) -
        fp_data.get("deductions_prud_at1", 0.0)
    )
    at1 = max(0.0, at1)

    t1 = cet1 + at1

    t2 = (
        fp_data.get("dettes_subordonnees_t2", 0.0) +
        fp_data.get("provisions_generales_t2", 0.0) -
        fp_data.get("deductions_prud_t2", 0.0)
    )
    t2 = max(0.0, t2)

    total_capital = t1 + t2

    return {
        "cet1": round(cet1, 2),
        "at1": round(at1, 2),
        "t1": round(t1, 2),
        "t2": round(t2, 2),
        "total_capital": round(total_capital, 2),
    }


def calculate_risque_marche(marche_data: dict[str, float]) -> dict[str, float]:
    """
    Calcule le RWA Marché (Titre VI).
    """
    position_nette = marche_data.get("position_nette_change", 0.0)

    exigence = abs(position_nette) * FX_CAPITAL_CHARGE_RATE

    rwa_marche = exigence * RWA_MULTIPLIER
    
    return {
        "exigence_fonds_propres": round(exigence, 2),
        "rwa_marche": round(rwa_marche, 2),
    }


def evaluate_ratios(
    rwa_total: float,
    fonds_propres: dict[str, float],
    total_expositions: float,
    seuils: dict[str, float] | None = None,
) -> dict[str, Any]:
    """
    Calcule et évalue les ratios de solvabilité et de levier par rapport aux normes UMOA.

    ``seuils`` (en pourcentage, clés ``cet1``/``tier1``/``solvency``/``leverage``)
    permet d'imposer des niveaux datés - la notice FODEP exige que le niveau à
    respecter soit paramétré par date d'arrêté plutôt que figé dans le code.
    Omis, les minima courants ci-dessus s'appliquent, ce qui préserve le
    comportement des appelants qui n'ont pas de date d'arrêté (tableau de bord).
    """
    cet1 = fonds_propres["cet1"]
    t1 = fonds_propres["t1"]
    total_capital = fonds_propres["total_capital"]
    seuils = seuils or {}
    
    if rwa_total <= 0:
        cet1_ratio = 0.0
        t1_ratio = 0.0
        solvency_ratio = 0.0
    else:
        cet1_ratio = cet1 / rwa_total
        t1_ratio = t1 / rwa_total
        solvency_ratio = total_capital / rwa_total
        
    if total_expositions <= 0:
        leverage_ratio = 0.0
    else:
        leverage_ratio = t1 / total_expositions
        
    def _evaluate(ratio: float, threshold: float) -> dict[str, Any]:
        diff = (ratio - threshold) * 100
        status = "Déficit" if ratio < threshold else "Excédent"
        if threshold <= ratio < (threshold + CONSERVATION_BUFFER):
            status = "Sous cible"
        return {
            "value": round(ratio * 100, 3),
            "threshold": round(threshold * 100, 3),
            "diff_points": round(diff, 3),
            "status": status
        }

    def _seuil(cle: str, defaut: float) -> float:
        valeur = seuils.get(cle)
        return valeur / 100.0 if valeur is not None else defaut

    return {
        "cet1": _evaluate(cet1_ratio, _seuil("cet1", MIN_CET1_RATIO)),
        "tier1": _evaluate(t1_ratio, _seuil("tier1", MIN_TIER1_RATIO)),
        "solvency": _evaluate(solvency_ratio, _seuil("solvency", MIN_SOLVENCY_RATIO)),
        "leverage": _evaluate(leverage_ratio, _seuil("leverage", MIN_LEVERAGE_RATIO)),
    }
