import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/role_access.dart';
import '../../core/i18n/locale_controller.dart';
import 'changer_mot_de_passe_sheet.dart';
import 'settings_widgets.dart';

/// Mon compte — identité, sécurité de connexion, statut, et actions liées
/// aux données personnelles.
class AccountSettingsPage extends ConsumerWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final acces = RoleAccess.depuis(user);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Mon compte'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SettingsSection(
            titre: tr(context, 'Identité'),
            enfants: [
              SettingsLigne(
                icon: Icons.badge_outlined,
                titre: tr(context, 'Nom et prénom'),
                sousTitre: user?.displayName,
              ),
              SettingsLigne(
                icon: Icons.alternate_email_rounded,
                titre: tr(context, 'Email'),
                sousTitre: user?.email,
              ),
              SettingsLigne(
                icon: Icons.tag_rounded,
                titre: tr(context, 'Identifiant'),
                sousTitre: (user?.identifiant?.isNotEmpty ?? false)
                    ? '@${user!.identifiant}'
                    : tr(context, 'Non défini'),
                trailing: IconButton(
                  tooltip: tr(context, 'Copier'),
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  onPressed: (user?.identifiant?.isNotEmpty ?? false)
                      ? () {
                          Clipboard.setData(
                            ClipboardData(text: '@${user!.identifiant}'),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(tr(context, 'Identifiant copié.')),
                            ),
                          );
                        }
                      : null,
                ),
              ),
              SettingsLigne(
                icon: Icons.language_rounded,
                titre: tr(context, 'Langue'),
                sousTitre: locale.languageCode == 'en'
                    ? tr(context, 'Anglais')
                    : tr(context, 'Français'),
                onTap: () => ref
                    .read(localeProvider.notifier)
                    .definir(Locale(locale.languageCode == 'en' ? 'fr' : 'en')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSection(
            titre: tr(context, 'Scolarité'),
            enfants: [
              SettingsLigne(
                icon: Icons.school_outlined,
                titre: tr(context, 'Changer de niveau'),
                sousTitre: tr(context, 'Après une réorientation en cours d\'année'),
                onTap: () => context.push('/onboarding'),
              ),
              if (acces.peutDemanderStatut)
                SettingsLigne(
                  icon: Icons.workspace_premium_outlined,
                  titre: tr(context, 'Demander un statut'),
                  sousTitre: tr(context, 'Devenir tuteur, formateur ou modérateur'),
                  onTap: () => context.push('/app/demandes'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSection(
            titre: tr(context, 'Sécurité'),
            enfants: [
              SettingsLigne(
                icon: Icons.lock_outline,
                titre: tr(context, 'Changer le mot de passe'),
                sousTitre: tr(context, 'Déconnecte tous tes autres appareils'),
                onTap: () => ouvrirChangerMotDePasse(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSection(
            titre: tr(context, 'Mes données'),
            enfants: [
              SettingsLigne(
                icon: Icons.download_outlined,
                titre: tr(context, 'Télécharger mes données'),
                sousTitre: tr(context, 'Une copie de ton profil et de ton activité'),
                onTap: () => _bientotDisponible(context),
              ),
              SettingsLigne(
                icon: Icons.delete_outline_rounded,
                titre: tr(context, 'Supprimer mon compte'),
                sousTitre: tr(context, 'Action définitive, après confirmation'),
                iconColor: UniverseColors.danger,
                onTap: () => _confirmerSuppression(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _bientotDisponible(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr(context, 'Bientôt disponible.')),
    ));
  }

  Future<void> _confirmerSuppression(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(ctx, 'Supprimer ton compte ?')),
        content: Text(
          tr(ctx, 'Cette action est définitive : ton profil, tes messages et tes '
              'contenus seront supprimés. Cette fonctionnalité n\'est pas '
              'encore branchée au serveur.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr(ctx, 'Annuler')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: UniverseColors.danger),
            child: Text(tr(ctx, 'Supprimer')),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) _bientotDisponible(context);
  }
}
