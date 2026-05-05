"""Accès SQLite aux données CRM."""

from __future__ import annotations

from contextlib import nullcontext
from typing import Any

from database.connection import database_manager

_SQLITE_CHUNK_SIZE = 400


def _bool_to_int(value: bool) -> int:
    return 1 if value else 0


def _normalize_key(value: str) -> str:
    return " ".join(value.lower().strip().split())


def _chunked(values: list[str], size: int = _SQLITE_CHUNK_SIZE):
    for index in range(0, len(values), size):
        yield values[index : index + size]


class CrmRepository:
    """Fournit les synchronisations et vues CRM depuis SQLite."""

    def sync_exposure_crm(self, exposure_record: dict[str, Any], *, connection=None) -> None:
        self.sync_exposures_crm([exposure_record], connection=connection)

    def sync_exposures_crm(
        self,
        exposure_records: list[dict[str, Any]],
        *,
        connection=None,
    ) -> None:
        if not exposure_records:
            return

        manager = nullcontext(connection) if connection is not None else database_manager.transaction()
        with manager as active_connection:
            exposure_ids = [str(record["id"]) for record in exposure_records]
            for chunk in _chunked(exposure_ids):
                placeholders = ", ".join("?" for _ in chunk)
                active_connection.execute(
                    f"DELETE FROM crm_financed WHERE exposure_id IN ({placeholders})",
                    chunk,
                )
                active_connection.execute(
                    f"DELETE FROM crm_non_financed WHERE exposure_id IN ({placeholders})",
                    chunk,
                )

            financed_rows: list[tuple[Any, ...]] = []
            non_financed_rows: list[tuple[Any, ...]] = []
            for exposure_record in exposure_records:
                exposure_id = str(exposure_record["id"])
                crm_details = dict(exposure_record.get("crm_details", {}))
                crm_mode = str(
                    exposure_record.get("crm_mode")
                    or crm_details.get("mode")
                    or "Aucune"
                )

                if crm_mode == "CRM financee":
                    financed_rows.append(
                        (
                            exposure_id,
                            float(crm_details.get("collateral_value", 0.0) or 0.0),
                            str(crm_details.get("issuer_type", "") or ""),
                            str(crm_details.get("issuer_rating", "") or ""),
                            str(crm_details.get("maturity_bucket", "<=1 an") or "<=1 an"),
                            float(crm_details.get("fx_haircut", 0.0) or 0.0),
                            float(crm_details.get("haircut", 0.0) or 0.0),
                        )
                    )
                elif crm_mode == "CRM non financee":
                    non_financed_rows.append(
                        (
                            exposure_id,
                            str(crm_details.get("guarantor_name", "") or ""),
                            str(crm_details.get("guarantor_category", "") or ""),
                            str(crm_details.get("guarantor_rating", "") or ""),
                            str(crm_details.get("guarantor_country", "") or ""),
                            str(crm_details.get("guarantor_country_rating", "") or ""),
                            float(crm_details.get("guarantor_country_rw", 0.0) or 0.0),
                            float(exposure_record.get("guarantor_rw", 0.0) or 0.0),
                            float(
                                crm_details.get(
                                    "coverage_percent",
                                    exposure_record.get("crm_coverage_percent", 0.0),
                                )
                                or 0.0
                            ),
                        )
                    )

            if financed_rows:
                active_connection.executemany(
                    """
                    INSERT INTO crm_financed(
                        exposure_id,
                        collateral_value,
                        issuer_type,
                        issuer_rating,
                        maturity_bucket,
                        fx_haircut,
                        haircut
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(exposure_id) DO UPDATE SET
                        collateral_value = excluded.collateral_value,
                        issuer_type = excluded.issuer_type,
                        issuer_rating = excluded.issuer_rating,
                        maturity_bucket = excluded.maturity_bucket,
                        fx_haircut = excluded.fx_haircut,
                        haircut = excluded.haircut
                    """,
                    financed_rows,
                )

            if non_financed_rows:
                active_connection.executemany(
                    """
                    INSERT INTO crm_non_financed(
                        exposure_id,
                        guarantor_name,
                        guarantor_category,
                        guarantor_rating,
                        guarantor_country,
                        guarantor_country_rating,
                        guarantor_country_rw,
                        guarantor_rw,
                        coverage_percent
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(exposure_id) DO UPDATE SET
                        guarantor_name = excluded.guarantor_name,
                        guarantor_category = excluded.guarantor_category,
                        guarantor_rating = excluded.guarantor_rating,
                        guarantor_country = excluded.guarantor_country,
                        guarantor_country_rating = excluded.guarantor_country_rating,
                        guarantor_country_rw = excluded.guarantor_country_rw,
                        guarantor_rw = excluded.guarantor_rw,
                        coverage_percent = excluded.coverage_percent
                    """,
                    non_financed_rows,
                )

    def list_guarantees(self, search: str | None = None, guarantee_type: str | None = None) -> list[dict[str, Any]]:
        query = """
            SELECT
                e.id AS exposure_id,
                cp.name AS borrower_name,
                cp.category_standard AS borrower_category,
                cp.rating AS borrower_rating,
                e.gross_amount,
                e.crm_type AS guarantee_type,
                e.crm_mode,
                e.crm_label,
                e.crm_coverage_percent,
                e.original_rw AS borrower_rw,
                e.final_rw,
                e.ead,
                e.rwa,
                e.capital,
                cf.collateral_value,
                cf.issuer_type,
                cf.issuer_rating,
                cf.maturity_bucket,
                cf.fx_haircut,
                cf.haircut,
                cn.guarantor_name,
                cn.guarantor_category,
                cn.guarantor_rating,
                cn.guarantor_rw
            FROM exposures e
            INNER JOIN counterparties cp ON cp.id = e.counterparty_id
            LEFT JOIN crm_financed cf ON cf.exposure_id = e.id
            LEFT JOIN crm_non_financed cn ON cn.exposure_id = e.id
            WHERE e.crm_mode <> 'Aucune'
        """
        params: list[Any] = []
        if search:
            like = f"%{search.lower()}%"
            query += " AND (LOWER(cp.name) LIKE ? OR LOWER(COALESCE(cn.guarantor_name, cf.issuer_type, '')) LIKE ?)"
            params.extend([like, like])
        if guarantee_type:
            query += " AND LOWER(e.crm_type) = ?"
            params.append(guarantee_type.lower())
        query += " ORDER BY e.id"

        with database_manager.connect() as connection:
            rows = connection.execute(query, params).fetchall()

        items: list[dict[str, Any]] = []
        for row in rows:
            coverage_ratio = float(row["crm_coverage_percent"] or 0.0)
            gross_amount = float(row["gross_amount"] or 0.0)
            coverage_amount = 0.0
            guarantor_name = "Sans garant"
            guarantor_category = row["borrower_category"]
            guarantor_rating = row["borrower_rating"]
            guarantor_rw = float(row["borrower_rw"] or 0.0)

            if row["crm_mode"] == "CRM financee":
                coverage_amount = float(row["collateral_value"] or 0.0)
                guarantor_name = str(row["issuer_type"] or "Garant non renseigne")
                guarantor_category = "Souverains" if _normalize_key(guarantor_name) == "souverain" else "Entreprises"
                guarantor_rating = str(row["issuer_rating"] or row["borrower_rating"] or "Non noté")
            else:
                coverage_amount = round(gross_amount * coverage_ratio, 2)
                guarantor_name = str(row["guarantor_name"] or "Garant non renseigne")
                guarantor_category = str(row["guarantor_category"] or row["borrower_category"])
                guarantor_rating = str(row["guarantor_rating"] or row["borrower_rating"])
                guarantor_rw = float(row["guarantor_rw"] or 0.0)

            rwa_before = round(float(row["ead"] or 0.0) * float(row["borrower_rw"] or 0.0), 2)
            capital_before = round(rwa_before * 0.08, 2)
            rwa_after = round(float(row["rwa"] or 0.0), 2)
            capital_after = round(float(row["capital"] or 0.0), 2)

            items.append(
                {
                    "id": f"CRM_{row['exposure_id']}",
                    "exposure_id": row["exposure_id"],
                    "borrower_name": row["borrower_name"],
                    "borrower_category": row["borrower_category"],
                    "borrower_rating": row["borrower_rating"],
                    "gross_amount": gross_amount,
                    "guarantor_name": guarantor_name,
                    "guarantor_category": guarantor_category,
                    "guarantor_rating": guarantor_rating,
                    "guarantee_type": row["guarantee_type"],
                    "coverage_amount": coverage_amount,
                    "coverage_ratio": coverage_ratio,
                    "borrower_rw": float(row["borrower_rw"] or 0.0),
                    "guarantor_rw": guarantor_rw,
                    "final_rw": float(row["final_rw"] or 0.0),
                    "ead": float(row["ead"] or 0.0),
                    "rwa_before": rwa_before,
                    "rwa_after": rwa_after,
                    "capital_before": capital_before,
                    "capital_after": capital_after,
                    "rwa_reduction": round(rwa_before - rwa_after, 2),
                    "capital_saving": round(capital_before - capital_after, 2),
                }
            )
        return items


crm_repository = CrmRepository()
