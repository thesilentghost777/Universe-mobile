import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/role_access.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/widgets/universe_ui.dart';
import '../messaging/contacts_store.dart';
import 'settings_widgets.dart';

enum _Visibilite { tous, universite }

/// Confidentialité — qui peut me contacter, visibilité du profil, contacts
/// bloqués. Une catégorie à part entière (§ retour utilisateur : « le plus
/// détaillé possible »), au lieu d'un simple lien noyé dans l'Aide.
class PrivacySettingsPage extends ConsumerStatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  ConsumerState<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends ConsumerState<PrivacySettingsPage> {
  static const _cleVisibilite = 'profil_visibilite';
  static const _cleStatutEnLigne = 'confidentialite_statut_en_ligne';
  static const _cleAccusesLecture = 'confidentialite_accuses_lecture';
  static const _cleActiviteRecente = 'confidentialite_activite_recente';

  _Visibilite _visibilite = _Visibilite.tous;
  bool _statutEnLigne = true;
  bool _accusesLecture = true;
  bool _activiteRecente = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_cleVisibilite);
    if (mounted) {
      setState(() {
        _visibilite = v == 'universite' ? _Visibilite.universite : _Visibilite.tous;
        _statutEnLigne = prefs.getBool(_cleStatutEnLigne) ?? true;
        _accusesLecture = prefs.getBool(_cleAccusesLecture) ?? true;
        _activiteRecente = prefs.getBool(_cleActiviteRecente) ?? true;
        _loading = false;
      });
    }
  }

  Future<void> _definirVisibilite(_Visibilite v) async {
    setState(() => _visibilite = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleVisibilite, v.name);
  }

  Future<void> _basculerBool(String cle, bool valeur, void Function(bool) appliquer) async {
    setState(() => appliquer(valeur));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(cle, valeur);
  }

  Future<void> _debloquer(BuildContext context, WidgetRef ref, Contact c) async {
    await ref.read(contactsProvider.notifier).oublier(c.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final acces = RoleAccess.depuis(ref.watch(authNotifierProvider).user);

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Confidentialité'))),
      body: _loading
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                SettingsSection(
                  titre: tr(context, 'Qui peut m\'écrire'),
                  enfants: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(acces.icone, size: 18, color: acces.couleur),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _expliquerContact(context, acces),
                              style: TextStyle(fontSize: 12.5, height: 1.4, color: t.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsSection(
                  titre: tr(context, 'Visibilité du profil'),
                  enfants: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: UniverseSegmentedRow(
                        labels: [
                          tr(context, 'Tout le monde'),
                          tr(context, 'Mon université'),
                        ],
                        icons: const [
                          Icons.public_rounded,
                          Icons.school_outlined,
                        ],
                        selectedIndex:
                            _visibilite == _Visibilite.tous ? 0 : 1,
                        onSelect: (i) => _definirVisibilite(
                          i == 0 ? _Visibilite.tous : _Visibilite.universite,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsSection(
                  titre: tr(context, 'Activité'),
                  enfants: [
                    SettingsLigne(
                      icon: Icons.circle,
                      iconColor: _statutEnLigne
                          ? UniverseColors.success
                          : t.textMuted,
                      iconSize: 11,
                      titre: tr(context, 'Statut en ligne visible'),
                      sousTitre: tr(context, 'Les autres voient quand tu es actif.'),
                      trailing: Switch(
                        value: _statutEnLigne,
                        onChanged: (v) => _basculerBool(
                          _cleStatutEnLigne,
                          v,
                          (x) => _statutEnLigne = x,
                        ),
                      ),
                    ),
                    SettingsLigne(
                      icon: Icons.done_all_rounded,
                      titre: tr(context, 'Accusés de lecture'),
                      sousTitre: tr(context, 'Indique quand tu as lu un message reçu.'),
                      trailing: Switch(
                        value: _accusesLecture,
                        onChanged: (v) => _basculerBool(
                          _cleAccusesLecture,
                          v,
                          (x) => _accusesLecture = x,
                        ),
                      ),
                    ),
                    SettingsLigne(
                      icon: Icons.history_rounded,
                      titre: tr(context, 'Activité récente visible'),
                      sousTitre: tr(context, 'Dernière connexion affichée sur ton profil.'),
                      trailing: Switch(
                        value: _activiteRecente,
                        onChanged: (v) => _basculerBool(
                          _cleActiviteRecente,
                          v,
                          (x) => _activiteRecente = x,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsSection(
                  titre: tr(context, 'Appareils connectés'),
                  enfants: [
                    SettingsLigne(
                      icon: Icons.phone_android_rounded,
                      titre: tr(context, 'Cet appareil'),
                      sousTitre: tr(context, 'Session active — connecté maintenant.'),
                    ),
                    SettingsLigne(
                      icon: Icons.logout_rounded,
                      iconColor: UniverseColors.danger,
                      titre: tr(context, 'Se déconnecter de tous les autres appareils'),
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            tr(context, 'Toutes tes autres sessions ont été fermées.'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Builder(builder: (context) {
                  final contacts = ref.watch(contactsProvider);
                  return SettingsSection(
                    titre: '${tr(context, 'Contacts')} (${contacts.length})',
                    enfants: contacts.isEmpty
                        ? [
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text(
                                tr(context, 'Aucun contact retenu pour l\'instant.'),
                                style: TextStyle(fontSize: 12.5, color: t.textMuted),
                              ),
                            ),
                          ]
                        : [
                            for (final c in contacts.take(20))
                              SettingsLigne(
                                icon: Icons.person_outline,
                                titre: c.nom,
                                sousTitre: tr(context, 'Retirer de mes contacts récents'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () => _debloquer(context, ref, c),
                                ),
                              ),
                          ],
                  );
                }),
                const SizedBox(height: 16),
                Builder(builder: (context) {
                  final bloques = ref.watch(blockedContactsProvider);
                  return SettingsSection(
                    titre: '${tr(context, 'Comptes bloqués')} (${bloques.length})',
                    enfants: bloques.isEmpty
                        ? [
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text(
                                tr(context, 'Aucun compte bloqué.'),
                                style: TextStyle(fontSize: 12.5, color: t.textMuted),
                              ),
                            ),
                          ]
                        : [
                            for (final c in bloques)
                              SettingsLigne(
                                icon: Icons.block_rounded,
                                iconColor: UniverseColors.danger,
                                titre: c.nom,
                                sousTitre: tr(context, 'Bloqué — ne peut plus t\'écrire'),
                                trailing: TextButton(
                                  onPressed: () => ref
                                      .read(blockedContactsProvider.notifier)
                                      .debloquer(c.id),
                                  child: Text(tr(context, 'Débloquer')),
                                ),
                              ),
                          ],
                  );
                }),
                const SizedBox(height: 16),
                SettingsSection(
                  titre: tr(context, 'Documents'),
                  enfants: [
                    SettingsLigne(
                      icon: Icons.privacy_tip_outlined,
                      titre: tr(context, 'Politique de confidentialité'),
                      onTap: () => context.push('/app/aide/confidentialite'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  static String _expliquerContact(BuildContext context, RoleAccess acces) =>
      switch (acces.rang) {
        Rang.etudiant => tr(context,
            'Tu peux écrire librement aux étudiants, tuteurs et formateurs. '
            'Un enseignant répond sous 24 h. Les modérateurs ne reçoivent '
            'que des signalements.'),
        Rang.tuteur || Rang.formateur => tr(context,
            'Tu peux écrire librement aux étudiants et aux membres de ton rang. '
            'Les modérateurs ne reçoivent que des signalements.'),
        Rang.enseignant => tr(
            context, 'Tu peux écrire à n\'importe quel compte, sans restriction.'),
        Rang.moderateur => tr(context,
            'Tu ne reçois que des signalements — pas de messagerie directe, '
            'pour rester joignable sans être submergé.'),
      };
}
