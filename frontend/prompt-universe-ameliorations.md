# PROMPT — Refonte et améliorations de l'application « Universe »

> **À remplir avant d'envoyer ce prompt** (remplace les crochets) :
> - Stack front : `[ex. React Native + Expo / Flutter / Next.js]`
> - Gestion d'état / navigation : `[ex. Redux, Zustand, React Navigation, GoRouter]`
> - Structure du projet : `[arborescence ou fichiers clés concernés]`
> - Design system existant : `[Tailwind / NativeWind / Material / aucun]`
> - API disponible : `[URL de la doc, ou « pas encore d'API » si les données doivent être mockées]`

---

## 0. Périmètre : FRONT-END UNIQUEMENT

**Tu ne travailles que sur le front-end.** Tu ne dois ni écrire ni modifier de code serveur, de base de données, de migration ou de règle de sécurité.

Pour tout ce qui dépend du back (envoi d'OTP, authentification Google, upload de CNI et de diplômes, validation du dossier enseignant, feed vidéo, canaux de discussion) :
- construis l'**interface complète** et toutes ses transitions d'états ;
- isole les appels réseau dans une **couche de services dédiée** (un fichier par domaine : `authService`, `userService`, `mediaService`…), afin que le branchement sur la vraie API ne touche pas les écrans ;
- fournis des **mocks réalistes** (données factices + délais simulés) pour que chaque écran soit démontrable sans back ;
- documente en commentaire, pour chaque fonction de service, le **contrat attendu** : méthode, route pressentie, payload envoyé, réponse attendue, codes d'erreur gérés.

À la fin, produis la **liste des endpoints dont le front a besoin** — c'est ce que je transmettrai à l'équipe back.

---

## 1. Contexte

Tu es **développeur front-end senior et designer produit**. Tu travailles sur **Universe**, une application mobile éducative qui réunit plusieurs types d'utilisateurs : **étudiant**, **tuteur**, **formateur TDS**, **enseignant**, **modérateur**.

L'application existe déjà mais souffre de trois problèmes majeurs :
1. un design global jugé peu soigné et peu engageant,
2. un parcours d'authentification incomplet,
3. une architecture de rôles à corriger (renommages, permissions, suppression de rôles à risque).

Ta mission : implémenter les changements ci-dessous **sans casser les fonctionnalités existantes**, en livrant du code propre, commenté et cohérent avec la stack indiquée.

---

## 2. Authentification

### 2.1 Écran de connexion
Trois méthodes doivent coexister sur le même écran :
- **Continuer avec Google** (bouton principal, en haut)
- **Numéro de téléphone + mot de passe**
- **Email + mot de passe**

Prévoir un sélecteur clair (onglets ou toggle « Téléphone / Email »), un lien « Mot de passe oublié », et la gestion des erreurs (identifiants invalides, compte inexistant, compte non vérifié).

### 2.2 Écran d'inscription
Trois méthodes :
- **S'inscrire avec Google**
- **Numéro de téléphone** → envoi d'un **code OTP** → validation
- **Email** → envoi d'un **code OTP** → validation

Après validation de l'OTP, l'utilisateur passe à l'**écran de complétion du profil** (voir §3), puis est **redirigé vers l'écran de connexion** pour se connecter et accéder à l'application.

Exigences UX de l'OTP : champ à cases séparées, collage automatique du code, compte à rebours avant renvoi, message d'erreur explicite si code expiré ou incorrect.

### 2.3 Bouton « Tester un compte »
Un bouton **« Tester un compte »** doit être **visible immédiatement au lancement de l'application**, sur l'écran d'accueil d'authentification, sans navigation supplémentaire. Il donne accès à des comptes de démonstration pour éviter toute friction.

### 2.4 Rôles supprimés
Supprimer complètement les rôles **admin université** et **super admin** (écrans, routes, permissions, entrées de menu, tables/règles associées) — jugés trop risqués.

---

## 3. Champs d'inscription par rôle

| Rôle | Champs demandés |
|---|---|
| **Étudiant** | Nom, prénom, date de naissance, sexe (**Masculin / Féminin** uniquement) |
| **Tuteur** | Idem étudiant **+ CNI recto-verso** (photo ou PDF) |
| **Formateur TDS** | Idem tuteur **+ logo de sa formation + sa photo**. **Email uniquement — pas de numéro de téléphone.** Connexion possible **uniquement par email**. |
| **Enseignant** | Toutes les informations ci-dessus (identité + CNI, etc.) |
| **Modérateur** | **Identiques à l'étudiant** : nom, prénom, date de naissance, sexe. Il s'inscrit exactement comme un étudiant ; seul son rôle et ses permissions diffèrent. |

### Processus de validation « Enseignant »
1. L'enseignant soumet son dossier à l'inscription.
2. Message affiché : réponse sous **2 à 3 jours ouvrables**.
3. L'équipe lui demande ensuite son **diplôme le plus élevé**.
4. **Tant que la validation n'est pas faite, le compte reste un compte étudiant, mais en version limitée** : l'enseignant n'accède qu'à un sous-ensemble des fonctionnalités étudiant, et **le statut de son dossier est affiché en permanence** (bandeau ou carte en haut de l'accueil : « Dossier en cours d'examen », « Diplôme demandé », « Validé »). Les fonctionnalités réservées aux enseignants sont visibles mais verrouillées, avec une explication de ce qui débloque l'accès.
5. Après validation, le compte bascule automatiquement en compte enseignant, avec une notification claire.

⚠️ **Chaque étape doit être expliquée très clairement, en langage simple**, car le public enseignant est plus âgé : textes explicatifs courts, statut du dossier toujours visible, pas de jargon.

---

## 4. Rôles, permissions et renommage

- **Renommage** : « tuteur TDS » devient **« formateur TDS »**. On distingue désormais **formateur TDS** et **tuteur** (deux rôles distincts). Mettre à jour tous les libellés, variables, enums et textes de l'app.
- **Le suivi des étudiants est assuré par le FORMATEUR**, plus par le tuteur. Déplacer les écrans, droits et notifications correspondants.
- **Modérateur** : **ne peut pas publier de contenu**. Il gère uniquement les signalements et problèmes. Masquer toute action de publication dans son interface.

---

## 5. Navigation et UniTube

### 5.1 UniTube en écran d'accueil (tous les rôles)

**Tous les utilisateurs** arrivent sur **UniTube dès l'ouverture de l'application**, comme sur un vrai YouTube. La disposition de cet accueil est la suivante :

- **Zone de droite (principale)** : le **feed de vidéos proposées** — miniatures, titre, chaîne, durée, vues. Défilement vertical, barre de recherche en haut, lecture au tap.
- **Colonne de gauche** : la **liste des canaux** (organisation type Discord, telle que définie précédemment dans le projet) — serveurs/canaux avec icônes rondes, indicateur de messages non lus, accès direct à la discussion au tap.

Les deux zones doivent rester lisibles sur mobile : prévoir une colonne de gauche compacte (bande d'icônes) extensible par tap ou swipe, le feed occupant le reste de la largeur.

### 5.2 Barre de navigation (footer)

- **Tuteur** : **5 onglets**, avec l'icône **UniTube au centre** du footer, mise en avant (bouton central proéminent).
- **Tous les autres rôles** : **4 onglets** au footer, **sans icône UniTube** — puisque UniTube est déjà leur écran d'accueil.

Les interfaces de chaque rôle doivent être **réellement distinctes**, pas un simple masquage d'onglets sur un même écran.

---

## 6. Interfaces dédiées par rôle

- **Enseignant** : interface **totalement séparée** et **la plus simple possible à utiliser** — public plus âgé. Grandes zones tactiles, typographie plus grande, contrastes forts, libellés explicites, peu d'éléments par écran, aucune interaction cachée (pas de swipe caché, pas d'icône sans texte).
- **Formateur TDS**, **tuteur**, **modérateur** : interfaces propres à chaque rôle, cohérentes avec le design system mais adaptées à leurs tâches.

---

## 7. Écrans et composants à corriger

### 7.1 Interface étudiant — bouton « Ajouter une université »
Actuellement placé en bas de l'écran et **quasiment invisible**. Le rendre **immédiatement visible et évident** : bouton d'action principal bien contrasté (FAB proéminent ou bouton plein largeur en haut de la liste), avec icône + libellé.

### 7.2 Onglet « Bibliothèque de livres »
Le fond actuel est **plat, moche et sans intérêt**. Le refaire avec des **formes d'étagères** dans lesquelles les livres sont posés : couvertures alignées sur des rayonnages, ombres portées, effet de profondeur, textures subtiles. L'expérience doit donner la sensation d'une vraie bibliothèque, avec animations douces au défilement et à l'ouverture d'un livre.

### 7.3 Onglet « Paramètres »
Actuellement **fade et sans intérêt**. Le refaire : sections groupées avec en-têtes clairs, icônes cohérentes, en-tête de profil en haut (photo + nom + rôle), interrupteurs animés, séparateurs propres, actions destructrices en rouge, recherche dans les paramètres.

### 7.4 Photo de profil et consultation des profils
- Chaque utilisateur peut **ajouter et modifier sa photo de profil** (appareil photo ou galerie, recadrage, compression).
- La photo de profil apparaît **dans les discussions** et partout où l'utilisateur est cité.
- On peut **consulter le profil d'une personne**, avec **peu d'informations, à la manière de WhatsApp** : grande photo, nom, courte bio/statut, rôle, et c'est tout. Pas de données sensibles exposées.

### 7.5 Module IA
Ajouter un **bouton « + »** dans la zone de saisie permettant de **joindre une photo ou une vidéo** au message envoyé à l'IA. Gérer : sélection galerie / appareil photo, aperçu de la pièce jointe, suppression avant envoi, limite de taille, indicateur de progression d'upload.

---

## 8. Lancement de l'application

- **Supprimer l'animation d'ouverture actuelle.**
- La remplacer par un **splash minimaliste : le logo « Universe » affiché environ 1 seconde**, à la manière de ChatGPT ou Grok, puis transition immédiate.

---

## 9. Tutoriel de première connexion

À la **première connexion**, chaque utilisateur voit un **tutoriel guidé** (coach marks) :
- petites mains / doigts pointant les éléments clés,
- bulles explicatives courtes : « ceci sert à… »,
- progression par étapes avec « Suivant » et « Passer »,
- **tutoriel adapté au rôle** de l'utilisateur,
- possibilité de le relancer depuis les Paramètres.

Le tutoriel destiné aux **enseignants** doit être particulièrement clair, lent et détaillé.

---

## 10. Direction artistique globale

Le design actuel est jugé très insuffisant. Objectif : **le meilleur design possible**, moderne et professionnel.

- **Tout doit être bien visible et bien cadré** : alignements stricts, grille cohérente, marges régulières, hiérarchie visuelle nette.
- **Boutons dynamiques** : états pressé / survol / désactivé / chargement, micro-animations, retour haptique.
- Palette cohérente (couleur primaire + accents), typographie hiérarchisée, coins arrondis homogènes, ombres et élévations cohérentes.
- Transitions d'écran fluides, squelettes de chargement plutôt que spinners nus, états vides illustrés et explicites.
- Accessibilité : contrastes AA minimum, zones tactiles ≥ 44 px, support du texte agrandi.
- Mode sombre si possible.

---

## 11. Contraintes et livrables attendus

1. Ne rien casser des écrans et parcours existants.
2. Centraliser les styles dans un **design system réutilisable** (tokens de couleur, typographie, espacements, composants Button / Input / Card / Modal).
3. Gérer systématiquement les états d'écran : chargement, erreur, vide, succès — y compris quand le back ne répond pas.
4. **Validation côté client** sur tous les formulaires : format email, format téléphone, longueur et expiration de l'OTP, date de naissance plausible, type et poids des fichiers (CNI, diplôme, logo, photo de profil) avant envoi.
5. Ne jamais stocker d'information sensible en clair côté client (token en stockage sécurisé, pas de CNI ni de mot de passe conservés localement). La sécurisation du stockage des fichiers relève du back.
6. Aucune clé secrète ni identifiant d'API en dur dans le code front — passer par des variables d'environnement.
7. Code commenté en français, nommage cohérent, composants découpés et réutilisables.

### Format de réponse souhaité
1. Un **plan d'implémentation** ordonné par priorité, découpé en lots livrables.
2. La **liste des fichiers** à créer ou modifier pour chaque lot.
3. Le **code complet** de chaque fichier concerné (écrans, composants, services mockés).
4. La **liste des endpoints attendus du back** (méthode, route, payload, réponse), à transmettre à l'équipe back.
5. Les **points d'ambiguïté** à me faire confirmer avant de coder.

Commence par le plan et la liste des questions. Ne génère le code qu'après ma validation.
