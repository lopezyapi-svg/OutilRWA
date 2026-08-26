"""Export / import Excel des déclarations FODEP basé strictement sur la matrice
officielle BCEAO (`Matrice_FODEP_Officielle.xlsx`).
"""

from __future__ import annotations

import io
from pathlib import Path
from typing import Any

from app.fodep.dispru import FONDS_PROPRES_CODES

_CHEMINS_MATRICE_OFFICIELLE = (
    Path(__file__).parent / "templates" / "Matrice_FODEP_Officielle.xlsx",
    Path(r"C:\RisqueManagement\backend\app\fodep\templates\Matrice_FODEP_Officielle.xlsx"),
    Path(r"C:\RisqueManagement\Matrice_FODEP_Officielle.xlsx"),
)


def get_matrice_officielle_path() -> Path | None:
    """Retourne le chemin absolu vers le classeur officiel FODEP BCEAO."""
    for candidat in _CHEMINS_MATRICE_OFFICIELLE:
        if candidat.exists():
            return candidat
    return None


def get_matrice_officielle_template_bytes() -> bytes:
    """Retourne les octets bruts du modèle officiel FODEP BCEAO, sans modification."""
    chemin = get_matrice_officielle_path()
    if chemin is None:
        raise FileNotFoundError(
            "La matrice FODEP officielle (Matrice_FODEP_Officielle.xlsx) est introuvable."
        )
    return chemin.read_bytes()


def _ecrire(ws: Any, ligne: int, colonne: int, valeur: Any) -> None:
    """Ecrit une valeur en tenant compte des cellules fusionnees.

    openpyxl refuse toute ecriture sur une cellule recouverte par une fusion :
    seule la cellule haut-gauche porte la valeur. Viser directement une case
    fusionnee (ainsi la denomination de l'etablissement, dans la fusion C5:K5
    de l'onglet ADPE) faisait echouer l'export entier.
    """

    for fusion in ws.merged_cells.ranges:
        if fusion.min_row <= ligne <= fusion.max_row and fusion.min_col <= colonne <= fusion.max_col:
            ligne, colonne = fusion.min_row, fusion.min_col
            break
    ws.cell(ligne, colonne, valeur)


# Categorie prudentielle (code rwa_credit) -> ligne EP09 (exposition brute) et
# onglet/ligne de synthese ou ecrire le total de la categorie (exposition
# apres ARC, RWA). Le detail par tranche de ponderation reglementaire n'est PAS
# rempli : rwa_credit calcule une ponderation continue par exposition (effet
# des suretes partielles, plafonnements pays...) alors que ces onglets
# attendent des tranches discretes fixes (0%, 20%, 35%, 50%, 75%, 100%, 150%).
# Forcer une ponderation continue dans la tranche la plus proche romprait la
# formule propre de la ligne (RWA = montant x ponderation figee de la ligne) et
# fausserait silencieusement le detail. Le total par categorie, lui, est fiable
# et vaut mieux qu'une case vide.
_VENTILATION_CREDIT: dict[str, tuple[int, str, int]] = {
    "a": (12, "EP12", 43),  # Souverains
    "b": (13, "EP13", 43),  # Organismes publics hors administration centrale
    "c": (14, "EP14", 43),  # Banques multilaterales de developpement
    "d": (15, "EP15", 43),  # Institutions financieres
    "e": (18, "EP16", 47),  # Entreprises (ligne "Autres entreprises", pas de suivi PME distinct cote app)
    "f": (21, "EP17", 38),  # Clientele de detail (ligne "Autres clientele de detail")
    "g": (22, "EP18", 35),  # Prets garantis par l'immobilier residentiel
    "h": (25, "EP19", 38),  # Prets garantis par l'immobilier commercial (ligne "Autres")
    "k": (26, "EP20", 27),  # Autres actifs
}

# Lignes de detail (ponderation par tranche) a vider dans EP12-EP19 : ce sont
# les memes categories que ci-dessus, colonnes C (avant ARC) a H (apres ARC).
# On ne les remplit pas (cf. note ci-dessus) mais on retire les montants d'un
# autre etablissement laisses par le modele, pour ne pas les laisser
# contredire silencieusement le total desormais correct de la categorie.
_LIGNES_DETAIL_CREDIT: dict[str, list[int]] = {
    "EP12": [12, 13, 14, 15, 16, 20, 21, 22, 23, 24, 28, 29, 30, 31, 32, 36, 37, 38, 39, 40],
    "EP13": [12, 13, 14, 15, 16, 20, 21, 22, 23, 24, 28, 29, 30, 31, 32, 36, 37, 38, 39, 40],
    "EP14": [12, 13, 14, 15, 16, 20, 21, 22, 23, 24, 28, 29, 30, 31, 32, 36, 37, 38, 39, 40],
    "EP15": [12, 13, 14, 15, 16, 20, 21, 22, 23, 24, 28, 29, 30, 31, 32, 36, 37, 38, 39, 40],
    "EP16": [12, 13, 14, 15, 16, 17, 21, 22, 23, 24, 25, 26, 30, 31, 32, 33, 34, 35, 39, 40, 41, 42, 43, 44],
    "EP17": [12, 13, 14, 15, 16, 17, 21, 22, 23, 24, 25, 26, 30, 31, 32, 33, 34, 35],
    "EP18": [12, 13, 14, 15, 16, 20, 21, 22, 23, 24, 28, 29, 30, 31, 32],
    "EP19": [12, 13, 14, 15, 16, 17, 21, 22, 23, 24, 25, 26, 30, 31, 32, 33, 34, 35],
}
_COLONNES_DETAIL_CREDIT = range(3, 9)  # C a H

# EP20 (autres actifs) : structure differente (poste par poste, pas de tranche
# de ponderation partagee) -> lignes de detail a vider, colonne C uniquement.
_LIGNES_DETAIL_EP20 = list(range(10, 27))

# EP09 : ligne -> categorie, pour les 4 categories qui se subdivisent en
# PME/Autres dans le formulaire officiel sans que rwa_credit ne fasse cette
# distinction (l'app ne suit pas separement les PME) : le total va sur la
# ligne "Autres", la ligne PME reste a 0 (deja le cas dans le modele).


def _ecrire_ventilation_credit(wb: Any, analyse: Any) -> None:
    """Renseigne EP09 (expositions brutes par categorie) et les totaux par
    categorie d'EP12 a EP20, a partir de l'analyse RWA credit reelle (module
    rwa_credit, la meme que celle affichee a l'ecran dans l'application).
    """

    agents = {agent.code: agent for agent in getattr(analyse, "agents", [])}
    ws09 = wb["EP09"] if "EP09" in wb.sheetnames else None

    for code, (ligne_ep09, onglet_total, ligne_total) in _VENTILATION_CREDIT.items():
        agent = agents.get(code)
        if agent is None:
            continue

        if ws09 is not None:
            _ecrire(ws09, ligne_ep09, 4, agent.gross_exposure)

        if onglet_total not in wb.sheetnames:
            continue
        ws = wb[onglet_total]

        if onglet_total == "EP20":
            _ecrire(ws, ligne_total, 3, agent.ead)
            _ecrire(ws, ligne_total, 5, agent.rwa)
            for r in _LIGNES_DETAIL_EP20:
                _ecrire(ws, r, 3, 0)
            continue

        _ecrire(ws, ligne_total, 9, agent.ead)
        _ecrire(ws, ligne_total, 10, agent.rwa)
        for r in _LIGNES_DETAIL_CREDIT.get(onglet_total, ()):
            for c in _COLONNES_DETAIL_CREDIT:
                _ecrire(ws, r, c, 0)


# Onglets ou le modele officiel contient des donnees de portefeuille d'un
# autre etablissement (grands risques, participations) qu'aucun module de
# l'application ne calcule aujourd'hui. Plutot que de les laisser dans l'export
# - un vrai risque de confidentialite et de conformite, la Commission Bancaire
# recevrait le portefeuille d'un tiers - on les vide : colonnes de donnees
# remises a blanc, code DISPRU de la ligne (colonne A) conserve car il fait
# partie de la structure officielle du formulaire.
_ONGLETS_A_VIDER: dict[str, tuple[int, int, int]] = {
    # onglet: (premiere_ligne, derniere_ligne, derniere_colonne)
    "EP10": (12, 45, 9),
    "EP29": (16, 91, 30),
    "EP30": (16, 116, 30),
    "EP31": (11, 31, 30),
    "EP32": (18, 68, 15),
    "EP34": (13, 127, 6),
}


def _vider_donnees_etrangeres(wb: Any) -> None:
    """Efface les montants et noms de contreparties laisses par le modele
    officiel dans les onglets que l'application ne renseigne pas encore.
    """

    for nom, (premiere, derniere, derniere_colonne) in _ONGLETS_A_VIDER.items():
        if nom not in wb.sheetnames:
            continue
        ws = wb[nom]
        for r in range(premiere, derniere + 1):
            for c in range(2, derniere_colonne + 1):
                cellule = ws.cell(r, c)
                if isinstance(cellule.value, str) and cellule.value.startswith("="):
                    continue  # une formule reste correcte une fois ses entrees a 0
                if cellule.value not in (None, ""):
                    # ws.cell(r, c, None) n'efface rien : pour openpyxl, une
                    # valeur None passee a cell() signifie « ne rien changer »,
                    # pas « vider ». Seule l'affectation directe .value = None
                    # efface reellement la cellule.
                    cible = ws.cell(r, c)
                    for fusion in ws.merged_cells.ranges:
                        if fusion.min_row <= r <= fusion.max_row and fusion.min_col <= c <= fusion.max_col:
                            cible = ws.cell(fusion.min_row, fusion.min_col)
                            break
                    cible.value = None


def build_fonds_propres_export(
    periode: str | None,
    postes: dict[str, float],
    *,
    etablissement: Any = None,
    participations: list[Any] | None = None,
    apr: Any = None,
    totaux: dict[str, float] | None = None,
    analyse_credit: Any = None,
) -> bytes:
    """Génère un export basé strictement sur la matrice officielle BCEAO,
    en renseignant les postes dans les états réglementaires (EP03, EP21, EP33, EP35, etc.)
    tout en préservant intacte la structure et les formules officielles.
    """
    import openpyxl

    chemin = get_matrice_officielle_path()
    if chemin is None:
        raise FileNotFoundError("Matrice FODEP officielle introuvable.")

    wb = openpyxl.load_workbook(chemin)
    codes_connus = {c.code.upper() for c in FONDS_PROPRES_CODES}

    # 0. Renseigner l'en-tête et l'établissement dans ADPE
    if "ADPE" in wb.sheetnames:
        ws = wb["ADPE"]
        if etablissement:
            nom = getattr(etablissement, "denomination", None) or (
                etablissement.get("denomination") if isinstance(etablissement, dict) else ""
            )
            code_b = getattr(etablissement, "code_bceao", None) or (
                etablissement.get("code_bceao") if isinstance(etablissement, dict) else ""
            )
            if nom:
                _ecrire(ws, 5, 4, str(nom).strip())
            if code_b:
                _ecrire(ws, 6, 4, str(code_b).strip())
        if periode:
            try:
                parts = periode.split("-")
                if len(parts) == 3:
                    _ecrire(ws, 9, 4, f"{parts[2]}/{parts[1]}/{parts[0]}")
            except Exception:
                _ecrire(ws, 9, 4, str(periode))

    # 1. Renseigner EP03 (Fonds Propres Base Individuelle)
    if "EP03" in wb.sheetnames:
        ws = wb["EP03"]
        for r in range(1, ws.max_row + 1):
            c1 = ws.cell(r, 1).value
            if c1:
                code = str(c1).strip().upper()
                if code in codes_connus and code.lower() in postes:
                    _ecrire(ws, r, 3, postes[code.lower()])

    # 2. Renseigner EP21 (Produit brut)
    if "EP21" in wb.sheetnames:
        ws = wb["EP21"]
        for r in range(1, ws.max_row + 1):
            c1 = ws.cell(r, 1).value
            if c1:
                code = str(c1).strip().upper()
                if code in codes_connus and code.lower() in postes:
                    _ecrire(ws, r, 4, postes[code.lower()])

    # 3. Renseigner EP33 (Ratio de levier)
    if "EP33" in wb.sheetnames:
        ws = wb["EP33"]
        for r in range(1, ws.max_row + 1):
            c1 = ws.cell(r, 1).value
            if c1:
                code = str(c1).strip().upper()
                if code in codes_connus and code.lower() in postes:
                    _ecrire(ws, r, 3, postes[code.lower()])

    # 4. Renseigner EP35 (Participations dans des entités commerciales)
    if "EP35" in wb.sheetnames and participations:
        ws = wb["EP35"]
        for idx, part in enumerate(participations):
            row_num = 12 + idx
            if row_num > 65:
                break
            denom = getattr(part, "denomination_emettrice", "") or (
                part.get("denomination_emettrice") if isinstance(part, dict) else ""
            )
            cap = getattr(part, "capital_emettrice", 0.0) or (
                part.get("capital_emettrice") if isinstance(part, dict) else 0.0
            )
            net = getattr(part, "montant_net", 0.0) or (
                part.get("montant_net") if isinstance(part, dict) else 0.0
            )
            if denom:
                _ecrire(ws, row_num, 2, denom)
            if cap > 0:
                _ecrire(ws, row_num, 4, cap)
            if net > 0:
                _ecrire(ws, row_num, 5, net)
                _ecrire(ws, row_num, 6, net)

    # 5. Renseigner EP36 (Immobilisations hors exploitation)
    if "EP36" in wb.sheetnames:
        ws = wb["EP36"]
        for r in range(1, ws.max_row + 1):
            c1 = ws.cell(r, 1).value
            if c1:
                code = str(c1).strip().upper()
                if code in codes_connus and code.lower() in postes:
                    _ecrire(ws, r, 3, postes[code.lower()])

    # 6. Renseigner EP37 (Immobilisations d'exploitation et participations)
    if "EP37" in wb.sheetnames:
        ws = wb["EP37"]
        for r in range(1, ws.max_row + 1):
            c1 = ws.cell(r, 1).value
            if c1:
                code = str(c1).strip().upper()
                if code in codes_connus and code.lower() in postes:
                    _ecrire(ws, r, 3, postes[code.lower()])

    # 7. Renseigner EP38 (Prêts dirigeants/actionnaires)
    if "EP38" in wb.sheetnames:
        ws = wb["EP38"]
        categories = ("A", "B", "C", "D", "E", "F", "G", "H")
        for idx, cat in enumerate(categories):
            col = 3 + idx
            k1 = f"pr001{cat.lower()}"
            if k1 in postes:
                _ecrire(ws, 11, col, postes[k1])
            k2 = f"pr002{cat.lower()}"
            if k2 in postes:
                _ecrire(ws, 12, col, postes[k2])

    # 8. Renseigner EP08 (Actifs pondérés des risques)
    if "EP08" in wb.sheetnames and apr:
        ws = wb["EP08"]
        rwa_credit = getattr(apr, "rwa_credit", 0.0) or (apr.get("rwa_credit") if isinstance(apr, dict) else 0.0)
        rwa_marche = getattr(apr, "rwa_marche", 0.0) or (apr.get("rwa_marche") if isinstance(apr, dict) else 0.0)
        rwa_op = getattr(apr, "rwa_operationnel", 0.0) or (apr.get("rwa_operationnel") if isinstance(apr, dict) else 0.0)
        _ecrire(ws, 19, 5, rwa_credit)
        _ecrire(ws, 26, 5, rwa_marche)
        _ecrire(ws, 32, 5, rwa_op)

    # 9. Renseigner EP02 (Solvabilité)
    if "EP02" in wb.sheetnames and totaux:
        ws = wb["EP02"]
        if "fpi22" in totaux:
            _ecrire(ws, 14, 6, totaux["fpi22"])
        if "fpi29" in totaux:
            _ecrire(ws, 15, 6, totaux["fpi29"])
        if "fpi41" in totaux:
            _ecrire(ws, 16, 6, totaux["fpi41"])

    # 10. Renseigner EP09 et les totaux EP12-EP20 (ventilation credit reelle)
    if analyse_credit is not None:
        _ecrire_ventilation_credit(wb, analyse_credit)

    # 11. Retirer les donnees de portefeuille d'un autre etablissement que le
    # modele officiel contient (grands risques, participations) : aucun module
    # de l'application ne les calcule encore, mieux vaut un tableau vide qu'un
    # portefeuille etranger dans une declaration reglementaire.
    _vider_donnees_etrangeres(wb)

    buffer = io.BytesIO()
    wb.save(buffer)
    return buffer.getvalue()


DISPRU_ALIASES: dict[str, str] = {
    "IM12": "im012",
    "ID09": "id009",
    "IM06": "im006",
    "IM10": "im010",
    "PR04": "pr004",
    "PA07": "pa149",
    "PA14": "pa156",
    "PA32": "pa173",
    "EP21_PB_N1": "ro001",
    "EP21_PB_N2": "ro001_n2",
    "EP21_PB_N3": "ro001_n3",
    "EP35_CHANGE_POSITION_NETTE": "rm067",
}


def parse_fonds_propres_import(contenu: bytes) -> dict[str, float]:
    """Lit un classeur FODEP et extrait les postes DISPRU détectés.

    Prend en charge :
    1. Le classeur officiel BCEAO multi-onglets (EP03/EP05, EP21, EP33, EP36, EP37, EP38...)
       tel que la matrice réglementaire officielle (`Matrice_FODEP_Officielle.xlsx`).
    2. Les classeurs de saisie multi-onglets (colonnes Catégorie / Code / Libellé / Valeur).
    3. Le format tabulaire simple ou export à 5 colonnes.
    """
    from openpyxl import load_workbook

    codes_connus: dict[str, str] = {c.code.upper(): c.code.lower() for c in FONDS_PROPRES_CODES}
    codes_connus.update(DISPRU_ALIASES)

    wb = load_workbook(io.BytesIO(contenu), data_only=True)
    postes: dict[str, float] = {}

    sheet_names_upper = {name.strip().upper(): name for name in wb.sheetnames}

    # ── Cas 1 : Classeur officiel BCEAO multi-onglets ────────────────────────
    # 1. EP03 (Fonds Propres Base Individuelle) ou EP05 (Base Consolidée)
    ep03_name = sheet_names_upper.get("EP03") or sheet_names_upper.get("EP05")
    if ep03_name:
        ws = wb[ep03_name]
        for r in range(1, ws.max_row + 1):
            c1 = ws.cell(r, 1).value
            if c1:
                code = str(c1).strip().upper()
                if code in codes_connus:
                    val = ws.cell(r, 3).value
                    if val is not None and str(val).strip() != "":
                        try:
                            postes[codes_connus[code]] = float(val)
                        except (ValueError, TypeError):
                            pass

    # 2. EP21 (Produit brut risque opérationnel - RO001 à RO008)
    if "EP21" in sheet_names_upper:
        ws = wb[sheet_names_upper["EP21"]]
        for r in range(1, ws.max_row + 1):
            c1 = ws.cell(r, 1).value
            if c1:
                code = str(c1).strip().upper()
                if code in codes_connus:
                    for col in (4, 3, 5):
                        val = ws.cell(r, col).value
                        if val is not None and str(val).strip() != "":
                            try:
                                postes[codes_connus[code]] = float(val)
                                break
                            except (ValueError, TypeError):
                                pass

    # 3. EP33 (Ratio de levier - RL001 à RL012)
    if "EP33" in sheet_names_upper:
        ws = wb[sheet_names_upper["EP33"]]
        for r in range(1, ws.max_row + 1):
            c1 = ws.cell(r, 1).value
            if c1:
                code = str(c1).strip().upper()
                if code in codes_connus:
                    val = ws.cell(r, 3).value
                    if val is not None and str(val).strip() != "":
                        try:
                            postes[codes_connus[code]] = float(val)
                        except (ValueError, TypeError):
                            pass

    # 4. EP36 (Immobilisations hors exploitation - IM001, IM002, IM003, PA084)
    if "EP36" in sheet_names_upper:
        ws = wb[sheet_names_upper["EP36"]]
        for r in range(1, ws.max_row + 1):
            c1 = ws.cell(r, 1).value
            if c1:
                code = str(c1).strip().upper()
                if code in codes_connus and codes_connus[code] not in postes:
                    for col in (4, 3, 5):
                        val = ws.cell(r, col).value
                        if val is not None and str(val).strip() != "":
                            try:
                                postes[codes_connus[code]] = float(val)
                                break
                            except (ValueError, TypeError):
                                pass

    # 5. EP37 (Immobilisations d'exploitation et participations - IM007, PA106)
    if "EP37" in sheet_names_upper:
        ws = wb[sheet_names_upper["EP37"]]
        for r in range(1, ws.max_row + 1):
            c1 = ws.cell(r, 1).value
            if c1:
                code = str(c1).strip().upper()
                if code in codes_connus and codes_connus[code] not in postes:
                    for col in (4, 3, 5):
                        val = ws.cell(r, col).value
                        if val is not None and str(val).strip() != "":
                            try:
                                postes[codes_connus[code]] = float(val)
                                break
                            except (ValueError, TypeError):
                                pass

    # 6. EP38 (Prêts aux actionnaires, dirigeants et personnel - PR001A-H, PR002A-H)
    if "EP38" in sheet_names_upper:
        ws = wb[sheet_names_upper["EP38"]]
        categories = ("A", "B", "C", "D", "E", "F", "G", "H")
        for idx, cat in enumerate(categories):
            col = 3 + idx
            val_pr1 = ws.cell(11, col).value
            if val_pr1 is not None and str(val_pr1).strip() != "":
                try:
                    postes[f"pr001{cat.lower()}"] = float(val_pr1)
                except (ValueError, TypeError):
                    pass
            val_pr2 = ws.cell(12, col).value
            if val_pr2 is not None and str(val_pr2).strip() != "":
                try:
                    postes[f"pr002{cat.lower()}"] = float(val_pr2)
                except (ValueError, TypeError):
                    pass

    # ── Cas 2 : Balayage universel (toutes feuilles, colonnes de codes 1 ou 2)
    for sname in wb.sheetnames:
        ws = wb[sname]
        for r in range(1, ws.max_row + 1):
            for c_idx in (1, 2):
                c_val = ws.cell(r, c_idx).value
                if c_val:
                    code_raw = str(c_val).strip().upper()
                    if code_raw in codes_connus:
                        tgt = codes_connus[code_raw]
                        if tgt not in postes:
                            for col in range(c_idx + 1, min(ws.max_column + 1, 10)):
                                v = ws.cell(r, col).value
                                if isinstance(v, (int, float)) and v != "":
                                    postes[tgt] = float(v)
                                    break

    return postes
