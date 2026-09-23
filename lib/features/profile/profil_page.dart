import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/role_access.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/widgets/universe_skeleton.dart';
import '../../core/widgets/universe_ui.dart';
import '../messaging/contacts_store.dart';
import '../messaging/nouveau_message_sheet.dart';
import '../roles/role_console_page.dart' show RoleBadge;
import '../signalements/signalement_sheet.dart';

/// Consultation du profil d'une personne (§7.4) — volontairement minimal,
/// façon WhatsApp : grande photo, nom, rôle, et une courte phrase de
/// présentation. Pas de données sensibles (email, statut de dossier…).
/// Soigné d'un bandeau de couleur et d'une action directe (message ou
/// signalement, selon ce que la matrice de contact autorise).
class ProfilPage extends ConsumerStatefulWidget {
  const ProfilPage({
    super.key,
    required this.id,
    required this.nomRepli,
    this.rangRepli,
    this.photoUrlRepli,
  });

  final String id;
  final String nomRepli;
  final String? rangRepli;
  final String? photoUrlRepli;

  @override
  ConsumerState<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends ConsumerState<ProfilPage> {
  bool _loading = true;
  String? _nom;
  String? _rang;
  String? _photoUrl;
  String? _bio;

  @override
  void initState() {
    super.initState();
    _nom = widget.nomRepli;
    _rang = widget.rangRepli;
    _photoUrl = widget.photoUrlRepli;
    _charger();
  }

  Future<void> _charger() async {
    // Mon propre profil : la bio n'existe encore que localement (voir le
    // contrat documenté sur UserProfile.bio) tant que le back ne la
    // renvoie pas sur /utilisateurs/:id.
    final moi = ref.read(authNotifierProvider).user;
    if (moi != null && moi.id == widget.id) {
      _bio = moi.bio;
    }
    try {
      final res =
          await ref.read(apiClientProvider).get('/utilisateurs/${widget.id}');
      final data = res.data as Map<String, dynamic>;
      final nom = '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.trim();
      if (!mounted) return;
      setState(() {
        if (nom.isNotEmpty) _nom = nom;
        _rang = data['rang'] as String? ?? _rang;
        _photoUrl = data['photoUrl'] as String? ?? _photoUrl;
        _bio ??= data['bio'] as String?;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final acces = RoleAccess(Rang.depuis(_rang));
    final nom = _nom?.isNotEmpty == true ? _nom! : tr(context, 'Utilisateur');
    final moi = ref.watch(authNotifierProvider).user;
    final estMoi = moi != null && moi.id == widget.id;
    final moiAcces = RoleAccess.depuis(moi);
    final mode = estMoi ? null : moiAcces.modeContactVers(acces.rang);

    return Scaffold(
      body: _loading
          ? const ListTileSkeleton()
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 150,
                  backgroundColor: t.canvas,
                  iconTheme: const IconThemeData(color: Colors.white),
                  flexibleSpace: FlexibleSpaceBar(
                    background: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            acces.couleur.withValues(alpha: 0.85),
                            UniverseColors.violet.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -46),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: t.canvas,
                              ),
                              child: UniverseAvatar(
                                initiale: nom,
                                photoUrl: _photoUrl,
                                radius: 52,
                                backgroundColor: acces.couleur,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              nom,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 21, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            RoleBadge(acces: acces),
                            const SizedBox(height: 18),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                (_bio?.trim().isNotEmpty ?? false)
                                    ? _bio!.trim()
                                    : acces.resume,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 14, height: 1.4, color: t.textMuted),
                              ),
                            ),
                            const SizedBox(height: 26),
                            if (!estMoi)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: _ActionContact(
                                  mode: mode!,
                                  couleur: acces.couleur,
                                  onEcrire: () => ouvrirConversationAvec(
                                    context,
                                    ref,
                                    Contact(
                                      id: widget.id,
                                      nom: nom,
                                      rang: _rang,
                                      photoUrl: _photoUrl,
                                    ),
                                  ),
                                  onSignaler: () => ouvrirSignalementProbleme(
                                    context,
                                    destinataireId: widget.id,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Bouton d'action principal du profil, adapté à ce que la matrice de
/// contact autorise réellement — jamais un bouton « Envoyer un message »
/// menant à un refus serveur (DV-03).
class _ActionContact extends StatelessWidget {
  const _ActionContact({
    required this.mode,
    required this.couleur,
    required this.onEcrire,
    required this.onSignaler,
  });

  final ModeContact mode;
  final Color couleur;
  final VoidCallback onEcrire;
  final VoidCallback onSignaler;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case ModeContact.conversation:
      case ModeContact.fenetreReponse:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onEcrire,
            style: FilledButton.styleFrom(backgroundColor: couleur),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: Text(
              mode == ModeContact.fenetreReponse
                  ? tr(context, 'Envoyer un message (répond sous 24 h)')
                  : tr(context, 'Envoyer un message'),
            ),
          ),
        );
      case ModeContact.signalement:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onSignaler,
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: Text(tr(context, 'Signaler un problème')),
          ),
        );
      case ModeContact.interdit:
        return const SizedBox.shrink();
    }
  }
}
