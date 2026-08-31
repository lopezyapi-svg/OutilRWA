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


class ParticipationEntry(BaseModel):
    id: str | None = None
    denomination_emettrice: str
    capital_emettrice: float
    montant_net: float


class ParticipationsSave(BaseModel):
    periode: str
    lignes: list[ParticipationEntry]


class ImportFodepResult(BaseModel):
    id: str
    nom_fichier: str
    periode: str | None
    postes_detectes: dict[str, float]
    ecarts: dict[str, dict[str, float]]


class AttestationView(BaseModel):
    rens_prenoms_nom: str
    rens_fonction: str
    rens_telephone: str
    rens_poste: str
    rens_email: str
    trans_prenoms_nom: str
    trans_fonction: str
    trans_telephone: str
    trans_poste: str
    trans_email: str
    certif_nous_1: str
    certif_nous_2: str
    sign1_code: str
    sign1_fonction: str
    sign1_date: str
    sign1_image: str
    sign2_code: str
    sign2_fonction: str
    sign2_date: str
    sign2_image: str


class AttestationUpdate(BaseModel):
    rens_prenoms_nom: str = ""
    rens_fonction: str = ""
    rens_telephone: str = ""
    rens_poste: str = ""
    rens_email: str = ""
    trans_prenoms_nom: str = ""
    trans_fonction: str = ""
    trans_telephone: str = ""
    trans_poste: str = ""
    trans_email: str = ""
    certif_nous_1: str = ""
    certif_nous_2: str = ""
    sign1_code: str = ""
    sign1_fonction: str = ""
    sign1_date: str = ""
    sign1_image: str = ""
    sign2_code: str = ""
    sign2_fonction: str = ""
    sign2_date: str = ""
    sign2_image: str = ""
