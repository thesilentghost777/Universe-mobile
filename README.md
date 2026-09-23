# UniVerse Frontend (Flutter)

Client mobile Android/iOS pour la plateforme **UniVerse** — L'université en ligne.

## Prérequis

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.22 (Dart ≥ 3.3)
- Backend NestJS démarré (`universe-backend` sur le port 3000)
- Pour l’IA : `GROQ_API_KEY` configurée côté backend

## Configuration

Par défaut, l’API pointe vers l’environnement distant :

```dart
// lib/core/config.dart
defaultValue: 'https://api.universe-icorp.com'
```

Lancer avec une autre base URL :

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

| Environnement | `API_BASE_URL` typique |
| --- | --- |
| Production | `https://api.universe-icorp.com` |
| Android emulator local | `http://10.0.2.2:3000` |
| iOS simulator / desktop local | `http://localhost:3000` |
| Appareil physique local | `http://<IP-LAN-PC>:3000` |

Côté backend (dev mobile), activer le refresh en body :

```env
ALLOW_REFRESH_BODY=true
EXPOSE_EMAIL_VERIFICATION_TOKEN=true
GROQ_API_KEY=gsk_...
```

## Démarrage

```bash
# 1. Installer Flutter SDK si besoin : https://docs.flutter.dev/get-started/install

cd universe-frontend

# 2. Générer les dossiers Android/iOS (une seule fois)
flutter create . --project-name universe_frontend --org cm.universe

# 3. Dépendances + run
flutter pub get
flutter run
```

## Architecture UI

- **Rail gauche** (Telegram) : universités actives
- **Zone centrale** : feed YouTube ou canaux Discord
- **Bottom nav** : Accueil · Bibliothèque · Messages · Paramètres
- **AiFab** : bouton déplaçable → `POST /ai/ask` (Groq Llama 3.3)
- **Skeleton loading** sur tous les écrans de liste
- **Inscription multistep** + onboarding orientation (niveau)

## Phase 2 (créateurs / admin)

Accessible depuis Paramètres selon le rang :

- Espace créateur — upload MinIO → `POST /videos`
- Administration — signalements, stats, création faculté
- Demandes de statut + signalement personne

## Logo

`assets/branding/universe_logo.png`

## Docs projet

Voir `universe-backend/CAHIER_PROJET_UNIVERSE.md` (v2) et `CAHIER_DES_CHARGES_COMPLET.md`.
