# Outil RWA

Base modulaire d'un outil de calcul et de pilotage des RWA, avec un backend Python et un frontend Flutter.

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
python -m uvicorn app.main:app --reload --port 8000
```

Si `python -m venv .venv` echoue sous Windows, verifie que Python est bien installe hors alias `WindowsApps`, puis recree le venv avec l'interprete reel.

## Demarrage frontend

```bash
cd frontend
flutter pub get
flutter run
```

## Arborescence

```text
backend/
  app/
    core/
    dashboard/
    expositions/
    hors_bilan/
    crm/
    referentiels/
    rapports/
    main.py

frontend/
  lib/
    core/
    modules/
    shared/
    main.dart
```
