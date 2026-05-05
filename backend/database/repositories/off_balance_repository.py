"""Accès SQLite aux engagements hors bilan."""

from __future__ import annotations

from contextlib import nullcontext
from typing import Any

from database.connection import database_manager, utcnow_iso

_SQLITE_CHUNK_SIZE = 400


def _chunked(values: list[str], size: int = _SQLITE_CHUNK_SIZE):
    for index in range(0, len(values), size):
        yield values[index : index + size]


class OffBalanceRepository:
    """Persiste et lit les engagements hors bilan."""

    def list_commitments(self, search: str | None = None, engagement_type: str | None = None) -> list[dict[str, Any]]:
        query = """
            SELECT
                hb.id,
                hb.analysis_date,
                hb.counterparty_id,
                cp.name AS counterparty_name,
                cp.category_standard AS category,
                cp.rating,
                hb.engagement_type,
                hb.nominal_amount,
                hb.ccf,
                hb.ead,
                hb.risk_weight,
                hb.rwa,
                hb.capital,
                hb.comment
            FROM off_balance_commitments hb
            INNER JOIN counterparties cp ON cp.id = hb.counterparty_id
            WHERE 1 = 1
        """
        params: list[Any] = []
        if search:
            like = f"%{search.lower()}%"
            query += " AND (LOWER(hb.id) LIKE ? OR LOWER(cp.name) LIKE ?)"
            params.extend([like, like])
        if engagement_type:
            query += " AND hb.engagement_type = ?"
            params.append(engagement_type)
        query += " ORDER BY hb.id"

        with database_manager.connect() as connection:
            rows = connection.execute(query, params).fetchall()
        return [dict(row) for row in rows]

    def next_commitment_id(self) -> str:
        with database_manager.connect() as connection:
            rows = connection.execute(
                """
                SELECT id
                FROM off_balance_commitments
                WHERE id LIKE 'HB%'
                """
            ).fetchall()
        max_index = 0
        for row in rows:
            identifier = str(row["id"])
            try:
                max_index = max(max_index, int(identifier[2:]))
            except ValueError:
                continue
        return f"HB{max_index + 1:03d}"

    def get_existing_ids(self, commitment_ids: list[str], *, connection=None) -> set[str]:
        normalized_ids = sorted({str(item).strip() for item in commitment_ids if str(item).strip()})
        if not normalized_ids:
            return set()

        active_connection = connection or database_manager.connect()
        try:
            existing_ids: set[str] = set()
            for chunk in _chunked(normalized_ids):
                placeholders = ", ".join("?" for _ in chunk)
                rows = active_connection.execute(
                    f"SELECT id FROM off_balance_commitments WHERE id IN ({placeholders})",
                    chunk,
                ).fetchall()
                existing_ids.update(str(row["id"]) for row in rows)
            return existing_ids
        finally:
            if connection is None:
                active_connection.close()

    def upsert_commitment(self, record: dict[str, Any], *, connection=None) -> dict[str, Any]:
        self.upsert_commitments([record], connection=connection)
        return record

    def upsert_commitments(self, records: list[dict[str, Any]], *, connection=None) -> list[dict[str, Any]]:
        if not records:
            return []
        manager = nullcontext(connection) if connection is not None else database_manager.transaction()
        with manager as active_connection:
            now = utcnow_iso()
            active_connection.executemany(
                """
                INSERT INTO off_balance_commitments(
                    id,
                    counterparty_id,
                    analysis_date,
                    engagement_type,
                    nominal_amount,
                    ccf,
                    ead,
                    risk_weight,
                    rwa,
                    capital,
                    comment,
                    created_at,
                    updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    counterparty_id = excluded.counterparty_id,
                    analysis_date = excluded.analysis_date,
                    engagement_type = excluded.engagement_type,
                    nominal_amount = excluded.nominal_amount,
                    ccf = excluded.ccf,
                    ead = excluded.ead,
                    risk_weight = excluded.risk_weight,
                    rwa = excluded.rwa,
                    capital = excluded.capital,
                    comment = excluded.comment,
                    updated_at = excluded.updated_at
                """,
                [
                    (
                        str(record["id"]),
                        str(record["counterparty_id"]),
                        record["analysis_date"].isoformat()
                        if hasattr(record["analysis_date"], "isoformat")
                        else str(record["analysis_date"]),
                        str(record["engagement_type"]),
                        float(record["nominal_amount"]),
                        float(record["ccf"]),
                        float(record["ead"]),
                        float(record["risk_weight"]),
                        float(record["rwa"]),
                        float(record["capital"]),
                        record.get("comment"),
                        now,
                        now,
                    )
                    for record in records
                ],
            )
        return [dict(record) for record in records]

    def replace_all(self, records: list[dict[str, Any]], *, connection=None) -> list[dict[str, Any]]:
        manager = nullcontext(connection) if connection is not None else database_manager.transaction()
        with manager as active_connection:
            active_connection.execute("DELETE FROM off_balance_commitments")
            self.upsert_commitments(records, connection=active_connection)
        return [dict(record) for record in records]


off_balance_repository = OffBalanceRepository()
