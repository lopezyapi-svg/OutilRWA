-- Migration 026 : Ajout revenus_leasing dans op_risk_financial_inputs
-- Le leasing est un composant de l'ILDC (Interest, Leasing & Dividends Component)
-- utilisé dans le calcul CRR3-COREP (onglet import de données).

ALTER TABLE op_risk_financial_inputs
    ADD COLUMN revenus_leasing REAL NOT NULL DEFAULT 0;
