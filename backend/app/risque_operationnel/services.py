"""Services du module Risque Opérationnel."""

from __future__ import annotations

import uuid
from datetime import date, datetime, timedelta

from database.connection import database_manager, utcnow_iso

from .models import (
    ControleCreate,
    ControleUpdate,
    ControleView,
    DashboardData,
    DashboardWidget1,
    DashboardWidget2,
    DashboardWidget3,
    EvolutionPoint,
    HistoriqueView,
    IncidentBulkImportRequest,
    IncidentCreate,
    IncidentImportResult,
    IncidentUpdate,
    IncidentView,
    KriModuleData,
    KriValeurCreate,
    KriValeurView,
    KriView,
    PlanCreate,
    PlanUpdate,
    PlanView,
    RepartitionItem,
    RisqueCreate,
    RisqueUpdate,
    RisqueView,
)

_LIGNES_METIER = [
    "Financement d'entreprise",
    "Activités de marché",
    "Banque de détail",
    "Banque commerciale",
    "Paiements et règlements",
    "Fonctions d'agent",
    "Gestion d'actifs",
    "Courtage de détail",
]

# ─── helpers ──────────────────────────────────────────────────────────────────

def _new_id() -> str:
    return str(uuid.uuid4())


def _today() -> str:
    return date.today().isoformat()


def _seq_reference(prefix: str, conn) -> str:
    year = date.today().year
    table_map = {
        "INC": "ro_incidents",
        "CTRL": "ro_controles",
        "ACT": "ro_plans_action",
    }
    table = table_map.get(prefix, "ro_incidents")
    row = conn.execute(
        f"SELECT COUNT(*) as cnt FROM {table} WHERE reference LIKE ?",
        (f"{prefix}-{year}-%",),
    ).fetchone()
    seq = (row["cnt"] if row else 0) + 1
    return f"{prefix}-{year}-{seq:04d}"


def _niveau_label(niveau: float) -> str:
    if niveau <= 4:
        return "Faible"
    if niveau <= 9:
        return "Moyen"
    if niveau <= 16:
        return "Élevé"
    return "Critique"


def _prochaine_date(date_str: str, frequence: str) -> str:
    if not date_str:
        return ""
    try:
        d = date.fromisoformat(date_str)
    except ValueError:
        return ""
    delta_map = {
        "Mensuel": timedelta(days=30),
        "Trimestriel": timedelta(days=91),
        "Semestriel": timedelta(days=182),
        "Annuel": timedelta(days=365),
    }
    delta = delta_map.get(frequence, timedelta(days=30))
    return (d + delta).isoformat()


def _log(conn, menu: str, type_action: str, element: str, ancienne: str = "", nouvelle: str = "") -> None:
    conn.execute(
        """INSERT INTO ro_historique (date_evenement, utilisateur, menu, type_action, element, ancienne_valeur, nouvelle_valeur)
           VALUES (?, ?, ?, ?, ?, ?, ?)""",
        (utcnow_iso(), "Système", menu, type_action, element, ancienne, nouvelle),
    )


# ─── Incidents ────────────────────────────────────────────────────────────────

def _row_to_incident(row) -> IncidentView:
    perte_nette = (row["perte_brute"] or 0) - (row["perte_recuperee"] or 0)
    return IncidentView(
        id=row["id"],
        reference=row["reference"],
        date_occurrence=row["date_occurrence"],
        description=row["description"],
        ligne_metier=row["ligne_metier"],
        type_evenement=row["type_evenement"],
        cause_racine=row["cause_racine"] or "",
        perte_brute=row["perte_brute"] or 0,
        perte_recuperee=row["perte_recuperee"] or 0,
        perte_nette=perte_nette,
        statut=row["statut"],
        significatif=perte_nette > 0,
        cree_le=row["cree_le"],
        modifie_le=row["modifie_le"],
    )


def list_incidents(statut: str | None = None, ligne_metier: str | None = None) -> list[IncidentView]:
    with database_manager.transaction() as conn:
        query = "SELECT * FROM ro_incidents WHERE 1=1"
        params: list = []
        if statut:
            query += " AND statut = ?"
            params.append(statut)
        if ligne_metier:
            query += " AND ligne_metier = ?"
            params.append(ligne_metier)
        query += " ORDER BY date_occurrence DESC"
        rows = conn.execute(query, params).fetchall()
    return [_row_to_incident(r) for r in rows]


def create_incident(data: IncidentCreate) -> IncidentView:
    id_ = _new_id()
    now = utcnow_iso()
    with database_manager.transaction() as conn:
        ref = _seq_reference("INC", conn)
        conn.execute(
            """INSERT INTO ro_incidents (id, reference, date_occurrence, description, ligne_metier,
               type_evenement, cause_racine, perte_brute, perte_recuperee, statut, cree_le, modifie_le)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
            (id_, ref, data.date_occurrence, data.description, data.ligne_metier,
             data.type_evenement, data.cause_racine, data.perte_brute,
             data.perte_recuperee, data.statut, now, now),
        )
        _log(conn, "Incidents", "CREATE", ref, "", data.description[:80])
    with database_manager.transaction() as conn:
        row = conn.execute("SELECT * FROM ro_incidents WHERE id = ?", (id_,)).fetchone()
    return _row_to_incident(row)


def update_incident(id_: str, data: IncidentUpdate) -> IncidentView:
    now = utcnow_iso()
    updates = {k: v for k, v in data.model_dump().items() if v is not None}
    if not updates:
        with database_manager.transaction() as conn:
            row = conn.execute("SELECT * FROM ro_incidents WHERE id = ?", (id_,)).fetchone()
        return _row_to_incident(row)
    set_clause = ", ".join(f"{k} = ?" for k in updates)
    with database_manager.transaction() as conn:
        old = conn.execute("SELECT * FROM ro_incidents WHERE id = ?", (id_,)).fetchone()
        conn.execute(
            f"UPDATE ro_incidents SET {set_clause}, modifie_le = ? WHERE id = ?",
            (*updates.values(), now, id_),
        )
        _log(conn, "Incidents", "UPDATE", old["reference"] if old else id_)
    with database_manager.transaction() as conn:
        row = conn.execute("SELECT * FROM ro_incidents WHERE id = ?", (id_,)).fetchone()
    return _row_to_incident(row)


def delete_incident(id_: str) -> None:
    with database_manager.transaction() as conn:
        row = conn.execute("SELECT reference FROM ro_incidents WHERE id = ?", (id_,)).fetchone()
        conn.execute("DELETE FROM ro_incidents WHERE id = ?", (id_,))
        _log(conn, "Incidents", "DELETE", row["reference"] if row else id_)


def build_ro_import_template() -> bytes:
    """Génère un classeur Excel de modèle pour l'import des pertes opérationnelles."""
    from io import BytesIO
    from openpyxl import Workbook
    from openpyxl.styles import (
        Alignment, Border, Font, PatternFill, Side
    )
    from openpyxl.utils import get_column_letter

    wb = Workbook()

    # ── Palette ─────────────────────────────────────────────────────────────
    BLUE_DARK   = "1D4ED8"
    BLUE_LIGHT  = "DBEAFE"
    GREEN_DARK  = "15803D"
    GREEN_LIGHT = "DCFCE7"
    YELLOW_BG   = "FEF9C3"
    RED_LIGHT   = "FEE2E2"
    GREY_HEADER = "F1F5F9"
    BORDER_CLR  = "CBD5E1"

    thin = Side(style="thin", color=BORDER_CLR)
    thin_b = Border(left=thin, right=thin, top=thin, bottom=thin)

    def hdr_font(bold=True, size=11, color="000000"):
        return Font(bold=bold, size=size, color=color)

    def fill(hex_color):
        return PatternFill("solid", fgColor=hex_color)

    def center(wrap=False):
        return Alignment(horizontal="center", vertical="center", wrap_text=wrap)

    def left(wrap=False):
        return Alignment(horizontal="left", vertical="center", wrap_text=wrap)

    # ── Feuille 1 : INCIDENTS (saisie) ────────────────────────────────────
    ws = wb.active
    ws.title = "Incidents"
    ws.freeze_panes = "A3"

    # Titre
    ws.row_dimensions[1].height = 32
    ws.merge_cells("A1:H1")
    title_cell = ws["A1"]
    title_cell.value = "Modèle d'import — Pertes Opérationnelles (Risque Opérationnel BCEAO)"
    title_cell.font = Font(bold=True, size=13, color="FFFFFF")
    title_cell.fill = fill(BLUE_DARK)
    title_cell.alignment = center()

    # En-têtes colonnes
    headers = [
        ("A", "date_occurrence",  "Date d'occurrence",    "AAAA-MM-JJ ou JJ/MM/AAAA",   True,  15),
        ("B", "description",      "Description",           "Libellé de l'incident",       True,  35),
        ("C", "ligne_metier",     "Ligne de métier",       "Voir onglet Lignes_Métier",   True,  22),
        ("D", "type_evenement",   "Type d'événement",      "Voir onglet Types_Événement", True,  18),
        ("E", "cause_racine",     "Cause racine",          "Optionnel",                   False, 20),
        ("F", "perte_brute",      "Perte brute (FCFA)",    "Montant numérique",           True,  18),
        ("G", "perte_recuperee",  "Perte récupérée (FCFA)","Assurance / provisions",      False, 20),
        ("H", "statut",           "Statut",                "Optionnel — défaut: Ouvert",  False, 14),
    ]

    ws.row_dimensions[2].height = 40
    for col_letter, _, label, hint, required, width in headers:
        c = ws[f"{col_letter}2"]
        c.value = f"{'★ ' if required else '○ '}{label}"
        c.font = Font(bold=True, size=10, color=BLUE_DARK if required else "475569")
        c.fill = fill(BLUE_LIGHT if required else GREY_HEADER)
        c.border = thin_b
        c.alignment = center(wrap=True)
        ws.column_dimensions[col_letter].width = width

        # Ligne hint sous l'en-tête (row 3)
        h = ws[f"{col_letter}3"]
        h.value = hint
        h.font = Font(italic=True, size=8, color="64748B")
        h.fill = fill("F8FAFC")
        h.border = thin_b
        h.alignment = center(wrap=True)

    ws.row_dimensions[3].height = 18

    # Lignes d'exemple (une par type d'événement)
    exemples = [
        ("2025-01-15", "Erreur de saisie virement client — doublon déclenché",            "Banque de détail",   "Processus", "Erreur humaine",       450000, 0,       "Résolu"),
        ("2025-02-03", "Tentative de phishing — données compromises employé",              "Banque commerciale", "Interne",   "Fraude interne",       0,      0,       "En cours"),
        ("2025-03-10", "Fraude carte bancaire — 12 transactions non autorisées",           "Banque de détail",   "Externe",   "Fraude externe",       1800000, 600000, "Résolu"),
        ("2025-03-22", "Panne du core banking 6h — transactions en attente",               "Paiements et règlements", "Système", "Défaillance système", 3200000, 0,    "Clôturé"),
        ("2025-04-08", "Litige client — mauvais conseil produit structuré",                "Financement d'entreprise", "Juridique", "Processus inadéquat", 7500000, 2500000, "En cours"),
        ("2025-05-14", "Accident du travail — blessure caissier",                          "Banque de détail",   "Personnel", "Événement externe",    0,      0,       "Clôturé"),
        ("2025-06-01", "Erreur règlement titre — mauvaise quantité exécutée",              "Activités de marché","Processus", "Erreur humaine",       950000, 950000, "Clôturé"),
        ("2025-06-20", "Perte physique fonds — vol agence",                                "Banque de détail",   "Externe",   "Fraude externe",       2100000, 400000, "En cours"),
    ]

    for row_idx, ex in enumerate(exemples, start=4):
        row_fill = fill("FFFFFF") if row_idx % 2 == 0 else fill("F8FAFC")
        vals = list(ex)
        for ci, val in enumerate(vals, start=1):
            c = ws.cell(row=row_idx, column=ci, value=val)
            c.border = thin_b
            c.fill = row_fill
            c.alignment = left(wrap=(ci == 2))
            c.font = Font(size=10)

    # ── Feuille 2 : Instructions ────────────────────────────────────────────
    ws2 = wb.create_sheet("Instructions")
    ws2.column_dimensions["A"].width = 22
    ws2.column_dimensions["B"].width = 58

    ws2.merge_cells("A1:B1")
    ws2["A1"].value = "Instructions — Import des pertes opérationnelles"
    ws2["A1"].font = Font(bold=True, size=13, color="FFFFFF")
    ws2["A1"].fill = fill(BLUE_DARK)
    ws2["A1"].alignment = center()

    instructions = [
        ("Feuille de saisie",   "Saisir vos incidents dans la feuille « Incidents » à partir de la ligne 4."),
        ("Ligne 2",             "★ = colonne OBLIGATOIRE   ○ = colonne optionnelle (peut rester vide)"),
        ("date_occurrence",     "Format ISO AAAA-MM-JJ (ex : 2025-06-15) ou JJ/MM/AAAA (ex : 15/06/2025)."),
        ("ligne_metier",        "Valeur exacte parmi les 8 options."),
        ("type_evenement",      "Valeur exacte parmi 6 options (Interne, Externe, Processus, Système, Personnel, Juridique)."),
        ("cause_racine",        "Optionnel : Erreur humaine | Défaillance système | Processus inadéquat | Fraude interne | Fraude externe | Événement externe | Non définie."),
        ("perte_brute",         "Montant total de la perte avant récupération, en FCFA (nombre entier ou décimal)."),
        ("perte_recuperee",     "Montant récupéré (assurance, provisions) — 0 si rien. Perte nette = brute − récupérée."),
        ("statut",              "Optionnel : Ouvert | En cours | Résolu | Clôturé. Défaut = Ouvert."),
        ("Lignes vides",        "Les lignes entièrement vides sont ignorées."),
        ("Doublons",            "Aucune vérification de doublon — vérifier avant import en mode remplacement."),
    ]

    for ri, (label, text) in enumerate(instructions, start=2):
        c_label = ws2.cell(row=ri, column=1, value=label)
        c_text  = ws2.cell(row=ri, column=2, value=text)
        row_fill = fill(BLUE_LIGHT) if label and label != "" else fill("FFFFFF")
        c_label.font = Font(bold=bool(label), size=10, color=BLUE_DARK if label else "000000")
        c_label.fill = row_fill
        c_label.border = thin_b
        c_label.alignment = left()
        c_text.font = Font(size=10)
        c_text.fill = fill("FFFFFF")
        c_text.border = thin_b
        c_text.alignment = left(wrap=True)
        ws2.row_dimensions[ri].height = 20

    # Onglet de référence : pas de validation externe ni de feuilles supplémentaires
    ws2.sheet_view.tabSelected = False

    # ── Export en bytes ────────────────────────────────────────────────────
    buf = BytesIO()
    wb.save(buf)
    return buf.getvalue()


_LIGNES_METIER = [
    "Financement d'entreprise", "Activités de marché", "Banque de détail",
    "Banque commerciale", "Paiements et règlements", "Fonctions d'agent",
    "Gestion d'actifs", "Courtage de détail",
]
_TYPES_EVENEMENT = ["Interne", "Externe", "Processus", "Système", "Personnel", "Juridique"]
_CAUSES_RACINE = [
    "Erreur humaine", "Défaillance système", "Processus inadéquat",
    "Fraude interne", "Fraude externe", "Événement externe", "Non définie",
]
_STATUTS_INCIDENT = ["Ouvert", "En cours", "Résolu", "Clôturé"]


def bulk_import_incidents(data: IncidentBulkImportRequest) -> IncidentImportResult:
    imported = 0
    errors: list[str] = []
    with database_manager.transaction() as conn:
        if data.mode == "replace":
            conn.execute("DELETE FROM ro_incidents")
        for idx, item in enumerate(data.incidents):
            try:
                id_ = _new_id()
                now = utcnow_iso()
                ref = _seq_reference("INC", conn)
                conn.execute(
                    """INSERT INTO ro_incidents (id, reference, date_occurrence, description,
                       ligne_metier, type_evenement, cause_racine, perte_brute, perte_recuperee,
                       statut, cree_le, modifie_le) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
                    (id_, ref, item.date_occurrence, item.description, item.ligne_metier,
                     item.type_evenement, item.cause_racine, item.perte_brute,
                     item.perte_recuperee, item.statut, now, now),
                )
                imported += 1
            except Exception as exc:
                errors.append(f"Ligne {idx + 2}: {exc}")
        if imported > 0:
            _log(conn, "Pertes", "IMPORT", f"{imported} incident(s) importé(s)")
    return IncidentImportResult(imported=imported, skipped=0, errors=errors)


# ─── KRI ──────────────────────────────────────────────────────────────────────

def _kri_statut(valeur: float | None, seuil_alerte: float, seuil_critique: float, sens: str) -> str:
    if valeur is None:
        return "non_renseigne"
    if sens == "superieur":
        if valeur >= seuil_critique:
            return "critique"
        if valeur >= seuil_alerte:
            return "alerte"
        return "normal"
    else:
        if valeur <= seuil_critique:
            return "critique"
        if valeur <= seuil_alerte:
            return "alerte"
        return "normal"


def get_kri_module() -> KriModuleData:
    with database_manager.transaction() as conn:
        defs = conn.execute("SELECT * FROM ro_kri_definitions ORDER BY id").fetchall()
        kri_list = []
        hors_seuil = 0
        for d in defs:
            vals = conn.execute(
                "SELECT * FROM ro_kri_valeurs WHERE kri_id = ? ORDER BY date_mesure DESC",
                (d["id"],),
            ).fetchall()
            historique = [
                KriValeurView(
                    id=v["id"], kri_id=v["kri_id"], date_mesure=v["date_mesure"],
                    valeur=v["valeur"], commentaire=v["commentaire"] or "", cree_le=v["cree_le"],
                )
                for v in vals
            ]
            derniere = vals[0] if vals else None
            derniere_valeur = derniere["valeur"] if derniere else None
            derniere_date = derniere["date_mesure"] if derniere else None
            statut = _kri_statut(derniere_valeur, d["seuil_alerte"], d["seuil_critique"], d["sens"])
            if statut in ("alerte", "critique"):
                hors_seuil += 1
            from .models import KriDefinition
            kri_list.append(KriView(
                definition=KriDefinition(
                    id=d["id"], nom=d["nom"], unite=d["unite"], formule=d["formule"],
                    seuil_alerte=d["seuil_alerte"], seuil_critique=d["seuil_critique"],
                    sens=d["sens"], frequence=d["frequence"],
                ),
                derniere_valeur=derniere_valeur,
                derniere_date=derniere_date,
                statut=statut,
                historique=historique,
            ))
    return KriModuleData(kri_list=kri_list, kri_hors_seuil=hors_seuil)


def add_kri_valeur(data: KriValeurCreate) -> KriValeurView:
    id_ = _new_id()
    now = utcnow_iso()
    with database_manager.transaction() as conn:
        conn.execute(
            """INSERT INTO ro_kri_valeurs (id, kri_id, date_mesure, valeur, commentaire, cree_le)
               VALUES (?,?,?,?,?,?)""",
            (id_, data.kri_id, data.date_mesure, data.valeur, data.commentaire, now),
        )
        _log(conn, "KRI", "CREATE", data.kri_id, "", str(data.valeur))
    with database_manager.transaction() as conn:
        row = conn.execute("SELECT * FROM ro_kri_valeurs WHERE id = ?", (id_,)).fetchone()
    return KriValeurView(
        id=row["id"], kri_id=row["kri_id"], date_mesure=row["date_mesure"],
        valeur=row["valeur"], commentaire=row["commentaire"] or "", cree_le=row["cree_le"],
    )


def auto_calcul_kri() -> KriModuleData:
    """
    Calcule automatiquement les KRI dérivables des données existantes
    (incidents et contrôles) et insère de nouvelles valeurs datées d'aujourd'hui.
    Seuls les KRI dont les données sources sont disponibles sont mis à jour :
      kri-04 : Incidents IT  (ro_incidents, type_evenement)
      kri-05 : Délai moyen de résolution (ro_incidents, statut=Clôturé)
      kri-06 : Taux d'erreurs de traitement (% incidents processus / total mois)
      kri-08 : Contrôles non conformes (ro_controles)
    Les KRI RH (kri-01/02/03/07) restent en saisie manuelle.
    """
    from datetime import date, timedelta
    now      = utcnow_iso()
    today    = date.today().isoformat()
    start_m  = date.today().replace(day=1).isoformat()
    ago30    = (date.today() - timedelta(days=30)).isoformat()

    with database_manager.transaction() as conn:
        # kri-04 : incidents liés aux systèmes/IT ce mois
        kri04 = float(conn.execute(
            """SELECT COUNT(*) AS cnt FROM ro_incidents
               WHERE date_occurrence >= ?
                 AND (type_evenement LIKE '%IT%'
                   OR type_evenement LIKE '%nterruption%'
                   OR type_evenement LIKE '%système%'
                   OR type_evenement LIKE '%Système%'
                   OR type_evenement LIKE '%informatique%')""",
            (start_m,),
        ).fetchone()["cnt"])

        # kri-05 : délai moyen de résolution des incidents clôturés (30 derniers jours)
        row05 = conn.execute(
            """SELECT AVG(julianday(modifie_le) - julianday(date_occurrence)) AS avg_d
               FROM ro_incidents
               WHERE statut = 'Clôturé' AND date_occurrence >= ?""",
            (ago30,),
        ).fetchone()
        kri05 = round(row05["avg_d"] or 0.0, 1)

        # kri-06 : % incidents liés aux processus / total incidents du mois
        total_m = conn.execute(
            "SELECT COUNT(*) AS cnt FROM ro_incidents WHERE date_occurrence >= ?",
            (start_m,),
        ).fetchone()["cnt"] or 0
        proc_m  = conn.execute(
            """SELECT COUNT(*) AS cnt FROM ro_incidents
               WHERE date_occurrence >= ?
                 AND (type_evenement LIKE '%xécution%'
                   OR type_evenement LIKE '%processus%'
                   OR type_evenement LIKE '%raitement%')""",
            (start_m,),
        ).fetchone()["cnt"]
        kri06 = round((proc_m / total_m * 100), 2) if total_m > 0 else 0.0

        # kri-08 : contrôles non conformes (tous, pas de fenêtre temporelle)
        kri08 = float(conn.execute(
            "SELECT COUNT(*) AS cnt FROM ro_controles WHERE resultat = 'Non-conforme'"
        ).fetchone()["cnt"])

        auto_values = {
            "kri-04": kri04,
            "kri-05": kri05,
            "kri-06": kri06,
            "kri-08": kri08,
        }
        for kri_id, valeur in auto_values.items():
            conn.execute(
                """INSERT INTO ro_kri_valeurs (id, kri_id, date_mesure, valeur, commentaire, cree_le)
                   VALUES (?,?,?,?,?,?)""",
                (_new_id(), kri_id, today, valeur, "auto", now),
            )
            _log(conn, "KRI", "AUTO_CALCUL", kri_id, "", str(valeur))

    return get_kri_module()


# ─── Risques ──────────────────────────────────────────────────────────────────

def _row_to_risque(row) -> RisqueView:
    p = row["probabilite"] or 1
    i = row["impact"] or 1
    eff = row["efficacite_controle"] or 3
    brut = p * i
    residuel = round(brut / eff, 2)
    return RisqueView(
        id=row["id"], nom=row["nom"], categorie=row["categorie"],
        ligne_metier=row["ligne_metier"], probabilite=p, impact=i,
        niveau_brut=brut, controle_existant=row["controle_existant"] or "",
        efficacite_controle=eff, niveau_residuel=residuel,
        niveau_label=_niveau_label(brut), plan_action_ref=row["plan_action_ref"] or "",
        cree_le=row["cree_le"], modifie_le=row["modifie_le"],
    )


def list_risques() -> list[RisqueView]:
    with database_manager.transaction() as conn:
        rows = conn.execute("SELECT * FROM ro_risques ORDER BY probabilite * impact DESC").fetchall()
    return [_row_to_risque(r) for r in rows]


def create_risque(data: RisqueCreate) -> RisqueView:
    id_ = _new_id()
    now = utcnow_iso()
    with database_manager.transaction() as conn:
        conn.execute(
            """INSERT INTO ro_risques (id, nom, categorie, ligne_metier, probabilite, impact,
               controle_existant, efficacite_controle, plan_action_ref, cree_le, modifie_le)
               VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
            (id_, data.nom, data.categorie, data.ligne_metier, data.probabilite, data.impact,
             data.controle_existant, data.efficacite_controle, data.plan_action_ref, now, now),
        )
        _log(conn, "Cartographie", "CREATE", data.nom)
    with database_manager.transaction() as conn:
        row = conn.execute("SELECT * FROM ro_risques WHERE id = ?", (id_,)).fetchone()
    return _row_to_risque(row)


def update_risque(id_: str, data: RisqueUpdate) -> RisqueView:
    now = utcnow_iso()
    updates = {k: v for k, v in data.model_dump().items() if v is not None}
    if updates:
        set_clause = ", ".join(f"{k} = ?" for k in updates)
        with database_manager.transaction() as conn:
            old = conn.execute("SELECT nom FROM ro_risques WHERE id = ?", (id_,)).fetchone()
            conn.execute(
                f"UPDATE ro_risques SET {set_clause}, modifie_le = ? WHERE id = ?",
                (*updates.values(), now, id_),
            )
            _log(conn, "Cartographie", "UPDATE", old["nom"] if old else id_)
    with database_manager.transaction() as conn:
        row = conn.execute("SELECT * FROM ro_risques WHERE id = ?", (id_,)).fetchone()
    return _row_to_risque(row)


def delete_risque(id_: str) -> None:
    with database_manager.transaction() as conn:
        row = conn.execute("SELECT nom FROM ro_risques WHERE id = ?", (id_,)).fetchone()
        conn.execute("DELETE FROM ro_risques WHERE id = ?", (id_,))
        _log(conn, "Cartographie", "DELETE", row["nom"] if row else id_)


# ─── Contrôles ────────────────────────────────────────────────────────────────

def _row_to_controle(row) -> ControleView:
    pc = row["points_conformes"] or 0
    ptc = row["points_controles"] or 0
    taux = round((pc / ptc) * 100, 1) if ptc > 0 else 0.0
    return ControleView(
        id=row["id"], reference=row["reference"], perimetre=row["perimetre"],
        type_controle=row["type_controle"], frequence=row["frequence"],
        date_dernier_test=row["date_dernier_test"] or "",
        prochaine_date=_prochaine_date(row["date_dernier_test"] or "", row["frequence"]),
        resultat=row["resultat"], taux_conformite=taux,
        points_conformes=pc, points_controles=ptc,
        non_conformites=row["non_conformites"] or "", validateur=row["validateur"] or "",
        cree_le=row["cree_le"], modifie_le=row["modifie_le"],
    )


def list_controles() -> list[ControleView]:
    with database_manager.transaction() as conn:
        rows = conn.execute("SELECT * FROM ro_controles ORDER BY cree_le DESC").fetchall()
    return [_row_to_controle(r) for r in rows]


def create_controle(data: ControleCreate) -> ControleView:
    id_ = _new_id()
    now = utcnow_iso()
    with database_manager.transaction() as conn:
        ref = _seq_reference("CTRL", conn)
        conn.execute(
            """INSERT INTO ro_controles (id, reference, perimetre, type_controle, frequence,
               date_dernier_test, resultat, points_conformes, points_controles,
               non_conformites, validateur, cree_le, modifie_le)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (id_, ref, data.perimetre, data.type_controle, data.frequence,
             data.date_dernier_test, data.resultat, data.points_conformes,
             data.points_controles, data.non_conformites, data.validateur, now, now),
        )
        _log(conn, "Contrôles", "CREATE", ref)
    with database_manager.transaction() as conn:
        row = conn.execute("SELECT * FROM ro_controles WHERE id = ?", (id_,)).fetchone()
    return _row_to_controle(row)


def update_controle(id_: str, data: ControleUpdate) -> ControleView:
    now = utcnow_iso()
    updates = {k: v for k, v in data.model_dump().items() if v is not None}
    if updates:
        set_clause = ", ".join(f"{k} = ?" for k in updates)
        with database_manager.transaction() as conn:
            old = conn.execute("SELECT reference FROM ro_controles WHERE id = ?", (id_,)).fetchone()
            conn.execute(
                f"UPDATE ro_controles SET {set_clause}, modifie_le = ? WHERE id = ?",
                (*updates.values(), now, id_),
            )
            _log(conn, "Contrôles", "UPDATE", old["reference"] if old else id_)
    with database_manager.transaction() as conn:
        row = conn.execute("SELECT * FROM ro_controles WHERE id = ?", (id_,)).fetchone()
    return _row_to_controle(row)


def delete_controle(id_: str) -> None:
    with database_manager.transaction() as conn:
        row = conn.execute("SELECT reference FROM ro_controles WHERE id = ?", (id_,)).fetchone()
        conn.execute("DELETE FROM ro_controles WHERE id = ?", (id_,))
        _log(conn, "Contrôles", "DELETE", row["reference"] if row else id_)


# ─── Plans d'actions ──────────────────────────────────────────────────────────

def _row_to_plan(row) -> PlanView:
    today = date.today()
    echeance_str = row["date_echeance"] or ""
    jours = 0
    en_retard = False
    if echeance_str:
        try:
            echeance = date.fromisoformat(echeance_str)
            diff = (echeance - today).days
            jours = max(0, diff)
            en_retard = diff < 0 and row["statut"] not in ("Terminé", "Abandonné")
        except ValueError:
            pass
    return PlanView(
        id=row["id"], reference=row["reference"], titre=row["titre"],
        description=row["description"] or "", type_action=row["type_action"],
        source=row["source"], source_ref=row["source_ref"] or "",
        responsable=row["responsable"] or "", date_debut=row["date_debut"] or "",
        date_echeance=echeance_str, jours_restants=jours, priorite=row["priorite"],
        statut=row["statut"], avancement=row["avancement"] or 0,
        en_retard=en_retard, cree_le=row["cree_le"], modifie_le=row["modifie_le"],
    )


def list_plans() -> list[PlanView]:
    with database_manager.transaction() as conn:
        rows = conn.execute("SELECT * FROM ro_plans_action ORDER BY cree_le DESC").fetchall()
    return [_row_to_plan(r) for r in rows]


def create_plan(data: PlanCreate) -> PlanView:
    id_ = _new_id()
    now = utcnow_iso()
    with database_manager.transaction() as conn:
        ref = _seq_reference("ACT", conn)
        conn.execute(
            """INSERT INTO ro_plans_action (id, reference, titre, description, type_action, source,
               source_ref, responsable, date_debut, date_echeance, priorite, statut, avancement,
               cree_le, modifie_le) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (id_, ref, data.titre, data.description, data.type_action, data.source,
             data.source_ref, data.responsable, data.date_debut, data.date_echeance,
             data.priorite, data.statut, data.avancement, now, now),
        )
        _log(conn, "Plans", "CREATE", ref, "", data.titre)
    with database_manager.transaction() as conn:
        row = conn.execute("SELECT * FROM ro_plans_action WHERE id = ?", (id_,)).fetchone()
    return _row_to_plan(row)


def update_plan(id_: str, data: PlanUpdate) -> PlanView:
    now = utcnow_iso()
    updates = {k: v for k, v in data.model_dump().items() if v is not None}
    if updates:
        set_clause = ", ".join(f"{k} = ?" for k in updates)
        with database_manager.transaction() as conn:
            old = conn.execute("SELECT reference FROM ro_plans_action WHERE id = ?", (id_,)).fetchone()
            conn.execute(
                f"UPDATE ro_plans_action SET {set_clause}, modifie_le = ? WHERE id = ?",
                (*updates.values(), now, id_),
            )
            _log(conn, "Plans", "UPDATE", old["reference"] if old else id_)
    with database_manager.transaction() as conn:
        row = conn.execute("SELECT * FROM ro_plans_action WHERE id = ?", (id_,)).fetchone()
    return _row_to_plan(row)


def delete_plan(id_: str) -> None:
    with database_manager.transaction() as conn:
        row = conn.execute("SELECT reference FROM ro_plans_action WHERE id = ?", (id_,)).fetchone()
        conn.execute("DELETE FROM ro_plans_action WHERE id = ?", (id_,))
        _log(conn, "Plans", "DELETE", row["reference"] if row else id_)


# ─── Historique ───────────────────────────────────────────────────────────────

def list_historique(limit: int = 200) -> list[HistoriqueView]:
    with database_manager.transaction() as conn:
        rows = conn.execute(
            "SELECT * FROM ro_historique ORDER BY date_evenement DESC LIMIT ?", (limit,)
        ).fetchall()
    return [
        HistoriqueView(
            id=r["id"], date_evenement=r["date_evenement"], utilisateur=r["utilisateur"],
            menu=r["menu"], type_action=r["type_action"], element=r["element"] or "",
            ancienne_valeur=r["ancienne_valeur"] or "", nouvelle_valeur=r["nouvelle_valeur"] or "",
            commentaire=r["commentaire"] or "",
        )
        for r in rows
    ]


# ─── Dashboard ────────────────────────────────────────────────────────────────

def get_dashboard() -> DashboardData:
    today = date.today()
    current_month = today.strftime("%Y-%m")
    last_month = (today.replace(day=1) - timedelta(days=1)).strftime("%Y-%m")

    with database_manager.transaction() as conn:
        # Widget 1 : on calcule K approché depuis les pertes (méthode indicateur de base simplifiée)
        total_pertes = conn.execute(
            "SELECT COALESCE(SUM(perte_nette_calc), 0) as total FROM "
            "(SELECT (perte_brute - perte_recuperee) as perte_nette_calc FROM ro_incidents)"
        ).fetchone()["total"] or 0
        # K_IB simplifié : 15% de la moyenne des pertes sur 3 ans (proxy)
        k_ib = total_pertes * 0.15
        apr = k_ib * 12.5

        # Widget 2
        inc_mois = conn.execute(
            "SELECT COUNT(*) as cnt FROM ro_incidents WHERE date_occurrence LIKE ?",
            (f"{current_month}%",),
        ).fetchone()["cnt"] or 0

        pertes_mois = conn.execute(
            "SELECT COALESCE(SUM(perte_brute - perte_recuperee), 0) as total "
            "FROM ro_incidents WHERE date_occurrence LIKE ?",
            (f"{current_month}%",),
        ).fetchone()["total"] or 0

        pertes_mois_prec = conn.execute(
            "SELECT COALESCE(SUM(perte_brute - perte_recuperee), 0) as total "
            "FROM ro_incidents WHERE date_occurrence LIKE ?",
            (f"{last_month}%",),
        ).fetchone()["total"] or 0

        non_clos = conn.execute(
            "SELECT COUNT(*) as cnt FROM ro_incidents WHERE statut != 'Clôturé'"
        ).fetchone()["cnt"] or 0

        evolution_pct: float | None = None
        if pertes_mois_prec and pertes_mois_prec != 0:
            evolution_pct = round(((pertes_mois - pertes_mois_prec) / abs(pertes_mois_prec)) * 100, 1)

        # Widget 3
        actions_retard = conn.execute(
            "SELECT COUNT(*) as cnt FROM ro_plans_action "
            "WHERE date_echeance != '' AND date_echeance < ? AND statut != 'Terminé'",
            (today.isoformat(),),
        ).fetchone()["cnt"] or 0

        ctrl_non_conf = conn.execute(
            "SELECT COUNT(*) as cnt FROM ro_controles WHERE resultat = 'Non-conforme'"
        ).fetchone()["cnt"] or 0

        # KRI hors seuil
        defs = conn.execute("SELECT * FROM ro_kri_definitions").fetchall()
        kri_hors = 0
        for d in defs:
            last_val = conn.execute(
                "SELECT valeur FROM ro_kri_valeurs WHERE kri_id = ? ORDER BY date_mesure DESC LIMIT 1",
                (d["id"],),
            ).fetchone()
            if last_val:
                st = _kri_statut(last_val["valeur"], d["seuil_alerte"], d["seuil_critique"], d["sens"])
                if st in ("alerte", "critique"):
                    kri_hors += 1

        # Évolution 12 mois
        evolution: list[EvolutionPoint] = []
        for i in range(11, -1, -1):
            d_ref = today.replace(day=1) - timedelta(days=i * 30)
            m_str = d_ref.strftime("%Y-%m")
            row_ev = conn.execute(
                "SELECT COALESCE(SUM(perte_brute), 0) as brute, "
                "COALESCE(SUM(perte_brute - perte_recuperee), 0) as nette "
                "FROM ro_incidents WHERE date_occurrence LIKE ?",
                (f"{m_str}%",),
            ).fetchone()
            evolution.append(EvolutionPoint(
                mois=d_ref.strftime("%b %Y"),
                perte_brute=row_ev["brute"] or 0,
                perte_nette=row_ev["nette"] or 0,
            ))

        # Répartitions
        lm_rows = conn.execute(
            "SELECT ligne_metier, COALESCE(SUM(perte_brute - perte_recuperee), 0) as valeur "
            "FROM ro_incidents GROUP BY ligne_metier"
        ).fetchall()
        repartition_lm = [RepartitionItem(label=r["ligne_metier"], valeur=int(r["valeur"])) for r in lm_rows]

        type_rows = conn.execute(
            "SELECT type_evenement, COUNT(*) as cnt FROM ro_incidents GROUP BY type_evenement"
        ).fetchall()
        repartition_type = [RepartitionItem(label=r["type_evenement"], valeur=r["cnt"]) for r in type_rows]

    return DashboardData(
        widget1=DashboardWidget1(
            exigence_fonds_propres=k_ib,
            apr_risque_op=apr,
            statut_reglementaire="Conforme" if k_ib >= 0 else "Attention",
        ),
        widget2=DashboardWidget2(
            total_incidents_mois=inc_mois,
            pertes_nettes_mois=pertes_mois,
            incidents_non_clos=non_clos,
            evolution_pertes_pct=evolution_pct,
        ),
        widget3=DashboardWidget3(
            actions_en_retard=actions_retard,
            controles_non_conformes=ctrl_non_conf,
            kri_hors_seuil=kri_hors,
        ),
        evolution_pertes=evolution,
        repartition_ligne_metier=repartition_lm,
        repartition_type=repartition_type,
    )
