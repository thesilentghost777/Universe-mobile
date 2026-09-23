import 'package:flutter/material.dart';

import '../../core/i18n/locale_controller.dart';
import '../help/help_page.dart' show PolitiqueConfidentialiteContenu;
import 'widgets/auth_scaffold.dart';

/// Politique de confidentialité complète, consultable pendant l'inscription
/// (§2.2 bis) — ouverte à la demande depuis la case à cocher de l'étape
/// « Tes informations », pas imposée d'entrée comme un mur avant même que
/// la personne ait commencé à s'inscrire.
class PrivacyAcceptScreen extends StatelessWidget {
  const PrivacyAcceptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: tr(context, 'Politique de confidentialité'),
      subtitle: tr(context, 'Le texte complet, en entier — reviens en arrière '
          'une fois ta lecture terminée.'),
      onBack: () => Navigator.of(context).pop(),
      children: const [PolitiqueConfidentialiteContenu(sombre: true)],
    );
  }
}
