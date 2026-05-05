"""Jeu de donnees en memoire pour demarrer rapidement le projet."""

COUNTERPARTIES = [
    {
        "id": "CP001",
        "name": "Societe A",
        "country": "France",
        "category": "Entreprises",
        "rating": "BBB",
    },
    {
        "id": "CP002",
        "name": "Banque X",
        "country": "Allemagne",
        "category": "Banques",
        "rating": "A",
    },
    {
        "id": "CP003",
        "name": "Etat Y",
        "country": "Espagne",
        "category": "Souverains",
        "rating": "AA",
    },
    {
        "id": "CP004",
        "name": "Client ABC",
        "country": "France",
        "category": "Particuliers",
        "rating": "BB+",
    },
    {
        "id": "CP005",
        "name": "Client XYZ",
        "country": "Cote d'Ivoire",
        "category": "Entreprises",
        "rating": "BBB",
    },
    {
        "id": "CP006",
        "name": "Banque ABC",
        "country": "Maroc",
        "category": "Banques",
        "rating": "A",
    },
]

EXPOSITIONS = [
    {
        "id": "CP001",
        "analysis_date": "2026-04-21",
        "counterparty_id": "CP001",
        "gross_amount": 50_000_000,
        "crm_type": "Garantie etatique",
        "crm_coverage_percent": 0.40,
        "comment": "Portefeuille corporate France",
    },
    {
        "id": "CP002",
        "analysis_date": "2026-04-21",
        "counterparty_id": "CP002",
        "gross_amount": 30_000_000,
        "crm_type": "Cash collateral",
        "crm_coverage_percent": 0.20,
        "comment": "Ligne interbancaire",
    },
    {
        "id": "CP003",
        "analysis_date": "2026-04-21",
        "counterparty_id": "CP003",
        "gross_amount": 40_000_000,
        "crm_type": "Aucune",
        "crm_coverage_percent": 0.00,
        "comment": "Exposition souveraine",
    },
    {
        "id": "CP004",
        "analysis_date": "2026-04-21",
        "counterparty_id": "CP004",
        "gross_amount": 10_000_000,
        "crm_type": "Assurance credit",
        "crm_coverage_percent": 0.75,
        "comment": "Retail securise",
    },
]

OFF_BALANCE_COMMITMENTS = [
    {
        "id": "HB001",
        "analysis_date": "2026-04-21",
        "counterparty_id": "CP002",
        "engagement_type": "Credit documentaire",
        "nominal_amount": 10_000_000,
        "comment": "Flux import",
    },
    {
        "id": "HB002",
        "analysis_date": "2026-04-21",
        "counterparty_id": "CP005",
        "engagement_type": "Lignes de credit",
        "nominal_amount": 15_000_000,
        "comment": "Lignes non annullables",
    },
    {
        "id": "HB003",
        "analysis_date": "2026-04-21",
        "counterparty_id": "CP006",
        "engagement_type": "Instruments financiers",
        "nominal_amount": 8_000_000,
        "comment": "Back-up market",
    },
    {
        "id": "HB004",
        "analysis_date": "2026-04-21",
        "counterparty_id": "CP001",
        "engagement_type": "Garanties financieres",
        "nominal_amount": 5_000_000,
        "comment": "Support de tresorerie",
    },
]

GUARANTEES = [
    {
        "id": "CRM001",
        "exposure_id": "CP001",
        "guarantor_name": "Etat Francais",
        "guarantor_category": "Souverains",
        "guarantor_rating": "AA",
        "coverage_amount": 20_000_000,
        "guarantee_type": "CRM non financee",
        "scenario_type": "Emprunteur -> Garant",
    },
    {
        "id": "CRM002",
        "exposure_id": "CP002",
        "guarantor_name": "Societe Z",
        "guarantor_category": "Entreprises",
        "guarantor_rating": "A",
        "coverage_amount": 9_000_000,
        "guarantee_type": "CRM financee",
        "scenario_type": "Banque -> Depot de cash",
    },
    {
        "id": "CRM003",
        "exposure_id": "CP004",
        "guarantor_name": "Assurance C",
        "guarantor_category": "Entreprises",
        "guarantor_rating": "BBB",
        "coverage_amount": 4_500_000,
        "guarantee_type": "Assurance credit",
        "scenario_type": "Particulier -> Assureur",
    },
]

RISK_WEIGHT_REFERENCES = [
    {"id": "RW001", "segment": "Souverains", "rating": "AAA/AA", "risk_weight": 0.00, "approach": "Standard"},
    {"id": "RW002", "segment": "Souverains", "rating": "A", "risk_weight": 0.20, "approach": "Standard"},
    {"id": "RW003", "segment": "Souverains", "rating": "BBB", "risk_weight": 0.50, "approach": "Standard"},
    {"id": "RW004", "segment": "Souverains", "rating": "Non noté", "risk_weight": 1.00, "approach": "Standard"},
    {"id": "RW005", "segment": "Banques", "rating": "AAA/AA", "risk_weight": 0.20, "approach": "Standard"},
    {"id": "RW006", "segment": "Banques", "rating": "A", "risk_weight": 0.50, "approach": "Standard"},
    {"id": "RW007", "segment": "Banques", "rating": "BBB", "risk_weight": 1.00, "approach": "Standard"},
    {"id": "RW008", "segment": "Banques", "rating": "Non noté", "risk_weight": 1.00, "approach": "Standard"},
    {"id": "RW009", "segment": "Entreprises", "rating": "AAA/AA", "risk_weight": 0.20, "approach": "Standard"},
    {"id": "RW010", "segment": "Entreprises", "rating": "A", "risk_weight": 0.50, "approach": "Standard"},
    {"id": "RW011", "segment": "Entreprises", "rating": "BBB", "risk_weight": 1.00, "approach": "Standard"},
    {"id": "RW012", "segment": "Entreprises", "rating": "BB/B", "risk_weight": 1.50, "approach": "Standard"},
    {"id": "RW013", "segment": "Entreprises", "rating": "Non noté", "risk_weight": 1.00, "approach": "Standard"},
    {"id": "RW014", "segment": "Particuliers", "rating": "AAA/AA", "risk_weight": 0.35, "approach": "Standard"},
    {"id": "RW015", "segment": "Particuliers", "rating": "A", "risk_weight": 0.50, "approach": "Standard"},
    {"id": "RW016", "segment": "Particuliers", "rating": "BBB", "risk_weight": 0.75, "approach": "Standard"},
    {"id": "RW017", "segment": "Particuliers", "rating": "BB/B", "risk_weight": 1.00, "approach": "Standard"},
    {"id": "RW018", "segment": "Particuliers", "rating": "Non noté", "risk_weight": 0.75, "approach": "Standard"},
]

CCF_REFERENCES = [
    {"id": "CCF001", "engagement_type": "Credit documentaire", "ccf": 0.75},
    {"id": "CCF002", "engagement_type": "Lignes de credit", "ccf": 0.50},
    {"id": "CCF003", "engagement_type": "Instruments financiers", "ccf": 1.00},
    {"id": "CCF004", "engagement_type": "Garanties financieres", "ccf": 0.50},
    {"id": "CCF005", "engagement_type": "Engagement de garantie", "ccf": 1.00},
]

RATING_REFERENCES = [
    {"id": "RT001", "label": "AAA/AA", "description": "Qualite de signature tres forte", "sort_order": 1},
    {"id": "RT002", "label": "A", "description": "Qualite de signature solide", "sort_order": 2},
    {"id": "RT003", "label": "BBB", "description": "Qualite investment grade", "sort_order": 3},
    {"id": "RT004", "label": "BB/B", "description": "Qualite speculative", "sort_order": 4},
    {"id": "RT005", "label": "Non noté", "description": "Aucune note externe", "sort_order": 5},
]

REPORTS = [
    {
        "id": "RPT001",
        "created_at": "2026-04-19",
        "period": "Mars 2026",
        "report_type": "Synthese",
        "currency": "EUR",
        "exposure_scope": "Toutes",
        "include_category_chart": True,
        "include_rating_chart": True,
    },
    {
        "id": "RPT002",
        "created_at": "2026-04-20",
        "period": "Mars 2026",
        "report_type": "Detaille",
        "currency": "EUR",
        "exposure_scope": "Toutes",
        "include_category_chart": True,
        "include_rating_chart": False,
    },
]
