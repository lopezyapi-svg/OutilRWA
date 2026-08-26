"""L'export PDF FODEP doit reproduire le classeur officiel, pas un autre document.

Deux bugs corriges par ce fichier :
1. build_fonds_propres_export plantait (AttributeError: 'MergedCell' object
   attribute 'value' is read-only) des qu'une denomination d'etablissement
   etait renseignee, car ADPE!D5 est dans la fusion C5:K5 et openpyxl refuse
   d'ecrire ailleurs que sur l'ancre d'une fusion.
2. openpyxl ne recalcule jamais les formules : apres load_workbook + save, les
   588 formules du classeur (dont les totaux EP03 et les ratios EP01/EP02)
   perdent leur valeur en cache et valent None. Sans un recalcul explicite
   (formula_engine.MoteurFormules), le PDF affiche des totaux vides.
"""

from __future__ import annotations

from pathlib import Path

import openpyxl
import pytest

from app.fodep import excel
from app.fodep.formula_engine import MoteurFormules
from app.fodep.xlsx_pdf import convertir_classeur_en_pdf


class _Etablissement:
    denomination = "BANQUE ATLANTIQUE CI"
    code_bceao = "CI0042"


def test_moteur_formules_reproduit_les_valeurs_calculees_par_excel():
    """Non-regression du risque n1 identifie a la conception : sans moteur de
    recalcul, un simple load_workbook + save d'openpyxl remet a None les 588
    formules du classeur (totaux EP03, ratios EP01/EP02 compris). Le moteur
    doit reproduire exactement les valeurs qu'Excel avait mises en cache dans
    le modele officiel, avant toute modification."""

    chemin = excel.get_matrice_officielle_path()
    assert chemin is not None, "Matrice FODEP officielle introuvable pour le test."

    wb_formules = openpyxl.load_workbook(chemin)
    wb_valeurs = openpyxl.load_workbook(chemin, data_only=True)

    moteur = MoteurFormules(wb_formules)
    ecarts: list[tuple[str, str, object, object]] = []

    for nom in wb_formules.sheetnames:
        for ligne in wb_formules[nom].iter_rows():
            for cellule in ligne:
                if not (isinstance(cellule.value, str) and cellule.value.startswith("=")):
                    continue
                attendu = wb_valeurs[nom][cellule.coordinate].value
                obtenu = moteur.valeur(nom, cellule.coordinate)
                if attendu is None:
                    continue
                if isinstance(attendu, (int, float)) and isinstance(obtenu, (int, float)):
                    if abs(float(attendu) - float(obtenu)) > max(1e-6, abs(float(attendu)) * 1e-9):
                        ecarts.append((nom, cellule.coordinate, attendu, obtenu))
                elif str(attendu) != str(obtenu):
                    ecarts.append((nom, cellule.coordinate, attendu, obtenu))

    assert not ecarts, f"Le moteur diverge d'Excel sur {len(ecarts)} cellule(s) : {ecarts[:10]}"
    assert not moteur.formules_ignorees, (
        f"Formules hors grammaire supportee : {moteur.formules_ignorees[:5]}"
    )


def test_export_avec_denomination_etablissement_ne_plante_pas():
    """ADPE!D5 (denomination) est dans la fusion C5:K5 : y ecrire directement
    levait AttributeError avant l'introduction de excel._ecrire."""

    contenu = excel.build_fonds_propres_export(
        "2026-06-30",
        {"fpi01": 1_000_000.0},
        etablissement=_Etablissement(),
        participations=[],
    )

    wb = openpyxl.load_workbook(__import__("io").BytesIO(contenu))
    assert wb["ADPE"]["C5"].value == "BANQUE ATLANTIQUE CI"


def test_convertir_classeur_en_pdf_produit_un_pdf_valide():
    """Le PDF genere doit etre un document PDF exploitable, pas un fichier vide
    ou tronque : c'est la garantie minimale avant tout controle de contenu."""

    contenu_xlsx = excel.build_fonds_propres_export(
        "2026-06-30",
        {"fpi01": 15_000_000_000.0, "fpi02": 2_500_000_000.0},
        etablissement=_Etablissement(),
        participations=[],
    )

    pdf = convertir_classeur_en_pdf(contenu_xlsx)

    assert pdf[:5] == b"%PDF-"
    assert len(pdf) > 10_000, "PDF anormalement petit pour un classeur de 44 onglets."


def test_conversion_pdf_echoue_proprement_sur_un_classeur_vide():
    """Un classeur sans le moindre onglet imprimable doit lever une erreur
    explicite plutot que produire un PDF vide silencieux."""

    from io import BytesIO

    wb = openpyxl.Workbook()  # une seule feuille visible, entierement vide

    tampon = BytesIO()
    wb.save(tampon)

    with pytest.raises(ValueError):
        convertir_classeur_en_pdf(tampon.getvalue())
