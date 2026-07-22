"""Espaces de travail : une base de donnees par compte.

Chaque compte importe ce qu'il veut sans jamais toucher aux donnees d'un
autre. L'isolation ne repose pas sur un filtre applique aux requetes SQL --
il suffirait d'en oublier une pour ouvrir une fuite -- mais sur des fichiers
distincts : deux comptes n'ouvrent jamais la meme base.
"""

from __future__ import annotations

import logging
from pathlib import Path
import re
import shutil
from threading import Lock

from app.core.runtime_paths import app_data_root, seed_data_path
from database.connection import DATABASE_PATH, database_manager, utiliser_espace

logger = logging.getLogger(__name__)

_ESPACES_DIR = app_data_root() / "espaces"

# Espaces deja prepares depuis le demarrage du processus : migrations jouees
# et regles de calcul a jour. Evite de refaire ce travail a chaque requete.
_espaces_prets: set[str] = set()
_verrou = Lock()


def nom_de_fichier(identifiant: str) -> str:
    """Transforme un identifiant de compte en nom de fichier sur.

    Un identifiant contient ce que l'administrateur y a mis : sans
    normalisation, « ../../etc/passwd » designerait un fichier hors du
    dossier des espaces.
    """

    normalise = re.sub(r"[^a-zA-Z0-9_-]+", "_", identifiant.strip().lower())
    normalise = normalise.strip("_")
    return normalise or "compte"


def chemin_espace(identifiant: str) -> Path:
    return _ESPACES_DIR / f"{nom_de_fichier(identifiant)}.db"


def _source_de_depart() -> Path:
    """Base servant de point de depart a un nouvel espace.

    Le jeu de demonstration livre avec l'application, de preference a la base
    commune : celle-ci porte les comptes et leurs empreintes de mots de passe,
    qui n'ont rien a faire dans l'espace d'un utilisateur.
    """

    graine = seed_data_path("rwa_data.db")
    return graine if graine.exists() else DATABASE_PATH


def preparer_espace(identifiant: str) -> Path:
    """Retourne l'espace du compte, en le creant au besoin.

    Un nouvel espace part du jeu de demonstration : un espace vide afficherait
    une application sans le moindre chiffre, illisible au premier coup d'oeil.
    """

    chemin = chemin_espace(identifiant)
    cle = chemin.name

    with _verrou:
        if cle in _espaces_prets and chemin.exists():
            return chemin

        _ESPACES_DIR.mkdir(parents=True, exist_ok=True)
        if not chemin.exists():
            source = _source_de_depart()
            if source.exists():
                shutil.copy2(source, chemin)
                logger.info(
                    "Espace de travail cree pour « %s » a partir du jeu de "
                    "demonstration.",
                    identifiant,
                )

        # Schema et migrations joues sur CET espace : une base copiee d'une
        # version anterieure doit rattraper son retard avant d'etre servie.
        jeton = utiliser_espace(chemin)
        try:
            database_manager.initialize()
            _rejouer_regles_si_besoin(identifiant)
        finally:
            from database.connection import restaurer_espace

            restaurer_espace(jeton)

        _espaces_prets.add(cle)
        return chemin


def _rejouer_regles_si_besoin(identifiant: str) -> None:
    """Aligne l'espace sur la version courante des regles de calcul."""

    try:
        from database.services.exposure_recalculation_service import (
            recalculate_all_exposures,
        )

        resultat = recalculate_all_exposures()
        if resultat.get("status") == "completed":
            logger.info(
                "Espace « %s » : %s expositions recalculees sur la version %s.",
                identifiant,
                resultat.get("recalculated_count"),
                resultat.get("version"),
            )
    except Exception:
        # Un espace qui ne se recalcule pas reste consultable avec ses valeurs
        # precedentes : mieux vaut une donnee datee qu'une session refusee.
        logger.exception(
            "Recalcul reglementaire impossible pour l'espace « %s ».",
            identifiant,
        )
