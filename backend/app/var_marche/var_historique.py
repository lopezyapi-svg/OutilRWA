"""Moteur de calcul de la VaR historique.

Entrée : série des pertes (convention perte positive, gain négatif),
déjà mise à l'échelle de l'horizon par la couche de données.
"""

from __future__ import annotations

import numpy as np


def construire_histogramme(pertes: np.ndarray, nombre_classes: int = 40) -> list[dict]:
    """Histogramme en classes de largeur égale entre min et max."""

    effectifs, bornes = np.histogram(pertes, bins=nombre_classes)
    return [
        {
            "borne_inf": float(bornes[indice]),
            "borne_sup": float(bornes[indice + 1]),
            "effectif": int(effectifs[indice]),
        }
        for indice in range(len(effectifs))
    ]


def calculer(pertes: np.ndarray, niveau_confiance: float) -> dict:
    """VaR historique par quantile empirique (interpolation linéaire)."""

    pertes = np.asarray(pertes, dtype=float)
    nombre_observations = len(pertes)
    if nombre_observations == 0:
        # Garde explicite : sans elle, np.quantile lève une IndexError
        # obscure. Les routes filtrent déjà ce cas (422), ceci protège
        # les appels directs au moteur.
        raise ValueError(
            "La VaR historique exige une série de pertes non vide."
        )

    var = float(np.quantile(pertes, niveau_confiance))
    pertes_extremes = pertes[pertes >= var]
    expected_shortfall = float(pertes_extremes.mean()) if len(pertes_extremes) else var
    pire_perte = float(pertes.max())
    p95 = float(np.quantile(pertes, 0.95))
    p975 = float(np.quantile(pertes, 0.975))
    p99 = float(np.quantile(pertes, 0.99))
    depassements = int((pertes > var).sum())
    taux_depassement_pct = depassements / nombre_observations * 100.0

    return {
        "var": var,
        "expected_shortfall": expected_shortfall,
        "pire_perte": pire_perte,
        "p95": p95,
        "p975": p975,
        "p99": p99,
        "taux_depassement_pct": taux_depassement_pct,
        "nombre_observations": nombre_observations,
        "histogramme": construire_histogramme(pertes),
    }
