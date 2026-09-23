import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/config.dart';
import '../../core/i18n/locale_controller.dart';

/// Les trois pages de contenu de la section Aide.
enum SectionAide {
  faq('FAQ UniVerse'),
  fonctionnalites('Fonctionnalités'),
  confidentialite('Politique de confidentialité');

  const SectionAide(this.titre);

  final String titre;
}

/// Page d'aide — contenu statique, consultable hors connexion.
///
/// Volontairement sans appel réseau : c'est souvent ici qu'un utilisateur
/// arrive quand quelque chose ne marche pas, y compris sa connexion.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key, required this.section});

  final SectionAide section;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, section.titre))),
      body: switch (section) {
        SectionAide.faq => const _Faq(),
        SectionAide.fonctionnalites => const _Fonctionnalites(),
        SectionAide.confidentialite => const _Confidentialite(),
      },
    );
  }
}

// ------------------------------------------------------------------- FAQ

class _Faq extends StatelessWidget {
  const _Faq();

  static List<(String, String)> _questions(BuildContext context) => [
        (
          tr(context, 'Pourquoi je ne peux pas écrire dans un canal ?'),
          tr(context,
              'Les canaux sont réservés aux modérateurs : c\'est ce qui garde les '
              'épreuves et les corrigés lisibles au lieu de les noyer sous les '
              'messages. Tu peux en revanche répondre librement sous chaque '
              'ressource, dans son fil de discussion.'),
        ),
        (
          tr(context, 'Comment contacter un modérateur ou l\'administration ?'),
          tr(context,
              'Par le bouton drapeau, en haut d\'un canal. Les modérateurs et '
              'l\'administration ne reçoivent pas de messages directs : le '
              'signalement est la seule façon de les joindre, et il est suivi '
              'jusqu\'à sa résolution.'),
        ),
        (
          tr(context, 'J\'ai écrit à un enseignant et je ne peux plus répondre.'),
          tr(context,
              'Un enseignant dispose de 24 heures pour répondre. Passé ce délai, le '
              'fil se ferme pour éviter les sollicitations excessives. Il se '
              'rouvre dès qu\'il répond une première fois — ce n\'est jamais un '
              'blocage définitif.'),
        ),
        (
          tr(context, 'Comment publier mes propres vidéos ?'),
          tr(context,
              'Paramètres puis « Demander un statut ». Choisis Formateur si tu es '
              'étudiant, Enseignant si tu es professeur ou chargé de cours. Un '
              'administrateur examine ta demande et tu es notifié de la décision.'),
        ),
        (
          tr(context, 'Puis-je voir le contenu d\'une autre université ?'),
          tr(context,
              'Oui, en lecture. Tout espace universitaire actif est consultable, '
              'ainsi que l\'espace TDS. Utilise le bouton + de la barre de gauche '
              'pour épingler les universités qui t\'intéressent.'),
        ),
        (
          tr(context, 'J\'ai changé de filière ou de niveau, que faire ?'),
          tr(context,
              'Paramètres puis « Changer de niveau ». Ton fil vidéo et tes canaux se '
              'réorientent immédiatement.'),
        ),
        (
          tr(context, 'L\'application est lente ou ne charge pas.'),
          tr(context,
              'Vérifie ta connexion. UniVerse charge les listes par pages pour '
              'limiter la consommation de données ; sur un réseau lent, laisse '
              'quelques secondes au chargement avant de rafraîchir.'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          tr(context, 'Les questions qui reviennent le plus souvent.'),
          style: TextStyle(fontSize: 13, color: t.textMuted),
        ),
        const SizedBox(height: 16),
        for (final (question, reponse) in _questions(context))
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(
                  question,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      reponse,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: t.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------- Fonctionnalités

class _Fonctionnalites extends StatelessWidget {
  const _Fonctionnalites();

  static List<(IconData, String, String)> _blocs(BuildContext context) => [
        (
          Icons.account_tree_outlined,
          tr(context, 'Espaces universitaires'),
          tr(context,
              'Chaque université a son espace, organisé comme elle : faculté, '
              'filière, niveau, matière, canal. Les épreuves, corrigés et supports '
              'sont rangés là où on les cherche.'),
        ),
        (
          Icons.play_circle_outline,
          'UniTube',
          tr(context,
              'Un fil de vidéos de cours orienté par ton niveau, puis par les '
              'créateurs que tu suis. Recherche par matière, niveau, université '
              'ou mot-clé.'),
        ),
        (
          Icons.menu_book_outlined,
          tr(context, 'Bibliothèque'),
          tr(context,
              'Des livres numériques partagés entre toutes les universités '
              'partenaires, consultables par tous.'),
        ),
        (
          Icons.forum_outlined,
          tr(context, 'Discussions'),
          tr(context,
              'Sous chaque ressource, un fil où poser une question précise et '
              'répondre à un message en particulier.'),
        ),
        (
          Icons.auto_awesome,
          tr(context, 'Assistant'),
          tr(context,
              'Un assistant disponible partout dans l\'application pour t\'aider sur '
              'tes cours, tes TD et tes révisions.'),
        ),
        (
          Icons.groups_outlined,
          tr(context, 'Groupes TDS'),
          tr(context,
              'Des espaces d\'accompagnement animés par des tuteurs indépendants, '
              'en complément des cours de ton université.'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        for (final (icone, titre, texte) in _blocs(context))
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: UniverseColors.blue.withValues(alpha: 0.14),
                  ),
                  child: Icon(icone, size: 20, color: UniverseColors.blue),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        texte,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: t.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------- Confidentialité

class _Confidentialite extends StatelessWidget {
  const _Confidentialite();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: const [PolitiqueConfidentialiteContenu()],
    );
  }
}

/// Contenu complet de la politique de confidentialité — extrait dans un
/// widget partagé pour être rejoué tel quel à l'écran d'aide **et** à
/// l'étape « J'accepte » de l'inscription (§2.2 bis).
class PolitiqueConfidentialiteContenu extends StatelessWidget {
  const PolitiqueConfidentialiteContenu({super.key, this.sombre = false});

  /// `true` quand affiché sur fond sombre (feuille d'inscription) plutôt que
  /// sur le fond clair/sombre normal des paramètres.
  final bool sombre;

  static List<(String, String)> _sections(BuildContext context) => [
        (
          tr(context, '1. Ce que ce document couvre'),
          tr(context,
              'En créant un compte UniVerse, tu acceptes la collecte, le stockage, '
              'le traitement et l\'exploitation de tes données personnelles et de '
              'tout contenu que tu publies, dans les conditions décrites ici. Ce '
              'texte s\'applique à tous les rôles — étudiant, tuteur, formateur '
              'TDS, enseignant, modérateur — sans exception, et à toutes les '
              'universités partenaires de la plateforme.'),
        ),
        (
          tr(context, '2. Les données que nous collectons'),
          tr(context,
              'Ton identité complète (nom, prénom, date de naissance, sexe), ton '
              'adresse e-mail et/ou ton numéro de téléphone, ton mot de passe '
              '(sous forme chiffrée), ta photo de profil et, selon ton rôle, ta '
              'pièce d\'identité, ton logo de formation ou ton dossier '
              'd\'accréditation. Ton établissement, ta filière et ton niveau '
              'd\'étude. L\'intégralité des messages que tu envoies ou reçois, '
              'les vidéos, documents, commentaires et signalements que tu '
              'publies. Les métadonnées techniques de ton activité : appareils '
              'utilisés, adresses IP, horodatages de connexion, pages '
              'consultées, durée de visionnage, interactions avec le contenu '
              '(likes, recherches, favoris). Nous conservons également '
              'l\'historique de tes échanges avec l\'assistant intégré à '
              'l\'application.'),
        ),
        (
          tr(context, '3. Stockage intégral'),
          tr(context,
              'Toutes ces données sont stockées, sans exception ni durée limitée '
              'par défaut, sur les serveurs d\'UniVerse et de ses prestataires '
              'techniques. Une information que tu modifies ou supprimes de ton '
              'côté peut rester conservée dans nos systèmes à des fins '
              'd\'archivage, de sécurité, de preuve ou de fonctionnement du '
              'service — la suppression visible dans l\'application n\'efface '
              'pas nécessairement la donnée sous-jacente.'),
        ),
        (
          tr(context, '4. Nos droits sur tes données et tes contenus'),
          tr(context,
              'En publiant un contenu sur UniVerse (vidéo, document, message, '
              'commentaire, photo, bannière), tu accordes à UniVerse un droit '
              'plein, entier, gratuit et permanent de l\'héberger, le '
              'reproduire, l\'afficher, le distribuer, l\'analyser et l\'adapter, '
              'sur la plateforme comme dans tout support de communication ou '
              'd\'analyse interne à UniVerse et à ses universités partenaires. '
              'Nous nous réservons le droit d\'exploiter l\'ensemble des données '
              'collectées — y compris à des fins statistiques, pédagogiques, '
              'de modération, d\'amélioration du service ou de recherche interne '
              '— sans que cela nécessite une autorisation supplémentaire de ta '
              'part au-delà de ton inscription.'),
        ),
        (
          tr(context, '5. Pourquoi nous collectons tout ceci'),
          tr(context,
              'Faire fonctionner l\'application (connexion, fil de contenu adapté à '
              'ton niveau, messagerie, notifications). Assurer la sécurité du '
              'service et prévenir la fraude, l\'usurpation d\'identité et les '
              'abus. Permettre la modération des contenus et le traitement des '
              'signalements. Produire des statistiques d\'usage pour les '
              'universités partenaires et pour les créateurs de contenu. Faire '
              'évoluer l\'application à partir de l\'usage réel qui en est fait.'),
        ),
        (
          tr(context, '6. Partage avec les universités partenaires'),
          tr(context,
              'Les administrations des universités partenaires ont accès, pour ce '
              'qui concerne leurs propres étudiants et personnels, à l\'identité '
              'des comptes, à leur statut, à leur activité de publication et aux '
              'signalements les concernant. Ce partage est nécessaire à la '
              'gestion pédagogique et disciplinaire de chaque établissement.'),
        ),
        (
          tr(context, '7. Ce que nous ne faisons pas — pour l\'instant'),
          tr(context,
              'À ce stade, UniVerse ne vend pas tes données à des annonceurs tiers '
              'et n\'affiche pas de publicité ciblée. Cet engagement n\'est pas '
              'contractuel et peut évoluer avec une future version de ce '
              'document ; nous t\'invitons à le consulter régulièrement.'),
        ),
        (
          tr(context, '8. Conservation et suppression de compte'),
          tr(context,
              'Une ressource ou un message supprimé est archivé plutôt qu\'effacé, '
              'pour préserver la cohérence des discussions et permettre une '
              'modération a posteriori. Le contenu d\'un compte suspendu, '
              'révoqué ou supprimé reste visible et attribué à son auteur '
              'lorsque cela sert la cohérence du fil de discussion ou de '
              'publication dans lequel il s\'insère. La suppression d\'un compte '
              'n\'entraîne pas automatiquement la suppression des données '
              'associées dans nos systèmes internes.'),
        ),
        (
          tr(context, '9. Sécurité'),
          tr(context,
              'Nous mettons en œuvre des mesures techniques raisonnables pour '
              'protéger tes données (chiffrement des mots de passe, connexions '
              'sécurisées). Aucun système n\'étant infaillible, tu restes '
              'responsable de la confidentialité de ton mot de passe et des '
              'appareils sur lesquels tu restes connecté.'),
        ),
        (
          tr(context, '10. Mineurs'),
          tr(context,
              'L\'inscription est ouverte à partir de 10 ans dans le cadre d\'un '
              'établissement partenaire. Pour un compte mineur, l\'établissement '
              'rattaché est considéré comme responsable du suivi de l\'usage qui '
              'en est fait au sens de ce document.'),
        ),
        (
          tr(context, '11. Tes droits'),
          tr(context,
              'Tu peux consulter et corriger les informations de ton profil depuis '
              'l\'application. Une demande de suppression ou de rectification '
              'plus large peut être adressée à l\'administration de ton '
              'université ; son traitement reste soumis aux limites de '
              'conservation décrites à la section 8.'),
        ),
        (
          tr(context, '12. Évolution de cette politique'),
          tr(context,
              'Ce document peut être modifié à tout moment. La poursuite de '
              'l\'utilisation d\'UniVerse après une mise à jour vaut acceptation '
              'de la nouvelle version. Les changements substantiels seront '
              'signalés dans l\'application.'),
        ),
        (
          tr(context, '13. Contact'),
          tr(context,
              'Pour toute question relative à cette politique, écris à '
              'l\'administration de ton université depuis l\'application, ou '
              'consulte la FAQ de la section Aide.'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final couleurTitre = sombre ? Colors.white : null;
    final couleurTexte =
        sombre ? Colors.white.withValues(alpha: 0.72) : null;
    final t = sombre ? null : context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: UniverseColors.blue.withValues(alpha: sombre ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined,
                  size: 18, color: UniverseColors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr(context,
                      'En utilisant UniVerse, tu acceptes que l\'intégralité de '
                      'tes données et de tes contenus soit stockée et exploitée '
                      'comme décrit ci-dessous.'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: couleurTexte ?? t?.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        for (final (titre, texte) in _sections(context)) ...[
          Text(
            titre,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: couleurTitre,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            texte,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: couleurTexte ?? t?.textMuted,
            ),
          ),
          const SizedBox(height: 20),
        ],
        Center(
          child: Text(
            '${AppConfig.appName} — ${AppConfig.tagline}',
            style: TextStyle(fontSize: 12, color: couleurTexte ?? t?.textMuted),
          ),
        ),
      ],
    );
  }
}
