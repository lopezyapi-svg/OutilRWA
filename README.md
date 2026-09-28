# Risque Management

Base modulaire d'un outil de calcul et de pilotage des RWA et des risques, avec un backend Python et un frontend Flutter.

## Architecture

- `backend/` expose les APIs metier et les calculs prudentiels.
- `frontend/` contient l'interface Flutter structuree par modules.
- Chaque module suit la meme logique: modeles, services, routes ou ecrans.

## Modules metier

- Dashboard
- Expositions
- Hors Bilan
- CRM
- Referentiels
- Rapports

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

## Arborescence

```text
├── backend/            # API FastAPI, calculs prudentiels, base SQLite
├── frontend/           # Application Flutter (Desktop Windows & Web)
├── docs/               # Documentation technique, réglementaire et manuels
├── deploy/             # Configurations Caddy / reverse proxy
├── scripts/            # Scripts de build d'installeur Windows (.exe) et d'audit
├── modeles_import/     # Modèles et générateurs de matrices d'import Excel
├── Demarrer_OutilRWA.bat # Lanceur rapide pour poste Windows
├── Dockerfile          # Image de production tout-en-un (Web + API)
├── docker-compose.yml  # Déploiement multi-conteneurs avec proxy HTTPS
└── render.yaml         # Blueprint de déploiement cloud Render
```
