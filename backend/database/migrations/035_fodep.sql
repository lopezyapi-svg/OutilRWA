-- Module FODEP (Formulaire de Déclaration Prudentielle, BCEAO/UMOA).
--
-- Distinct de la table « fonds_propres » existante (modèle simplifié à 11
-- postes utilisé par le tableau de bord) : le FODEP officiel exige le détail
-- des 45 postes réglementaires (codes DISPRU FPIxx / IMxxx / IDxxx / PAxxx)
-- prévus par la notice technique BCEAO, avec convention de signe stricte
-- pour les déductions. Les deux tables cohabitent sans se remplacer.
--
-- Une ligne par période d'arrêté (semestrielle : 30/06 ou 31/12).
CREATE TABLE IF NOT EXISTS fodep_fonds_propres (
    id TEXT PRIMARY KEY,
    periode TEXT NOT NULL UNIQUE,

    -- CET1 — éléments positifs
    fpi01 REAL NOT NULL DEFAULT 0,
    fpi02 REAL NOT NULL DEFAULT 0,
    fpi03 REAL NOT NULL DEFAULT 0,
    fpi04 REAL NOT NULL DEFAULT 0,
    fpi05 REAL NOT NULL DEFAULT 0,
    fpi06 REAL NOT NULL DEFAULT 0,
    fpi07 REAL NOT NULL DEFAULT 0,

    -- CET1 — déductions (saisies <= 0)
    fpi09 REAL NOT NULL DEFAULT 0,
    fpi10 REAL NOT NULL DEFAULT 0,
    im012 REAL NOT NULL DEFAULT 0,
    id009 REAL NOT NULL DEFAULT 0,
    pa156 REAL NOT NULL DEFAULT 0,
    pa173 REAL NOT NULL DEFAULT 0,
    fpi11 REAL NOT NULL DEFAULT 0,
    pa149 REAL NOT NULL DEFAULT 0,
    im006 REAL NOT NULL DEFAULT 0,
    im010 REAL NOT NULL DEFAULT 0,
    pr004 REAL NOT NULL DEFAULT 0,
    fpi12 REAL NOT NULL DEFAULT 0,
    fpi13 REAL NOT NULL DEFAULT 0,
    pa163 REAL NOT NULL DEFAULT 0,
    pa172 REAL NOT NULL DEFAULT 0,
    id011 REAL NOT NULL DEFAULT 0,
    fpi20 REAL NOT NULL DEFAULT 0,
    fpi21 REAL NOT NULL DEFAULT 0,

    -- AT1
    fpi23 REAL NOT NULL DEFAULT 0,
    fpi24 REAL NOT NULL DEFAULT 0,
    fpi25 REAL NOT NULL DEFAULT 0,
    pa157 REAL NOT NULL DEFAULT 0,
    pa164 REAL NOT NULL DEFAULT 0,
    pa174 REAL NOT NULL DEFAULT 0,
    fpi27 REAL NOT NULL DEFAULT 0,

    -- Tier 2
    fpi30 REAL NOT NULL DEFAULT 0,
    fpi31 REAL NOT NULL DEFAULT 0,
    fpi32 REAL NOT NULL DEFAULT 0,
    fpi33 REAL NOT NULL DEFAULT 0,
    fpi34 REAL NOT NULL DEFAULT 0,
    fpi35 REAL NOT NULL DEFAULT 0,
    fpi36 REAL NOT NULL DEFAULT 0,
    fpi37 REAL NOT NULL DEFAULT 0,
    fpi38 REAL NOT NULL DEFAULT 0,
    pa158 REAL NOT NULL DEFAULT 0,
    pa165 REAL NOT NULL DEFAULT 0,
    pa175 REAL NOT NULL DEFAULT 0,

    -- Fonds propres nets (grands risques)
    fpi42 REAL NOT NULL DEFAULT 0,

    cree_le TEXT NOT NULL,
    modifie_le TEXT NOT NULL
);

-- Établissement déclarant (une seule ligne en pratique).
CREATE TABLE IF NOT EXISTS fodep_etablissement (
    id TEXT PRIMARY KEY,
    denomination TEXT NOT NULL DEFAULT '',
    code_bceao TEXT NOT NULL DEFAULT '',
    modifie_le TEXT NOT NULL
);

-- FODEP importés pour analyse (onglet « Analyser un FODEP existant »).
-- Les valeurs extraites du classeur sont conservées en JSON : le tableau
-- officiel comporte 39 états, la structure varie section par section, et une
-- table à colonnes fixes serait périmée dès la section suivante portée.
CREATE TABLE IF NOT EXISTS fodep_import (
    id TEXT PRIMARY KEY,
    nom_fichier TEXT NOT NULL,
    periode TEXT,
    donnees_json TEXT NOT NULL,
    cree_le TEXT NOT NULL
);
