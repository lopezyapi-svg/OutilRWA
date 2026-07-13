"""Endpoints REST du module Value at Risk (VaR).

Toutes les valeurs monétaires des réponses JSON sont exprimées en
milliards de FCFA (Md FCFA), nombres bruts avec point décimal ; le
formatage français est fait uniquement côté client.
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, HTTPException, Query, status

from app.var_marche import portefeuille_data, var_historique, var_montecarlo, var_parametrique
from app.var_marche.portefeuille_data import DonneesAbsentesError, ErreurDonneesVar

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/var", tags=["Value at Risk"])

_MILLIARD_FCFA = 1e9

_TYPES_PORTEFEUILLE = ("obligations", "actions")
_NIVEAUX_CONFIANCE = (0.95, 0.975, 0.99)
_HORIZONS_JOURS = (1, 3, 10, 21)
_FENETRES_JOURS = (250, 500, 1000)
_NB_SIMULATIONS = (1_000, 10_000, 50_000)

# Écart relatif entre méthodes au-delà duquel un avertissement de
# calibrage est journalisé (vérification de cohérence de la Partie 6).
_SEUIL_ALERTE_CALIBRAGE = 0.30


def _erreur_422(message: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        detail={"code": "VAR_PARAMETRE_INVALIDE", "message": message},
    )


def _valider_parametres(
    type_portefeuille: str,
    niveau_confiance: float,
    horizon_jours: int,
    fenetre_jours: int,
) -> None:
    if type_portefeuille not in _TYPES_PORTEFEUILLE:
        raise _erreur_422(
            f"Type de portefeuille invalide : '{type_portefeuille}'. "
            "Valeurs acceptées : obligations, actions."
        )
    if round(niveau_confiance, 4) not in _NIVEAUX_CONFIANCE:
        raise _erreur_422(
            f"Niveau de confiance invalide : {niveau_confiance}. "
            "Valeurs acceptées : 0.95, 0.975, 0.99."
        )
    if horizon_jours not in _HORIZONS_JOURS:
        raise _erreur_422(
            f"Horizon invalide : {horizon_jours}. "
            "Valeurs acceptées : 1, 3, 10, 21 jours."
        )
    if fenetre_jours not in _FENETRES_JOURS:
        raise _erreur_422(
            f"Fenêtre historique invalide : {fenetre_jours}. "
            "Valeurs acceptées : 250, 500, 1000 jours."
        )


def _serie_ou_422(
    type_portefeuille: str, fenetre_jours: int, horizon_jours: int
) -> portefeuille_data.SeriePnl:
    try:
        return portefeuille_data.get_serie_pnl(
            type_portefeuille, fenetre_jours, horizon_jours
        )
    except DonneesAbsentesError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "VAR_DONNEES_ABSENTES", "message": str(exc)},
        ) from exc
    except ErreurDonneesVar as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "VAR_DONNEES_INVALIDES", "message": str(exc)},
        ) from exc


def _en_milliards(serie_pnl: portefeuille_data.SeriePnl) -> dict[str, Any]:
    return {
        "valeur_portefeuille": serie_pnl.valeur_portefeuille / _MILLIARD_FCFA,
        "pertes": serie_pnl.pertes / _MILLIARD_FCFA,
        "pertes_quotidiennes": serie_pnl.pertes_quotidiennes / _MILLIARD_FCFA,
    }


def _reponse_commune(
    methode: str,
    parametres: dict[str, Any],
    serie_pnl: portefeuille_data.SeriePnl,
    resultat: dict[str, Any],
) -> dict[str, Any]:
    return {
        "methode": methode,
        "parametres": parametres,
        "source_donnees": serie_pnl.source_donnees,
        "valeur_portefeuille": serie_pnl.valeur_portefeuille / _MILLIARD_FCFA,
        "unite": "Md FCFA",
        "avertissements": serie_pnl.avertissements,
        **resultat,
    }


def _verifier_coherence_methodes(
    pertes_md, niveau_confiance: float, contexte: str
) -> None:
    """Journalise un avertissement si VaR historique et paramétrique divergent."""

    var_hist = var_historique.calculer(pertes_md, niveau_confiance)["var"]
    var_param = var_parametrique.calculer(pertes_md, niveau_confiance)["var"]
    reference = max(abs(var_hist), abs(var_param))
    if reference <= 0:
        return
    ecart = abs(var_hist - var_param) / reference
    if ecart > _SEUIL_ALERTE_CALIBRAGE:
        logger.warning(
            "Avertissement de calibrage (%s) : écart de %.0f %% entre la VaR "
            "historique (%.2f Md) et la VaR paramétrique (%.2f Md).",
            contexte,
            ecart * 100,
            var_hist,
            var_param,
        )


@router.get("/historique")
def var_historique_endpoint(
    type_portefeuille: str = Query("obligations"),
    niveau_confiance: float = Query(0.99),
    horizon_jours: int = Query(1),
    fenetre_jours: int = Query(500),
) -> dict[str, Any]:
    """VaR historique : quantile empirique de la série des pertes."""

    _valider_parametres(type_portefeuille, niveau_confiance, horizon_jours, fenetre_jours)
    serie_pnl = _serie_ou_422(type_portefeuille, fenetre_jours, horizon_jours)
    donnees = _en_milliards(serie_pnl)
    resultat = var_historique.calculer(donnees["pertes"], niveau_confiance)
    _verifier_coherence_methodes(
        donnees["pertes"], niveau_confiance, f"historique {type_portefeuille}"
    )
    return _reponse_commune(
        "historique",
        {
            "type_portefeuille": type_portefeuille,
            "niveau_confiance": niveau_confiance,
            "horizon_jours": horizon_jours,
            "fenetre_jours": fenetre_jours,
        },
        serie_pnl,
        resultat,
    )


@router.get("/parametrique")
def var_parametrique_endpoint(
    type_portefeuille: str = Query("obligations"),
    niveau_confiance: float = Query(0.99),
    horizon_jours: int = Query(1),
    fenetre_jours: int = Query(500),
) -> dict[str, Any]:
    """VaR paramétrique (variance-covariance, hypothèse normale)."""

    _valider_parametres(type_portefeuille, niveau_confiance, horizon_jours, fenetre_jours)
    serie_pnl = _serie_ou_422(type_portefeuille, fenetre_jours, horizon_jours)
    donnees = _en_milliards(serie_pnl)
    resultat = var_parametrique.calculer(donnees["pertes"], niveau_confiance)
    _verifier_coherence_methodes(
        donnees["pertes"], niveau_confiance, f"parametrique {type_portefeuille}"
    )
    return _reponse_commune(
        "parametrique",
        {
            "type_portefeuille": type_portefeuille,
            "niveau_confiance": niveau_confiance,
            "horizon_jours": horizon_jours,
            "fenetre_jours": fenetre_jours,
        },
        serie_pnl,
        resultat,
    )


@router.get("/montecarlo")
def var_montecarlo_endpoint(
    type_portefeuille: str = Query("obligations"),
    niveau_confiance: float = Query(0.99),
    horizon_jours: int = Query(1),
    fenetre_jours: int = Query(500),
    nb_simulations: int = Query(var_montecarlo.NB_SIMULATIONS_DEFAUT),
    graine: int = Query(var_montecarlo.GRAINE_DEFAUT),
) -> dict[str, Any]:
    """VaR Monte-Carlo : quantile empirique des pertes simulées."""

    _valider_parametres(type_portefeuille, niveau_confiance, horizon_jours, fenetre_jours)
    if nb_simulations not in _NB_SIMULATIONS:
        raise _erreur_422(
            f"Nombre de simulations invalide : {nb_simulations}. "
            "Valeurs acceptées : 1000, 10000, 50000."
        )
    serie_pnl = _serie_ou_422(type_portefeuille, fenetre_jours, horizon_jours)
    donnees = _en_milliards(serie_pnl)
    variations_taux = serie_pnl.variations_taux
    resultat = var_montecarlo.calculer(
        type_portefeuille=type_portefeuille,
        valeur_portefeuille=donnees["valeur_portefeuille"],
        pertes_quotidiennes=donnees["pertes_quotidiennes"],
        niveau_confiance=niveau_confiance,
        horizon_jours=horizon_jours,
        nb_simulations=nb_simulations,
        graine=graine,
        duration_modifiee=serie_pnl.duration_modifiee,
        variations_taux=variations_taux,
    )
    _verifier_coherence_methodes(
        donnees["pertes"], niveau_confiance, f"montecarlo {type_portefeuille}"
    )
    return _reponse_commune(
        "montecarlo",
        {
            "type_portefeuille": type_portefeuille,
            "niveau_confiance": niveau_confiance,
            "horizon_jours": horizon_jours,
            "fenetre_jours": fenetre_jours,
            "nb_simulations": nb_simulations,
            "graine": graine,
        },
        serie_pnl,
        resultat,
    )
