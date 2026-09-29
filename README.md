# Risque Management

Plateforme modulaire de gestion des risques prudentiels bancaires (BCEAO / UMOA / Bâle III), avec un backend Python et un frontend Flutter. Au-delà du calcul des RWA, elle couvre l'ensemble du cycle de gestion des risques d'un établissement : suivi des expositions et contreparties (CRM), risque de marché (VaR, courbes de taux), risque opérationnel, ICAAP (Pilier 2), déclarations réglementaires FODEP, tableaux de bord et reporting.

## Architecture

- `backend/` (Python / FastAPI) expose les APIs metier et les calculs prudentiels. Point d'entree : `backend/app/main.py`, qui monte un routeur FastAPI par module (`backend/app/<module>/`).
- `frontend/` (Flutter, desktop Windows + web) contient l'interface, structuree par modules sous `frontend/lib/modules/<module>/`.
- Chaque module backend suit la meme logique interne : modeles, services, routes. Chaque module frontend suit la meme logique : ecrans, widgets, services.
- Les deux cotes partagent le meme decoupage fonctionnel (ex. `risque_marche` cote backend `market/` et cote frontend `risque_marche/`).

## Modules metier

Cote backend (`backend/app/`) :

- `auth` : authentification et gestion des sessions/roles
- `dashboard` : tableau de bord et KPI agreges
- `expositions` : gestion des expositions (credit)
- `hors_bilan` : engagements hors bilan
- `crm` : suivi des contreparties (CRM)
- `referentiels` : donnees de reference (nomenclatures, taux, echeanciers...)
- `rapports` : generation de rapports
- `rwa_credit` : calcul des RWA credit (densite, ponderations...)
- `market` / `var_marche` : risque de marche, courbes de taux (UEMOA/CEMAC), Value at Risk
- `risque_operationnel` : calculs de risque operationnel
- `icaap` : Pilier 2 / PIEAFP (capital economique, stress tests, rapport ICAAP)
- `fodep` : declarations FODEP (matrice reglementaire BCEAO)
- `core` : configuration, base de donnees, utilitaires partages
- `validators` : regles de validation transverses

Cote frontend (`frontend/lib/modules/`), en plus des equivalents ci-dessus : `vue_ensemble`, `concentration`, `garanties`, `defauts_impayes`, `importations`, `reporting_credit`, `reporting_global`, `risque_credit_shared`, `rwa_engine`, `analyse`.

## Demarrage backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python run_server.py --reload --port 8001
```

> Ne pas lancer `python -m uvicorn app.main:app --reload` directement : le
> rechargement automatique surveillerait alors aussi `data/` (base SQLite,
> logs) et redemarrerait le serveur a chaque enregistrement, faisant echouer
> les requetes en cours. `run_server.py` exclut ces dossiers du rechargement.
> Le port 8001 est celui attendu par defaut par le client desktop.

Si `python -m venv .venv` echoue sous Windows, verifie que Python est bien installe hors alias `WindowsApps`, puis recree le venv avec l'interprete reel.

## Demarrage frontend

```bash
cd frontend
flutter pub get
flutter run
```

## Generation d'un executable Windows

Le projet peut maintenant etre livre sous forme d'un installateur `.exe` Windows qui embarque:

- le frontend Flutter Windows
- le backend Python FastAPI compile en executable
- la base SQLite et les fichiers runtime dans `AppData\Local\RWA Calculator`

Commande de build:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_windows_package.ps1
```

Artefacts generes:

- `dist\RWA_Calculator_Setup.exe` : installateur a transmettre
- `dist\RWA Calculator Portable\` : version portable deja assemblee

## Documentation

Toutes les documentations techniques, fonctionnelles et réglementaires sont centralisées dans le dossier [`docs/`](docs/) :

- **Déploiement Web & Cloud (Docker, Render, Nginx, Caddy) :** [`docs/README_DEPLOIEMENT.md`](docs/README_DEPLOIEMENT.md)
- **Guide des Indicateurs Prudentiels (BCEAO / UMOA / Bâle III) :** [`docs/README_INDICATEURS.md`](docs/README_INDICATEURS.md) ([version HTML](docs/DOCUMENTATION_INDICATEURS.html))
- **Spécification Réglementaire - Risque de Marché :** [`docs/RISQUE_MARCHE_SPEC_REGLEMENTAIRE.md`](docs/RISQUE_MARCHE_SPEC_REGLEMENTAIRE.md)
- **Architecture & Guide Module Risque de Change :** [`docs/FX_RISK_QUICK_REFERENCE.md`](docs/FX_RISK_QUICK_REFERENCE.md), [`docs/FX_RISK_ANALYSIS_GUIDE.md`](docs/FX_RISK_ANALYSIS_GUIDE.md)
- **Diagrammes d'Architecture (PlantUML) :** [`docs/diagrams_uml.txt`](docs/diagrams_uml.txt)
- **Cahier des charges & exemple ICAAP :** [`docs/Cahier_des_Charges_ICAAP.pdf`](docs/Cahier_des_Charges_ICAAP.pdf), [`docs/Rapport_ICAAP_exemple.pdf`](docs/Rapport_ICAAP_exemple.pdf)

## Lancement rapide sous Windows

Pour lancer l'application (backend + interface desktop) directement :
Double-cliquez sur `Demarrer_OutilRWA.bat` à la racine.

## Tests

- Backend : `cd backend && pytest` (suites dans `backend/tests/`, une par fonctionnalité : calculs, ICAAP, FODEP, risque de marché, authentification...).
- Frontend : `cd frontend && flutter test` (suites dans `frontend/test/`, une par écran/service).

## Arborescence

```text
├── backend/             # API FastAPI, calculs prudentiels, base SQLite
│   ├── app/              # Un sous-dossier par module métier (voir "Modules métier")
│   │   └── main.py         # Point d'entrée FastAPI, montage des routeurs
│   ├── data/             # Base SQLite de démo + fichiers runtime (versionnés pour le poste de démo uniquement)
│   ├── database/         # Migrations / accès base
│   ├── scripts/          # Scripts d'exploitation backend (seed, audits...)
│   ├── tests/            # Suite de tests pytest
│   └── run_server.py     # Lanceur du serveur (voir avertissement ci-dessus)
├── frontend/            # Application Flutter (Desktop Windows & Web)
│   ├── lib/modules/      # Un sous-dossier par module métier (voir "Modules métier")
│   ├── assets/           # Polices, images, animations
│   └── test/             # Suite de tests Flutter
├── docs/                # Documentation technique, réglementaire et manuels
├── deploy/              # Configurations Caddy / reverse proxy (interne & public)
├── scripts/             # Build de l'installeur Windows (.exe) et audits (ex. duration obligataire)
├── modeles_import/      # Générateurs et modèles Excel d'import (marché, opérationnel, crédit, fonds propres)
├── Demarrer_OutilRWA.bat # Lanceur rapide pour poste Windows
├── Dockerfile           # Image de production tout-en-un (Web + API)
├── docker-compose.yml   # Déploiement multi-conteneurs avec proxy HTTPS
└── render.yaml          # Blueprint de déploiement cloud Render
```
