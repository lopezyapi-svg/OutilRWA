"""Services d'export Excel depuis SQLite."""

from __future__ import annotations

from datetime import date, datetime
from io import BytesIO
from pathlib import Path
from typing import Any

from openpyxl import load_workbook

from app.core.excel_repository import EXCEL_SOURCE_PATH
from database.repositories.exposure_repository import exposure_repository
from database.repositories.off_balance_repository import off_balance_repository


EXPORTS_DIR = Path(__file__).resolve().parents[2] / "data" / "exports"


class ExportService:
    """Construit les exports Excel depuis la base SQLite."""

    _TEMPLATE_SHEET = "Template données"
    _CRM_FINANCED_SHEET = "CRM_financée"
    _CRM_NON_FINANCED_SHEET = "CRM_non_financee"
    _OFF_BALANCE_SHEET = "Traitement_HB"

    def export_excel_workbook_bytes(self) -> bytes:
        """Construit un classeur Excel complet basé sur le vrai modèle RWA."""

        if not EXCEL_SOURCE_PATH.exists():
            raise FileNotFoundError(
                f"Modèle Excel introuvable: {EXCEL_SOURCE_PATH}"
            )

        exposures = exposure_repository.list_exposures()
        off_balance_rows = off_balance_repository.list_commitments()
        workbook = load_workbook(EXCEL_SOURCE_PATH)
        try:
            self._fill_template_sheet(workbook[self._TEMPLATE_SHEET], exposures)
            self._fill_crm_financed_sheet(
                workbook[self._CRM_FINANCED_SHEET],
                exposures,
            )
            self._fill_crm_non_financed_sheet(
                workbook[self._CRM_NON_FINANCED_SHEET],
                exposures,
            )
            self._fill_off_balance_sheet(
                workbook[self._OFF_BALANCE_SHEET],
                off_balance_rows,
            )

            output = BytesIO()
            workbook.save(output)
            output.seek(0)
            return output.getvalue()
        finally:
            workbook.close()

    def export_excel_workbook(self) -> Path:
        """Sauvegarde un export Excel sur disque et retourne son chemin."""

        EXPORTS_DIR.mkdir(parents=True, exist_ok=True)
        export_path = (
            EXPORTS_DIR
            / f"expositions_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"
        )
        export_path.write_bytes(self.export_excel_workbook_bytes())
        return export_path

    def _clear_sheet_values(self, sheet, *, max_columns: int) -> None:
        """Efface les valeurs d'une feuille en conservant sa structure."""

        if sheet.max_row < 2:
            return
        final_column = max(sheet.max_column, max_columns)
        for row in sheet.iter_rows(
            min_row=2,
            max_row=sheet.max_row,
            min_col=1,
            max_col=final_column,
        ):
            for cell in row:
                cell.value = None

    def _write_row(self, sheet, row_index: int, values: list[Any]) -> None:
        for column_index, value in enumerate(values, start=1):
            sheet.cell(row=row_index, column=column_index, value=value)

    def _coerce_excel_date(self, value: Any) -> date | None:
        if value in (None, ""):
            return None
        if isinstance(value, datetime):
            return value.date()
        if isinstance(value, date):
            return value
        text = str(value).strip()
        if not text:
            return None
        for parser in (date.fromisoformat,):
            try:
                return parser(text.split("T")[0])
            except ValueError:
                continue
        return None

    def _coerce_float(self, value: Any, default: float = 0.0) -> float:
        if value in (None, ""):
            return default
        if isinstance(value, (int, float)):
            return float(value)
        text = str(value).strip().replace(" ", "").replace(",", ".")
        if not text:
            return default
        try:
            return float(text)
        except ValueError:
            return default

    def _coverage_ratio(self, exposure: dict[str, Any]) -> float:
        return min(
            max(self._coerce_float(exposure.get("crm_coverage_percent")), 0.0),
            1.0,
        )

    def _crm_type_label(self, exposure: dict[str, Any]) -> str:
        crm_mode = str(exposure.get("crm_mode") or "")
        if crm_mode == "CRM financee":
            return "CRM financee"
        if crm_mode == "CRM non financee":
            return "CRM non financee"
        return ""

    def _fill_template_sheet(
        self,
        sheet,
        exposures: list[dict[str, Any]],
    ) -> None:
        self._clear_sheet_values(sheet, max_columns=21)

        for row_index, exposure in enumerate(exposures, start=2):
            analysis_date = self._coerce_excel_date(exposure.get("analysis_date"))
            grant_date = self._coerce_excel_date(exposure.get("grant_date"))
            maturity_date = self._coerce_excel_date(exposure.get("maturity_date"))
            identifier = str(exposure["id"])
            crm_exists = bool(exposure.get("crm_exists"))
            self._write_row(
                sheet,
                row_index,
                [
                    analysis_date,
                    identifier,
                    grant_date,
                    maturity_date,
                    (
                        f'=IF(OR(C{row_index}="",D{row_index}="",D{row_index}<C{row_index}),'
                        f'0,DATEDIF(C{row_index},D{row_index},"m"))'
                    ),
                    (
                        f'=IF(OR(A{row_index}="",D{row_index}="",D{row_index}<A{row_index}),'
                        f'0,DATEDIF(A{row_index},D{row_index},"m"))'
                    ),
                    str(exposure.get("counterparty_name") or ""),
                    str(exposure.get("rating") or ""),
                    str(exposure.get("country") or ""),
                    str(exposure.get("country_rating") or "Non noté"),
                    (
                        f'=IFERROR(INDEX(Ref_Ponderation!$B$3:$B$20,'
                        f'MATCH(TRIM(J{row_index}),Ref_Ponderation!$A$3:$A$20,0)),"")'
                    ),
                    str(exposure.get("category_raw") or ""),
                    self._coerce_float(exposure.get("final_rw")),
                    self._coerce_float(exposure.get("gross_amount")),
                    str(exposure.get("currency") or "XOF"),
                    "OUI" if crm_exists else "NON",
                    self._crm_type_label(exposure),
                    self._coerce_float(exposure.get("ead")),
                    self._coerce_float(exposure.get("ead")),
                    self._coerce_float(exposure.get("rwa")),
                    self._coerce_float(exposure.get("capital")),
                ],
            )

    def _fill_crm_financed_sheet(
        self,
        sheet,
        exposures: list[dict[str, Any]],
    ) -> None:
        self._clear_sheet_values(sheet, max_columns=11)

        row_index = 2
        for exposure in exposures:
            crm_details = exposure.get("crm_details", {})
            if crm_details.get("mode") != "CRM financee":
                continue

            collateral_value = self._coerce_float(crm_details.get("collateral_value"))
            self._write_row(
                sheet,
                row_index,
                [
                    str(exposure["id"]),
                    collateral_value,
                    str(crm_details.get("issuer_type") or ""),
                    str(crm_details.get("issuer_rating") or ""),
                    "",
                    str(crm_details.get("maturity_bucket") or ""),
                    0.0,
                    self._coerce_float(crm_details.get("haircut")),
                    self._coerce_float(crm_details.get("fx_haircut")),
                    collateral_value,
                    0.0,
                ],
            )
            row_index += 1

    def _fill_crm_non_financed_sheet(
        self,
        sheet,
        exposures: list[dict[str, Any]],
    ) -> None:
        self._clear_sheet_values(sheet, max_columns=13)

        row_index = 2
        for exposure in exposures:
            crm_details = exposure.get("crm_details", {})
            if crm_details.get("mode") != "CRM non financee":
                continue

            gross_amount = self._coerce_float(exposure.get("gross_amount"))
            coverage = self._coverage_ratio(exposure)
            covered_amount = round(gross_amount * coverage, 2)
            uncovered_amount = round(gross_amount - covered_amount, 2)
            self._write_row(
                sheet,
                row_index,
                [
                    str(exposure["id"]),
                    str(crm_details.get("guarantor_name") or ""),
                    str(crm_details.get("guarantor_rating") or ""),
                    str(crm_details.get("guarantor_country") or ""),
                    str(
                        crm_details.get("guarantor_country_rating") or ""
                    ),
                    self._coerce_float(crm_details.get("guarantor_country_rw")),
                    str(crm_details.get("guarantor_category") or ""),
                    self._coerce_float(exposure.get("guarantor_rw")),
                    coverage,
                    max(0.0, round(1.0 - coverage, 4)),
                    covered_amount,
                    uncovered_amount,
                    self._coerce_float(exposure.get("rwa")),
                ],
            )
            row_index += 1

    def _fill_off_balance_sheet(
        self,
        sheet,
        off_balance_rows: list[dict[str, Any]],
    ) -> None:
        self._clear_sheet_values(sheet, max_columns=4)

        for row_index, row in enumerate(off_balance_rows, start=2):
            self._write_row(
                sheet,
                row_index,
                [
                    str(row.get("counterparty_id") or ""),
                    str(row.get("engagement_type") or ""),
                    self._coerce_float(row.get("ccf")),
                    self._coerce_float(row.get("nominal_amount")),
                ],
            )


export_service = ExportService()
