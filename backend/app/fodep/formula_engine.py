"""Recalcul des formules du classeur FODEP officiel, en Python pur.

openpyxl sait lire et reecrire les formules, mais ne les calcule jamais : apres
`build_fonds_propres_export`, les cellules de totaux ne contiennent que du texte
`=C11+C12+...` et plus aucune valeur en cache. Sans recalcul, le PDF afficherait
des totaux vides la ou le classeur ouvert dans Excel affiche des montants.

Ce module evalue donc les formules lui-meme. La grammaire implementee n'est pas
celle d'Excel en general : c'est exactement celle relevee dans la matrice
officielle BCEAO (588 formules), volontairement close et donc verifiable :

    - operateurs      + - * / et le suffixe % (ex. `=C66*17.65%`)
    - unaires         + et - en tete (ex. `=+'EP03'!C69`, `=-C67`)
    - comparaisons    = <> < <= > >=
    - fonction        IF(condition, alors, sinon)
    - references      C11, $G10, G$10, $G$10, 'EP02'!F10, EP02!F10
    - litteraux       nombres, decimaux, chaines entre guillemets
    - aucune plage    (A1:B5) : le classeur officiel n'en contient aucune

Toute construction hors de cette grammaire leve `FormuleNonSupportee`, plutot
que de produire un nombre faux en silence : sur un document prudentiel, une
valeur inventee est pire qu'une erreur visible.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any

# ── Valeurs d'erreur ────────────────────────────────────────────────────────


@dataclass(frozen=True)
class ErreurExcel:
    """Equivalent des #DIV/0! et autres valeurs d'erreur d'Excel."""

    code: str

    def __str__(self) -> str:  # pragma: no cover - trivial
        return self.code


DIV_ZERO = ErreurExcel("#DIV/0!")
VALEUR = ErreurExcel("#VALUE!")
REFERENCE = ErreurExcel("#REF!")
CYCLE = ErreurExcel("#CYCLE!")


class FormuleNonSupportee(ValueError):
    """La formule sort de la grammaire relevee dans la matrice officielle."""


# ── Analyse lexicale ────────────────────────────────────────────────────────

# Une reference peut etre prefixee d'un nom d'onglet, entre apostrophes ou non.
# La forme entre apostrophes couvre les noms accentues ou espaces
# (`'Liste_EP_a_renseigner'!B4`) ; deux apostrophes y representent une
# apostrophe litterale, comme dans Excel.
_MOTIF_JETONS = re.compile(
    r"""
    (?P<espace>\s+)
  | (?P<nombre>\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|\.\d+)
  | (?P<chaine>"(?:[^"]|"")*")
  | (?P<ref>
        (?:
            '(?:[^']|'')+'          # nom d'onglet entre apostrophes
          | [A-Za-z_][A-Za-z0-9_.]* # nom d'onglet nu
        )
        !
    )?
    \$?(?P<col>[A-Za-z]{1,3})\$?(?P<lig>\d{1,7})\b
  | (?P<fonction>[A-Za-z][A-Za-z0-9_.]*)\s*(?=\()
  | (?P<compare><>|<=|>=|<|>|=)
  | (?P<operateur>[+\-*/])
  | (?P<pourcent>%)
  | (?P<parO>\()
  | (?P<parF>\))
  | (?P<virgule>[,;])
    """,
    re.VERBOSE,
)


@dataclass(frozen=True)
class Jeton:
    genre: str
    texte: str
    # Renseignes uniquement pour les references de cellule.
    onglet: str | None = None
    colonne: str | None = None
    ligne: int | None = None


def _decouper(formule: str) -> list[Jeton]:
    """Transforme une formule en liste de jetons."""

    jetons: list[Jeton] = []
    position = 0
    longueur = len(formule)

    while position < longueur:
        correspondance = _MOTIF_JETONS.match(formule, position)
        if correspondance is None:
            raise FormuleNonSupportee(
                f"Caractere inattendu a la position {position} dans « {formule} »"
            )
        position = correspondance.end()
        groupes = correspondance.groupdict()

        if groupes["espace"]:
            continue

        if groupes["col"] is not None:
            onglet = groupes["ref"]
            if onglet:
                onglet = onglet[:-1]  # retire le « ! »
                if onglet.startswith("'") and onglet.endswith("'"):
                    onglet = onglet[1:-1].replace("''", "'")
            jetons.append(
                Jeton(
                    "ref",
                    correspondance.group(0),
                    onglet=onglet,
                    colonne=groupes["col"].upper(),
                    ligne=int(groupes["lig"]),
                )
            )
            continue

        for genre in (
            "nombre",
            "chaine",
            "fonction",
            "compare",
            "operateur",
            "pourcent",
            "parO",
            "parF",
            "virgule",
        ):
            valeur = groupes[genre]
            if valeur:
                jetons.append(Jeton(genre, valeur))
                break

    return jetons


# ── Analyse syntaxique et evaluation ────────────────────────────────────────


def _en_nombre(valeur: Any) -> float | ErreurExcel:
    """Convertit une valeur de cellule en nombre, a la maniere d'Excel.

    Une cellule vide vaut 0 dans un calcul : c'est le comportement d'Excel, et
    la matrice officielle s'en sert abondamment (les totaux additionnent des
    postes non renseignes).
    """

    if isinstance(valeur, ErreurExcel):
        return valeur
    if valeur is None or valeur == "":
        return 0.0
    if isinstance(valeur, bool):
        return 1.0 if valeur else 0.0
    if isinstance(valeur, (int, float)):
        return float(valeur)
    if isinstance(valeur, str):
        try:
            return float(valeur.replace(",", ".").strip())
        except ValueError:
            return VALEUR
    return VALEUR


class _Analyseur:
    """Analyseur descendant recursif sur la grammaire close du classeur."""

    def __init__(self, jetons: list[Jeton], resoudre) -> None:
        self._jetons = jetons
        self._i = 0
        self._resoudre = resoudre

    # -- utilitaires --

    def _courant(self) -> Jeton | None:
        return self._jetons[self._i] if self._i < len(self._jetons) else None

    def _avancer(self) -> Jeton:
        jeton = self._jetons[self._i]
        self._i += 1
        return jeton

    def _attendre(self, genre: str, texte: str | None = None) -> Jeton:
        jeton = self._courant()
        if jeton is None or jeton.genre != genre or (texte and jeton.texte != texte):
            raise FormuleNonSupportee(
                f"Jeton {texte or genre} attendu, obtenu {jeton.texte if jeton else 'fin'}"
            )
        return self._avancer()

    # -- regles --

    def analyser(self) -> Any:
        valeur = self._comparaison()
        if self._courant() is not None:
            raise FormuleNonSupportee(f"Jeton residuel « {self._courant().texte} »")
        return valeur

    def _comparaison(self) -> Any:
        gauche = self._addition()
        jeton = self._courant()
        if jeton is not None and jeton.genre == "compare":
            operateur = self._avancer().texte
            droite = self._addition()
            return self._comparer(operateur, gauche, droite)
        return gauche

    @staticmethod
    def _comparer(operateur: str, gauche: Any, droite: Any) -> Any:
        if isinstance(gauche, ErreurExcel):
            return gauche
        if isinstance(droite, ErreurExcel):
            return droite

        # Excel compare les textes entre eux, sans casse ; tout le reste passe
        # par une conversion numerique (une cellule vide vaut alors 0).
        if isinstance(gauche, str) or isinstance(droite, str):
            g: Any = gauche.lower() if isinstance(gauche, str) else gauche
            d: Any = droite.lower() if isinstance(droite, str) else droite
            if not isinstance(g, str) or not isinstance(d, str):
                g, d = str(g).lower(), str(d).lower()
        else:
            g, d = _en_nombre(gauche), _en_nombre(droite)
            if isinstance(g, ErreurExcel):
                return g
            if isinstance(d, ErreurExcel):
                return d

        if operateur == "=":
            return g == d
        if operateur == "<>":
            return g != d
        if operateur == ">":
            return g > d
        if operateur == "<":
            return g < d
        if operateur == ">=":
            return g >= d
        if operateur == "<=":
            return g <= d
        raise FormuleNonSupportee(f"Comparateur inconnu « {operateur} »")

    def _addition(self) -> Any:
        valeur = self._multiplication()
        while True:
            jeton = self._courant()
            if jeton is None or jeton.genre != "operateur" or jeton.texte not in "+-":
                return valeur
            operateur = self._avancer().texte
            droite = self._multiplication()
            gauche_n, droite_n = _en_nombre(valeur), _en_nombre(droite)
            if isinstance(gauche_n, ErreurExcel):
                return gauche_n
            if isinstance(droite_n, ErreurExcel):
                return droite_n
            valeur = gauche_n + droite_n if operateur == "+" else gauche_n - droite_n

    def _multiplication(self) -> Any:
        valeur = self._unaire()
        while True:
            jeton = self._courant()
            if jeton is None or jeton.genre != "operateur" or jeton.texte not in "*/":
                return valeur
            operateur = self._avancer().texte
            droite = self._unaire()
            gauche_n, droite_n = _en_nombre(valeur), _en_nombre(droite)
            if isinstance(gauche_n, ErreurExcel):
                return gauche_n
            if isinstance(droite_n, ErreurExcel):
                return droite_n
            if operateur == "*":
                valeur = gauche_n * droite_n
            else:
                if droite_n == 0:
                    return DIV_ZERO
                valeur = gauche_n / droite_n

    def _unaire(self) -> Any:
        jeton = self._courant()
        if jeton is not None and jeton.genre == "operateur" and jeton.texte in "+-":
            operateur = self._avancer().texte
            valeur = _en_nombre(self._unaire())
            if isinstance(valeur, ErreurExcel):
                return valeur
            return valeur if operateur == "+" else -valeur
        return self._pourcentage()

    def _pourcentage(self) -> Any:
        valeur = self._primaire()
        while True:
            jeton = self._courant()
            if jeton is None or jeton.genre != "pourcent":
                return valeur
            self._avancer()
            nombre = _en_nombre(valeur)
            if isinstance(nombre, ErreurExcel):
                return nombre
            valeur = nombre / 100.0

    def _primaire(self) -> Any:
        jeton = self._courant()
        if jeton is None:
            raise FormuleNonSupportee("Formule tronquee")

        if jeton.genre == "nombre":
            return float(self._avancer().texte)

        if jeton.genre == "chaine":
            brut = self._avancer().texte
            return brut[1:-1].replace('""', '"')

        if jeton.genre == "ref":
            self._avancer()
            return self._resoudre(jeton)

        if jeton.genre == "parO":
            self._avancer()
            valeur = self._comparaison()
            self._attendre("parF")
            return valeur

        if jeton.genre == "fonction":
            return self._fonction()

        raise FormuleNonSupportee(f"Element inattendu « {jeton.texte} »")

    def _fonction(self) -> Any:
        nom = self._avancer().texte.upper()
        self._attendre("parO")

        arguments: list[Any] = []
        if self._courant() is not None and self._courant().genre != "parF":
            # IF n'evalue idealement qu'une branche, mais la matrice officielle
            # n'utilise que des branches sans effet de bord ni division risquee :
            # les evaluer toutes reste sur, et garde l'analyseur trivial.
            arguments.append(self._comparaison())
            while self._courant() is not None and self._courant().genre == "virgule":
                self._avancer()
                arguments.append(self._comparaison())
        self._attendre("parF")

        if nom == "IF":
            if len(arguments) not in (2, 3):
                raise FormuleNonSupportee("IF attend 2 ou 3 arguments")
            condition = arguments[0]
            if isinstance(condition, ErreurExcel):
                return condition
            if not isinstance(condition, bool):
                nombre = _en_nombre(condition)
                if isinstance(nombre, ErreurExcel):
                    return nombre
                condition = nombre != 0
            if condition:
                return arguments[1]
            return arguments[2] if len(arguments) == 3 else False

        raise FormuleNonSupportee(f"Fonction « {nom} » non prise en charge")


# ── Moteur ──────────────────────────────────────────────────────────────────


class MoteurFormules:
    """Calcule la valeur de chaque cellule d'un classeur openpyxl.

    Les resultats sont memorises : une meme cellule referencee par vingt
    formules n'est evaluee qu'une fois, et le graphe de dependances est parcouru
    a la demande plutot que trie au prealable.
    """

    def __init__(self, wb: Any) -> None:
        self._wb = wb
        self._cache: dict[tuple[str, str], Any] = {}
        self._en_cours: set[tuple[str, str]] = set()
        self._onglets = {nom.strip().upper(): nom for nom in wb.sheetnames}
        self.formules_ignorees: list[tuple[str, str, str]] = []

    # -- API publique --

    def valeur(self, onglet: str, coordonnee: str) -> Any:
        """Valeur calculee d'une cellule, formules resolues."""

        cle = (onglet, coordonnee.upper())
        if cle in self._cache:
            return self._cache[cle]

        # Une cellule qui se reference elle-meme, directement ou via une chaine
        # de dependances, est signalee au lieu de faire deborder la pile.
        if cle in self._en_cours:
            return CYCLE

        nom_reel = self._onglets.get(onglet.strip().upper())
        if nom_reel is None:
            return REFERENCE

        brut = self._wb[nom_reel][coordonnee.upper()].value
        if not (isinstance(brut, str) and brut.startswith("=")):
            self._cache[cle] = brut
            return brut

        self._en_cours.add(cle)
        try:
            resultat = self._evaluer(nom_reel, brut)
        finally:
            self._en_cours.discard(cle)

        self._cache[cle] = resultat
        return resultat

    def valeurs_par_onglet(self, onglet: str) -> dict[str, Any]:
        """Valeurs calculees de toutes les cellules a formule d'un onglet."""

        resultats: dict[str, Any] = {}
        for ligne in self._wb[onglet].iter_rows():
            for cellule in ligne:
                if isinstance(cellule.value, str) and cellule.value.startswith("="):
                    resultats[cellule.coordinate] = self.valeur(onglet, cellule.coordinate)
        return resultats

    # -- interne --

    def _evaluer(self, onglet: str, formule: str) -> Any:
        corps = formule[1:].strip()
        if not corps:
            return None
        try:
            jetons = _decouper(corps)
            return _Analyseur(jetons, lambda j: self._resoudre(onglet, j)).analyser()
        except FormuleNonSupportee as exc:
            # Une formule hors grammaire ne doit pas faire echouer l'export
            # entier : on la note, la cellule reste vide, et l'appelant peut
            # decider d'alerter.
            self.formules_ignorees.append((onglet, formule, str(exc)))
            return None
        except RecursionError:
            self.formules_ignorees.append((onglet, formule, "profondeur excessive"))
            return CYCLE

    def _resoudre(self, onglet_courant: str, jeton: Jeton) -> Any:
        onglet = jeton.onglet or onglet_courant
        return self.valeur(onglet, f"{jeton.colonne}{jeton.ligne}")
