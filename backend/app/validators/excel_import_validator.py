"""Validation et description du format d'import Excel."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any
import unicodedata


class ExcelImportValidationError(ValueError):
    """Erreur métier retournée si le classeur ne respecte pas le format attendu."""

    def __init__(self, payload: dict[str, Any]) -> None:
        super().__init__(payload.get("message", "Format Excel d'import invalide."))
        self.payload = payload


@dataclass(frozen=True, slots=True)
class ExcelColumnSpec:
    name: str
    value_type: str
    description: str

    def to_dict(self) -> dict[str, str]:
        return {
            "name": self.name,
            "type": self.value_type,
            "description": self.description,
        }


@dataclass(frozen=True, slots=True)
class ExcelSheetSpec:
    name: str
    description: str
    role: str
    required: bool
    required_columns: tuple[ExcelColumnSpec, ...] = ()
    optional_columns: tuple[ExcelColumnSpec, ...] = ()
    required_markers: tuple[str, ...] = ()
    notes: tuple[str, ...] = ()
    header_row: int = 1

    @property
    def import_columns(self) -> tuple[str, ...]:
        return tuple(
            column.name for column in self.required_columns + self.optional_columns
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "description": self.description,
            "role": self.role,
            "required": self.required,
            "header_row": self.header_row,
            "required_columns": [column.to_dict() for column in self.required_columns],
            "optional_columns": [column.to_dict() for column in self.optional_columns],
            "required_markers": list(self.required_markers),
            "notes": list(self.notes),
        }


def _column(name: str, value_type: str, description: str) -> ExcelColumnSpec:
    return ExcelColumnSpec(name=name, value_type=value_type, description=description)


def _normalize_text(value: str) -> str:
    normalized = value.replace("’", "'").replace("`", "'").strip().lower()
    normalized = unicodedata.normalize("NFKD", normalized)
    normalized = "".join(
        character
        for character in normalized
        if not unicodedata.combining(character)
    )
    return " ".join(normalized.split())


IMPORT_SHEET_SPECS: tuple[ExcelSheetSpec, ...] = (
    ExcelSheetSpec(
        name="Template données",
        description="Feuille principale de saisie et de calcul des expositions au bilan.",
        role="Saisie",
        required=True,
        header_row=1,
        required_columns=(
            _column("Date d'analyse", "date", "Date d'observation de l'exposition"),
            _column("ID_Exposition", "texte", "Identifiant unique de l'exposition"),
            _column("Date d'octroi", "date", "Date d'octroi du concours"),
            _column("Date d'échéance", "date", "Date d'échéance contractuelle"),
            _column(
                "Maturité de l'exposition",
                "texte",
                "Maturité théorique de l'exposition",
            ),
            _column(
                "Maturité résiduelle",
                "texte",
                "Maturité résiduelle observée",
            ),
            _column("Contrepartie", "texte", "Nom de la contrepartie"),
            _column(
                "Notation_externe_contrepartie",
                "texte",
                "Notation externe de la contrepartie",
            ),
            _column("Pays_contrepartie", "texte", "Pays de résidence"),
            _column(
                "Notation_externe_pays",
                "texte",
                "Notation externe du pays",
            ),
            _column(
                "Pondération_pays",
                "nombre",
                "Pondération liée au risque pays",
            ),
            _column(
                "Catégorie d'exposition",
                "texte",
                "Catégorie prudentielle BCEAO",
            ),
            _column(
                "Pondération (RW)",
                "nombre",
                "Pondération prudentielle finale",
            ),
            _column(
                "PRÊT TOTAL",
                "nombre",
                "Montant total du prêt ou de l'exposition",
            ),
            _column(
                "Montant_exposition_but_au_bilan",
                "nombre",
                "Montant de l'exposition porté au bilan",
            ),
            _column(
                "Montant d'exposition au HB",
                "nombre",
                "Montant de l'exposition portée hors bilan",
            ),
            _column("Devise", "devise", "Devise de l'exposition"),
            _column("CRM_existe", "texte", "Oui / Non"),
            _column("Type_CRM", "texte", "financee / non_financee / aucune"),
            _column("EAD_bilan", "nombre", "EAD bilan"),
            _column("EAD_HB", "nombre", "EAD hors bilan avant CCF final"),
            _column("EAD_HB_ccf", "nombre", "EAD hors bilan après application du CCF"),
            _column("EAD_Total", "nombre", "EAD total"),
            _column("RWA_EB", "nombre", "RWA sur exposition au bilan"),
            _column("RWA_HB", "nombre", "RWA sur exposition hors bilan"),
            _column("RWA_crédit", "nombre", "RWA crédit"),
            _column(
                "Capital_min_reg",
                "nombre",
                "Exigence minimale de capital",
            ),
        ),
        notes=(
            "Cette feuille pilote la saisie principale et les résultats prudentiels.",
        ),
    ),
    ExcelSheetSpec(
        name="LISTE",
        description="Feuille de listes métier et de valeurs à conserver telle quelle.",
        role="Support",
        required=True,
        required_markers=("CATEGOREIS", "Type de CRM", "Financée", "Non financée"),
        notes=("Ne pas supprimer ni renommer cette feuille.",),
    ),
    ExcelSheetSpec(
        name="Traitement_HB",
        description="Feuille de saisie des engagements hors bilan.",
        role="Saisie",
        required=True,
        header_row=1,
        required_columns=(
            _column("ID_Exposition", "texte", "Identifiant de l'exposition"),
            _column(
                "Catégorie Hors bilan",
                "texte",
                "Niveau de risque hors bilan",
            ),
            _column(
                "Facteur_conversion (CCF)",
                "nombre",
                "Facteur de conversion appliqué",
            ),
            _column(
                "EAD_HB_ccf",
                "nombre",
                "EAD hors bilan après application du CCF",
            ),
        ),
    ),
    ExcelSheetSpec(
        name="CRM_non_financee",
        description="Détails des garanties et protections non financées.",
        role="Saisie",
        required=True,
        header_row=1,
        required_columns=(
            _column("ID_Exposition", "texte", "Identifiant de l'exposition"),
            _column("Nom du garant", "texte", "Nom du garant"),
            _column("Note_garant", "texte", "Notation du garant"),
            _column("Pays_garant", "texte", "Pays du garant"),
            _column(
                "Note_pays_garant",
                "texte",
                "Notation externe du pays du garant",
            ),
            _column(
                "Pondération_pays_garant",
                "nombre",
                "Pondération liée au pays du garant",
            ),
            _column(
                "Catégorie du garant",
                "texte",
                "Catégorie prudentielle du garant",
            ),
            _column(
                "Pondération du garant",
                "nombre",
                "Pondération du garant",
            ),
            _column("% Exp_couverte", "nombre", "Part couverte de l'exposition"),
            _column(
                "%Exp_Nn_couverte",
                "nombre",
                "Part non couverte de l'exposition",
            ),
            _column("Part couverte", "nombre", "Montant couvert"),
            _column("Part non couverte", "nombre", "Montant non couvert"),
            _column("RWA_non_fin", "nombre", "RWA lié à la protection"),
        ),
    ),
    ExcelSheetSpec(
        name="CRM_financée",
        description="Détails des sûretés financées associées aux expositions.",
        role="Saisie",
        required=True,
        header_row=1,
        required_columns=(
            _column("ID_Exposition", "texte", "Identifiant de l'exposition"),
            _column(
                "Valeur_Collatéral",
                "nombre",
                "Valeur du collatéral",
            ),
            _column("Type_emetteur", "texte", "Type d'émetteur"),
            _column("Notation", "texte", "Notation du collatéral"),
            _column("Bloc", "texte", "Bloc de traitement CRM"),
            _column("Maturite", "texte", "Tranche de maturité"),
            _column("HE", "nombre", "Haircut émetteur"),
            _column("HC", "nombre", "Haircut collatéral"),
            _column("Hfx", "nombre", "Haircut de change"),
            _column("Eva_EB", "nombre", "Valeur ajustée de l'exposition au bilan"),
            _column("Eva_HB", "nombre", "Valeur ajustée de l'exposition hors bilan"),
            _column("Cva", "nombre", "Ajustement de volatilité"),
        ),
    ),
    ExcelSheetSpec(
        name="(a) souverains",
        description="Référence métier pour les souverains et banques centrales.",
        role="Référentiel",
        required=True,
        required_markers=("Notation", "Pondération"),
    ),
    ExcelSheetSpec(
        name="(b) organismes pub. hors Adm c",
        description="Référence de pondération des organismes publics hors administration centrale.",
        role="Référentiel",
        required=True,
        required_markers=("Notation", "Pondération"),
    ),
    ExcelSheetSpec(
        name="(c) Expositions sur les BMD",
        description="Référence métier sur les banques multilatérales de développement.",
        role="Référentiel",
        required=True,
        required_markers=("BMD", "Pondérations"),
    ),
    ExcelSheetSpec(
        name="(d) institutions financières",
        description="Référence métier sur les institutions financières.",
        role="Référentiel",
        required=True,
        required_markers=("institutions financières", "Pondération ="),
    ),
    ExcelSheetSpec(
        name="(e) entreprises",
        description="Référence de pondération des entreprises.",
        role="Référentiel",
        required=True,
        required_markers=("Notation", "Pondération"),
    ),
    ExcelSheetSpec(
        name="(f) clientèle de détail",
        description="Critères de classement de la clientèle de détail.",
        role="Référentiel",
        required=True,
        required_markers=("Critère", "Condition"),
    ),
    ExcelSheetSpec(
        name="(g) prêts garantis par l'immo R",
        description="Règles métier sur l'immobilier résidentiel.",
        role="Référentiel",
        required=True,
        required_markers=("Immobilier Résidentiel", "Pondération ="),
    ),
    ExcelSheetSpec(
        name="(h) prêts garantis par l'immo C",
        description="Règles métier sur l'immobilier commercial.",
        role="Référentiel",
        required=True,
        required_markers=("Immobilier Commercial", "Condition de garantie"),
    ),
    ExcelSheetSpec(
        name="(i) créances en souffrance",
        description="Barème prudentiel des créances en souffrance.",
        role="Référentiel",
        required=True,
        required_markers=("Elements", "Ponderations"),
    ),
    ExcelSheetSpec(
        name="(j) créances à risque élevé",
        description="Traitement prudentiel des créances à risque élevé.",
        role="Référentiel",
        required=True,
        required_markers=("Ponderation", "1.5"),
    ),
    ExcelSheetSpec(
        name="(k) autres actifs",
        description="Barème des autres actifs.",
        role="Référentiel",
        required=True,
        required_markers=("Elements", "Pondérations"),
    ),
    ExcelSheetSpec(
        name="(l) Hors bilan",
        description="Référentiel des catégories et FCEC de hors bilan.",
        role="Référentiel",
        required=True,
        required_markers=("Catégorie", "FCEC (%)"),
    ),
    ExcelSheetSpec(
        name="Mapping des pondérations",
        description="Mapping des notations externes reconnues dans l'UMOA.",
        role="Paramétrage",
        required=True,
        required_markers=("DBRS", "Moody", "S&P", "Fitch"),
    ),
    ExcelSheetSpec(
        name="Ref_Ponderation",
        description="Table de paramètres utilisée par l'application pour les RW et les CCF.",
        role="Paramétrage",
        required=True,
        required_markers=(
            "RW_souverain",
            "RW_org_pub",
            "RW_entreprise",
            "RW_inst_<=3m",
            "RW_inst_>3m",
            "Type_HB",
            "CCF_HB",
        ),
        notes=("Cette feuille alimente directement les calculs de l'outil.",),
    ),
)


def build_excel_import_spec() -> dict[str, Any]:
    required_names = [spec.name for spec in IMPORT_SHEET_SPECS if spec.required]
    return {
        "accepted_extensions": [".xlsx"],
        "sheets": [spec.to_dict() for spec in IMPORT_SHEET_SPECS],
        "required_sheet_names": required_names,
        "optional_sheet_names": [],
        "notes": [
            "Le modèle téléchargé reprend le classeur complet utilisé par l'outil.",
            "Toutes les feuilles du modèle sont requises et doivent être conservées.",
            "Les noms de feuilles, l'ordre des colonnes de saisie et les libellés doivent être respectés exactement.",
            "Les feuilles de référence et de paramétrage ne doivent pas être supprimées ni renommées.",
            "Le fichier Excel reste uniquement une source d'entrée et n'est jamais réécrit pendant l'import.",
        ],
    }


def read_sheet_headers(sheet, row_index: int = 1) -> list[str]:
    header_row = next(
        sheet.iter_rows(min_row=row_index, max_row=row_index, values_only=True),
        (),
    )
    return [str(value).strip() if value is not None else "" for value in header_row]


def _collect_sheet_markers(
    sheet,
    *,
    max_rows: int = 40,
    max_columns: int = 30,
) -> list[str]:
    markers: list[str] = []
    for row in sheet.iter_rows(
        min_row=1,
        max_row=max_rows,
        min_col=1,
        max_col=max_columns,
        values_only=True,
    ):
        for value in row:
            if value is None:
                continue
            text = str(value).strip()
            if text:
                markers.append(_normalize_text(text))
    return markers


def _has_marker(expected_marker: str, available_markers: list[str]) -> bool:
    normalized_expected = _normalize_text(expected_marker)
    return any(
        normalized_expected in marker or marker in normalized_expected
        for marker in available_markers
    )


def inspect_workbook_structure(workbook) -> dict[str, Any]:
    workbook_sheets = set(workbook.sheetnames)
    sheet_reports: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []

    for spec in IMPORT_SHEET_SPECS:
        exists = spec.name in workbook_sheets
        headers = (
            read_sheet_headers(workbook[spec.name], row_index=spec.header_row)
            if exists and spec.required_columns
            else []
        )
        missing_required_columns = [
            column.name for column in spec.required_columns if column.name not in headers
        ]
        available_markers = (
            _collect_sheet_markers(workbook[spec.name])
            if exists and spec.required_markers
            else []
        )
        missing_required_markers = [
            marker
            for marker in spec.required_markers
            if not _has_marker(marker, available_markers)
        ]

        if spec.required and not exists:
            errors.append(
                {
                    "sheet": spec.name,
                    "row": None,
                    "column": None,
                    "message": "Feuille requise manquante.",
                }
            )
        elif exists and missing_required_columns:
            for column_name in missing_required_columns:
                errors.append(
                    {
                        "sheet": spec.name,
                        "row": spec.header_row,
                        "column": column_name,
                        "message": "Colonne requise manquante.",
                    }
                )
        elif exists and missing_required_markers:
            for marker_name in missing_required_markers:
                errors.append(
                    {
                        "sheet": spec.name,
                        "row": None,
                        "column": None,
                        "message": f"Repère requis manquant: {marker_name}.",
                    }
                )

        sheet_reports.append(
            {
                "name": spec.name,
                "description": spec.description,
                "role": spec.role,
                "required": spec.required,
                "header_row": spec.header_row,
                "available_columns": headers,
                "required_columns": [column.to_dict() for column in spec.required_columns],
                "optional_columns": [],
                "required_markers": list(spec.required_markers),
                "missing_required_columns": missing_required_columns,
                "missing_optional_columns": [],
                "missing_required_markers": missing_required_markers,
                "notes": list(spec.notes),
                "exists": exists,
            }
        )

    return {
        "valid": not errors,
        "sheet_count": len(workbook.sheetnames),
        "detected_sheets": list(workbook.sheetnames),
        "sheets": sheet_reports,
        "errors": errors,
    }


def ensure_valid_workbook(workbook) -> dict[str, Any]:
    report = inspect_workbook_structure(workbook)
    if not report["valid"]:
        payload = {
            "message": "Le fichier Excel ne respecte pas le format d'import attendu.",
            **report,
        }
        raise ExcelImportValidationError(payload)
    return report
