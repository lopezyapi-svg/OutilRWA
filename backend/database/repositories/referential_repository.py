"""Accès SQLite aux référentiels prudentiels."""

from __future__ import annotations

from contextlib import nullcontext
import unicodedata
from typing import Any

from app.core.calculations import bucketize_rating
from app.referentiels.models import CcfReference, RatingReference, ReferentialBundle, RiskWeightReference
from database.connection import database_manager


def _as_float(value: Any) -> float:
    if value is None:
        return 0.0
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip().replace("\u202f", "").replace(" ", "").replace(",", ".")
    try:
        return float(text)
    except ValueError:
        return 0.0


def _as_text(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip()


def _normalize_key(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value.strip().lower())
    normalized = "".join(char for char in normalized if not unicodedata.combining(char))
    return " ".join(normalized.split())


def _normalize_rating_label(value: str) -> str:
    if not value:
        return "Non noté"
    lowered = value.lower().strip()
    if lowered in {"non noté", "non note", "non_noté", "non_note"}:
        return "Non noté"
    return value.strip()


def _is_rating_label(value: str) -> bool:
    allowed = {
        "AAA",
        "AA+",
        "AA",
        "AA-",
        "A+",
        "A",
        "A-",
        "BBB+",
        "BBB",
        "BBB-",
        "BB+",
        "BB",
        "BB-",
        "B+",
        "B",
        "B-",
        "< B-",
        "Non noté",
    }
    return value in allowed


def build_referential_payload(ref_rows: list[list[Any]]) -> dict[str, list[dict[str, Any]]]:
    risk_weights: list[dict[str, Any]] = []
    ccf_rows: list[dict[str, Any]] = []
    ratings: list[dict[str, Any]] = []
    seen_ratings: set[str] = set()

    sequence = 1
    segment_columns = [
        ("Souverains", 1, 2),
        ("Organismes publics", 4, 5),
        ("Entreprises", 7, 8),
        ("Banques <=3m", 10, 11),
        ("Banques >3m", 13, 14),
    ]
    for raw in ref_rows:
        for segment, rating_col, rw_col in segment_columns:
            rating = _normalize_rating_label(_as_text(raw[rating_col - 1]))
            risk_weight = _as_float(raw[rw_col - 1])
            if not _is_rating_label(rating):
                continue
            risk_weights.append(
                {
                    "id": f"RW{sequence:03d}",
                    "segment": segment,
                    "rating": rating,
                    "risk_weight": risk_weight,
                    "approach": "Standard",
                }
            )
            lowered = rating.lower()
            if lowered not in seen_ratings:
                seen_ratings.add(lowered)
                ratings.append(
                    {
                        "id": f"RT{len(ratings) + 1:03d}",
                        "label": rating,
                        "description": f"Notation {rating}",
                        "sort_order": len(ratings) + 1,
                    }
                )
            sequence += 1

    ccf_sequence = 1
    for raw in ref_rows:
        engagement_type = _as_text(raw[15])
        ccf = _as_float(raw[16])
        if not engagement_type or engagement_type == "Type_HB":
            continue
        ccf_rows.append(
            {
                "id": f"CCF{ccf_sequence:03d}",
                "engagement_type": engagement_type,
                "ccf": ccf,
            }
        )
        ccf_sequence += 1

    return {
        "risk_weights": risk_weights,
        "ccf_table": ccf_rows,
        "ratings": ratings,
        "country_ratings": [],
    }


class ReferentialRepository:
    """Fournit les référentiels depuis SQLite."""

    def list_risk_weight_references(self) -> list[RiskWeightReference]:
        with database_manager.connect() as connection:
            rows = connection.execute(
                """
                SELECT id, segment, notation AS rating, ponderation AS risk_weight, approche AS approach
                FROM baremes_ponderation
                ORDER BY segment, id
                """
            ).fetchall()
        return [RiskWeightReference(**dict(row)) for row in rows]

    def list_ccf_references(self) -> list[CcfReference]:
        with database_manager.connect() as connection:
            rows = connection.execute(
                """
                SELECT id, type_engagement AS engagement_type, ccf
                FROM baremes_ccf
                ORDER BY id
                """
            ).fetchall()
        return [CcfReference(**dict(row)) for row in rows]

    def list_rating_references(self) -> list[RatingReference]:
        with database_manager.connect() as connection:
            rows = connection.execute(
                """
                SELECT id, libelle AS label, description, ordre_tri AS sort_order
                FROM references_notation
                ORDER BY ordre_tri, id
                """
            ).fetchall()
        return [RatingReference(**dict(row)) for row in rows]

    def get_referential_bundle(self) -> ReferentialBundle:
        return ReferentialBundle(
            risk_weights=self.list_risk_weight_references(),
            ccf_table=self.list_ccf_references(),
            ratings=self.list_rating_references(),
        )

    def replace_all(
        self,
        *,
        risk_weights: list[dict[str, Any]],
        ccf_table: list[dict[str, Any]],
        ratings: list[dict[str, Any]],
        country_ratings: list[dict[str, Any]] | None = None,
        connection=None,
    ) -> None:
        manager = nullcontext(connection) if connection is not None else database_manager.transaction()
        with manager as active_connection:
            active_connection.execute("DELETE FROM references_pays_souverains")
            active_connection.execute("DELETE FROM references_notation")
            active_connection.execute("DELETE FROM baremes_ccf")
            active_connection.execute("DELETE FROM baremes_ponderation")

            if risk_weights:
                active_connection.executemany(
                    """
                    INSERT INTO baremes_ponderation(id, segment, notation, ponderation, approche)
                    VALUES (:id, :segment, :rating, :risk_weight, :approach)
                    """,
                    risk_weights,
                )
            if ccf_table:
                active_connection.executemany(
                    """
                    INSERT INTO baremes_ccf(id, type_engagement, ccf)
                    VALUES (:id, :engagement_type, :ccf)
                    """,
                    ccf_table,
                )
            if ratings:
                active_connection.executemany(
                    """
                    INSERT INTO references_notation(id, libelle, description, ordre_tri)
                    VALUES (:id, :label, :description, :sort_order)
                    """,
                    ratings,
                )
            if country_ratings:
                active_connection.executemany(
                    """
                    INSERT INTO references_pays_souverains(pays, notation_souveraine, ponderation)
                    VALUES (:country, :sovereign_rating, :risk_weight)
                    """,
                    country_ratings,
                )

    def get_risk_weight(self, segment: str, rating: str) -> float:
        target_bucket = bucketize_rating(rating)
        target_candidates = {target_bucket, target_bucket.replace(" ", ""), rating}
        references = self.list_risk_weight_references()
        exact = next(
            (
                reference.risk_weight
                for reference in references
                if _normalize_key(reference.segment) == _normalize_key(segment)
                and reference.rating in target_candidates
            ),
            None,
        )
        if exact is not None:
            return exact
        if _normalize_key(segment) == "banques":
            for option in ("Banques >3m", "Banques <=3m"):
                found = next(
                    (
                        reference.risk_weight
                        for reference in references
                        if _normalize_key(reference.segment) == _normalize_key(option)
                        and reference.rating in target_candidates
                    ),
                    None,
                )
                if found is not None:
                    return found
        if _normalize_key(segment) == "particuliers":
            found = next(
                (
                    reference.risk_weight
                    for reference in references
                    if _normalize_key(reference.segment) == "entreprises"
                    and reference.rating in target_candidates
                ),
                None,
            )
            if found is not None:
                return found
        fallback = next(
            (
                reference.risk_weight
                for reference in references
                if _normalize_key(reference.segment) == "entreprises"
                and reference.rating in target_candidates
            ),
            None,
        )
        return fallback if fallback is not None else 1.0

    def get_ccf(self, engagement_type: str) -> float:
        lowered = _normalize_key(engagement_type)
        for reference in self.list_ccf_references():
            if _normalize_key(reference.engagement_type) == lowered:
                return reference.ccf
        return 1.0

    def is_empty(self) -> bool:
        with database_manager.connect() as connection:
            row = connection.execute("SELECT COUNT(*) AS total FROM baremes_ponderation").fetchone()
        return row is None or int(row["total"]) == 0


referential_repository = ReferentialRepository()
