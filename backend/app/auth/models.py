"""Modeles d'echange du module d'authentification."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

# Deux roles, et deux seulement. Toute valeur inconnue doit etre refusee a
# l'ecriture comme a la lecture : un role non reconnu ne doit jamais tomber
# dans le cas permissif.
Role = Literal["consultation", "edition"]

ROLES: tuple[str, ...] = ("consultation", "edition")


class LoginRequest(BaseModel):
    """Identifiants soumis a la connexion."""

    identifiant: str = Field(min_length=1, max_length=120)
    # bcrypt ne prend en compte que les 72 premiers octets : au-dela, deux mots
    # de passe differents produiraient la meme empreinte. La limite est donc
    # posee a la saisie plutot que subie silencieusement.
    mot_de_passe: str = Field(min_length=8, max_length=72)


class UserProfile(BaseModel):
    """Profil renvoye au client apres authentification."""

    identifiant: str
    role: Role
    nom_complet: str | None = None
    derniere_connexion: str | None = None

    @property
    def peut_editer(self) -> bool:
        return self.role == "edition"


class TokenResponse(BaseModel):
    """Jeton d'acces et profil associe.

    Le jeton de renouvellement n'apparait pas ici : il est depose dans un
    cookie HttpOnly, hors de portee du JavaScript.
    """

    access_token: str
    token_type: str = "bearer"
    expires_in: int
    profil: UserProfile
