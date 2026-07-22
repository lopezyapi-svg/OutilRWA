"""Endpoints d'authentification."""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, Request, Response, status

from app.auth.models import LoginRequest, TokenResponse, UserProfile
from app.auth.service import (
    AuthenticationError,
    SessionOuverte,
    authentifier,
    fermer_session,
    renouveler,
)
from app.core.config import settings

router = APIRouter(prefix="/auth", tags=["Authentification"])


def _poser_cookie(response: Response, session: SessionOuverte) -> None:
    """Depose le jeton de renouvellement hors de portee du JavaScript."""

    expire_le = session.refresh_expire_le
    duree = int(
        (expire_le - datetime.now(timezone.utc)).total_seconds()
    ) if isinstance(expire_le, datetime) else settings.refresh_token_hours * 3600
    response.set_cookie(
        key=settings.refresh_cookie_name,
        value=session.refresh_token,
        max_age=max(duree, 0),
        # httponly : illisible par document.cookie, donc hors d'atteinte d'un XSS.
        httponly=True,
        # secure : jamais transmis en clair.
        secure=settings.refresh_cookie_secure,
        # strict : pas envoye depuis un autre site, ce qui coupe le CSRF.
        samesite="strict",
        # Le cookie n'est utile qu'aux routes d'authentification : il n'accompagne
        # donc pas les cent autres requetes de l'application.
        #
        # Ce chemin est celui vu par le NAVIGATEUR, pas celui vu par l'API.
        # Derriere un proxy qui prefixe les appels par /api, le navigateur
        # s'adresse a /api/auth/refresh : un cookie pose sur « /auth » ne lui
        # serait jamais renvoye et la session serait perdue a chaque
        # rechargement. D'ou la configuration par l'environnement.
        path=settings.refresh_cookie_path,
    )


def _effacer_cookie(response: Response) -> None:
    response.delete_cookie(
        key=settings.refresh_cookie_name,
        path=settings.refresh_cookie_path,
        httponly=True,
        secure=settings.refresh_cookie_secure,
        samesite="strict",
    )


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, response: Response) -> TokenResponse:
    """Ouvre une session a partir d'un identifiant et d'un mot de passe."""

    try:
        session = authentifier(payload.identifiant, payload.mot_de_passe)
    except AuthenticationError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(exc),
        ) from exc

    _poser_cookie(response, session)
    return TokenResponse(
        access_token=session.access_token,
        expires_in=session.expires_in,
        profil=session.profil,
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh(request: Request, response: Response) -> TokenResponse:
    """Delivre un nouveau jeton d'acces a partir du cookie de session."""

    jeton = request.cookies.get(settings.refresh_cookie_name)
    if not jeton:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Aucune session ouverte.",
        )
    try:
        session = renouveler(jeton)
    except AuthenticationError as exc:
        _effacer_cookie(response)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(exc),
        ) from exc

    _poser_cookie(response, session)
    return TokenResponse(
        access_token=session.access_token,
        expires_in=session.expires_in,
        profil=session.profil,
    )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(request: Request, response: Response) -> Response:
    """Revoque la session courante et efface le cookie."""

    fermer_session(request.cookies.get(settings.refresh_cookie_name))
    _effacer_cookie(response)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/me", response_model=UserProfile)
def profil_courant(request: Request) -> UserProfile:
    """Retourne le profil porte par le jeton d'acces."""

    utilisateur = getattr(request.state, "utilisateur", None)
    if not utilisateur:
        # Sans authentification active, l'API n'a pas de notion d'utilisateur :
        # annoncer un role d'edition serait mentir au client.
        if not settings.auth_enabled:
            return UserProfile(identifiant="local", role="edition")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentification requise.",
        )
    return UserProfile(
        identifiant=str(utilisateur["identifiant"]),
        role=str(utilisateur["role"]),
    )
