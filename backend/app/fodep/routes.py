"""Routes FastAPI du module FODEP."""

from __future__ import annotations

from fastapi import APIRouter, File, HTTPException, UploadFile, status
from fastapi.responses import Response

from app.fodep import excel, services
from app.fodep.dispru import FONDS_PROPRES_CODES, SOLVABILITE_SEUILS
from app.fodep.models import (
    EtablissementUpdate,
    EtablissementView,
    FodepApercu,
    FondsPropresSave,
    ImportFodepResult,
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


@router.get("/etablissement", response_model=EtablissementView)
def obtenir_etablissement() -> EtablissementView:
    return services.obtenir_etablissement()


@router.put("/etablissement", response_model=EtablissementView)
def enregistrer_etablissement(payload: EtablissementUpdate) -> EtablissementView:
    return services.enregistrer_etablissement(payload.denomination, payload.code_bceao)


@router.get("/fonds-propres/export")
def exporter_fonds_propres(periode: str | None = None) -> Response:
    apercu = services.generer_apercu(periode)
    contenu = excel.build_fonds_propres_export(apercu.periode, apercu.postes)
    nom = f"FODEP_fonds_propres_{apercu.periode or 'brouillon'}.xlsx"
    return Response(
        content=contenu,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
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
            "Aucun poste FODEP reconnu dans ce fichier. Le format attendu est "
            "celui produit par l'export FODEP de cet outil (colonnes Code / "
            "EP / Groupe / Libellé / Valeur).",
        )

    ecarts = services.comparer_a_l_existant(postes)
    identifiant = services.enregistrer_import(file.filename or "import.xlsx", None, postes)

    return ImportFodepResult(
        id=identifiant,
        nom_fichier=file.filename or "import.xlsx",
        periode=None,
        postes_detectes=postes,
        ecarts=ecarts,
    )
