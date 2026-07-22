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


def _compter_contreparties() -> int:
    with database_manager.read_connection() as connexion:
        return int(
            connexion.execute("SELECT COUNT(*) FROM contreparties").fetchone()[0]
        )


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


def test_ce_qu_un_compte_saisit_reste_chez_lui():
    """Le coeur de l'isolation : une ecriture ne franchit pas les espaces."""

    espace_a = preparer_espace("compte_essai_a")
    espace_b = preparer_espace("compte_essai_b")
    assert espace_a != espace_b

    jeton = utiliser_espace(espace_a)
    try:
        with database_manager.transaction() as connexion:
            connexion.execute(
                """
                INSERT INTO contreparties(
                    id, nom, pays, notation_pays, categorie_standard,
                    categorie_prudentielle, notation, cree_le, modifie_le
                )
                VALUES('CP_ESSAI', 'Contrepartie A', 'Togo', 'BB',
                       'Entreprises', 'Entreprises', 'BBB',
                       '2026-01-01', '2026-01-01')
                """
            )
        chez_a = _compter_contreparties()
    finally:
        restaurer_espace(jeton)

    assert chez_a == 1

    jeton = utiliser_espace(espace_b)
    try:
        chez_b = _compter_contreparties()
    finally:
        restaurer_espace(jeton)

    assert chez_b == 0, (
        "Une contrepartie saisie dans un espace apparait dans un autre : les "
        "comptes partagent la meme base."
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


def test_un_espace_neuf_est_entierement_vide():
    """Un nouvel arrivant ne doit trouver aucune donnee, d'aucun module.

    Un espace pre-rempli du jeu de demonstration laisse croire a un
    portefeuille reel : credit, marche et operationnel doivent partir de zero.
    """

    import sqlite3

    from app.auth.espaces import _TABLES_REFERENCE

    espace = preparer_espace("compte_neuf_essai")
    connexion = sqlite3.connect(espace)
    try:
        tables = [
            str(ligne[0])
            for ligne in connexion.execute(
                "SELECT name FROM sqlite_master "
                "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
            )
        ]
        peuplees = {
            table: connexion.execute(
                f'SELECT COUNT(*) FROM "{table}"'
            ).fetchone()[0]
            for table in tables
            if table not in _TABLES_REFERENCE
        }
    finally:
        connexion.close()

    restantes = {table: n for table, n in peuplees.items() if n}
    assert not restantes, (
        f"Ces tables portent encore des donnees dans un espace neuf : "
        f"{restantes}. Une table de donnees ajoutee depuis doit etre videe, "
        "ou declaree comme table de reference si elle porte le dispositif."
    )


def test_le_dispositif_prudentiel_survit_a_la_purge():
    """Vider les grilles rendrait tout calcul impossible."""

    import sqlite3

    espace = preparer_espace("compte_neuf_essai")
    connexion = sqlite3.connect(espace)
    try:
        for table in ("risk_weight_references", "ccf_references", "rating_references"):
            n = connexion.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0]
            assert n > 0, (
                f"La table de reference « {table} » est vide : aucune "
                "ponderation ne pourrait plus etre determinee."
            )
    finally:
        connexion.close()
