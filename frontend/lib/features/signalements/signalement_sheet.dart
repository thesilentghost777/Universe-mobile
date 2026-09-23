import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/role_access.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/widgets/universe_ui.dart';

/// Destinataire d'un signalement de type `personne`.
enum CibleSignalement {
  /// Un problème sur un canal précis — traité par ses modérateurs (MOD-6).
  moderateur('moderateur', 'Modérateur du canal',
      'Un problème sur les ressources ou la discussion de ce canal.'),

  /// Un problème qui dépasse le canal — traité par l'Admin (AU-5).
  adminUniversite('admin_universite', 'Administration de l\'université',
      'Un problème qui ne relève pas d\'un modérateur en particulier.');

  const CibleSignalement(this.cle, this.libelle, this.aide);

  final String cle;
  final String libelle;
  final String aide;
}

/// Signaler une **personne / un problème** (ET-13).
///
/// C'est le seul canal ouvert à un étudiant vers un Modérateur ou un Admin :
/// le cahier des charges interdit explicitement la messagerie directe vers ces
/// rangs (ET-14, DV-03). L'interface ne doit donc jamais proposer « envoyer un
/// message » à leur place.
Future<void> ouvrirSignalementProbleme(
  BuildContext context, {
  String? canalId,
  String? nomCanal,
  String? destinataireId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SignalementSheet(
      titre: tr(context, 'Signaler un problème'),
      canalId: canalId,
      nomCanal: nomCanal,
      destinataireId: destinataireId,
    ),
  );
}

/// Signaler un **contenu** — une vidéo ou un livre jugé problématique.
///
/// Ouvert à tous les rôles, contrairement au signalement de personne.
/// Le masquage reste réservé au Superadmin et à l'Admin de l'université du
/// créateur (AU-9).
Future<void> ouvrirSignalementContenu(
  BuildContext context, {
  required String type,
  required String cibleId,
  required String titreContenu,
  String? destinataireId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SignalementSheet(
      titre: type == 'livre'
          ? tr(context, 'Signaler ce livre')
          : tr(context, 'Signaler cette vidéo'),
      typeContenu: type,
      cibleId: cibleId,
      titreContenu: titreContenu,
      destinataireId: destinataireId,
    ),
  );
}

class _SignalementSheet extends ConsumerStatefulWidget {
  const _SignalementSheet({
    required this.titre,
    this.canalId,
    this.nomCanal,
    this.typeContenu,
    this.cibleId,
    this.titreContenu,
    this.destinataireId,
  });

  final String titre;

  // Variante « personne ».
  final String? canalId;
  final String? nomCanal;

  // Variante « contenu ».
  final String? typeContenu;
  final String? cibleId;
  final String? titreContenu;
  final String? destinataireId;

  bool get estContenu => typeContenu != null;

  @override
  ConsumerState<_SignalementSheet> createState() => _SignalementSheetState();
}

enum _Gravite { faible, moderee, urgente }

class _SignalementSheetState extends ConsumerState<_SignalementSheet> {
  final _sujet = TextEditingController();
  final _description = TextEditingController();
  final _instant = TextEditingController();
  late CibleSignalement _cible;
  String _motif = 'contenu_inapproprie';
  _Gravite _gravite = _Gravite.moderee;
  bool _envoi = false;

  // Motifs riches, propres au signalement d'un contenu (vidéo/livre) — un
  // simple champ libre ne suffisait pas pour un vrai traitement par
  // l'équipe de modération.
  static const _motifsContenu = <String, (IconData, String)>{
    'contenu_inapproprie': (Icons.report_gmailerrorred_outlined, 'Contenu inapproprié'),
    'violence': (Icons.warning_amber_rounded, 'Violence ou contenu choquant'),
    'desinformation': (Icons.fact_check_outlined, 'Désinformation ou erreur pédagogique'),
    'harcelement': (Icons.shield_outlined, 'Harcèlement ou discours haineux'),
    'droit_auteur': (Icons.copyright_outlined, 'Atteinte aux droits d\'auteur'),
    'hors_sujet': (Icons.filter_alt_off_outlined, 'Hors sujet ou mal classé'),
    'spam': (Icons.block_flipped, 'Spam ou publicité'),
    'autre': (Icons.more_horiz_rounded, 'Autre'),
  };

  @override
  void initState() {
    super.initState();
    // Sans canal d'origine, seule l'administration peut être destinataire.
    _cible = widget.canalId == null
        ? CibleSignalement.adminUniversite
        : CibleSignalement.moderateur;
  }

  @override
  void dispose() {
    _sujet.dispose();
    _description.dispose();
    _instant.dispose();
    super.dispose();
  }

  bool get _valide =>
      _description.text.trim().length >= 10 &&
      (widget.estContenu || _sujet.text.trim().isNotEmpty);

  Future<void> _envoyer() async {
    setState(() => _envoi = true);
    final api = ref.read(apiClientProvider);

    try {
      if (widget.estContenu) {
        final user = ref.read(authNotifierProvider).user;
        final destId = widget.destinataireId ?? user?.id ?? '';
        await api.post('/signalements/contenu', data: {
          'destinataireId': destId,
          'cible': widget.typeContenu == 'livre' ? 'livre' : 'video',
          if (widget.typeContenu != 'livre' && widget.cibleId != null)
            'videoId': widget.cibleId,
          if (widget.typeContenu == 'livre' && widget.cibleId != null)
            'livreId': widget.cibleId,
          'motif': _motif,
          'gravite': _gravite.name,
          if (_instant.text.trim().isNotEmpty) 'instant': _instant.text.trim(),
          'sujet': widget.titreContenu ??
              _motifsContenu[_motif]?.$2 ??
              'Signalement contenu',
          'description': _description.text.trim(),
        });
      } else {
        final user = ref.read(authNotifierProvider).user;
        final destId = widget.destinataireId ?? user?.id ?? '';
        await api.post('/signalements/personne', data: {
          'destinataireId': destId,
          if (widget.canalId != null && _cible == CibleSignalement.moderateur)
            'canalId': widget.canalId,
          'sujet': _sujet.text.trim(),
          'description': _description.text.trim(),
        });
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(context, 'Signalement envoyé. Tu seras informé de son traitement.'),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _envoi = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, 'Envoi impossible. Réessaie dans un instant.')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final acces = RoleAccess.depuis(ref.watch(authNotifierProvider).user);
    final clavier = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: clavier),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.titre,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.estContenu
                      ? tr(context,
                          'Ton signalement est transmis aux responsables '
                          'habilités à retirer ce contenu.')
                      : tr(context,
                          'Un signalement est un envoi unique, sans échange de '
                          'messages. Tu suivras son avancement dans tes '
                          'notifications.'),
                  style: TextStyle(fontSize: 13, color: t.textMuted),
                ),
                const SizedBox(height: 20),

                if (widget.estContenu) ...[
                  _Cartouche(
                    icone: widget.typeContenu == 'livre'
                        ? Icons.menu_book_outlined
                        : Icons.play_circle_outline,
                    texte: widget.titreContenu ?? '',
                  ),
                  const SizedBox(height: 18),
                  _Label(tr(context, 'Motif')),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio:
                        (2.6 / MediaQuery.textScalerOf(context).scale(1))
                            .clamp(1.15, 2.6),
                    children: [
                      for (final e in _motifsContenu.entries)
                        _MotifTuile(
                          icone: e.value.$1,
                          libelle: tr(context, e.value.$2),
                          selectionne: _motif == e.key,
                          onTap: () => setState(() => _motif = e.key),
                        ),
                    ],
                  ),
                  if (widget.typeContenu != 'livre') ...[
                    const SizedBox(height: 16),
                    _Label(tr(context, 'Instant précis (optionnel)')),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _instant,
                      decoration: InputDecoration(
                        hintText: tr(context, 'Ex. 2:35 — au moment où ça se produit'),
                        prefixIcon: const Icon(Icons.schedule_outlined, size: 20),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _Label(tr(context, 'Gravité')),
                  const SizedBox(height: 8),
                  UniverseSegmentedRow(
                    labels: [
                      tr(context, 'Faible'),
                      tr(context, 'Modérée'),
                      tr(context, 'Urgente'),
                    ],
                    selectedIndex: switch (_gravite) {
                      _Gravite.faible => 0,
                      _Gravite.moderee => 1,
                      _Gravite.urgente => 2,
                    },
                    onSelect: (i) => setState(() {
                      _gravite = switch (i) {
                        0 => _Gravite.faible,
                        1 => _Gravite.moderee,
                        _ => _Gravite.urgente,
                      };
                    }),
                  ),
                  if (_gravite == _Gravite.urgente) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: UniverseColors.danger.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: UniverseColors.danger.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.priority_high_rounded,
                              color: UniverseColors.danger, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tr(context,
                                  'Marqué urgent : ce signalement remonte en '
                                  'priorité à l\'équipe de modération.'),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: t.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  _Label(tr(context, 'À qui l\'adresser')),
                  const SizedBox(height: 8),
                  for (final c in CibleSignalement.values)
                    if (c != CibleSignalement.moderateur ||
                        widget.canalId != null)
                      _OptionCible(
                        cible: c,
                        contexte: c == CibleSignalement.moderateur
                            ? widget.nomCanal
                            : null,
                        selectionne: _cible == c,
                        onTap: () => setState(() => _cible = c),
                      ),
                  const SizedBox(height: 18),
                  _Label(tr(context, 'Sujet')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _sujet,
                    maxLength: 80,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: tr(context, 'En quelques mots'),
                      counterText: '',
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                _Label(tr(context, 'Description')),
                const SizedBox(height: 8),
                TextField(
                  controller: _description,
                  maxLines: 5,
                  maxLength: 800,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: tr(context,
                        'Décris le problème le plus précisément '
                        'possible : ce que tu as vu, où, et quand.'),
                  ),
                ),

                // Rappel de la règle pour ceux à qui la messagerie est fermée.
                if (!widget.estContenu &&
                    acces.peutSignalerA(Rang.moderateur)) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 15, color: t.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr(context,
                              'Les modérateurs et l\'administration ne reçoivent '
                              'pas de messages directs : ce formulaire est la '
                              'seule façon de les joindre.'),
                          style: TextStyle(fontSize: 12, color: t.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: (_valide && !_envoi) ? _envoyer : null,
                  child: _envoi
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(tr(context, 'Envoyer le signalement')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionCible extends StatelessWidget {
  const _OptionCible({
    required this.cible,
    required this.selectionne,
    required this.onTap,
    this.contexte,
  });

  final CibleSignalement cible;
  final bool selectionne;
  final VoidCallback onTap;
  final String? contexte;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selectionne
                ? UniverseColors.blue.withValues(alpha: 0.10)
                : t.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selectionne ? UniverseColors.blue : t.border,
              width: selectionne ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selectionne
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 19,
                color: selectionne ? UniverseColors.blue : t.textMuted,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contexte == null
                          ? tr(context, cible.libelle)
                          : '${tr(context, cible.libelle)} · $contexte',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr(context, cible.aide),
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MotifTuile extends StatelessWidget {
  const _MotifTuile({
    required this.icone,
    required this.libelle,
    required this.selectionne,
    required this.onTap,
  });

  final IconData icone;
  final String libelle;
  final bool selectionne;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selectionne
              ? UniverseColors.blue.withValues(alpha: 0.10)
              : t.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectionne ? UniverseColors.blue : t.border,
            width: selectionne ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icone,
                size: 17, color: selectionne ? UniverseColors.blue : t.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                libelle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: selectionne ? UniverseColors.blue : t.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cartouche extends StatelessWidget {
  const _Cartouche({required this.icone, required this.texte});

  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: t.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Icon(icone, size: 19, color: t.textMuted),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              texte,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Text(
      texte.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: context.tokens.textMuted,
      ),
    );
  }
}
