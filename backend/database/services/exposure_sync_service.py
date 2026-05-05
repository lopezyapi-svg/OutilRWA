"""Synchronisation légère des champs Expositions entre Excel source et SQLite."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from app.core.excel_repository import excel_repository
from database.connection import database_manager, utcnow_iso
from database.repositories.exposure_repository import exposure_repository


def _has_value(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value.strip())
    return True


class ExposureSyncService:
    """Complète SQLite avec les dates/référentiels portés par le classeur source."""

    def backfill_reference_fields_from_excel(self) -> dict[str, Any]:
        source_path = excel_repository.source_path
        if not source_path.exists():
            return {
                "status": "skipped",
                "reason": "excel_source_not_found",
                "source_path": str(source_path),
                "updated_count": 0,
            }

        workbook_index = excel_repository.exposure_template_fields_by_id()
        sqlite_records = exposure_repository.list_exposures()
        if not sqlite_records:
            self._write_sync_metadata(
                source_path=source_path,
                updated_count=0,
                matched_count=0,
            )
            return {
                "status": "success",
                "source_path": str(source_path),
                "matched_count": 0,
                "updated_count": 0,
                "backup_path": None,
            }

        records_to_update: list[dict[str, Any]] = []
        matched_count = 0
        for record in sqlite_records:
            template_fields = workbook_index.get(str(record["id"]))
            if template_fields is None:
                continue
            matched_count += 1
            updated = False

            if not _has_value(record.get("grant_date")) and template_fields.get("grant_date") is not None:
                record["grant_date"] = template_fields["grant_date"]
                updated = True

            if not _has_value(record.get("maturity_date")) and template_fields.get("maturity_date") is not None:
                record["maturity_date"] = template_fields["maturity_date"]
                updated = True

            current_country_rating = str(record.get("country_rating") or "").strip()
            source_country_rating = str(template_fields.get("country_rating") or "").strip()
            if (
                (not current_country_rating or current_country_rating == "Non noté")
                and source_country_rating
                and source_country_rating != "Non noté"
            ):
                record["country_rating"] = source_country_rating
                updated = True

            if updated:
                records_to_update.append(record)

        backup_path = (
            database_manager.create_backup("before_exposure_reference_backfill")
            if records_to_update
            else None
        )
        if records_to_update:
            with database_manager.transaction() as connection:
                exposure_repository.upsert_exposures(records_to_update, connection=connection)
                self._write_sync_metadata(
                    source_path=source_path,
                    updated_count=len(records_to_update),
                    matched_count=matched_count,
                    connection=connection,
                )
        else:
            self._write_sync_metadata(
                source_path=source_path,
                updated_count=0,
                matched_count=matched_count,
            )

        return {
            "status": "success",
            "source_path": str(source_path),
            "matched_count": matched_count,
            "updated_count": len(records_to_update),
            "backup_path": str(backup_path) if backup_path is not None else None,
        }

    def _write_sync_metadata(
        self,
        *,
        source_path: Path,
        updated_count: int,
        matched_count: int,
        connection=None,
    ) -> None:
        payload = {
            "active_excel_source_path": str(source_path),
            "last_exposure_reference_backfill_at": utcnow_iso(),
            "last_exposure_reference_backfill_count": str(updated_count),
            "last_exposure_reference_match_count": str(matched_count),
            "storage_backend": "sqlite",
        }
        if connection is not None:
            self._write_metadata_payload(connection, payload)
            return
        with database_manager.transaction() as active_connection:
            self._write_metadata_payload(active_connection, payload)

    @staticmethod
    def _write_metadata_payload(connection, payload: dict[str, str]) -> None:
        for key, value in payload.items():
            connection.execute(
                """
                INSERT INTO app_metadata(key, value)
                VALUES(?, ?)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """,
                (key, value),
            )


exposure_sync_service = ExposureSyncService()
