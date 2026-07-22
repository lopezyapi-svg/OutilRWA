"""Chaque compte travaille dans sa propre base, sans voir celle des autres.

L'isolation ne repose pas sur un filtre applique aux requetes SQL : il
suffirait d'en oublier une pour ouvrir une fuite. Elle repose sur des fichiers
distincts. Ces tests verifient qu'une ecriture faite sous un compte reste
invisible sous un autre.
"""

from __future__ import annotations

import pytest

from app.auth.espaces import chemin_espace, nom_de_fichier, preparer_espace
from database.connection import (
    DATABASE_PATH,
    base_commune,
    database_manager,
    espace_courant,
    restaurer_espace,
    utiliser_espace,
)


def _compter_expositions() -> int:
    with database_manager.read_connection() as connexion:
        return int(
            connexion.execute("SELECT COUNT(*) FROM expositions").fetchone()[0]
        )


def _supprimer_une_exposition() -> str:
    with database_manager.transaction() as connexion:
        identifiant = str(
            connexion.execute("SELECT id FROM expositions LIMIT 1").fetchone()[0]
        )
        connexion.execute("DELETE FROM expositions WHERE id = ?", (identifiant,))
    return identifiant


@pytest.mark.parametrize(
    ("saisi", "attendu"),
    [
        ("Pascal", "pascal"),
        ("marie.kone@banque.ci", "marie_kone_banque_ci"),
        # Un identifiant hostile ne doit pas designer un fichier hors du
        # dossier des espaces.
        ("../../etc/passwd", "etc_passwd"),
        ("   ", "compte"),
    ],
)
def test_un_identifiant_ne_peut_pas_sortir_du_dossier(saisi, attendu):
    assert nom_de_fichier(saisi) == attendu
    assert chemin_espace(saisi).parent == chemin_espace("autre").parent


def test_deux_comptes_ne_partagent_pas_leurs_donnees(tmp_path, monkeypatch):
    espace_a = preparer_espace("compte_essai_a")
    espace_b = preparer_espace("compte_essai_b")
    assert espace_a != espace_b

    jeton = utiliser_espace(espace_a)
    try:
        total_a = _compter_expositions()
        supprimee = _supprimer_une_exposition()
        apres_a = _compter_expositions()
    finally:
        restaurer_espace(jeton)

    assert apres_a == total_a - 1

    jeton = utiliser_espace(espace_b)
    try:
        # La suppression faite chez A ne doit pas se voir chez B.
        with database_manager.read_connection() as connexion:
            presente = connexion.execute(
                "SELECT COUNT(*) FROM expositions WHERE id = ?", (supprimee,)
            ).fetchone()[0]
    finally:
        restaurer_espace(jeton)

    assert presente == 1, (
        "Une exposition supprimee dans un espace a disparu d'un autre : les "
        "comptes partagent la meme base."
    )


def test_un_nouvel_espace_part_du_jeu_de_demonstration():
    espace = preparer_espace("compte_essai_c")
    jeton = utiliser_espace(espace)
    try:
        total = _compter_expositions()
    finally:
        restaurer_espace(jeton)

    assert total > 0, (
        "Un espace neuf sans aucune exposition afficherait une application "
        "vide, illisible au premier coup d'oeil."
    )


def test_les_comptes_restent_dans_la_base_commune():
    """Sans cette regle, se connecter deviendrait impossible.

    Les comptes n'appartiennent a aucun espace : ils doivent rester lisibles
    quel que soit l'espace actif au moment de la requete.
    """

    espace = preparer_espace("compte_essai_d")
    jeton = utiliser_espace(espace)
    try:
        assert espace_courant() == espace
        with base_commune():
            assert espace_courant() == DATABASE_PATH
        # La bascule est bien rendue a la sortie du bloc.
        assert espace_courant() == espace
    finally:
        restaurer_espace(jeton)


def test_hors_requete_la_base_commune_s_applique():
    # Application de bureau et taches de fond : aucun espace n'est pose.
    assert espace_courant() == DATABASE_PATH
