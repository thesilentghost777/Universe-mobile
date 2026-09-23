import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/services/media_service.dart';
import 'ai_store.dart';

/// Assistant UniVerse — feuille de discussion façon ChatGPT.
///
/// Trois éléments demandés dans les notes UI : un fil de discussion, un
/// **historique** de conversations, et des **suggestions** de départ.
///
/// La clé du modèle reste côté serveur : l'app ne parle qu'à `POST /ai/ask`.
class AiChatSheet extends ConsumerStatefulWidget {
  const AiChatSheet({super.key});

  @override
  ConsumerState<AiChatSheet> createState() => _AiChatSheetState();
}

class _AiChatSheetState extends ConsumerState<AiChatSheet> {
  final _saisie = TextEditingController();
  final _defilement = ScrollController();
  bool _historiqueOuvert = false;
  PlatformFile? _pieceJointe;
  Uint8List? _pieceJointeOctets;
  bool _pieceJointeEstImage = true;

  /// Amorces proposées sur un fil vide.
  List<(IconData, String)> _suggestions(BuildContext context) => [
        (Icons.functions_rounded,
            tr(context, 'Explique-moi la dérivée d\'une fonction composée')),
        (Icons.quiz_outlined,
            tr(context, 'Pose-moi 5 questions de révision sur les limites')),
        (Icons.summarize_outlined,
            tr(context, 'Résume ce chapitre en 5 points essentiels')),
        (Icons.edit_note_outlined,
            tr(context, 'Comment structurer ma réponse à une épreuve ?')),
      ];

  @override
  void dispose() {
    _saisie.dispose();
    _defilement.dispose();
    super.dispose();
  }

  Future<void> _choisirPieceJointe() async {
    const media = MediaService();
    final res = await media.choisirImageOuPdf();
    if (res.statut == MediaPickStatut.tropLourd) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(context, 'Fichier trop lourd (8 Mo maximum).')),
        ));
      }
      return;
    }
    if (!res.estValide) return;
    final ext = (res.fichier!.extension ?? '').toLowerCase();
    setState(() {
      _pieceJointe = res.fichier;
      _pieceJointeOctets = res.octets;
      _pieceJointeEstImage =
          ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
    });
  }

  void _retirerPieceJointe() => setState(() {
        _pieceJointe = null;
        _pieceJointeOctets = null;
      });

  Future<void> _envoyer([String? texte]) async {
    final message = (texte ?? _saisie.text).trim();
    final fichier = _pieceJointe;
    final octets = _pieceJointeOctets;
    if (message.isEmpty && fichier == null) return;
    _saisie.clear();
    setState(() {
      _historiqueOuvert = false;
      _pieceJointe = null;
      _pieceJointeOctets = null;
    });
    ref.read(aiChatProvider.notifier).envoyer(
          message,
          pieceJointeNom: fichier?.name,
          pieceJointeBytes: octets,
          pieceJointeEstImage: _pieceJointeEstImage,
        );
    _versLeBas();
  }

  void _versLeBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_defilement.hasClients) return;
      _defilement.animateTo(
        _defilement.position.maxScrollExtent + 160,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final etat = ref.watch(aiChatProvider);
    final clavier = MediaQuery.viewInsetsOf(context).bottom;

    ref.listen(aiChatProvider, (_, __) => _versLeBas());

    // Plein écran (§ retour utilisateur : « on est déjà dans une
    // conversation », pas besoin d'une feuille partielle) — Material
    // fournit le fond, SafeArea protège de l'encoche/barre système.
    return Material(
      color: t.surface,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: clavier),
          child: Column(
          children: [
            _EnTete(
              historiqueOuvert: _historiqueOuvert,
              onHistorique: () =>
                  setState(() => _historiqueOuvert = !_historiqueOuvert),
              onNouvelle: () {
                ref.read(aiChatProvider.notifier).nouvelleConversation();
                setState(() => _historiqueOuvert = false);
              },
            ),
            Divider(height: 1, color: t.border),
            Expanded(
              child: _historiqueOuvert
                  ? _Historique(
                      onOuvrir: (id) {
                        ref.read(aiChatProvider.notifier).ouvrir(id);
                        setState(() => _historiqueOuvert = false);
                      },
                    )
                  : etat.messages.isEmpty
                      ? _Accueil(
                          suggestions: _suggestions(context),
                          onChoisir: _envoyer,
                        )
                      : _Fil(
                          controller: _defilement,
                          messages: etat.messages,
                          enCours: etat.envoiEnCours,
                        ),
            ),
            if (!_historiqueOuvert)
              _Saisie(
                controller: _saisie,
                actif: !etat.envoiEnCours,
                onEnvoyer: _envoyer,
                pieceJointe: _pieceJointe,
                pieceJointeOctets: _pieceJointeOctets,
                pieceJointeEstImage: _pieceJointeEstImage,
                onChoisirFichier: _choisirPieceJointe,
                onRetirerFichier: _retirerPieceJointe,
              ),
          ],
          ),
        ),
      ),
    );
  }
}

class _EnTete extends StatelessWidget {
  const _EnTete({
    required this.historiqueOuvert,
    required this.onHistorique,
    required this.onNouvelle,
  });

  final bool historiqueOuvert;
  final VoidCallback onHistorique;
  final VoidCallback onNouvelle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: tr(context, 'Fermer'),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: UniverseColors.brandGradient,
                ),
                child: const Icon(Icons.auto_awesome,
                    size: 17, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  historiqueOuvert ? tr(context, 'Historique') : tr(context, 'Assistant UniVerse'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                onPressed: onHistorique,
                tooltip: historiqueOuvert ? tr(context, 'Retour au fil') : tr(context, 'Historique'),
                icon: Icon(
                  historiqueOuvert
                      ? Icons.close_rounded
                      : Icons.history_rounded,
                ),
              ),
              IconButton(
                onPressed: onNouvelle,
                tooltip: tr(context, 'Nouvelle conversation'),
                icon: const Icon(Icons.add_comment_outlined),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Écran de départ : les suggestions de conversation.
class _Accueil extends StatelessWidget {
  const _Accueil({required this.suggestions, required this.onChoisir});

  final List<(IconData, String)> suggestions;
  final ValueChanged<String> onChoisir;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      children: [
        Center(
          child: Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: UniverseColors.blue.withValues(alpha: 0.14),
            ),
            child: const Icon(Icons.auto_awesome,
                size: 27, color: UniverseColors.blue),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          tr(context, 'Comment puis-je t\'aider ?'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          tr(context, 'Pose une question sur tes cours, tes TD ou tes révisions.'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: t.textMuted),
        ),
        const SizedBox(height: 26),
        for (final (icone, texte) in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => onChoisir(texte),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.border),
                ),
                child: Row(
                  children: [
                    Icon(icone, size: 19, color: t.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(texte,
                          style: const TextStyle(fontSize: 13.5)),
                    ),
                    Icon(Icons.north_east_rounded,
                        size: 15, color: t.textMuted),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Liste des conversations passées.
class _Historique extends ConsumerWidget {
  const _Historique({required this.onOuvrir});

  final ValueChanged<String> onOuvrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final etat = ref.watch(aiChatProvider);

    if (etat.conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            tr(context, 'Aucune conversation enregistrée pour le moment.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textMuted),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: etat.conversations.length,
      itemBuilder: (context, i) {
        final c = etat.conversations[i];
        return Dismissible(
          key: ValueKey(c.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: UniverseColors.danger.withValues(alpha: 0.18),
            child: const Icon(Icons.delete_outline,
                color: UniverseColors.danger),
          ),
          onDismissed: (_) =>
              ref.read(aiChatProvider.notifier).supprimer(c.id),
          child: ListTile(
            leading: Icon(Icons.chat_bubble_outline, color: t.textMuted),
            title: Text(
              c.titre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              '${c.messages.length} '
              '${c.messages.length > 1 ? tr(context, 'messages') : tr(context, 'message')}'
              ' · ${_quand(context, c.majLe)}',
              style: TextStyle(fontSize: 12, color: t.textMuted),
            ),
            selected: c.id == etat.couranteId,
            onTap: () => onOuvrir(c.id),
          ),
        );
      },
    );
  }

  static String _quand(BuildContext context, DateTime d) {
    final ecart = DateTime.now().difference(d);
    if (ecart.inMinutes < 1) return tr(context, 'à l\'instant');
    if (ecart.inMinutes < 60) {
      return '${tr(context, 'il y a')} ${ecart.inMinutes} min';
    }
    if (ecart.inHours < 24) return '${tr(context, 'il y a')} ${ecart.inHours} h';
    if (ecart.inDays < 7) return '${tr(context, 'il y a')} ${ecart.inDays} j';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}';
  }
}

/// Le fil de messages.
class _Fil extends StatelessWidget {
  const _Fil({
    required this.controller,
    required this.messages,
    required this.enCours,
  });

  final ScrollController controller;
  final List<AiMessage> messages;
  final bool enCours;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      itemCount: messages.length + (enCours ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= messages.length) return const _Frappe();
        return _Bulle(message: messages[i]);
      },
    );
  }
}

class _Bulle extends ConsumerWidget {
  const _Bulle({required this.message});

  final AiMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;

    if (message.isError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: UniverseColors.danger.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: UniverseColors.danger.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline,
                  size: 18, color: UniverseColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message.content,
                    style: const TextStyle(fontSize: 13)),
              ),
              TextButton(
                onPressed: () => ref.read(aiChatProvider.notifier).reessayer(),
                child: Text(tr(context, 'Réessayer')),
              ),
            ],
          ),
        ),
      );
    }

    final estUser = message.isUser;
    return Align(
      alignment: estUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: message.content));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr(context, 'Message copié'))),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          decoration: BoxDecoration(
            gradient: estUser ? UniverseColors.brandGradient : null,
            color: estUser ? null : t.surfaceElevated,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(estUser ? 16 : 4),
              bottomRight: Radius.circular(estUser ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.aUnePieceJointe) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: message.pieceJointeEstImage &&
                          message.pieceJointeBytes != null
                      ? Image.memory(
                          message.pieceJointeBytes!,
                          height: 140,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          color: (estUser ? Colors.white : t.surface)
                              .withValues(alpha: 0.14),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                message.pieceJointeEstImage
                                    ? Icons.image_outlined
                                    : Icons.picture_as_pdf_outlined,
                                size: 16,
                                color: estUser ? Colors.white : t.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  message.pieceJointeNom ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: estUser ? Colors.white : t.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                if (message.content.isNotEmpty) const SizedBox(height: 8),
              ],
              if (message.content.isNotEmpty)
                SelectableText(
                  message.content,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.42,
                    color: estUser ? Colors.white : t.textPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trois points animés pendant l'attente de la réponse.
class _Frappe extends StatefulWidget {
  const _Frappe();

  @override
  State<_Frappe> createState() => _FrappeState();
}

class _FrappeState extends State<_Frappe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: t.surfaceElevated,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                // Chaque point pulse avec un léger décalage.
                final phase = (_c.value - i * 0.18) % 1.0;
                final intensite =
                    phase < 0.5 ? (phase * 2) : (2 - phase * 2);
                return Container(
                  width: 7,
                  height: 7,
                  margin: EdgeInsets.only(right: i == 2 ? 0 : 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.textMuted
                        .withValues(alpha: 0.35 + 0.55 * intensite),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _Saisie extends StatelessWidget {
  const _Saisie({
    required this.controller,
    required this.actif,
    required this.onEnvoyer,
    required this.onChoisirFichier,
    required this.onRetirerFichier,
    this.pieceJointe,
    this.pieceJointeOctets,
    this.pieceJointeEstImage = true,
  });

  final TextEditingController controller;
  final bool actif;
  final VoidCallback onEnvoyer;
  final VoidCallback onChoisirFichier;
  final VoidCallback onRetirerFichier;
  final PlatformFile? pieceJointe;
  final Uint8List? pieceJointeOctets;
  final bool pieceJointeEstImage;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pieceJointe != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ApercuPieceJointe(
                  fichier: pieceJointe!,
                  octets: pieceJointeOctets,
                  estImage: pieceJointeEstImage,
                  onRetirer: onRetirerFichier,
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: tr(context, 'Joindre une photo ou un PDF'),
                  onPressed: onChoisirFichier,
                  icon: Icon(Icons.add_circle_outline, color: t.textMuted),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: tr(context, 'Pose ta question…'),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Opacity(
                  opacity: actif ? 1 : 0.45,
                  child: InkWell(
                    onTap: actif ? onEnvoyer : null,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: UniverseColors.brandGradient,
                      ),
                      child: actif
                          ? const Icon(Icons.arrow_upward_rounded,
                              color: Colors.white, size: 21)
                          : const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Aperçu de la pièce jointe choisie, avant envoi — miniature pour une
/// image, icône pour un PDF, bouton de suppression.
class _ApercuPieceJointe extends StatelessWidget {
  const _ApercuPieceJointe({
    required this.fichier,
    required this.octets,
    required this.estImage,
    required this.onRetirer,
  });

  final PlatformFile fichier;
  final Uint8List? octets;
  final bool estImage;
  final VoidCallback onRetirer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: t.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: estImage && octets != null
                ? Image.memory(octets!,
                    width: 40, height: 40, fit: BoxFit.cover)
                : Container(
                    width: 40,
                    height: 40,
                    color: t.surface,
                    alignment: Alignment.center,
                    child: Icon(Icons.picture_as_pdf_outlined,
                        color: t.textMuted, size: 20),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fichier.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: tr(context, 'Retirer'),
            onPressed: onRetirer,
          ),
        ],
      ),
    );
  }
}
