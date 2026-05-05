"""Accès SQLite au portefeuille d'expositions."""

from __future__ import annotations

from contextlib import nullcontext
import json
import re
from typing import Any

from database.connection import database_manager, utcnow_iso
from database.repositories.crm_repository import crm_repository

_SQLITE_CHUNK_SIZE = 400
_EXPOSURE_ID_PATTERN = re.compile(r"^CP(\d+)$")


def _bool_to_int(value: bool) -> int:
    return 1 if value else 0


def _nullable_bool_to_int(value: bool | None) -> int | None:
    if value is None:
        return None
    return 1 if value else 0


def _nullable_int_to_bool(value: Any) -> bool | None:
    if value is None:
        return None
    return bool(value)


def _normalize_key(value: str) -> str:
    return " ".join(value.lower().strip().split())


def _normalize_rating_label(value: Any, fallback: str = "Non noté") -> str:
    text = str(value or "").strip()
    normalized = _normalize_key(
        text.replace("é", "e").replace("è", "e").replace("ê", "e")
    )
    if not text:
        return fallback
    if normalized in {"non note", "non_note"}:
        return "Non noté"
    return text


def _chunked(values: list[str], size: int = _SQLITE_CHUNK_SIZE):
    for index in range(0, len(values), size):
        yield values[index : index + size]


def _parse_exposure_index(identifier: str) -> int | None:
    match = _EXPOSURE_ID_PATTERN.fullmatch(identifier.strip())
    if match is None:
        return None
    return int(match.group(1))


def _format_exposure_id(index: int) -> str:
    return f"CP{index:03d}"


class ExposureRepository:
    """Persiste et lit les expositions depuis SQLite."""

    def list_exposures(self, search: str | None = None, category: str | None = None) -> list[dict[str, Any]]:
        query = """
            SELECT
                e.id,
                e.analysis_date,
                e.grant_date,
                e.maturity_date,
                cp.name AS counterparty_name,
                cp.country,
                cp.country_rating,
                cp.category_prudential AS category_raw,
                cp.category_standard,
                e.crm_type,
                e.crm_mode,
                e.crm_label,
                e.crm_exists,
                e.crm_coverage_percent,
                cp.rating,
                e.gross_amount,
                e.currency,
                e.status,
                e.sovereign_special_case,
                e.sovereign_preferential_zero_weight,
                e.sovereign_oce_established,
                e.sovereign_oce_note,
                e.public_body_uemoa_fcfa_case,
                e.public_body_non_public_activity,
                e.bmd_high_quality_case,
                e.bmd_uemoa_fcfa_case,
                e.bmd_uemoa_criteria_satisfied,
                e.bmd_listed_institution_fcfa_case,
                e.bank_institution_case,
                e.other_asset_type,
                e.off_balance_risk_level,
                e.retail_eligibility_criteria_satisfied,
                e.residential_mortgage_eligible,
                e.commercial_real_estate_eligible,
                e.defaulted_exposure_initial_risk_weight,
                e.defaulted_exposure_residential_mortgage_in_default,
                e.defaulted_exposure_provision_at_least_twenty_percent,
                e.enterprise_exceeds_bceao_degradation_threshold,
                e.enterprise_prudential_procedure,
                e.enterprise_investment_firm_without_banking_law,
                e.original_rw,
                e.final_rw,
                e.ead,
                e.rwa,
                e.capital,
                e.comment,
                cf.collateral_value,
                cf.issuer_type,
                cf.issuer_rating,
                cf.maturity_bucket,
                cf.fx_haircut,
                cf.haircut,
                cn.guarantor_name,
                cn.guarantor_category,
                cn.guarantor_rating,
                cn.guarantor_country,
                cn.guarantor_country_rating,
                cn.guarantor_country_rw,
                cn.guarantor_rw
            FROM exposures e
            INNER JOIN counterparties cp ON cp.id = e.counterparty_id
            LEFT JOIN crm_financed cf ON cf.exposure_id = e.id
            LEFT JOIN crm_non_financed cn ON cn.exposure_id = e.id
            WHERE 1 = 1
        """
        params: list[Any] = []
        if search:
            like = f"%{search.lower()}%"
            query += " AND (LOWER(e.id) LIKE ? OR LOWER(cp.name) LIKE ? OR LOWER(cp.country) LIKE ?)"
            params.extend([like, like, like])
        if category:
            normalized_category = category.lower()
            query += """
                AND (
                    LOWER(cp.category_prudential) = ?
                    OR LOWER(cp.category_standard) = ?
                )
            """
            params.extend([normalized_category, normalized_category])
        query += " ORDER BY e.id"

        with database_manager.connect() as connection:
            rows = connection.execute(query, params).fetchall()
        return [self._row_to_record(dict(row)) for row in rows]

    def get_exposure(self, exposure_id: str) -> dict[str, Any] | None:
        rows = self.list_exposures(search=exposure_id)
        for row in rows:
            if row["id"] == exposure_id:
                return row
        return None

    def count_exposures(self) -> int:
        with database_manager.connect() as connection:
            row = connection.execute("SELECT COUNT(*) AS total FROM exposures").fetchone()
        return int(row["total"]) if row is not None else 0

    def get_existing_ids(self, exposure_ids: list[str], *, connection=None) -> set[str]:
        normalized_ids = sorted({str(item).strip() for item in exposure_ids if str(item).strip()})
        if not normalized_ids:
            return set()

        active_connection = connection or database_manager.connect()
        try:
            existing_ids: set[str] = set()
            for chunk in _chunked(normalized_ids):
                placeholders = ", ".join("?" for _ in chunk)
                rows = active_connection.execute(
                    f"SELECT id FROM exposures WHERE id IN ({placeholders})",
                    chunk,
                ).fetchall()
                existing_ids.update(str(row["id"]) for row in rows)
            return existing_ids
        finally:
            if connection is None:
                active_connection.close()

    def next_exposure_id(self) -> str:
        with database_manager.connect() as connection:
            rows = connection.execute(
                """
                SELECT id
                FROM exposures
                WHERE id LIKE 'CP%'
                """
            ).fetchall()
        max_index = 0
        for row in rows:
            parsed_index = _parse_exposure_index(str(row["id"]))
            if parsed_index is not None and parsed_index > max_index:
                max_index = parsed_index
        return _format_exposure_id(max_index + 1)

    def upsert_exposure(self, record: dict[str, Any], *, connection=None) -> dict[str, Any]:
        self.upsert_exposures([record], connection=connection)
        return record

    def upsert_exposures(self, records: list[dict[str, Any]], *, connection=None) -> list[dict[str, Any]]:
        if not records:
            return []
        manager = nullcontext(connection) if connection is not None else database_manager.transaction()
        with manager as active_connection:
            now = utcnow_iso()
            self._upsert_counterparties(active_connection, records, now=now)
            active_connection.executemany(
                """
                INSERT INTO exposures(
                    id,
                    counterparty_id,
                    analysis_date,
                    grant_date,
                    maturity_date,
                    gross_amount,
                    currency,
                    status,
                    sovereign_special_case,
                    sovereign_preferential_zero_weight,
                    sovereign_oce_established,
                    sovereign_oce_note,
                    public_body_uemoa_fcfa_case,
                    public_body_non_public_activity,
                    bmd_high_quality_case,
                    bmd_uemoa_fcfa_case,
                    bmd_uemoa_criteria_satisfied,
                    bmd_listed_institution_fcfa_case,
                    bank_institution_case,
                    other_asset_type,
                    off_balance_risk_level,
                    retail_eligibility_criteria_satisfied,
                    residential_mortgage_eligible,
                    commercial_real_estate_eligible,
                    defaulted_exposure_initial_risk_weight,
                    defaulted_exposure_residential_mortgage_in_default,
                    defaulted_exposure_provision_at_least_twenty_percent,
                    enterprise_exceeds_bceao_degradation_threshold,
                    enterprise_prudential_procedure,
                    enterprise_investment_firm_without_banking_law,
                    crm_exists,
                    crm_type,
                    crm_mode,
                    crm_label,
                    crm_coverage_percent,
                    original_rw,
                    final_rw,
                    ead,
                    rwa,
                    capital,
                    comment,
                    created_at,
                    updated_at
                ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?
                )
                ON CONFLICT(id) DO UPDATE SET
                    counterparty_id = excluded.counterparty_id,
                    analysis_date = excluded.analysis_date,
                    grant_date = excluded.grant_date,
                    maturity_date = excluded.maturity_date,
                    gross_amount = excluded.gross_amount,
                    currency = excluded.currency,
                    status = excluded.status,
                    sovereign_special_case = excluded.sovereign_special_case,
                    sovereign_preferential_zero_weight = excluded.sovereign_preferential_zero_weight,
                    sovereign_oce_established = excluded.sovereign_oce_established,
                    sovereign_oce_note = excluded.sovereign_oce_note,
                    public_body_uemoa_fcfa_case = excluded.public_body_uemoa_fcfa_case,
                    public_body_non_public_activity = excluded.public_body_non_public_activity,
                    bmd_high_quality_case = excluded.bmd_high_quality_case,
                    bmd_uemoa_fcfa_case = excluded.bmd_uemoa_fcfa_case,
                    bmd_uemoa_criteria_satisfied = excluded.bmd_uemoa_criteria_satisfied,
                    bmd_listed_institution_fcfa_case = excluded.bmd_listed_institution_fcfa_case,
                    bank_institution_case = excluded.bank_institution_case,
                    other_asset_type = excluded.other_asset_type,
                    off_balance_risk_level = excluded.off_balance_risk_level,
                    retail_eligibility_criteria_satisfied = excluded.retail_eligibility_criteria_satisfied,
                    residential_mortgage_eligible = excluded.residential_mortgage_eligible,
                    commercial_real_estate_eligible = excluded.commercial_real_estate_eligible,
                    defaulted_exposure_initial_risk_weight = excluded.defaulted_exposure_initial_risk_weight,
                    defaulted_exposure_residential_mortgage_in_default = excluded.defaulted_exposure_residential_mortgage_in_default,
                    defaulted_exposure_provision_at_least_twenty_percent = excluded.defaulted_exposure_provision_at_least_twenty_percent,
                    enterprise_exceeds_bceao_degradation_threshold = excluded.enterprise_exceeds_bceao_degradation_threshold,
                    enterprise_prudential_procedure = excluded.enterprise_prudential_procedure,
                    enterprise_investment_firm_without_banking_law = excluded.enterprise_investment_firm_without_banking_law,
                    crm_exists = excluded.crm_exists,
                    crm_type = excluded.crm_type,
                    crm_mode = excluded.crm_mode,
                    crm_label = excluded.crm_label,
                    crm_coverage_percent = excluded.crm_coverage_percent,
                    original_rw = excluded.original_rw,
                    final_rw = excluded.final_rw,
                    ead = excluded.ead,
                    rwa = excluded.rwa,
                    capital = excluded.capital,
                    comment = excluded.comment,
                    updated_at = excluded.updated_at
                """,
                [
                    (
                        str(record["id"]),
                        str(record["id"]),
                        record["analysis_date"].isoformat()
                        if hasattr(record["analysis_date"], "isoformat")
                        else str(record["analysis_date"]),
                        record["grant_date"].isoformat()
                        if record.get("grant_date") is not None
                        and hasattr(record["grant_date"], "isoformat")
                        else (
                            str(record["grant_date"])
                            if record.get("grant_date") is not None
                            else None
                        ),
                        record["maturity_date"].isoformat()
                        if record.get("maturity_date") is not None
                        and hasattr(record["maturity_date"], "isoformat")
                        else (
                            str(record["maturity_date"])
                            if record.get("maturity_date") is not None
                            else None
                        ),
                        float(record["gross_amount"]),
                        str(record.get("currency", "XOF")),
                        str(record.get("status", "Active")),
                        str(record.get("sovereign_special_case") or ""),
                        _bool_to_int(bool(record.get("sovereign_preferential_zero_weight"))),
                        _bool_to_int(bool(record.get("sovereign_oce_established"))),
                        str(record.get("sovereign_oce_note") or ""),
                        _nullable_bool_to_int(record.get("public_body_uemoa_fcfa_case")),
                        _nullable_bool_to_int(record.get("public_body_non_public_activity")),
                        _nullable_bool_to_int(record.get("bmd_high_quality_case")),
                        _nullable_bool_to_int(record.get("bmd_uemoa_fcfa_case")),
                        _nullable_bool_to_int(record.get("bmd_uemoa_criteria_satisfied")),
                        _nullable_bool_to_int(record.get("bmd_listed_institution_fcfa_case")),
                        str(record.get("bank_institution_case") or "")
                        or None,
                        str(record.get("other_asset_type") or "") or None,
                        str(record.get("off_balance_risk_level") or "") or None,
                        _nullable_bool_to_int(
                            record.get("retail_eligibility_criteria_satisfied")
                        ),
                        _nullable_bool_to_int(
                            record.get("residential_mortgage_eligible")
                        ),
                        _nullable_bool_to_int(
                            record.get("commercial_real_estate_eligible")
                        ),
                        (
                            float(
                                record.get(
                                    "defaulted_exposure_initial_risk_weight", 0.0
                                )
                            )
                            if record.get(
                                "defaulted_exposure_initial_risk_weight"
                            )
                            is not None
                            else None
                        ),
                        _nullable_bool_to_int(
                            record.get(
                                "defaulted_exposure_residential_mortgage_in_default"
                            )
                        ),
                        _nullable_bool_to_int(
                            record.get(
                                "defaulted_exposure_provision_at_least_twenty_percent"
                            )
                        ),
                        _nullable_bool_to_int(
                            record.get(
                                "enterprise_exceeds_bceao_degradation_threshold"
                            )
                        ),
                        _nullable_bool_to_int(
                            record.get("enterprise_prudential_procedure")
                        ),
                        _nullable_bool_to_int(
                            record.get(
                                "enterprise_investment_firm_without_banking_law"
                            )
                        ),
                        _bool_to_int(bool(record.get("crm_exists"))),
                        str(record.get("crm_type", "Aucune")),
                        str(record.get("crm_mode") or record.get("crm_details", {}).get("mode") or "Aucune"),
                        str(record.get("crm_label") or record.get("crm_details", {}).get("label") or record.get("crm_type", "Aucune")),
                        float(record.get("crm_coverage_percent", 0.0) or 0.0),
                        float(record.get("original_rw", 0.0) or 0.0),
                        float(record.get("final_rw", 0.0) or 0.0),
                        float(record.get("ead", 0.0) or 0.0),
                        float(record.get("rwa", 0.0) or 0.0),
                        float(record.get("capital", 0.0) or 0.0),
                        record.get("comment"),
                        now,
                        now,
                    )
                    for record in records
                ],
            )
            crm_repository.sync_exposures_crm(records, connection=active_connection)
            self._log_operation(
                active_connection,
                entity_type="exposure",
                entity_id=None,
                operation="bulk_upsert",
                payload={
                    "count": len(records),
                    "ids": [record["id"] for record in records],
                },
            )
        return [dict(record) for record in records]

    def replace_all(self, records: list[dict[str, Any]], *, connection=None) -> list[dict[str, Any]]:
        manager = nullcontext(connection) if connection is not None else database_manager.transaction()
        with manager as active_connection:
            self.clear_portfolio(connection=active_connection)
            self.upsert_exposures(records, connection=active_connection)
        return [dict(record) for record in records]

    def clear_portfolio(self, *, connection=None) -> None:
        manager = nullcontext(connection) if connection is not None else database_manager.transaction()
        with manager as active_connection:
            active_connection.execute("DELETE FROM off_balance_commitments")
            active_connection.execute("DELETE FROM crm_financed")
            active_connection.execute("DELETE FROM crm_non_financed")
            active_connection.execute("DELETE FROM exposures")
            active_connection.execute("DELETE FROM counterparties")

    def delete_exposures(
        self,
        exposure_ids: list[str],
        *,
        connection=None,
        reindex_ids: bool = False,
    ) -> dict[str, int | list[str] | bool | dict[str, str]]:
        normalized_ids = sorted({str(item).strip() for item in exposure_ids if str(item).strip()})
        if not normalized_ids:
            return {
                "requested_ids": [],
                "deleted_ids": [],
                "missing_ids": [],
                "deleted_count": 0,
                "missing_count": 0,
                "reindexed_ids": False,
                "renumbered_ids": {},
            }

        placeholders = ", ".join("?" for _ in normalized_ids)
        manager = nullcontext(connection) if connection is not None else database_manager.transaction()
        with manager as active_connection:
            rows = active_connection.execute(
                f"SELECT id FROM exposures WHERE id IN ({placeholders})",
                normalized_ids,
            ).fetchall()
            deleted_ids = sorted(str(row["id"]) for row in rows)
            missing_ids = [item for item in normalized_ids if item not in deleted_ids]
            if deleted_ids:
                delete_placeholders = ", ".join("?" for _ in deleted_ids)
                active_connection.execute(
                    f"DELETE FROM exposures WHERE id IN ({delete_placeholders})",
                    deleted_ids,
                )
                renumbered_ids = (
                    self._reindex_exposure_ids(active_connection)
                    if reindex_ids
                    else {}
                )
                self._cleanup_orphan_counterparties(active_connection)
                self._log_operation(
                    active_connection,
                    entity_type="exposure",
                    entity_id=None,
                    operation="bulk_delete",
                    payload={
                        "ids": deleted_ids,
                        "missing_ids": missing_ids,
                        "reindex_ids": reindex_ids,
                        "renumbered_ids": renumbered_ids,
                    },
                )
            else:
                renumbered_ids = {}

        return {
            "requested_ids": normalized_ids,
            "deleted_ids": deleted_ids,
            "missing_ids": missing_ids,
            "deleted_count": len(deleted_ids),
            "missing_count": len(missing_ids),
            "reindexed_ids": bool(reindex_ids and renumbered_ids),
            "renumbered_ids": renumbered_ids,
        }

    def _reindex_exposure_ids(self, connection) -> dict[str, str]:
        rows = connection.execute(
            """
            SELECT
                cp.id,
                CASE
                    WHEN EXISTS(
                        SELECT 1
                        FROM exposures e_exists
                        WHERE e_exists.counterparty_id = cp.id
                    ) THEN 1
                    ELSE 0
                END AS has_exposure,
                MIN(
                    CASE
                        WHEN e.id LIKE 'CP%' THEN CAST(SUBSTR(e.id, 3) AS INTEGER)
                        ELSE NULL
                    END
                ) AS exposure_order
            FROM counterparties cp
            LEFT JOIN exposures e ON e.counterparty_id = cp.id
            WHERE cp.id LIKE 'CP%'
            GROUP BY cp.id
            """
        ).fetchall()
        ordered_rows = sorted(
            rows,
            key=lambda row: (
                0 if int(row["has_exposure"]) else 1,
                row["exposure_order"] if row["exposure_order"] is not None else 10**9,
                _parse_exposure_index(str(row["id"])) or 10**9,
                str(row["id"]),
            ),
        )
        ordered_ids = [str(row["id"]) for row in ordered_rows]
        all_renumbered_ids = {
            current_id: _format_exposure_id(index)
            for index, current_id in enumerate(ordered_ids, start=1)
            if current_id != _format_exposure_id(index)
        }
        if not all_renumbered_ids:
            return {}

        connection.execute("PRAGMA defer_foreign_keys = ON")
        temporary_ids = {
            source_id: f"__TMP_CP_{position:06d}__"
            for position, source_id in enumerate(all_renumbered_ids.keys(), start=1)
        }

        for source_id, temporary_id in temporary_ids.items():
            self._remap_exposure_identifier(connection, source_id, temporary_id)
        for source_id, final_id in all_renumbered_ids.items():
            self._remap_exposure_identifier(
                connection,
                temporary_ids[source_id],
                final_id,
            )

        exposure_ids_after = {
            str(row["id"])
            for row in connection.execute(
                """
                SELECT id
                FROM exposures
                WHERE id LIKE 'CP%'
                """
            ).fetchall()
        }
        return {
            source_id: target_id
            for source_id, target_id in all_renumbered_ids.items()
            if target_id in exposure_ids_after
        }

    def _remap_exposure_identifier(
        self,
        connection,
        source_id: str,
        target_id: str,
    ) -> None:
        connection.execute(
            "UPDATE counterparties SET id = ? WHERE id = ?",
            (target_id, source_id),
        )
        connection.execute(
            "UPDATE exposures SET id = ? WHERE id = ?",
            (target_id, source_id),
        )
        connection.execute(
            "UPDATE exposures SET counterparty_id = ? WHERE counterparty_id = ?",
            (target_id, source_id),
        )
        connection.execute(
            "UPDATE crm_financed SET exposure_id = ? WHERE exposure_id = ?",
            (target_id, source_id),
        )
        connection.execute(
            "UPDATE crm_non_financed SET exposure_id = ? WHERE exposure_id = ?",
            (target_id, source_id),
        )
        connection.execute(
            "UPDATE crm_guarantees SET exposure_id = ? WHERE exposure_id = ?",
            (target_id, source_id),
        )
        connection.execute(
            "UPDATE off_balance_commitments SET counterparty_id = ? WHERE counterparty_id = ?",
            (target_id, source_id),
        )
        connection.execute(
            """
            UPDATE report_lines
            SET item_id = ?
            WHERE source = 'Exposition' AND item_id = ?
            """,
            (target_id, source_id),
        )

    def _upsert_counterparties(self, connection, records: list[dict[str, Any]], *, now: str) -> None:
        connection.executemany(
            """
            INSERT INTO counterparties(
                id,
                name,
                country,
                country_rating,
                category_standard,
                category_prudential,
                rating,
                created_at,
                updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                country = excluded.country,
                country_rating = excluded.country_rating,
                category_standard = excluded.category_standard,
                category_prudential = excluded.category_prudential,
                rating = excluded.rating,
                updated_at = excluded.updated_at
            """,
            [
                (
                    str(record["id"]),
                    str(record["counterparty_name"]),
                    str(record["country"]),
                    str(record.get("country_rating", "Non noté") or "Non noté"),
                    str(record.get("category_standard", "Entreprises")),
                    str(record.get("category_raw", record.get("category_standard", "Entreprises"))),
                    str(record["rating"]),
                    now,
                    now,
                )
                for record in records
            ],
        )

    def _cleanup_orphan_counterparties(self, connection) -> None:
        connection.execute(
            """
            DELETE FROM counterparties
            WHERE id NOT IN (SELECT counterparty_id FROM exposures)
              AND id NOT IN (SELECT counterparty_id FROM off_balance_commitments)
            """
        )

    def _log_operation(self, connection, *, entity_type: str, entity_id: str | None, operation: str, payload: dict[str, Any]) -> None:
        connection.execute(
            """
            INSERT INTO operation_history(entity_type, entity_id, operation, payload_json, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                entity_type,
                entity_id,
                operation,
                json.dumps(payload, ensure_ascii=False),
                utcnow_iso(),
            ),
        )

    def _row_to_record(self, row: dict[str, Any]) -> dict[str, Any]:
        crm_mode = str(row.get("crm_mode") or "Aucune")
        if crm_mode == "CRM financee":
            crm_details = {
                "mode": crm_mode,
                "label": row.get("crm_label") or row.get("crm_type") or "Aucune",
                "collateral_value": float(row.get("collateral_value", 0.0) or 0.0),
                "issuer_type": str(row.get("issuer_type") or ""),
                "issuer_rating": _normalize_rating_label(row.get("issuer_rating"), fallback=""),
                "maturity_bucket": str(row.get("maturity_bucket") or "<=1 an"),
                "fx_haircut": float(row.get("fx_haircut", 0.0) or 0.0),
                "guarantor_name": "",
                "guarantor_category": "",
                "guarantor_rating": "",
                "coverage_percent": float(row.get("crm_coverage_percent", 0.0) or 0.0),
                "haircut": float(row.get("haircut", 0.0) or 0.0),
            }
            guarantor_rw = 0.0
        elif crm_mode == "CRM non financee":
            crm_details = {
                "mode": crm_mode,
                "label": row.get("crm_label") or row.get("crm_type") or "Aucune",
                "collateral_value": 0.0,
                "issuer_type": "",
                "issuer_rating": "",
                "maturity_bucket": "<=1 an",
                "fx_haircut": 0.0,
                "guarantor_name": str(row.get("guarantor_name") or ""),
                "guarantor_category": str(row.get("guarantor_category") or ""),
                "guarantor_rating": _normalize_rating_label(
                    row.get("guarantor_rating"),
                    fallback="",
                ),
                "guarantor_country": str(row.get("guarantor_country") or ""),
                "guarantor_country_rating": _normalize_rating_label(
                    row.get("guarantor_country_rating"),
                    fallback="",
                ),
                "guarantor_country_rw": float(row.get("guarantor_country_rw", 0.0) or 0.0),
                "coverage_percent": float(row.get("crm_coverage_percent", 0.0) or 0.0),
            }
            guarantor_rw = float(row.get("guarantor_rw", 0.0) or 0.0)
        else:
            crm_details = {
                "mode": "Aucune",
                "label": row.get("crm_type") or "Aucune",
                "coverage_percent": 0.0,
            }
            guarantor_rw = 0.0
        return {
            "id": str(row["id"]),
            "analysis_date": row["analysis_date"],
            "grant_date": row.get("grant_date"),
            "maturity_date": row.get("maturity_date"),
            "counterparty_name": str(row["counterparty_name"]),
            "country": str(row["country"]),
            "country_rating": _normalize_rating_label(row.get("country_rating")),
            "category_raw": str(row.get("category_raw") or row.get("category_standard") or "Entreprises"),
            "category_dashboard": str(row.get("category_standard") or "Entreprises"),
            "category_standard": str(row.get("category_standard") or "Entreprises"),
            "rating": _normalize_rating_label(row.get("rating")),
            "gross_amount": float(row.get("gross_amount", 0.0) or 0.0),
            "currency": str(row.get("currency") or "XOF"),
            "status": str(row.get("status") or "Active"),
            "sovereign_special_case": str(row.get("sovereign_special_case") or ""),
            "sovereign_preferential_zero_weight": bool(
                row.get("sovereign_preferential_zero_weight")
            ),
            "sovereign_oce_established": bool(row.get("sovereign_oce_established")),
            "sovereign_oce_note": str(row.get("sovereign_oce_note") or ""),
            "public_body_uemoa_fcfa_case": _nullable_int_to_bool(
                row.get("public_body_uemoa_fcfa_case")
            ),
            "public_body_non_public_activity": _nullable_int_to_bool(
                row.get("public_body_non_public_activity")
            ),
            "bmd_high_quality_case": _nullable_int_to_bool(
                row.get("bmd_high_quality_case")
            ),
            "bmd_uemoa_fcfa_case": _nullable_int_to_bool(
                row.get("bmd_uemoa_fcfa_case")
            ),
            "bmd_uemoa_criteria_satisfied": _nullable_int_to_bool(
                row.get("bmd_uemoa_criteria_satisfied")
            ),
            "bmd_listed_institution_fcfa_case": _nullable_int_to_bool(
                row.get("bmd_listed_institution_fcfa_case")
            ),
            "bank_institution_case": str(row.get("bank_institution_case") or "")
            or None,
            "other_asset_type": str(row.get("other_asset_type") or "") or None,
            "off_balance_risk_level":
                str(row.get("off_balance_risk_level") or "") or None,
            "retail_eligibility_criteria_satisfied": _nullable_int_to_bool(
                row.get("retail_eligibility_criteria_satisfied")
            ),
            "residential_mortgage_eligible": _nullable_int_to_bool(
                row.get("residential_mortgage_eligible")
            ),
            "commercial_real_estate_eligible": _nullable_int_to_bool(
                row.get("commercial_real_estate_eligible")
            ),
            "defaulted_exposure_initial_risk_weight": (
                float(row.get("defaulted_exposure_initial_risk_weight"))
                if row.get("defaulted_exposure_initial_risk_weight") is not None
                else None
            ),
            "defaulted_exposure_residential_mortgage_in_default": _nullable_int_to_bool(
                row.get("defaulted_exposure_residential_mortgage_in_default")
            ),
            "defaulted_exposure_provision_at_least_twenty_percent": _nullable_int_to_bool(
                row.get("defaulted_exposure_provision_at_least_twenty_percent")
            ),
            "enterprise_exceeds_bceao_degradation_threshold": _nullable_int_to_bool(
                row.get("enterprise_exceeds_bceao_degradation_threshold")
            ),
            "enterprise_prudential_procedure": _nullable_int_to_bool(
                row.get("enterprise_prudential_procedure")
            ),
            "enterprise_investment_firm_without_banking_law": _nullable_int_to_bool(
                row.get("enterprise_investment_firm_without_banking_law")
            ),
            "crm_exists": bool(row.get("crm_exists")),
            "crm_type": str(row.get("crm_type") or "Aucune"),
            "crm_mode": crm_mode,
            "crm_label": str(row.get("crm_label") or row.get("crm_type") or "Aucune"),
            "crm_coverage_percent": float(row.get("crm_coverage_percent", 0.0) or 0.0),
            "crm_details": crm_details,
            "guarantor_rw": guarantor_rw,
            "original_rw": float(row.get("original_rw", 0.0) or 0.0),
            "final_rw": float(row.get("final_rw", 0.0) or 0.0),
            "ead": float(row.get("ead", 0.0) or 0.0),
            "rwa": float(row.get("rwa", 0.0) or 0.0),
            "capital": float(row.get("capital", 0.0) or 0.0),
            "comment": row.get("comment"),
        }


exposure_repository = ExposureRepository()
