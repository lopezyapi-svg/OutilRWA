"""Acces SQLite aux rapports generes."""

from __future__ import annotations

from contextlib import nullcontext
from typing import Any

from database.connection import database_manager


def _bool_to_int(value: bool) -> int:
    return 1 if value else 0


class ReportRepository:
    """Persiste les rapports et leurs lignes dans SQLite."""

    def list_reports(self) -> list[dict[str, Any]]:
        with database_manager.connect() as connection:
            report_rows = connection.execute(
                """
                SELECT
                    id,
                    created_at,
                    period,
                    report_type,
                    currency,
                    exposure_scope,
                    include_category_chart,
                    include_rating_chart,
                    export_pdf_path,
                    export_excel_path
                FROM reports
                ORDER BY created_at DESC, id DESC
                """
            ).fetchall()

            line_rows = connection.execute(
                """
                SELECT
                    report_id,
                    line_order,
                    source,
                    item_id,
                    counterparty,
                    amount,
                    ead,
                    rwa,
                    capital
                FROM report_lines
                ORDER BY report_id, line_order
                """
            ).fetchall()

        lines_by_report: dict[str, list[dict[str, Any]]] = {}
        for row in line_rows:
            row_dict = dict(row)
            report_id = str(row_dict.pop("report_id"))
            row_dict.pop("line_order", None)
            lines_by_report.setdefault(report_id, []).append(row_dict)

        reports: list[dict[str, Any]] = []
        for row in report_rows:
            row_dict = dict(row)
            report_id = str(row_dict["id"])
            reports.append(
                {
                    "id": report_id,
                    "created_at": row_dict["created_at"],
                    "period": row_dict["period"],
                    "report_type": row_dict["report_type"],
                    "currency": row_dict["currency"],
                    "exposure_scope": row_dict["exposure_scope"],
                    "include_category_chart": bool(row_dict["include_category_chart"]),
                    "include_rating_chart": bool(row_dict["include_rating_chart"]),
                    "exports": {
                        "pdf": row_dict["export_pdf_path"],
                        "excel": row_dict["export_excel_path"],
                    },
                    "lines": lines_by_report.get(report_id, []),
                }
            )
        return reports

    def next_report_id(self) -> str:
        with database_manager.connect() as connection:
            rows = connection.execute(
                """
                SELECT id
                FROM reports
                WHERE id LIKE 'RPT%'
                """
            ).fetchall()
        max_index = 0
        for row in rows:
            identifier = str(row["id"])
            try:
                max_index = max(max_index, int(identifier[3:]))
            except ValueError:
                continue
        return f"RPT{max_index + 1:03d}"

    def save_report(self, report: dict[str, Any], *, connection=None) -> dict[str, Any]:
        manager = nullcontext(connection) if connection is not None else database_manager.transaction()
        with manager as active_connection:
            active_connection.execute(
                """
                INSERT INTO reports(
                    id,
                    created_at,
                    period,
                    report_type,
                    currency,
                    exposure_scope,
                    include_category_chart,
                    include_rating_chart,
                    export_pdf_path,
                    export_excel_path
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    created_at = excluded.created_at,
                    period = excluded.period,
                    report_type = excluded.report_type,
                    currency = excluded.currency,
                    exposure_scope = excluded.exposure_scope,
                    include_category_chart = excluded.include_category_chart,
                    include_rating_chart = excluded.include_rating_chart,
                    export_pdf_path = excluded.export_pdf_path,
                    export_excel_path = excluded.export_excel_path
                """,
                (
                    str(report["id"]),
                    report["created_at"].isoformat() if hasattr(report["created_at"], "isoformat") else str(report["created_at"]),
                    str(report["period"]),
                    str(report["report_type"]),
                    str(report["currency"]),
                    str(report["exposure_scope"]),
                    _bool_to_int(bool(report["include_category_chart"])),
                    _bool_to_int(bool(report["include_rating_chart"])),
                    str(report["exports"]["pdf"]),
                    str(report["exports"]["excel"]),
                ),
            )
            active_connection.execute(
                "DELETE FROM report_lines WHERE report_id = ?",
                (str(report["id"]),),
            )
            active_connection.executemany(
                """
                INSERT INTO report_lines(
                    report_id,
                    line_order,
                    source,
                    item_id,
                    counterparty,
                    amount,
                    ead,
                    rwa,
                    capital
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    (
                        str(report["id"]),
                        index,
                        str(line["source"]),
                        str(line["item_id"]),
                        str(line["counterparty"]),
                        float(line["amount"]),
                        float(line["ead"]),
                        float(line["rwa"]),
                        float(line["capital"]),
                    )
                    for index, line in enumerate(report.get("lines", []), start=1)
                ],
            )
        return dict(report)


report_repository = ReportRepository()
