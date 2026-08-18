"""Export / import Excel des Fonds Propres FODEP (45 postes DISPRU).

Première version : structure lisible et auditable (code, libellé, groupe,
valeur), pas encore calée cellule à cellule sur le classeur officiel BCEAO
(`documents sources/FODEP 31052026.xlsx`). Fidélité totale au gabarit officiel
= travail de suivi, à valider poste par poste contre le document source avant
tout envoi réel à la BCEAO.
"""

from __future__ import annotations

from io import BytesIO

from app.fodep.dispru import FONDS_PROPRES_CODES


def build_fonds_propres_export(periode: str | None, postes: dict[str, float]) -> bytes:
    from openpyxl import Workbook
    from openpyxl.styles import Alignment, Border, Font, PatternFill, Side

    wb = Workbook()
    ws = wb.active
    ws.title = "Fonds propres FODEP"

    BLUE_DARK = "1D4ED8"
    BLUE_LIGHT = "DBEAFE"
    BORDER_CLR = "CBD5E1"
    thin = Side(style="thin", color=BORDER_CLR)
    border = Border(left=thin, right=thin, top=thin, bottom=thin)

    ws["A1"] = f"FODEP — Fonds propres réglementaires — période {periode or '(brouillon)'}"
    ws["A1"].font = Font(bold=True, size=13, color=BLUE_DARK)
    ws.merge_cells("A1:E1")

    headers = ["Code", "EP", "Groupe", "Libellé", "Valeur (MFCFA)"]
    for col, header in enumerate(headers, start=1):
        cell = ws.cell(row=3, column=col, value=header)
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = PatternFill("solid", fgColor=BLUE_DARK)
        cell.border = border
        cell.alignment = Alignment(horizontal="center")

    row_index = 4
    for c in FONDS_PROPRES_CODES:
        valeur = float(postes.get(c.code.lower(), 0.0) or 0.0)
        ws.cell(row=row_index, column=1, value=c.code).border = border
        ws.cell(row=row_index, column=2, value=c.ep).border = border
        ws.cell(row=row_index, column=3, value=c.groupe).border = border
        ws.cell(row=row_index, column=4, value=c.label).border = border
        valeur_cell = ws.cell(row=row_index, column=5, value=valeur)
        valeur_cell.border = border
        valeur_cell.number_format = "#,##0.00"
        if row_index % 2 == 0:
            for col in range(1, 6):
                ws.cell(row=row_index, column=col).fill = PatternFill(
                    "solid", fgColor=BLUE_LIGHT
                )
        row_index += 1

    ws.column_dimensions["A"].width = 10
    ws.column_dimensions["B"].width = 8
    ws.column_dimensions["C"].width = 12
    ws.column_dimensions["D"].width = 70
    ws.column_dimensions["E"].width = 18

    buffer = BytesIO()
    wb.save(buffer)
    return buffer.getvalue()


def parse_fonds_propres_import(contenu: bytes) -> dict[str, float]:
    """Lit un classeur exporté par ``build_fonds_propres_export`` (colonnes
    Code / EP / Groupe / Libellé / Valeur) et retourne les postes détectés.

    Ne lit PAS (encore) le gabarit officiel BCEAO brut : seulement le format
    que ce module produit lui-même, ou tout classeur qui reprend la même
    structure de colonnes. Un import du classeur officiel BCEAO tel quel
    nécessite un mappage cellule à cellule distinct, à construire contre le
    document source.
    """

    from openpyxl import load_workbook

    codes_connus = {c.code.upper() for c in FONDS_PROPRES_CODES}
    wb = load_workbook(BytesIO(contenu), data_only=True)
    ws = wb.active

    postes: dict[str, float] = {}
    for row in ws.iter_rows(min_row=4, max_col=5, values_only=True):
        code, _ep, _groupe, _label, valeur = (row + (None,) * 5)[:5]
        if not code:
            continue
        code_upper = str(code).strip().upper()
        if code_upper not in codes_connus:
            continue
        try:
            postes[code_upper.lower()] = float(valeur or 0.0)
        except (TypeError, ValueError):
            continue

    return postes
