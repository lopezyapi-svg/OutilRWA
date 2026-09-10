"""Rapport ICAAP en PDF (lot L5).

Assemble, à partir des services du module, un document paginé : page de
garde, sommaire, synthèse, cartographie des risques, besoin en capital
économique et couverture, capital interne disponible, stress tests (avec
graphique), planification du capital, plan d'action et opinions.

Rendu en Python pur avec reportlab (déjà requis par l'export FODEP) : le
poste qui héberge l'API n'a besoin d'aucun logiciel installé à côté.
"""

from __future__ import annotations

from io import BytesIO

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    NextPageTemplate,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)

from database.connection import database_manager

from app.icaap import services

_NAVY = colors.HexColor("#1F3864")
_BLUE = colors.HexColor("#2E5C99")
_LIGHT = colors.HexColor("#EAF0F8")
_LINE = colors.HexColor("#B9C6DA")
_GREY = colors.HexColor("#5A5A5A")
_ALERT = colors.HexColor("#B03A2E")
_OK = colors.HexColor("#1E7E34")

_base = getSampleStyleSheet()
_S = {
    "title": ParagraphStyle("t", parent=_base["Title"], fontName="Helvetica-Bold",
                            fontSize=24, textColor=_NAVY, leading=28),
    "subtitle": ParagraphStyle("st", parent=_base["Normal"], fontSize=12,
                               textColor=_GREY, alignment=TA_CENTER, leading=17),
    "h1": ParagraphStyle("h1", parent=_base["Heading1"], fontName="Helvetica-Bold",
                         fontSize=14, textColor=colors.white, backColor=_NAVY,
                         borderPadding=(5, 7, 5, 7), spaceBefore=16, spaceAfter=9,
                         leading=18),
    "h2": ParagraphStyle("h2", parent=_base["Heading2"], fontName="Helvetica-Bold",
                         fontSize=11.5, textColor=_NAVY, spaceBefore=10, spaceAfter=4),
    "body": ParagraphStyle("b", parent=_base["Normal"], fontSize=9.5, leading=13.5,
                           alignment=TA_JUSTIFY, spaceAfter=5),
    "cell": ParagraphStyle("c", parent=_base["Normal"], fontSize=8.5, leading=11),
    "cellb": ParagraphStyle("cb", parent=_base["Normal"], fontSize=8.5, leading=11,
                            fontName="Helvetica-Bold", textColor=colors.white),
    "small": ParagraphStyle("sm", parent=_base["Normal"], fontSize=8, textColor=_GREY),
    "toc": ParagraphStyle("toc", parent=_base["Normal"], fontSize=10, leading=17),
}


def _p(text: str, style: str = "body") -> Paragraph:
    return Paragraph(text, _S[style])


def _fmt(valeur: float, suffixe: str = "") -> str:
    return f"{valeur:,.2f}{suffixe}".replace(",", " ")


def _table(data, col_widths, header: bool = True) -> Table:
    t = Table(data, colWidths=col_widths, repeatRows=1 if header else 0)
    cmds = [
        ("GRID", (0, 0), (-1, -1), 0.4, _LINE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ("ROWBACKGROUNDS", (0, 1 if header else 0), (-1, -1), [colors.white, _LIGHT]),
    ]
    if header:
        cmds += [
            ("BACKGROUND", (0, 0), (-1, 0), _BLUE),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("FONTSIZE", (0, 0), (-1, 0), 8.5),
        ]
    t.setStyle(TableStyle(cmds))
    return t


def _hrow(*cells):
    return [Paragraph(str(c), _S["cellb"]) for c in cells]


def _row(*cells):
    return [Paragraph("" if c is None else str(c), _S["cell"]) for c in cells]


def _etablissement() -> str:
    try:
        with database_manager.read_connection() as conn:
            row = conn.execute(
                "SELECT denomination FROM fodep_etablissement "
                "WHERE denomination <> '' ORDER BY modifie_le DESC LIMIT 1"
            ).fetchone()
        return (row["denomination"] if row else "") or ""
    except Exception:  # noqa: BLE001 - table absente sur certains schémas
        return ""


# ── graphique ratio par année ─────────────────────────────────────────────
def _drawing_ratios(series: list[tuple[str, list[tuple[int, float]]]],
                    seuils: dict[str, float]):
    """Line chart : ratio de solvabilité (%) par année, une ligne par série.
    Renvoie None si la construction échoue ou s'il n'y a rien à tracer."""

    points = [pts for _, pts in series if pts]
    if not points:
        return None
    try:
        from reportlab.graphics.charts.legends import Legend
        from reportlab.graphics.charts.linecharts import HorizontalLineChart
        from reportlab.graphics.shapes import Drawing, Line, String

        annees = sorted({a for pts in points for a, _ in pts})
        data = []
        for _, pts in series:
            m = dict(pts)
            data.append([m.get(a) for a in annees])

        d = Drawing(440, 210)
        chart = HorizontalLineChart()
        chart.x, chart.y, chart.width, chart.height = 40, 40, 330, 150
        chart.data = data
        chart.categoryAxis.categoryNames = [str(a) for a in annees]
        chart.categoryAxis.labels.fontSize = 7
        chart.valueAxis.labels.fontSize = 7
        chart.valueAxis.valueMin = 0
        chart.lines.strokeWidth = 1.5
        palette = [_BLUE, _ALERT, _OK, colors.orange, colors.purple]
        for i in range(len(data)):
            chart.lines[i].strokeColor = palette[i % len(palette)]
        d.add(chart)

        # Lignes de seuil réglementaire.
        try:
            vmax = max(v for pts in points for _, v in pts) or 1.0
            vmax = max(vmax, *seuils.values()) * 1.15
            chart.valueAxis.valueMax = round(vmax + 1)
            for libelle, seuil in seuils.items():
                y = 40 + 150 * (seuil / (chart.valueAxis.valueMax or 1))
                d.add(Line(40, y, 370, y, strokeColor=_GREY, strokeDashArray=[2, 2]))
                d.add(String(372, y - 3, f"{libelle} {seuil:g}%", fontSize=6,
                             fillColor=_GREY))
        except Exception:  # noqa: BLE001
            pass

        leg = Legend()
        leg.x, leg.y = 40, 20
        leg.fontSize = 7
        leg.alignment = "right"
        leg.columnMaximum = 1
        leg.deltax = 90
        leg.colorNamePairs = [
            (palette[i % len(palette)], nom) for i, (nom, _) in enumerate(series)
        ]
        d.add(leg)
        return d
    except Exception:  # noqa: BLE001 - le rapport reste utilisable sans graphe
        return None


# ── sections ──────────────────────────────────────────────────────────────
def _section_synthese(story, exercice, couverture, seuil_solva_cible):
    story.append(_p("1. Synthèse", "h1"))
    if couverture is None:
        story.append(_p("Le besoin en capital économique n'a pas encore été "
                        "calculé pour cet exercice."))
        return
    verdict = ("<font color='#B03A2E'><b>sous le seuil d'alerte "
               "(100 %)</b></font>" if couverture.en_alerte
               else "<font color='#1E7E34'><b>au-dessus du seuil d'alerte</b></font>")
    ratio = ("infini" if couverture.ratio_couverture == float("inf")
             else _fmt(couverture.ratio_couverture, " %"))
    story.append(_table([
        _hrow("Indicateur", "Valeur"),
        _row("Besoin en capital économique — somme simple",
             _fmt(couverture.besoin_somme_simple)),
        _row("Besoin en capital économique — après diversification",
             _fmt(couverture.besoin_apres_diversification)),
        _row("Bénéfice de diversification", _fmt(couverture.benefice_diversification)),
        _row("Capital interne disponible", _fmt(couverture.capital_interne_disponible)),
        _row("Ratio de couverture ICAAP", ratio),
        _row("Ratio de solvabilité cible (référence)", _fmt(seuil_solva_cible, " %")),
    ], [95 * mm, 70 * mm]))
    story.append(Spacer(1, 4))
    story.append(_p(f"Appréciation : la couverture du capital interne est {verdict}."))


def _section_cartographie(story, risques):
    story.append(_p("2. Cartographie des risques", "h1"))
    if not risques:
        story.append(_p("Aucun risque cartographié."))
        return
    data = [_hrow("Catégorie", "Libellé", "P", "I", "Matérialité", "Méthode", "Pilier")]
    for r in risques:
        data.append(_row(r.categorie, r.libelle, r.probabilite, r.impact,
                         r.materialite, r.methode, r.pilier))
    story.append(_table(data, [30 * mm, 45 * mm, 10 * mm, 10 * mm, 25 * mm,
                               20 * mm, 15 * mm]))


def _section_capital_eco(story, couverture):
    story.append(_p("3. Besoin en capital économique par risque", "h1"))
    if couverture is None or not couverture.detail_par_risque:
        story.append(_p("Non calculé."))
        return
    data = [_hrow("Risque", "Famille", "Méthode", "Besoin")]
    for l in couverture.detail_par_risque:
        data.append(_row(l.libelle or l.categorie, l.cle_correlation, l.methode,
                         _fmt(l.montant_besoin)))
    data.append(_row("", "", "Somme simple", _fmt(couverture.besoin_somme_simple)))
    data.append(_row("", "", "Après diversification",
                     _fmt(couverture.besoin_apres_diversification)))
    story.append(_table(data, [58 * mm, 32 * mm, 40 * mm, 35 * mm]))


def _section_capital_dispo(story, dispo):
    story.append(_p("4. Capital interne disponible", "h1"))
    if dispo is None:
        story.append(_p("Non renseigné pour cet exercice."))
        return
    story.append(_table([
        _hrow("Composante", "Montant"),
        _row("Fonds propres de base durs (CET1)", _fmt(dispo.cet1)),
        _row("Fonds propres additionnels de catégorie 1 (AT1)", _fmt(dispo.at1)),
        _row("Fonds propres de catégorie 2 (T2)", _fmt(dispo.t2)),
        _row("Déductions", _fmt(-abs(dispo.deductions))),
        _row("Capital interne total", _fmt(dispo.capital_interne_total)),
        _row("RWA Pilier 1 total (référence)", _fmt(dispo.rwa_pilier1_total)),
        _row("Source", dispo.source or "—"),
    ], [95 * mm, 70 * mm]))


def _section_stress(story, scenarios, seuils):
    story.append(_p("5. Stress tests", "h1"))
    if not scenarios:
        story.append(_p("Aucun scénario de stress défini."))
        return

    series = []
    for sc in scenarios:
        pts = [(r.annee_proj, r.ratio_projete) for r in sc.resultats]
        if pts:
            series.append((sc.libelle or sc.type_scenario, pts))

    drawing = _drawing_ratios(series, seuils)
    if drawing is not None:
        story.append(_p("Ratio de solvabilité projeté (%) par année", "h2"))
        story.append(drawing)
        story.append(Spacer(1, 6))

    for sc in scenarios:
        story.append(_p(f"{sc.libelle or '(sans titre)'} "
                        f"— type : {sc.type_scenario}", "h2"))
        if not sc.resultats:
            story.append(_p("Scénario non exécuté.", "small"))
            continue
        data = [_hrow("Année", "RWA projeté", "Résultat net",
                      "Fonds propres", "Ratio")]
        for r in sc.resultats:
            data.append(_row(r.annee_proj, _fmt(r.rwa_projete),
                             _fmt(r.resultat_projete),
                             _fmt(r.fonds_propres_projetes),
                             _fmt(r.ratio_projete, " %")))
        story.append(_table(data, [18 * mm, 37 * mm, 37 * mm, 37 * mm, 26 * mm]))
        story.append(Spacer(1, 4))


def _section_plan_capital(story, plan, seuils):
    story.append(_p("6. Planification du capital", "h1"))
    if plan is None or not plan.trajectoire:
        story.append(_p("Aucune projection de capital enregistrée."))
        return
    data = [_hrow("Année", "RWA projeté", "Mise en réserve", "Distributions",
                  "Fonds propres", "Ratio", "Coussin entamé")]
    for l in plan.trajectoire:
        data.append(_row(l.annee_proj, _fmt(l.rwa_projete),
                         _fmt(l.resultat_mis_en_reserve), _fmt(l.distributions),
                         _fmt(l.fonds_propres_projetes), _fmt(l.ratio_projete, " %"),
                         "oui" if l.coussin_entame else "non"))
    story.append(_table(data, [15 * mm, 30 * mm, 28 * mm, 25 * mm, 28 * mm,
                               21 * mm, 22 * mm]))
    story.append(Spacer(1, 4))
    if plan.annee_entame_coussin:
        story.append(_p(
            f"<font color='#B03A2E'>Le ratio de solvabilité passerait sous "
            f"minimum + coussin de conservation "
            f"({seuils.get('minimum + coussin', 0):g} %) dès l'année "
            f"{plan.annee_entame_coussin} de la projection.</font>"))
    else:
        story.append(_p("<font color='#1E7E34'>Le coussin de conservation "
                        "n'est entamé sur aucune année de l'horizon.</font>"))


def _section_plan_action(story, actions):
    story.append(_p("7. Plan d'action", "h1"))
    if not actions:
        story.append(_p("Aucune action corrective enregistrée."))
        return
    data = [_hrow("Constat", "Action", "Responsable", "Échéance", "Statut")]
    for a in actions:
        data.append(_row(a.constat, a.action, a.responsable, a.echeance or "—",
                         a.statut))
    story.append(_table(data, [45 * mm, 55 * mm, 27 * mm, 20 * mm, 18 * mm]))


def _section_opinions(story, exercice):
    story.append(_p("8. Opinion de l'organe exécutif et avis de l'organe "
                    "délibérant", "h1"))
    story.append(_p("Opinion de l'organe exécutif", "h2"))
    story.append(_p(exercice.opinion_executif.replace("\n", "<br/>")
                    if exercice.opinion_executif else "<i>Non renseignée.</i>"))
    story.append(_p("Avis de l'organe délibérant", "h2"))
    story.append(_p(exercice.avis_deliberant.replace("\n", "<br/>")
                    if exercice.avis_deliberant else "<i>Non renseigné.</i>"))


# ── chrome ────────────────────────────────────────────────────────────────
def _footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 7.5)
    canvas.setFillColor(_GREY)
    canvas.drawString(20 * mm, 12 * mm, "Rapport ICAAP — confidentiel")
    canvas.drawRightString(190 * mm, 12 * mm, f"Page {doc.page}")
    canvas.setStrokeColor(_LINE)
    canvas.line(20 * mm, 15 * mm, 190 * mm, 15 * mm)
    canvas.restoreState()


def _cover_bg(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(_NAVY)
    canvas.rect(0, 232 * mm, 210 * mm, 65 * mm, fill=1, stroke=0)
    canvas.setFillColor(_BLUE)
    canvas.rect(0, 228 * mm, 210 * mm, 4 * mm, fill=1, stroke=0)
    canvas.restoreState()


def construire_rapport_pdf(exercice_id: str) -> bytes:
    """Assemble le rapport ICAAP de l'exercice. Lève ``IcaapIntrouvable`` si
    l'exercice n'existe pas ; les sections dont les données manquent sont
    rendues avec la mention « non renseigné »."""

    exercice = services.obtenir_exercice(exercice_id)

    risques = services.lister_cartographie(exercice_id)
    dispo = services.obtenir_capital_dispo(exercice_id)
    try:
        couverture = services.obtenir_couverture(exercice_id)
    except services.IcaapDonneesManquantes:
        couverture = None
    scenarios = services.lister_scenarios(exercice_id)
    plan = services.obtenir_plan_capital(exercice_id)
    actions = services.lister_plan_action(exercice_id)

    params = {p.cle: p.valeur for p in services.lister_parametres()}
    seuil_min = params.get("ratio_solvabilite_min", 9.0)
    seuil_coussin = seuil_min + params.get("coussin_conservation", 2.5)
    seuil_cible = params.get("ratio_solvabilite_cible", seuil_coussin)
    seuils_graphe = {"minimum": seuil_min, "minimum + coussin": seuil_coussin}

    buffer = BytesIO()
    frame = Frame(20 * mm, 17 * mm, 170 * mm, 262 * mm, id="f")
    doc = BaseDocTemplate(
        buffer, pagesize=A4,
        title=f"Rapport ICAAP {exercice.annee}",
        author=_etablissement() or "Risque Management",
        subject="ICAAP / Pilier 2 — UMOA-BCEAO",
    )
    doc.addPageTemplates([
        PageTemplate(id="cover", frames=[frame], onPage=_cover_bg),
        PageTemplate(id="later", frames=[frame], onPage=_footer),
    ])

    story = []
    etab = _etablissement()
    story += [
        Spacer(1, 70 * mm),
        _p("RAPPORT ICAAP", "title"),
        _p("Processus interne d'évaluation de l'adéquation des fonds propres",
           "subtitle"),
        Spacer(1, 20 * mm),
    ]
    story.append(_table([
        _hrow("Rubrique", "Valeur"),
        _row("Établissement", etab or "—"),
        _row("Exercice", exercice.annee),
        _row("Date d'arrêté", exercice.date_arrete),
        _row("Statut", exercice.statut),
        _row("Date de validation", exercice.date_validation or "—"),
    ], [55 * mm, 110 * mm]))
    story += [Spacer(1, 10 * mm),
              _p("Document produit automatiquement par l'outil Risque Management. "
                 "Pilier 2 du dispositif prudentiel UMOA.", "small")]
    story += [NextPageTemplate("later"), PageBreak()]

    story.append(_p("Sommaire", "h1"))
    for t in [
        "1. Synthèse", "2. Cartographie des risques",
        "3. Besoin en capital économique par risque",
        "4. Capital interne disponible", "5. Stress tests",
        "6. Planification du capital", "7. Plan d'action",
        "8. Opinion de l'organe exécutif et avis de l'organe délibérant",
    ]:
        story.append(Paragraph(t, _S["toc"]))
    story.append(PageBreak())

    _section_synthese(story, exercice, couverture, seuil_cible)
    _section_cartographie(story, risques)
    _section_capital_eco(story, couverture)
    _section_capital_dispo(story, dispo)
    _section_stress(story, scenarios, seuils_graphe)
    _section_plan_capital(story, plan, {"minimum + coussin": seuil_coussin})
    _section_plan_action(story, actions)
    _section_opinions(story, exercice)

    doc.build(story)
    return buffer.getvalue()
