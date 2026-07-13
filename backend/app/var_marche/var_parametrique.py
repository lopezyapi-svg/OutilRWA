"""Moteur de calcul de la VaR paramétrique (variance-covariance).

Hypothèse : les P&L suivent une loi normale. Entrée : série des pertes
(convention perte positive), déjà mise à l'échelle de l'horizon par la
couche de données ; mu et sigma sont donc estimés directement sur cette
série, sans nouvelle multiplication par racine(horizon).
"""

from __future__ import annotations

import math

import numpy as np

from app.var_marche.var_historique import construire_histogramme

# Quantiles de la loi normale standard imposés par la spécification.
Z_ALPHA = {0.95: 1.6449, 0.975: 1.9600, 0.99: 2.3263}

_NOMBRE_POINTS_COURBE = 100
_NOMBRE_CLASSES = 40


def densite_normale(x: float) -> float:
    """Densité de la loi normale standard."""

    return math.exp(-0.5 * x * x) / math.sqrt(2.0 * math.pi)


def var_depuis_moments(mu: float, sigma: float, z_alpha: float) -> float:
    """VaR = -(mu - z_alpha x sigma), mu en convention gain positif."""

    return -(mu - z_alpha * sigma)


def es_depuis_moments(mu: float, sigma: float, z_alpha: float, alpha: float) -> float:
    """ES = sigma x phi(z_alpha) / (1 - alpha) - mu, mu en convention gain."""

    return sigma * densite_normale(z_alpha) / (1.0 - alpha) - mu


def calculer(pertes: np.ndarray, niveau_confiance: float) -> dict:
    pertes = np.asarray(pertes, dtype=float)
    nombre_observations = len(pertes)
    z_alpha = Z_ALPHA[round(niveau_confiance, 4)]

    # mu est rapporté en convention gain positif (P&L comptable) ; la série
    # reçue est en convention perte positive, d'où le changement de signe.
    mu_pertes = float(pertes.mean())
    sigma = float(pertes.std(ddof=1))
    mu = -mu_pertes

    var = var_depuis_moments(mu, sigma, z_alpha)
    expected_shortfall = es_depuis_moments(mu, sigma, z_alpha, niveau_confiance)
    p95 = var_depuis_moments(mu, sigma, Z_ALPHA[0.95])
    p99 = var_depuis_moments(mu, sigma, Z_ALPHA[0.99])
    pire_perte = float(pertes.max())

    depassements = int((pertes > var).sum())
    taux_depassement_pct = depassements / nombre_observations * 100.0

    # Indicateurs de validité de l'hypothèse normale (moments empiriques).
    ecarts = pertes - mu_pertes
    sigma_population = float(pertes.std(ddof=0))
    if sigma_population > 0:
        skewness = float((ecarts**3).mean() / sigma_population**3)
        kurtosis_exces = float((ecarts**4).mean() / sigma_population**4 - 3.0)
    else:
        skewness = 0.0
        kurtosis_exces = 0.0
    hypothese_normale_douteuse = kurtosis_exces > 1.0 or abs(skewness) > 0.5

    histogramme = construire_histogramme(pertes, _NOMBRE_CLASSES)

    # Courbe de densité normale théorique sur l'axe des pertes, échantillonnée
    # entre mu - 4 sigma et mu + 4 sigma. L'ordonnée est exprimée en effectif
    # théorique par classe (densité x nombre d'observations x largeur de
    # classe) pour une superposition directe sur l'histogramme, sans aucun
    # calcul côté client.
    largeur_classe = (
        (float(pertes.max()) - float(pertes.min())) / _NOMBRE_CLASSES
        if len(pertes) > 1
        else 1.0
    )
    courbe_normale = []
    if sigma > 0:
        abscisses = np.linspace(
            mu_pertes - 4.0 * sigma, mu_pertes + 4.0 * sigma, _NOMBRE_POINTS_COURBE
        )
        for x in abscisses:
            z = (x - mu_pertes) / sigma
            densite = densite_normale(float(z)) / sigma
            courbe_normale.append(
                {
                    "x": float(x),
                    "y": densite * nombre_observations * largeur_classe,
                }
            )

    return {
        "var": var,
        "expected_shortfall": expected_shortfall,
        "pire_perte": pire_perte,
        "p95": p95,
        "p99": p99,
        "taux_depassement_pct": taux_depassement_pct,
        "nombre_observations": nombre_observations,
        "mu": mu,
        "sigma": sigma,
        "z_alpha": z_alpha,
        "skewness": skewness,
        "kurtosis_exces": kurtosis_exces,
        "hypothese_normale_douteuse": hypothese_normale_douteuse,
        "courbe_normale": courbe_normale,
        "histogramme": histogramme,
    }
