"\"\"Module de calcul des ratios réglementaires stricts (Dispositif Prudentiel BCEAO)."""

from typing import Any

# ============================================================================
# CONSTANTES REGLEMENTAIRES UMOA / BALE III (Titre III & X)
# ============================================================================
MIN_CET1_RATIO = 0.05       # 5%
MIN_TIER1_RATIO = 0.06      # 6%
MIN_SOLVENCY_RATIO = 0.09   # 9%
MIN_LEVERAGE_RATIO = 0.03   # 3%

# Coussin de conservation (Titre III, section IV, Paragraphe 92)
CONSERVATION_BUFFER = 0.025 # 2.5%


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


def calculate_risque_operationnel(pb_data: dict[str, float]) -> dict[str, float]:
    """
    Calcule le RWA Opérationnel selon l'Approche Indicateur de Base (AIB).
    Titre V, Section II. 2.1, Paragraphe 301.
    """
    produits_bruts = [
        pb_data.get("produit_brut_annee_1", 0.0),
        pb_data.get("produit_brut_annee_2", 0.0),
        pb_data.get("produit_brut_annee_3", 0.0),
    ]
    
    pb_positifs = [pb for pb in produits_bruts if pb > 0]
    
    if not pb_positifs:
        exigence = 0.0
    else:
        alpha = 0.15
        moyenne_pb = sum(pb_positifs) / len(pb_positifs)
        exigence = moyenne_pb * alpha
        
    rwa_op = exigence * 12.5
    
    return {
        "exigence_fonds_propres": round(exigence, 2),
        "rwa_operationnel": round(rwa_op, 2),
    }


def calculate_risque_marche(marche_data: dict[str, float]) -> dict[str, float]:
    """
    Calcule le RWA Marché (Titre VI).
    """
    position_nette = marche_data.get("position_nette_change", 0.0)
    
    exigence = abs(position_nette) * 0.09
    
    rwa_marche = exigence * 12.5
    
    return {
        "exigence_fonds_propres": round(exigence, 2),
        "rwa_marche": round(rwa_marche, 2),
    }


def evaluate_ratios(rwa_total: float, fonds_propres: dict[str, float], total_expositions: float) -> dict[str, Any]:
    """
    Calcule et évalue les ratios de solvabilité et de levier par rapport aux normes UMOA.
    """
    cet1 = fonds_propres["cet1"]
    t1 = fonds_propres["t1"]
    total_capital = fonds_propres["total_capital"]
    
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
            "value": round(ratio * 100, 2),
            "threshold": round(threshold * 100, 2),
            "diff_points": round(diff, 2),
            "status": status
        }

    return {
        "cet1": _evaluate(cet1_ratio, MIN_CET1_RATIO),
        "tier1": _evaluate(t1_ratio, MIN_TIER1_RATIO),
        "solvency": _evaluate(solvency_ratio, MIN_SOLVENCY_RATIO),
        "leverage": _evaluate(leverage_ratio, MIN_LEVERAGE_RATIO),
    }
