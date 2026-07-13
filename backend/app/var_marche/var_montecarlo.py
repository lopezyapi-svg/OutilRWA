"""Moteur de calcul de la VaR Monte-Carlo.

Convention de signe : perte positive, gain négatif.

Calibrage :
- Obligations : si la duration modifiée du portefeuille et l'historique des
  variations de taux sont disponibles (valorisation par courbe), les chocs de
  taux sont tirés dans une loi normale calibrée sur ces variations et
  perte simulée = Duration modifiée x V x dTaux simulé (une hausse de taux
  produit une perte positive). Sinon, repli sur le calibrage des P&L
  historiques.
- Actions : rendements simulés en loi de Student calibrée sur l'historique
  (moyenne, écart-type, degrés de liberté estimés par la méthode des
  moments), repli en loi normale si les queues ne sont pas épaisses ;
  perte simulée = -V x rendement simulé x racine(horizon).
"""

from __future__ import annotations

import numpy as np

from app.var_marche.var_historique import construire_histogramme

GRAINE_DEFAUT = 42
NB_SIMULATIONS_DEFAUT = 10_000

_NB_REECHANTILLONNAGES_BOOTSTRAP = 200
_DDL_MINIMUM = 3.0
_DDL_MAXIMUM = 100.0


def _degres_liberte_student(rendements: np.ndarray) -> float:
    """Degrés de liberté estimés par la méthode des moments sur le kurtosis.

    Pour une loi de Student, kurtosis en excès = 6 / (ddl - 4), donc
    ddl = 4 + 6 / kurtosis. Au-delà de _DDL_MAXIMUM la loi est
    indistinguable d'une normale.
    """

    sigma = rendements.std(ddof=0)
    if sigma <= 0:
        return _DDL_MAXIMUM
    ecarts = rendements - rendements.mean()
    kurtosis_exces = float((ecarts**4).mean() / sigma**4 - 3.0)
    if kurtosis_exces <= 0.1:
        return _DDL_MAXIMUM
    return float(np.clip(4.0 + 6.0 / kurtosis_exces, _DDL_MINIMUM + 0.1, _DDL_MAXIMUM))


def _simuler_pertes_obligations(
    generateur: np.random.Generator,
    nb_simulations: int,
    valeur_portefeuille: float,
    duration_modifiee: float,
    variations_taux: np.ndarray,
    horizon_jours: int,
) -> np.ndarray:
    moyenne = float(variations_taux.mean())
    ecart_type = float(variations_taux.std(ddof=1))
    chocs_taux = generateur.normal(moyenne, ecart_type, nb_simulations)
    # Perte positive quand le taux monte : perte = DM x V x dTaux.
    pertes_quotidiennes = duration_modifiee * valeur_portefeuille * chocs_taux
    return pertes_quotidiennes * np.sqrt(horizon_jours)


def _simuler_pertes_par_calibrage_pnl(
    generateur: np.random.Generator,
    nb_simulations: int,
    pertes_quotidiennes: np.ndarray,
    horizon_jours: int,
) -> np.ndarray:
    moyenne = float(pertes_quotidiennes.mean())
    ecart_type = float(pertes_quotidiennes.std(ddof=1))
    tirages = generateur.normal(moyenne, ecart_type, nb_simulations)
    return tirages * np.sqrt(horizon_jours)


def _simuler_pertes_actions(
    generateur: np.random.Generator,
    nb_simulations: int,
    valeur_portefeuille: float,
    pertes_quotidiennes: np.ndarray,
    horizon_jours: int,
) -> tuple[np.ndarray, float]:
    # Rendements quotidiens en convention gain : r = -perte / V.
    rendements = -pertes_quotidiennes / valeur_portefeuille
    moyenne = float(rendements.mean())
    ecart_type = float(rendements.std(ddof=1))
    ddl = _degres_liberte_student(rendements)

    if ddl >= _DDL_MAXIMUM:
        rendements_simules = generateur.normal(moyenne, ecart_type, nb_simulations)
    else:
        tirages = generateur.standard_t(ddl, nb_simulations)
        facteur_normalisation = np.sqrt(ddl / (ddl - 2.0))
        rendements_simules = moyenne + ecart_type * tirages / facteur_normalisation

    pertes = -valeur_portefeuille * rendements_simules * np.sqrt(horizon_jours)
    return pertes, ddl


def _intervalle_confiance_var(
    generateur: np.random.Generator,
    pertes_simulees: np.ndarray,
    niveau_confiance: float,
) -> tuple[float, float]:
    """IC à 95 % de la VaR par bootstrap léger (200 rééchantillonnages)."""

    nombre = len(pertes_simulees)
    quantiles = np.empty(_NB_REECHANTILLONNAGES_BOOTSTRAP)
    for indice in range(_NB_REECHANTILLONNAGES_BOOTSTRAP):
        echantillon = pertes_simulees[
            generateur.integers(0, nombre, nombre)
        ]
        quantiles[indice] = np.quantile(echantillon, niveau_confiance)
    return float(np.quantile(quantiles, 0.025)), float(np.quantile(quantiles, 0.975))


def calculer(
    *,
    type_portefeuille: str,
    valeur_portefeuille: float,
    pertes_quotidiennes: np.ndarray,
    niveau_confiance: float,
    horizon_jours: int,
    nb_simulations: int = NB_SIMULATIONS_DEFAUT,
    graine: int = GRAINE_DEFAUT,
    duration_modifiee: float | None = None,
    variations_taux: np.ndarray | None = None,
) -> dict:
    pertes_quotidiennes = np.asarray(pertes_quotidiennes, dtype=float)
    generateur = np.random.default_rng(graine)
    modele = "normale calibrée sur les P&L"
    degres_liberte = None

    if type_portefeuille == "obligations":
        if (
            duration_modifiee is not None
            and duration_modifiee > 0
            and variations_taux is not None
            and len(variations_taux) >= 2
        ):
            pertes_simulees = _simuler_pertes_obligations(
                generateur,
                nb_simulations,
                valeur_portefeuille,
                duration_modifiee,
                np.asarray(variations_taux, dtype=float),
                horizon_jours,
            )
            modele = "chocs de taux normaux x duration modifiée"
        else:
            pertes_simulees = _simuler_pertes_par_calibrage_pnl(
                generateur, nb_simulations, pertes_quotidiennes, horizon_jours
            )
    else:
        pertes_simulees, degres_liberte = _simuler_pertes_actions(
            generateur,
            nb_simulations,
            valeur_portefeuille,
            pertes_quotidiennes,
            horizon_jours,
        )
        modele = (
            "rendements Student"
            if degres_liberte < _DDL_MAXIMUM
            else "rendements normaux"
        )

    var = float(np.quantile(pertes_simulees, niveau_confiance))
    pertes_extremes = pertes_simulees[pertes_simulees >= var]
    expected_shortfall = (
        float(pertes_extremes.mean()) if len(pertes_extremes) else var
    )
    pire_perte = float(pertes_simulees.max())
    p95 = float(np.quantile(pertes_simulees, 0.95))
    p99 = float(np.quantile(pertes_simulees, 0.99))
    depassements = int((pertes_simulees > var).sum())
    taux_depassement_pct = depassements / nb_simulations * 100.0

    borne_basse, borne_haute = _intervalle_confiance_var(
        generateur, pertes_simulees, niveau_confiance
    )

    return {
        "var": var,
        "expected_shortfall": expected_shortfall,
        "pire_perte": pire_perte,
        "p95": p95,
        "p99": p99,
        "taux_depassement_pct": taux_depassement_pct,
        "nombre_observations": nb_simulations,
        "nb_simulations": nb_simulations,
        "graine": graine,
        "modele_simulation": modele,
        "degres_liberte": degres_liberte,
        "ic_var_95": {"borne_basse": borne_basse, "borne_haute": borne_haute},
        "histogramme": construire_histogramme(pertes_simulees),
    }
