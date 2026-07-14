"""Nouveau pipeline d'import Excel optimisé pour SQLite."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from io import BytesIO
import json
import logging
from time import perf_counter
from typing import Any

from openpyxl import Workbook, load_workbook

from app.core.excel_repository import (
    EXPECTED_COLUMNS_BY_SHEET,
    EXPECTED_INDICATORS_BY_SHEET,
    EXPECTED_SHEETS,
    REF_MIN_COLUMN_COUNT,
    excel_repository,
)
from app.core.runtime_paths import seed_data_path
from app.validators.excel_import_validator import (
    IMPORT_SHEET_SPECS,
    ExcelImportValidationError,
    build_excel_import_spec,
    inspect_workbook_structure,
    read_sheet_headers,
)
from database.connection import database_manager, utcnow_iso
from database.repositories.import_repository import import_repository

logger = logging.getLogger(__name__)


def _clean_text(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip()


def _create_import_run(
    connection,
    *,
    source_type: str,
    source_name: str,
    total_rows: int,
    details: dict[str, Any] | None = None,
) -> int:
    cursor = connection.execute(
        """
        INSERT INTO import_runs(source_type, source_name, imported_at, total_rows, imported_rows, rejected_rows, status, details_json)
        VALUES (?, ?, ?, ?, 0, 0, 'running', ?)
        """,
        (
            source_type,
            source_name,
            utcnow_iso(),
            total_rows,
            json.dumps(details or {}, ensure_ascii=False),
        ),
    )
    return int(cursor.lastrowid)


def _finish_import_run(
    connection,
    run_id: int,
    *,
    imported_rows: int,
    rejected_rows: int,
    details: dict[str, Any],
) -> None:
    connection.execute(
        """
        UPDATE import_runs
        SET imported_rows = ?, rejected_rows = ?, status = 'success', details_json = ?
        WHERE id = ?
        """,
        (
            imported_rows,
            rejected_rows,
            json.dumps(details, ensure_ascii=False),
            run_id,
        ),
    )


def _write_metadata(connection, key: str, value: str) -> None:
    connection.execute(
        """
        INSERT INTO metadonnees_app(cle, valeur)
        VALUES(?, ?)
        ON CONFLICT(cle) DO UPDATE SET valeur = excluded.valeur
        """,
        (key, value),
    )


@dataclass(slots=True)
class ParsedImportBundle:
    exposure_records: list[dict[str, Any]]
    off_balance_records: list[dict[str, Any]]
    rows_read: int
    valid_rows: int
    rejected_rows: int
    errors: list[dict[str, Any]] = field(default_factory=list)
    rows_read_by_sheet: dict[str, int] = field(default_factory=dict)


class ImportProfiler:
    def __init__(self, *, source_name: str) -> None:
        self.source_name = source_name
        self._started_at = perf_counter()
        self.timings_ms: dict[str, float] = {}

    def measure(self, step_name: str):
        start = perf_counter()

        class _StepContext:
            def __enter__(inner_self):
                return inner_self

            def __exit__(inner_self, exc_type, exc, tb):
                elapsed = round((perf_counter() - start) * 1000, 2)
                self.timings_ms[step_name] = elapsed
                logger.info(
                    "Import Excel [%s] - %s: %.2f ms",
                    self.source_name,
                    step_name,
                    elapsed,
                )
                return False

        return _StepContext()

    @property
    def total_ms(self) -> float:
        return round((perf_counter() - self._started_at) * 1000, 2)


class ExcelImportService:
    """Service d'import Excel moderne, rapide et batch."""

    def get_import_spec(self) -> dict[str, Any]:
        return build_excel_import_spec()

    def build_template_workbook(self) -> bytes:
        template_candidates = (seed_data_path("modele_import_rwa.xlsx"),)
        for candidate in template_candidates:
            if candidate.is_file():
                return candidate.read_bytes()

        return self._build_fallback_template_workbook()

    def _build_fallback_template_workbook(self) -> bytes:
        workbook = Workbook()
        default_sheet = workbook.active
        workbook.remove(default_sheet)

        for sheet_name in EXPECTED_SHEETS:
            sheet = workbook.create_sheet(sheet_name)
            required_columns = EXPECTED_COLUMNS_BY_SHEET.get(sheet_name)
            if required_columns:
                sheet.append(list(required_columns))
                sheet.freeze_panes = "A2"
                continue

            markers = EXPECTED_INDICATORS_BY_SHEET.get(sheet_name)
            if markers:
                # Ref_Ponderation alimente directement les calculs de l'outil
                # et doit conserver sa largeur minimale de colonnes ; les
                # autres feuilles de référence ne sont vérifiées que sur la
                # présence de ces repères texte (voir _has_marker dans
                # excel_import_validator.py) — une simple ligne de repères
                # suffit à rendre le modèle téléchargé valide tel quel.
                width = REF_MIN_COLUMN_COUNT if sheet_name == "Ref_Ponderation" else len(markers)
                indicator_row = [""] * max(width, len(markers))
                for index, marker in enumerate(markers):
                    indicator_row[index] = marker
                sheet.append(indicator_row)
                sheet.freeze_panes = "A2"

        output = BytesIO()
        workbook.save(output)
        workbook.close()
        output.seek(0)
        return output.getvalue()

    def inspect_uploaded_workbook(self, workbook_bytes: bytes, filename: str | None = None) -> dict[str, Any]:
        source_name = filename or "upload.xlsx"
        profiler = ImportProfiler(source_name=source_name)

        with profiler.measure("lecture_fichier_excel"):
            workbook = load_workbook(BytesIO(workbook_bytes), data_only=True, read_only=True)

        try:
            inspection = self._inspect_structure(workbook, profiler=profiler)

            with profiler.measure("lecture_des_lignes_utiles"):
                rows_read_by_sheet = self._collect_rows_read_by_sheet(workbook)
        finally:
            workbook.close()

        return {
            "file": source_name,
            "valid": inspection["valid"],
            "sheet_count": inspection["sheet_count"],
            "detected_sheets": inspection["detected_sheets"],
            "sheets": inspection["sheets"],
            "errors": inspection["errors"],
            "rows_read_by_sheet": rows_read_by_sheet,
            "duration_ms": profiler.total_ms,
            "steps_ms": profiler.timings_ms,
        }

    def import_uploaded_workbook(
        self,
        workbook_bytes: bytes,
        filename: str | None = None,
        *,
        mode: str = "merge",
    ) -> dict[str, Any]:
        source_name = filename or "upload.xlsx"
        normalized_mode = mode.strip().lower()
        if normalized_mode not in {"merge", "replace"}:
            raise ValueError("Le mode d'import doit être 'merge' ou 'replace'.")

        profiler = ImportProfiler(source_name=source_name)

        with profiler.measure("lecture_fichier_excel"):
            workbook = load_workbook(BytesIO(workbook_bytes), data_only=True, read_only=True)

        try:
            inspection = self._inspect_structure(workbook, profiler=profiler)
            self._ensure_valid_inspection(inspection)

            parsed = self._parse_workbook(workbook, profiler=profiler)
        finally:
            workbook.close()

        backup_path = None
        if normalized_mode == "replace":
            with profiler.measure("sauvegarde_avant_ecrasement"):
                backup_path = database_manager.create_backup("before_excel_replace_import")

        with profiler.measure("insertion_sqlite"):
            with database_manager.transaction() as connection:
                run_id = _create_import_run(
                    connection,
                    source_type="excel_upload",
                    source_name=source_name,
                    total_rows=parsed.rows_read,
                    details={
                        "mode": normalized_mode,
                        "rows_read_by_sheet": parsed.rows_read_by_sheet,
                    },
                )
                persistence_stats = import_repository.persist_import(
                    exposure_records=parsed.exposure_records,
                    off_balance_records=parsed.off_balance_records,
                    mode=normalized_mode,
                    connection=connection,
                )
                _write_metadata(connection, "last_upload_import_at", utcnow_iso())
                _write_metadata(connection, "storage_backend", "sqlite")
                if backup_path is not None:
                    _write_metadata(connection, "last_backup_path", str(backup_path))

                report_details = {
                    "mode": normalized_mode,
                    "rows_read_by_sheet": parsed.rows_read_by_sheet,
                    "valid_rows": parsed.valid_rows,
                    "inserted_exposures": persistence_stats["inserted_exposures"],
                    "updated_exposures": persistence_stats["updated_exposures"],
                    "inserted_off_balance": persistence_stats["inserted_off_balance"],
                    "updated_off_balance": persistence_stats["updated_off_balance"],
                    "errors": parsed.errors,
                    "steps_ms": profiler.timings_ms,
                    "duration_ms": profiler.total_ms,
                    "backup_path": str(backup_path) if backup_path else None,
                }
                _finish_import_run(
                    connection,
                    run_id,
                    imported_rows=(
                        len(parsed.exposure_records) + len(parsed.off_balance_records)
                    ),
                    rejected_rows=parsed.rejected_rows,
                    details=report_details,
                )

        total_imported = (
            persistence_stats["inserted_exposures"] + persistence_stats["inserted_off_balance"]
        )
        total_updated = (
            persistence_stats["updated_exposures"] + persistence_stats["updated_off_balance"]
        )

        report = {
            "status": "success",
            "file": source_name,
            "mode": normalized_mode,
            "rows_read": parsed.rows_read,
            "valid_rows": parsed.valid_rows,
            "imported_rows": total_imported,
            "updated_rows": total_updated,
            "rejected_rows": parsed.rejected_rows,
            "rows_read_by_sheet": parsed.rows_read_by_sheet,
            "errors": parsed.errors,
            "backup_path": str(backup_path) if backup_path else None,
            "duration_ms": profiler.total_ms,
            "steps_ms": profiler.timings_ms,
        }
        logger.info(
            "Import Excel [%s] terminé en %.2f ms | lues=%s importées=%s mises_a_jour=%s rejetées=%s",
            source_name,
            profiler.total_ms,
            parsed.rows_read,
            total_imported,
            total_updated,
            parsed.rejected_rows,
        )
        return report

    def _inspect_structure(self, workbook, *, profiler: ImportProfiler) -> dict[str, Any]:
        with profiler.measure("detection_des_feuilles"):
            detected_sheets = list(workbook.sheetnames)

        with profiler.measure("validation_des_colonnes"):
            inspection = inspect_workbook_structure(workbook)

        inspection["detected_sheets"] = detected_sheets
        inspection["sheet_count"] = len(detected_sheets)
        return inspection

    def _ensure_valid_inspection(self, inspection: dict[str, Any]) -> None:
        if inspection.get("valid") is True:
            return
        raise ExcelImportValidationError(
            {
                "message": "Le fichier Excel ne respecte pas le format d'import attendu.",
                **inspection,
            }
        )

    def _collect_rows_read_by_sheet(self, workbook) -> dict[str, int]:
        counts: dict[str, int] = {}
        for spec in IMPORT_SHEET_SPECS:
            if spec.name not in workbook.sheetnames:
                counts[spec.name] = 0
                continue
            rows = self._read_sheet_rows(workbook[spec.name], spec)
            counts[spec.name] = len(rows)
        return counts

    def _read_sheet_rows(self, sheet, spec) -> list[tuple[int, dict[str, Any]]]:
        headers = read_sheet_headers(sheet)
        selected_indexes = {
            header: index
            for index, header in enumerate(headers)
            if header and header in spec.import_columns
        }
        rows: list[tuple[int, dict[str, Any]]] = []
        for excel_row_index, values in enumerate(
            sheet.iter_rows(min_row=2, values_only=True),
            start=2,
        ):
            if not selected_indexes:
                continue
            if not any(
                index < len(values) and values[index] not in (None, "")
                for index in selected_indexes.values()
            ):
                continue
            row = {
                column_name: values[index] if index < len(values) else None
                for column_name, index in selected_indexes.items()
            }
            rows.append((excel_row_index, row))
        return rows

    def _parse_workbook(self, workbook, *, profiler: ImportProfiler) -> ParsedImportBundle:
        spec_by_name = {spec.name: spec for spec in IMPORT_SHEET_SPECS}
        with profiler.measure("lecture_feuille_template_donnees"):
            template_rows = self._read_sheet_rows(
                workbook["Template données"],
                spec_by_name["Template données"],
            )
        with profiler.measure("lecture_feuille_crm_financee"):
            crm_fin_rows = (
                self._read_sheet_rows(
                    workbook["CRM_financée"],
                    spec_by_name["CRM_financée"],
                )
                if "CRM_financée" in workbook.sheetnames
                else []
            )
        with profiler.measure("lecture_feuille_crm_non_financee"):
            crm_non_fin_rows = (
                self._read_sheet_rows(
                    workbook["CRM_non_financee"],
                    spec_by_name["CRM_non_financee"],
                )
                if "CRM_non_financee" in workbook.sheetnames
                else []
            )
        with profiler.measure("lecture_feuille_traitement_hb"):
            hb_rows = (
                self._read_sheet_rows(
                    workbook["Traitement_HB"],
                    spec_by_name["Traitement_HB"],
                )
                if "Traitement_HB" in workbook.sheetnames
                else []
            )

        rows_read_by_sheet = {
            "Template données": len(template_rows),
            "CRM_financée": len(crm_fin_rows),
            "CRM_non_financee": len(crm_non_fin_rows),
            "Traitement_HB": len(hb_rows),
        }

        with profiler.measure("normalisation_des_donnees"):
            crm_non_fin = excel_repository._crm_non_fin_by_rows(
                [row for _, row in crm_non_fin_rows]
            )
            crm_fin = excel_repository._crm_fin_by_rows([row for _, row in crm_fin_rows])

        all_templates: dict[str, dict[str, Any]] = {}
        exposure_records_by_id: dict[str, dict[str, Any]] = {}
        off_balance_records: list[dict[str, Any]] = []
        errors: list[dict[str, Any]] = []

        with profiler.measure("controle_des_doublons"):
            for excel_row_index, row in template_rows:
                exposure_id = _clean_text(row.get("ID_Exposition"))
                if not exposure_id:
                    errors.append(
                        {
                            "sheet": "Template données",
                            "row": excel_row_index,
                            "column": "ID_Exposition",
                            "message": "ID_Exposition manquant.",
                        }
                    )
                    continue
                if exposure_id in all_templates:
                    errors.append(
                        {
                            "sheet": "Template données",
                            "row": excel_row_index,
                            "column": "ID_Exposition",
                            "message": f"ID dupliqué dans le fichier: {exposure_id}.",
                        }
                    )
                    continue
                try:
                    built = excel_repository._build_exposure_from_template(
                        row,
                        crm_non_fin_row=crm_non_fin.get(exposure_id),
                        crm_fin_row=crm_fin.get(exposure_id),
                    )
                except Exception as exc:
                    errors.append(
                        {
                            "sheet": "Template données",
                            "row": excel_row_index,
                            "column": None,
                            "message": str(exc),
                        }
                    )
                    continue

                all_templates[exposure_id] = dict(built)
                if self._is_off_balance_category(str(built.get("category_raw") or "")):
                    continue
                exposure_records_by_id[exposure_id] = dict(built)

        exposure_ids = set(exposure_records_by_id.keys())
        generated_hb_ids: set[str] = set()
        with profiler.measure("recalcul_rwa"):
            for excel_row_index, hb_row in hb_rows:
                exposure_id = _clean_text(hb_row.get("ID_Exposition"))
                if not exposure_id:
                    errors.append(
                        {
                            "sheet": "Traitement_HB",
                            "row": excel_row_index,
                            "column": "ID_Exposition",
                            "message": "ID_Exposition manquant.",
                        }
                    )
                    continue
                support_record = all_templates.get(exposure_id)
                if support_record is None:
                    errors.append(
                        {
                            "sheet": "Traitement_HB",
                            "row": excel_row_index,
                            "column": "ID_Exposition",
                            "message": f"Aucune ligne correspondante dans Template données pour {exposure_id}.",
                        }
                    )
                    continue
                if exposure_id not in exposure_ids:
                    exposure_records_by_id[exposure_id] = dict(support_record)
                    exposure_ids.add(exposure_id)
                try:
                    ccf = float(hb_row.get("Facteur_conversion (CCF)") or 1.0)
                    nominal_amount = float(
                        support_record.get("off_balance_exposure_amount")
                        or support_record.get("loan_total_amount")
                        or support_record.get("gross_amount")
                        or 0.0
                    )
                    ead = float(
                        hb_row.get("EAD_HB_ccf")
                        or support_record.get("ead_hb_ccf_amount")
                        or round(nominal_amount * ccf, 2)
                    )
                    rwa = float(
                        support_record.get("rwa_hb_amount")
                        or 0.0
                    )
                    risk_weight = (
                        round(rwa / ead, 6)
                        if ead > 0 and rwa > 0
                        else float(
                            support_record.get("original_rw")
                            or support_record.get("final_rw")
                            or 0.0
                        )
                    )
                    if rwa <= 0:
                        rwa = round(ead * risk_weight, 2)
                except Exception as exc:
                    errors.append(
                        {
                            "sheet": "Traitement_HB",
                            "row": excel_row_index,
                            "column": None,
                            "message": str(exc),
                        }
                    )
                    continue

                record_id = f"HB_{exposure_id}_{excel_row_index:03d}"
                if record_id in generated_hb_ids:
                    errors.append(
                        {
                            "sheet": "Traitement_HB",
                            "row": excel_row_index,
                            "column": "ID_Exposition",
                            "message": f"Ligne hors bilan dupliquée pour {exposure_id}.",
                        }
                    )
                    continue
                generated_hb_ids.add(record_id)
                off_balance_records.append(
                    {
                        "id": record_id,
                        "analysis_date": support_record.get("analysis_date") or date.today(),
                        "counterparty_id": exposure_id,
                        "engagement_type": _clean_text(hb_row.get("Catégorie Hors bilan"))
                        or "Risque élevé",
                        "nominal_amount": nominal_amount,
                        "ccf": ccf,
                        "ead": ead,
                        "risk_weight": risk_weight,
                        "rwa": rwa,
                        "capital": round(rwa * 0.09, 2),
                        "comment": f"Import Excel {exposure_id}",
                    }
                )

        exposure_records = list(exposure_records_by_id.values())
        rows_read = sum(rows_read_by_sheet.values())
        valid_rows = len(exposure_records) + len(off_balance_records)
        return ParsedImportBundle(
            exposure_records=exposure_records,
            off_balance_records=off_balance_records,
            rows_read=rows_read,
            valid_rows=valid_rows,
            rejected_rows=len(errors),
            errors=errors,
            rows_read_by_sheet=rows_read_by_sheet,
        )

    @staticmethod
    def _is_off_balance_category(category_raw: str) -> bool:
        return category_raw.strip().lower().startswith("(l) hors bilan")


excel_import_service = ExcelImportService()
