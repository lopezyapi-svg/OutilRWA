-- Migration 040 : Refonte complète de la table fodep_attestation selon le modèle officiel BCEAO
-- Le modèle précédent était générique. Le nouveau modèle exige des champs spécifiques
-- pour le responsable du renseignement, le responsable de la transmission, et deux signataires.

DROP TABLE IF EXISTS fodep_attestation;

CREATE TABLE fodep_attestation (
    id TEXT PRIMARY KEY,
    
    -- Renseignement
    rens_prenoms_nom TEXT NOT NULL DEFAULT '',
    rens_fonction TEXT NOT NULL DEFAULT '',
    rens_telephone TEXT NOT NULL DEFAULT '',
    rens_poste TEXT NOT NULL DEFAULT '',
    rens_email TEXT NOT NULL DEFAULT '',
    
    -- Transmission
    trans_prenoms_nom TEXT NOT NULL DEFAULT '',
    trans_fonction TEXT NOT NULL DEFAULT '',
    trans_telephone TEXT NOT NULL DEFAULT '',
    trans_poste TEXT NOT NULL DEFAULT '',
    trans_email TEXT NOT NULL DEFAULT '',
    
    -- Certification
    certif_nous_1 TEXT NOT NULL DEFAULT '',
    certif_nous_2 TEXT NOT NULL DEFAULT '',
    
    -- Signatures
    sign1_code TEXT NOT NULL DEFAULT '',
    sign1_fonction TEXT NOT NULL DEFAULT '',
    sign1_date TEXT NOT NULL DEFAULT '',
    
    sign2_code TEXT NOT NULL DEFAULT '',
    sign2_fonction TEXT NOT NULL DEFAULT '',
    sign2_date TEXT NOT NULL DEFAULT '',
    
    cree_le TEXT NOT NULL,
    modifie_le TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_fodep_attestation_modif
    ON fodep_attestation(modifie_le);
