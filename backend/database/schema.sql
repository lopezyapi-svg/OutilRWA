CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    applied_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS app_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS import_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_type TEXT NOT NULL,
    source_name TEXT,
    imported_at TEXT NOT NULL,
    total_rows INTEGER NOT NULL DEFAULT 0,
    imported_rows INTEGER NOT NULL DEFAULT 0,
    rejected_rows INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL,
    details_json TEXT
);

CREATE TABLE IF NOT EXISTS operation_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL,
    entity_id TEXT,
    operation TEXT NOT NULL,
    payload_json TEXT,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS counterparties (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    country TEXT NOT NULL,
    country_rating TEXT NOT NULL DEFAULT 'Non noté',
    category_standard TEXT NOT NULL,
    category_prudential TEXT NOT NULL,
    rating TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS exposures (
    id TEXT PRIMARY KEY,
    counterparty_id TEXT NOT NULL,
    analysis_date TEXT NOT NULL,
    grant_date TEXT,
    maturity_date TEXT,
    gross_amount REAL NOT NULL,
    currency TEXT NOT NULL DEFAULT 'XOF',
    status TEXT NOT NULL DEFAULT 'Active',
    sovereign_special_case TEXT NOT NULL DEFAULT '',
    sovereign_preferential_zero_weight INTEGER NOT NULL DEFAULT 0,
    sovereign_oce_established INTEGER NOT NULL DEFAULT 0,
    sovereign_oce_note TEXT NOT NULL DEFAULT '',
    public_body_uemoa_fcfa_case INTEGER,
    public_body_non_public_activity INTEGER,
    bmd_high_quality_case INTEGER,
    bmd_uemoa_fcfa_case INTEGER,
    bmd_uemoa_criteria_satisfied INTEGER,
    bmd_listed_institution_fcfa_case INTEGER,
    bank_institution_case TEXT,
    other_asset_type TEXT,
    off_balance_risk_level TEXT,
    retail_eligibility_criteria_satisfied INTEGER,
    residential_mortgage_eligible INTEGER,
    commercial_real_estate_eligible INTEGER,
    defaulted_exposure_initial_risk_weight REAL,
    defaulted_exposure_residential_mortgage_in_default INTEGER,
    defaulted_exposure_provision_at_least_twenty_percent INTEGER,
    enterprise_exceeds_bceao_degradation_threshold INTEGER,
    enterprise_prudential_procedure INTEGER,
    enterprise_investment_firm_without_banking_law INTEGER,
    crm_exists INTEGER NOT NULL DEFAULT 0,
    crm_type TEXT NOT NULL DEFAULT 'Aucune',
    crm_mode TEXT NOT NULL DEFAULT 'Aucune',
    crm_label TEXT NOT NULL DEFAULT 'Aucune',
    crm_coverage_percent REAL NOT NULL DEFAULT 0,
    original_rw REAL NOT NULL DEFAULT 0,
    final_rw REAL NOT NULL DEFAULT 0,
    ead REAL NOT NULL DEFAULT 0,
    rwa REAL NOT NULL DEFAULT 0,
    capital REAL NOT NULL DEFAULT 0,
    comment TEXT,
    source_fields_json TEXT NOT NULL DEFAULT '{}',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY(counterparty_id) REFERENCES counterparties(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS crm_financed (
    exposure_id TEXT PRIMARY KEY,
    collateral_value REAL NOT NULL DEFAULT 0,
    collateral_currency TEXT NOT NULL DEFAULT 'XOF',
    collateral_type TEXT NOT NULL DEFAULT 'Liquidités dans la même devise',
    issuer_type TEXT NOT NULL DEFAULT '',
    issuer_rating TEXT NOT NULL DEFAULT '',
    maturity_bucket TEXT NOT NULL DEFAULT '<=1 an',
    convertible_main_index INTEGER NOT NULL DEFAULT 1,
    opcvm_highest_haircut REAL NOT NULL DEFAULT 0.30,
    basket_items_json TEXT NOT NULL DEFAULT '[]',
    fx_haircut REAL NOT NULL DEFAULT 0,
    haircut REAL NOT NULL DEFAULT 0,
    exposure_currency TEXT NOT NULL DEFAULT 'XOF',
    risk_weight REAL NOT NULL DEFAULT 0,
    collateral_eligible INTEGER NOT NULL DEFAULT 1,
    ineligibility_reason TEXT NOT NULL DEFAULT '',
    he REAL NOT NULL DEFAULT 0,
    hc REAL NOT NULL DEFAULT 0,
    hfx REAL NOT NULL DEFAULT 0,
    eva REAL NOT NULL DEFAULT 0,
    cva REAL NOT NULL DEFAULT 0,
    ead_after_financed_crm REAL NOT NULL DEFAULT 0,
    rwa_final REAL NOT NULL DEFAULT 0,
    crm_gain REAL NOT NULL DEFAULT 0,
    FOREIGN KEY(exposure_id) REFERENCES exposures(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS crm_non_financed (
    exposure_id TEXT PRIMARY KEY,
    guarantor_name TEXT NOT NULL DEFAULT '',
    guarantor_category TEXT NOT NULL DEFAULT '',
    guarantor_rating TEXT NOT NULL DEFAULT '',
    guarantor_country TEXT NOT NULL DEFAULT '',
    guarantor_country_rating TEXT NOT NULL DEFAULT '',
    guarantor_country_rw REAL NOT NULL DEFAULT 0,
    guarantor_rw REAL NOT NULL DEFAULT 0,
    coverage_percent REAL NOT NULL DEFAULT 0,
    FOREIGN KEY(exposure_id) REFERENCES exposures(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS off_balance_commitments (
    id TEXT PRIMARY KEY,
    counterparty_id TEXT NOT NULL,
    analysis_date TEXT NOT NULL,
    engagement_type TEXT NOT NULL,
    nominal_amount REAL NOT NULL,
    ccf REAL NOT NULL DEFAULT 1,
    ead REAL NOT NULL DEFAULT 0,
    risk_weight REAL NOT NULL DEFAULT 0,
    rwa REAL NOT NULL DEFAULT 0,
    capital REAL NOT NULL DEFAULT 0,
    comment TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY(counterparty_id) REFERENCES counterparties(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS crm_guarantees (
    id TEXT PRIMARY KEY,
    exposure_id TEXT NOT NULL,
    guarantor_name TEXT NOT NULL,
    guarantor_category TEXT NOT NULL,
    guarantor_rating TEXT NOT NULL,
    coverage_amount REAL NOT NULL,
    guarantee_type TEXT NOT NULL,
    scenario_type TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY(exposure_id) REFERENCES exposures(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS risk_weight_references (
    id TEXT PRIMARY KEY,
    segment TEXT NOT NULL,
    rating TEXT NOT NULL,
    risk_weight REAL NOT NULL,
    approach TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS ccf_references (
    id TEXT PRIMARY KEY,
    engagement_type TEXT NOT NULL,
    ccf REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS rating_references (
    id TEXT PRIMARY KEY,
    label TEXT NOT NULL,
    description TEXT NOT NULL,
    sort_order INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS sovereign_country_references (
    country TEXT PRIMARY KEY,
    sovereign_rating TEXT NOT NULL,
    risk_weight REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS reports (
    id TEXT PRIMARY KEY,
    created_at TEXT NOT NULL,
    period TEXT NOT NULL,
    report_type TEXT NOT NULL,
    currency TEXT NOT NULL,
    exposure_scope TEXT NOT NULL,
    include_category_chart INTEGER NOT NULL DEFAULT 1,
    include_rating_chart INTEGER NOT NULL DEFAULT 1,
    export_pdf_path TEXT NOT NULL,
    export_excel_path TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS report_lines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_id TEXT NOT NULL,
    line_order INTEGER NOT NULL,
    source TEXT NOT NULL,
    item_id TEXT NOT NULL,
    counterparty TEXT NOT NULL,
    amount REAL NOT NULL,
    ead REAL NOT NULL,
    rwa REAL NOT NULL,
    capital REAL NOT NULL,
    FOREIGN KEY(report_id) REFERENCES reports(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_counterparties_name ON counterparties(name);
CREATE INDEX IF NOT EXISTS idx_counterparties_country ON counterparties(country);
CREATE INDEX IF NOT EXISTS idx_counterparties_category ON counterparties(category_standard);
CREATE INDEX IF NOT EXISTS idx_counterparties_prudential ON counterparties(category_prudential);
CREATE INDEX IF NOT EXISTS idx_counterparties_rating ON counterparties(rating);
CREATE INDEX IF NOT EXISTS idx_exposures_analysis_date ON exposures(analysis_date);
CREATE INDEX IF NOT EXISTS idx_exposures_status ON exposures(status);
CREATE INDEX IF NOT EXISTS idx_exposures_currency ON exposures(currency);
CREATE INDEX IF NOT EXISTS idx_exposures_crm_mode ON exposures(crm_mode);
CREATE INDEX IF NOT EXISTS idx_exposures_counterparty ON exposures(counterparty_id);
CREATE INDEX IF NOT EXISTS idx_off_balance_counterparty ON off_balance_commitments(counterparty_id);
CREATE INDEX IF NOT EXISTS idx_off_balance_type ON off_balance_commitments(engagement_type);
CREATE INDEX IF NOT EXISTS idx_crm_guarantees_exposure ON crm_guarantees(exposure_id);
CREATE INDEX IF NOT EXISTS idx_risk_weight_segment_rating ON risk_weight_references(segment, rating);
CREATE INDEX IF NOT EXISTS idx_ccf_engagement_type ON ccf_references(engagement_type);
CREATE INDEX IF NOT EXISTS idx_rating_sort_order ON rating_references(sort_order);
CREATE INDEX IF NOT EXISTS idx_report_lines_report ON report_lines(report_id, line_order);
