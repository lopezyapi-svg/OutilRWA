"""Modèles Pydantic du module FODEP."""

from __future__ import annotations

from pydantic import BaseModel


class FondsPropresSave(BaseModel):
    periode: str
    postes: dict[str, float]


class AprDetail(BaseModel):
    rwa_credit: float
    rwa_marche: float
    rwa_operationnel: float
    apr_total: float


class RatioDetail(BaseModel):
    value: float
    threshold: float
    diff_points: float
    status: str


class FodepApercu(BaseModel):
    periode: str | None
    postes: dict[str, float]
    totaux: dict[str, float]
    apr: AprDetail
    ratios: dict[str, RatioDetail]
    source_prefill: bool


class EtablissementView(BaseModel):
    denomination: str
    code_bceao: str


class EtablissementUpdate(BaseModel):
    denomination: str
    code_bceao: str


class ImportFodepResult(BaseModel):
    id: str
    nom_fichier: str
    periode: str | None
    postes_detectes: dict[str, float]
    ecarts: dict[str, dict[str, float]]
