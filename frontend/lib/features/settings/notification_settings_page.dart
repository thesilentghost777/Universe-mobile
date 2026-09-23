import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/notifications/notifications_store.dart';
import 'settings_widgets.dart';

/// Les 5 types du cahier des charges (NOTIF-2), dans l'ordre affiché.
const _typesNotifTous = [
  TypesNotification.nouveauMessageDirect,
  TypesNotification.reponseRecue,
  TypesNotification.nouvelleRessource,
  TypesNotification.nouvelleVideoSuivie,
  TypesNotification.statutDemande,
];

/// Catégorie lisible. `null` si le type n'est pas connu : on n'affiche
/// jamais la clé technique (`nouveau_message_direct`, etc.).
String? _categorieNotif(BuildContext context, String type) {
  final libelle = _libelleNotif(context, type);
  return libelle == type ? null : libelle;
}

String _libelleNotif(BuildContext context, String type) => switch (type) {
      TypesNotification.nouveauMessageDirect => tr(context, 'Nouveaux messages'),
      TypesNotification.reponseRecue => tr(context, 'Réponses dans un canal'),
      TypesNotification.nouvelleRessource =>
        tr(context, 'Nouvelles ressources publiées'),
      TypesNotification.nouvelleVideoSuivie =>
        tr(context, 'Vidéos des comptes suivis'),
      TypesNotification.statutDemande =>
        tr(context, 'Suivi de mes demandes de statut'),
      _ => type,
    };

IconData _iconeNotif(String type) => switch (type) {
      TypesNotification.nouveauMessageDirect => Icons.forum_outlined,
      TypesNotification.reponseRecue => Icons.reply_outlined,
      TypesNotification.nouvelleRessource => Icons.description_outlined,
      TypesNotification.nouvelleVideoSuivie => Icons.play_circle_outline,
      TypesNotification.statutDemande => Icons.workspace_premium_outlined,
      _ => Icons.notifications_outlined,
    };

/// Notifications — alertes navigateur, préférences par type d'évènement,
/// et les notifications déjà reçues.
class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  bool _loading = true;
  Map<String, bool> _prefsNotif = {for (final t in _typesNotifTous) t: true};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await ref.read(notificationsProvider.notifier).charger();
    final prefs = await SharedPreferences.getInstance();
    final chargees = {
      for (final t in _typesNotifTous) t: prefs.getBool('notif_pref_$t') ?? true,
    };
    if (mounted) {
      setState(() {
        _prefsNotif = chargees;
        _loading = false;
      });
    }
  }

  Future<void> _basculerPrefNotif(String type, bool valeur) async {
    setState(() => _prefsNotif = {..._prefsNotif, type: valeur});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_pref_$type', valeur);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final notifs = ref.watch(notificationsProvider).items;
    final nonLues = ref.watch(notificationsProvider).total;

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Notifications'))),
      body: _loading
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                SettingsSection(
                  titre: tr(context, 'Préférences'),
                  enfants: [
                    for (final type in _typesNotifTous)
                      SettingsLigne(
                        icon: _iconeNotif(type),
                        titre: _libelleNotif(context, type),
                        trailing: Switch(
                          value: _prefsNotif[type] ?? true,
                          onChanged: (v) => _basculerPrefNotif(type, v),
                        ),
                      ),
                  ],
                ),
                if (notifs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SettingsSection(
                    titre: '${tr(context, 'Reçues')} · $nonLues '
                        '${nonLues > 1 ? tr(context, 'non lues') : tr(context, 'non lue')}',
                    enfants: [
                      ...notifs.take(20).map(
                            (n) => SettingsLigne(
                              icon: n.lu ? Icons.circle_outlined : Icons.circle,
                              iconColor: n.lu ? t.textMuted : UniverseColors.blue,
                              iconSize: n.lu ? 18 : 10,
                              titre: n.titre,
                              sousTitre: _categorieNotif(context, n.type),
                              onTap: () => ref
                                  .read(notificationsProvider.notifier)
                                  .marquerLue(n.id),
                            ),
                          ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}
