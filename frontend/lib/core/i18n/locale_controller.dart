import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Langue choisie par l'utilisateur — persistée entre deux lancements.
///
/// UniVerse n'utilise pas `flutter_localizations`/ARB : l'app existait déjà
/// en français dans des centaines de widgets avant que le besoin de
/// bilinguisme n'apparaisse, et une migration complète vers `gen-l10n`
/// remplacerait bien plus que ce qui est demandé ici. À la place, [tr]
/// traduit à la volée les textes déjà écrits en français quand la langue
/// choisie est l'anglais, via [traductions]. C'est un filet pragmatique :
/// tout texte non encore couvert par [traductions] reste affiché en
/// français tant qu'il n'a pas été ajouté au dictionnaire.
final localeProvider =
    NotifierProvider<LocaleController, Locale>(LocaleController.new);

class LocaleController extends Notifier<Locale> {
  static const _key = 'universe_langue';

  @override
  Locale build() {
    _restaurer();
    return const Locale('fr');
  }

  Future<void> _restaurer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == 'en') {
        state = const Locale('en');
      }
    } catch (_) {}
  }

  Future<void> definir(Locale locale) async {
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, locale.languageCode);
    } catch (_) {}
  }
}

/// Porte la langue courante à travers l'arbre de widgets — placé une seule
/// fois, au-dessus du contenu routé par GoRouter (voir `main.dart`), pour
/// que [tr] puisse s'enregistrer comme dépendant et se reconstruire tout
/// seul au changement de langue, exactement comme `Theme.of(context)`. Une
/// simple variable globale ne suffirait pas : GoRouter ne reconstruit pas
/// systématiquement chaque page quand un ancêtre lointain se reconstruit.
class LocaleScope extends InheritedWidget {
  const LocaleScope({super.key, required this.estAnglais, required super.child});

  final bool estAnglais;

  static bool of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    return scope?.estAnglais ?? false;
  }

  @override
  bool updateShouldNotify(LocaleScope oldWidget) =>
      estAnglais != oldWidget.estAnglais;
}

/// Traduit [fr] en anglais si l'utilisateur a choisi l'anglais, sinon
/// renvoie [fr] tel quel. Voir [traductions] pour le dictionnaire couvert —
/// un texte absent du dictionnaire reste affiché en français. Enregistre
/// [context] comme dépendant de [LocaleScope] : le widget appelant se
/// reconstruit automatiquement quand la langue change.
String tr(BuildContext context, String fr) =>
    LocaleScope.of(context) ? (traductions[fr] ?? fr) : fr;

/// Dictionnaire français → anglais. Couvre en priorité les écrans les plus
/// vus (connexion/inscription, navigation, paramètres) — à compléter au fil
/// de l'eau pour le reste de l'application.
const Map<String, String> traductions = {
  // ------------------------------------------------------------- Connexion
  'Connexion': 'Log in',
  'Retrouve les épreuves, TD et cours de ta filière. Connecte-toi en 10 secondes.':
      'Find your exams, tutorials and course material. Log in within 10 seconds.',
  'Continuer avec Google': 'Continue with Google',
  'ou': 'or',
  'Téléphone': 'Phone',
  'Email': 'Email',
  'Mot de passe': 'Password',
  'Mot de passe oublié ?': 'Forgot password?',
  'Se connecter': 'Log in',
  'Nouveau sur UniVerse ?': 'New to UniVerse?',
  'Créer un compte': 'Create an account',
  'Créer un compte UniVerse': 'Create a UniVerse account',
  'Choisis comment tu veux t\'inscrire. Le rôle et le reste de ton profil se règlent juste après.':
      'Choose how you want to sign up. Your role and the rest of your profile come right after.',
  'S\'inscrire avec Google': 'Sign up with Google',
  'Continuer': 'Continue',
  'Qui es-tu ?': 'Who are you?',
  'Tes informations': 'Your details',
  'C\'est fait !': 'All done!',
  'Aller à la connexion': 'Go to login',
  'Déjà un compte ?': 'Already have an account?',
  'Coche la case pour accepter la politique de confidentialité avant de continuer.':
      'Tick the box to accept the privacy policy before continuing.',
  'J\'accepte que UniVerse stocke et utilise mes données et mes contenus. ':
      'I agree that UniVerse stores and uses my data and content. ',
  'Lire la politique complète': 'Read the full policy',
  'Le texte complet, en entier — reviens en arrière une fois ta lecture terminée.':
      'The full text, in its entirety — go back once you\'re done reading.',

  // -------------------------------------------------------- Navigation app
  'UniTube': 'UniTube',
  'Université': 'University',
  'Mon espace': 'My space',
  'Accueil': 'Home',
  'Biblio': 'Library',
  'Bibliothèque': 'Library',
  'Messages': 'Messages',
  'Paramètres': 'Settings',
  'Conversations': 'Conversations',
  'Ajouter une université': 'Add a university',
  'Nouveau message': 'New message',
  'Rechercher un nom': 'Search a name',
  'Rechercher un livre': 'Search a book',
  'Rechercher': 'Search',

  // ---------------------------------------------------------- Paramètres
  'Mon compte': 'My account',
  'Identité, scolarité, sécurité, données': 'Identity, studies, security, data',
  'Confidentialité': 'Privacy',
  'Qui peut m\'écrire, visibilité, contacts':
      'Who can message me, visibility, contacts',
  'Notifications': 'Notifications',
  'Alertes et préférences': 'Alerts and preferences',
  'Enseignant — en attente': 'Teacher — pending',
  'Apparence': 'Appearance',
  'Thème et taille du texte': 'Theme and text size',
  'Aide & Support': 'Help & Support',
  'Tutoriel, FAQ, contact': 'Tutorial, FAQ, contact',
  'Identité': 'Identity',
  'Nom et prénom': 'Full name',
  'Identifiant': 'Username',
  'Langue': 'Language',
  'Français': 'French',
  'Anglais': 'English',
  'Scolarité': 'Studies',
  'Changer de niveau': 'Change level',
  'Demander un statut': 'Request a status',
  'Sécurité': 'Security',
  'Changer le mot de passe': 'Change password',
  'Mes données': 'My data',
  'Télécharger mes données': 'Download my data',
  'Supprimer mon compte': 'Delete my account',
  'Politique de confidentialité': 'Privacy policy',
  'Comptes bloqués': 'Blocked accounts',
  'Appareils connectés': 'Connected devices',
  'Activité': 'Activity',
  'Annuler': 'Cancel',
  'Fermer': 'Close',
  'Enregistrer': 'Save',
  'Envoyer': 'Send',
  'Publier': 'Publish',
  'Publier une vidéo': 'Publish a video',
  'Retour': 'Back',

  // ----------------------------------------------------------------- Vidéo
  'Commentaires': 'Comments',
  'Ajouter un commentaire': 'Add a comment',
  'Partager': 'Share',
  'S\'abonner': 'Subscribe',
  'Abonné': 'Subscribed',
};
