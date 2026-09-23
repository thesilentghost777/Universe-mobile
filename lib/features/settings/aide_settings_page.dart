import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_state.dart';
import '../../core/i18n/locale_controller.dart';
import '../home/app_shell.dart' show tutorielRelanceProvider;
import '../signalements/signalement_sheet.dart';
import '../tutorial/tutorial_service.dart';
import 'settings_widgets.dart';

/// Aide & Support — tutoriel, contact, documentation.
class AideSettingsPage extends ConsumerWidget {
  const AideSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Aide & Support'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SettingsSection(
            titre: tr(context, 'Découverte'),
            enfants: [
              if (user != null)
                SettingsLigne(
                  icon: Icons.school_rounded,
                  titre: tr(context, 'Relancer le tutoriel'),
                  sousTitre: tr(context, 'Revoir la visite guidée de ton rôle'),
                  onTap: () async {
                    await const TutorialService().reinitialiser(user.id, user.rang);
                    if (!context.mounted) return;
                    // Cet écran est poussé au-dessus d'AppShell : on y
                    // revient d'abord pour que le tutoriel puisse changer
                    // d'onglet en vrai derrière son voile (voir
                    // tutorielRelanceProvider).
                    Navigator.of(context).pop();
                    ref.read(tutorielRelanceProvider.notifier).state = true;
                  },
                ),
              SettingsLigne(
                icon: Icons.auto_awesome_outlined,
                titre: tr(context, 'Fonctionnalités'),
                onTap: () => context.push('/app/aide/fonctionnalites'),
              ),
              SettingsLigne(
                icon: Icons.quiz_outlined,
                titre: tr(context, 'FAQ UniVerse'),
                onTap: () => context.push('/app/aide/faq'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSection(
            titre: tr(context, 'Contact'),
            enfants: [
              SettingsLigne(
                icon: Icons.help_outline,
                titre: tr(context, 'Poser une question'),
                sousTitre: tr(context, 'Écrire à l\'administration de ton université'),
                onTap: () => ouvrirSignalementProbleme(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
