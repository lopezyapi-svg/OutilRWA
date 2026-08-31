"""Routes FastAPI du module FODEP."""

from __future__ import annotations

from fastapi import APIRouter, File, HTTPException, UploadFile, status
from fastapi.responses import Response

from app.fodep import excel, services
from app.fodep.dispru import FONDS_PROPRES_CODES, SOLVABILITE_SEUILS
from app.fodep.models import (
    AttestationUpdate,
    AttestationView,
    EtablissementUpdate,
    EtablissementView,
    FodepApercu,
    FondsPropresSave,
    ImportFodepResult,
    ParticipationEntry,
    ParticipationsSave,
)

router = APIRouter(prefix="/fodep", tags=["FODEP"])


@router.get("/dispru/fonds-propres")
def lister_codes_dispru() -> list[dict]:
    """Registre des 45 postes officiels (code, EP, groupe, libellé, signe)."""

    return [
        {
            "code": c.code,
            "ep": c.ep,
            "groupe": c.groupe,
            "label": c.label,
            "sign": c.sign,
            "paragraphes": list(c.paragraphes),
        }
        for c in FONDS_PROPRES_CODES
    ]


@router.get("/dispru/seuils")
def obtenir_seuils() -> dict[str, float]:
    return SOLVABILITE_SEUILS


@router.get("/fonds-propres", response_model=FodepApercu)
def obtenir_apercu(periode: str | None = None) -> FodepApercu:
    return services.generer_apercu(periode)


@router.put("/fonds-propres", response_model=FodepApercu)
def enregistrer(payload: FondsPropresSave) -> FodepApercu:
    if not payload.periode.strip():
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Période requise.")
    return services.enregistrer_fonds_propres(payload.periode.strip(), payload.postes)


@router.get("/participations", response_model=list[ParticipationEntry])
def lister_participations(periode: str | None = None) -> list[ParticipationEntry]:
    """Registre des participations dans des entités commerciales (EP35),
    utilisé pour les normes RA006-RA008."""

    return services.lister_participations(periode)


@router.put("/participations", response_model=list[ParticipationEntry])
def enregistrer_participations(payload: ParticipationsSave) -> list[ParticipationEntry]:
    if not payload.periode.strip():
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Période requise.")
    return services.enregistrer_participations(payload.periode.strip(), payload.lignes)


@router.get("/etablissement", response_model=EtablissementView)
def obtenir_etablissement() -> EtablissementView:
    return services.obtenir_etablissement()


@router.put("/etablissement", response_model=EtablissementView)
def enregistrer_etablissement(payload: EtablissementUpdate) -> EtablissementView:
    return services.enregistrer_etablissement(payload.denomination, payload.code_bceao)


@router.get("/attestation", response_model=AttestationView)
def obtenir_attestation() -> AttestationView:
    """Attestation de déclaration prudentielle (déclarant, qualité, lieu, date
    et corps du texte). Un texte réglementaire par défaut est fourni si rien
    n'a encore été saisi."""

    return services.obtenir_attestation()


@router.put("/attestation", response_model=AttestationView)
def enregistrer_attestation(payload: AttestationUpdate, periode: str | None = None) -> AttestationView:
    """Enregistre l'attestation type de l'établissement (réutilisée d'un arrêté
    à l'autre). Une date de signature non fournie reprend la date d'arrêté."""

    return services.enregistrer_attestation(payload, periode=periode)


@router.get("/template")
@router.get("/fonds-propres/template")
def telecharger_modele_officiel() -> Response:
    contenu = excel.get_matrice_officielle_template_bytes()
    nom = "Matrice_FODEP_Officielle.xlsx"
    return Response(
        content=contenu,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{nom}"'},
    )


@router.get("/fonds-propres/export")
def exporter_fonds_propres(periode: str | None = None) -> Response:
    apercu = services.generer_apercu(periode)
    etablissement = services.obtenir_etablissement()
    participations = services.lister_participations(periode)
    attestation = services.obtenir_attestation()
    from app.rwa_credit.services import get_rwa_credit_analysis

    contenu = excel.build_fonds_propres_export(
        apercu.periode,
        apercu.postes,
        etablissement=etablissement,
        participations=participations,
        apr=apercu.apr,
        totaux=apercu.totaux,
        analyse_credit=get_rwa_credit_analysis(),
        attestation=attestation,
    )
    nom = f"Matrice_FODEP_Officielle_{apercu.periode or 'brouillon'}.xlsx"
    return Response(
        content=contenu,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{nom}"'},
    )


@router.get("/fonds-propres/export-pdf")
def exporter_fonds_propres_pdf(periode: str | None = None) -> Response:
    """Rend en PDF le classeur officiel lui-meme, onglet par onglet.

    La conversion est faite en Python pur (openpyxl + reportlab) : le poste qui
    heberge l'API n'a besoin ni d'Excel, ni de LibreOffice, ni d'aucun logiciel
    installe a cote.
    """

    from app.fodep.xlsx_pdf import convertir_classeur_en_pdf
    from app.rwa_credit.services import get_rwa_credit_analysis

    apercu = services.generer_apercu(periode)
    etablissement = services.obtenir_etablissement()
    participations = services.lister_participations(periode)
    attestation = services.obtenir_attestation()

    contenu_xlsx = excel.build_fonds_propres_export(
        apercu.periode,
        apercu.postes,
        etablissement=etablissement,
        participations=participations,
        apr=apercu.apr,
        totaux=apercu.totaux,
        analyse_credit=get_rwa_credit_analysis(),
        attestation=attestation,
    )

    try:
        pdf_bytes = convertir_classeur_en_pdf(contenu_xlsx)
    except Exception as exc:  # noqa: BLE001 - remonte une erreur lisible au client
        raise HTTPException(
            status.HTTP_500_INTERNAL_SERVER_ERROR,
            f"Generation du PDF impossible : {exc}",
        ) from exc

    nom = f"Matrice_FODEP_Officielle_{apercu.periode or 'brouillon'}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{nom}"'},
    )


@router.post("/fonds-propres/import", response_model=ImportFodepResult)
async def importer_fonds_propres(file: UploadFile = File(...)) -> ImportFodepResult:
    contenu = await file.read()
    try:
        postes = excel.parse_fonds_propres_import(contenu)
    except Exception as exc:  # noqa: BLE001 - fichier utilisateur non maîtrisé
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"Fichier illisible : {exc}",
        ) from exc

    if not postes:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "Aucun montant numérique n'a été détecté pour les postes FODEP dans ce fichier. "
            "Veuillez renseigner vos montants dans la matrice officielle FODEP (Matrice_FODEP_Officielle.xlsx).",
        )

    import re
    periode_detectee = None
    if file.filename:
        m = re.search(r"(\d{2})[-_]?(\d{2})[-_]?(\d{4})", file.filename)
        if m:
            j, m_num, a = m.groups()
            if 1 <= int(j) <= 31 and 1 <= int(m_num) <= 12 and int(a) >= 2000:
                periode_detectee = f"{a}-{m_num.zfill(2)}-{j.zfill(2)}"
        if not periode_detectee:
            m = re.search(r"(\d{4})[-_]?(\d{2})[-_]?(\d{2})", file.filename)
            if m:
                a, m_num, j = m.groups()
                if 1 <= int(j) <= 31 and 1 <= int(m_num) <= 12 and int(a) >= 2000:
                    periode_detectee = f"{a}-{m_num.zfill(2)}-{j.zfill(2)}"

    ecarts = services.comparer_a_l_existant(postes)
    identifiant = services.enregistrer_import(
        file.filename or "import.xlsx",
        periode_detectee,
        postes,
    )

    return ImportFodepResult(
        id=identifiant,
        nom_fichier=file.filename or "import.xlsx",
        periode=periode_detectee,
        postes_detectes=postes,
        ecarts=ecarts,
    )
