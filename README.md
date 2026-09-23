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

# 2. Dépendances + run
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

Les icônes de lancement Android et iOS sont générées à partir de ce fichier.

## Builds de production

La version livrée est définie dans `pubspec.yaml` (`version: 1.0.0+1`). Incrémentez
le numéro de build à chaque envoi sur Google Play ou App Store Connect. L'identifiant
de production est `com.universe.app237` sur Android et iOS ; ne le modifiez pas après
la première publication.

### Android (AAB Google Play)

1. Créez un keystore de publication et placez-le hors du dépôt, par exemple dans
   `android/keystore/universe-release.jks`.
2. Copiez `android/key.properties.example` vers `android/key.properties`, puis
   remplacez les valeurs `CHANGE_ME`. Ce fichier et le keystore sont ignorés par Git.
3. Produisez le bundle avec l'API de production :

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.universe-icorp.com
```

Le fichier à téléverser est `build/app/outputs/bundle/release/app-release.aab`.
Les versions release Android refusent le trafic HTTP ; le HTTP local est conservé
uniquement pour les builds debug.

### iOS (App Store Connect)

Sur macOS avec Xcode, associez le bundle id `com.universe.app237` à l'équipe Apple
Developer et à un profil de distribution dans **Runner > Signing & Capabilities**,
puis archivez :

```bash
flutter build ipa --release --dart-define=API_BASE_URL=https://api.universe-icorp.com
```

L'archive `.ipa` est générée dans `build/ios/ipa/`. La signature iOS dépend du
certificat et du profil Apple de l'organisation ; ils ne sont pas stockés dans le dépôt.

## Docs projet

Voir `universe-backend/CAHIER_PROJET_UNIVERSE.md` (v2) et `CAHIER_DES_CHARGES_COMPLET.md`.
