import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_erreur.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/role_access.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/services/media_service.dart';
import '../../core/notifications/notifications_store.dart';
import '../../core/socket/socket_service.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/chat_wallpaper.dart';
import '../../core/widgets/date_separator_pill.dart';
import '../../core/widgets/draggable_ai_fab.dart';
import '../../core/widgets/message_input_bar.dart';
import '../../core/widgets/universe_glass.dart';
import '../../core/widgets/universe_skeleton.dart';
import '../../core/widgets/universe_ui.dart';
import '../../shared/models/models.dart';
import 'contacts_store.dart';
import 'nouveau_message_sheet.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key, this.embedded = true});

  /// `true` quand la page est un onglet du shell (pas de flèche retour) ;
  /// `false` quand elle est ouverte en route poussée depuis le rail.
  final bool embedded;

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  List<ConversationItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Ouvrir la liste des messages vaut lecture des notifications de
    // nouveaux messages directs.
    ref
        .read(notificationsProvider.notifier)
        .marquerTypeLu(TypesNotification.nouveauMessageDirect);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get('/conversations');
      final raw = res.data;
      final list = raw is List ? raw : (raw as Map)['items'] as List? ?? [];
      setState(() {
        _items = list
            .map((e) => ConversationItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final acces = RoleAccess.depuis(ref.watch(authNotifierProvider).user);
    return Column(
      children: [
        AppBar(
          title: Text(tr(context, 'Messages')),
          automaticallyImplyLeading: !widget.embedded,
          leading: widget.embedded
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: tr(context, 'Retour'),
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/app'),
                ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Pressable(
                onTap: () => ouvrirNouveauMessage(context),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: UniverseColors.brandGradient,
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
        if (acces.estEnseignantEnAttente) const _BandeauEnseignantEnAttente(),
        Expanded(
          child: _loading
              ? const ListTileSkeleton()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? Center(
                          child: Text(tr(context, 'Aucune conversation'),
                              style:
                                  TextStyle(color: context.tokens.textMuted)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(
                            bottom: DraggableAiFab.degagement,
                          ),
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            indent: 78,
                            color: context.tokens.border,
                          ),
                          itemBuilder: (_, i) {
                            final c = _items[i];
                            final nonLu = c.nonLus > 0;
                            final t = context.tokens;
                            return ListTile(
                              contentPadding: const EdgeInsets.fromLTRB(
                                  16, 8, 16, 8),
                              leading: GestureDetector(
                                onTap: c.destinataireId == null
                                    ? null
                                    : () => context.push(
                                          '/app/profil/${c.destinataireId}',
                                          extra: Contact(
                                            id: c.destinataireId!,
                                            nom: c.destinataireNom ??
                                                tr(context, 'Utilisateur'),
                                            rang: c.destinataireRang,
                                            photoUrl: c.destinatairePhotoUrl,
                                          ),
                                        ),
                                child: UniverseAvatar(
                                  initiale: (c.destinataireNom ?? '?')
                                      .substring(0, 1),
                                  photoUrl: c.destinatairePhotoUrl,
                                  radius: 26,
                                  backgroundColor: t.surfaceElevated,
                                ),
                              ),
                              title: Text(
                                c.destinataireNom ?? tr(context, 'Conversation'),
                                style: TextStyle(
                                  fontWeight:
                                      nonLu ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                c.dernierMessage ?? c.type,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: nonLu ? t.textPrimary : t.textMuted,
                                  fontWeight:
                                      nonLu ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (c.updatedAt != null)
                                    Text(
                                      heureListe(context, c.updatedAt!),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: nonLu
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: nonLu
                                            ? UniverseColors.blue
                                            : t.textMuted,
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  if (nonLu)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      constraints:
                                          const BoxConstraints(minWidth: 20),
                                      decoration: const BoxDecoration(
                                        gradient: UniverseColors.brandGradient,
                                        borderRadius:
                                            BorderRadius.all(Radius.circular(10)),
                                      ),
                                      child: Text(
                                        c.nonLus > 99 ? '99+' : '${c.nonLus}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () => context.push(
                                '/app/conversation/${c.id}',
                                extra: c.destinataireId == null
                                    ? null
                                    : Contact(
                                        id: c.destinataireId!,
                                        nom: c.destinataireNom ?? tr(context, 'Utilisateur'),
                                        rang: c.destinataireRang,
                                        photoUrl: c.destinatairePhotoUrl,
                                      ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({
    super.key,
    required this.conversationId,
    this.contactRepli,
  });

  final String conversationId;

  /// Identité affichée en en-tête (photo + nom) — repli pendant que le
  /// détail de la conversation charge, `null` si on arrive sans contexte
  /// (ex. lien direct).
  final Contact? contactRepli;

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  /// Hauteur de la barre de saisie — le bouton IA flottant ne doit jamais
  /// passer par-dessus (voir [DraggableAiFab.bottomInset]).
  static const double _barreSaisieHauteur = 80;

  final _ctrl = TextEditingController();
  List<MessageItem> _messages = [];
  bool _loading = true;
  String? _erreur;
  bool _contactEcrit = false;
  PlatformFile? _pieceJointe;
  Uint8List? _pieceJointeOctets;
  bool _pieceJointeEstImage = true;
  DateTime? _dernierTypingEmis;
  Timer? _cacherFrappeTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Entrer dans la conversation vaut lecture — la pastille de messages
    // directs ne doit pas rester allumée une fois le fil ouvert.
    ref
        .read(notificationsProvider.notifier)
        .marquerTypeLu(TypesNotification.nouveauMessageDirect);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sock = ref.read(socketServiceProvider);
      sock.connect();
      sock.joinConversation(widget.conversationId);
      sock.onConversationMessage((data) {
        if (!mounted) return;
        try {
          final map = Map<String, dynamic>.from(data as Map);
          if (map['conversationId'] == widget.conversationId ||
              map['conversationId'] == null) {
            setState(() {
              _messages = [..._messages, MessageItem.fromJson(map)];
              _contactEcrit = false;
            });
            _accuserLecture(MessageItem.fromJson(map));
          }
        } catch (_) {}
      });
      sock.onTypingConversation((data) {
        if (!mounted) return;
        try {
          final map = Map<String, dynamic>.from(data as Map);
          if (map['conversationId'] != widget.conversationId) return;
        } catch (_) {}
        setState(() => _contactEcrit = true);
        _cacherFrappeTimer?.cancel();
        _cacherFrappeTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _contactEcrit = false);
        });
      });
      sock.onMessageLu((data) {
        if (!mounted) return;
        try {
          final id = (Map<String, dynamic>.from(data as Map))['messageId'] as String?;
          if (id == null) return;
          setState(() {
            _messages = [
              for (final m in _messages)
                if (m.id == id) m.copyWith(lu: true) else m,
            ];
          });
        } catch (_) {}
      });
    });
  }

  /// Signale à l'interlocuteur qu'on est en train d'écrire — au plus une
  /// fois toutes les deux secondes, pour ne pas saturer le socket à chaque
  /// frappe.
  void _signalerFrappe() {
    final maintenant = DateTime.now();
    if (_dernierTypingEmis != null &&
        maintenant.difference(_dernierTypingEmis!) < const Duration(seconds: 2)) {
      return;
    }
    _dernierTypingEmis = maintenant;
    ref.read(socketServiceProvider).emitTypingConversation(widget.conversationId);
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get(
            '/conversations/${widget.conversationId}/messages',
          );
      final raw = res.data;
      final list = raw is List ? raw : (raw as Map)['items'] as List? ?? [];
      final messages = list
          .map((e) => MessageItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _erreur = null;
        _loading = false;
      });
      for (final m in messages) {
        _accuserLecture(m);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = ApiErreur.depuis(e).message;
        _loading = false;
      });
    }
  }

  void _accuserLecture(MessageItem message) {
    final moiId = ref.read(authNotifierProvider).user?.id;
    if (moiId == null ||
        message.id.isEmpty ||
        message.auteurId.isEmpty ||
        message.auteurId == moiId ||
        message.lu) {
      return;
    }
    ref
        .read(socketServiceProvider)
        .emitMessageLu(widget.conversationId, message.id);
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
      _pieceJointeEstImage = ext != 'pdf';
    });
  }

  void _retirerPieceJointe() => setState(() {
        _pieceJointe = null;
        _pieceJointeOctets = null;
      });

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    final fichier = _pieceJointe;
    if (text.isEmpty && fichier == null) return;
    _ctrl.clear();
    setState(() {
      _pieceJointe = null;
      _pieceJointeOctets = null;
    });
    await ref.read(apiClientProvider).post(
      '/conversations/${widget.conversationId}/messages',
      data: {
        'contenu': text,
        // Pas d'endpoint d'upload de message côté back : transmis à titre
        // indicatif, contrat à confirmer (voir MessageItem.pieceJointeNom).
        if (fichier != null) 'pieceJointeNom': fichier.name,
      },
    );
    await _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _cacherFrappeTimer?.cancel();
    super.dispose();
  }

  /// Identité affichée en en-tête — le repli passé à l'ouverture, ou à
  /// défaut déduite du premier message reçu (lien direct, sans contexte).
  Contact? _contactAffiche(String? moiId) {
    if (widget.contactRepli != null) return widget.contactRepli;
    for (final m in _messages) {
      if (m.auteurId.isNotEmpty && m.auteurId != moiId) {
        return Contact(
          id: m.auteurId,
          nom: m.auteurNom ?? tr(context, 'Utilisateur'),
          rang: m.auteurRang,
          photoUrl: m.auteurPhotoUrl,
        );
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // AiFab is in AppShell Stack — conversation is a pushed route;
    // wrap with Stack + DraggableAiFab so it remains available in DMs.
    final moiId = ref.watch(authNotifierProvider).user?.id;
    final contact = _contactAffiche(moiId);
    final t = context.tokens;
    // Première prise de contact (ex. via identifiant) : le fil est vide et
    // l'expéditeur n'est pas encore dans le carnet — le destinataire choisit
    // d'accepter ou de bloquer avant que la messagerie ne s'ouvre vraiment.
    final estConnu = contact != null &&
        ref.watch(contactsProvider).any((c) => c.id == contact.id);
    final enAttenteDecision =
        !_loading && contact != null && _messages.isEmpty && !estConnu;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: contact == null ? null : 0,
        title: contact == null
            ? Text(tr(context, 'Conversation'))
            : GestureDetector(
                onTap: () => context.push(
                  '/app/profil/${contact.id}',
                  extra: contact,
                ),
                child: Row(
                  children: [
                    UniverseAvatar(
                      initiale: contact.nom,
                      photoUrl: contact.photoUrl,
                      radius: 18,
                      backgroundColor: t.surfaceElevated,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            contact.nom,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          if (contact.rang != null)
                            Text(
                              RoleAccess(Rang.depuis(contact.rang)).libelle,
                              style: TextStyle(fontSize: 11.5, color: t.textMuted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
      body: ChatWallpaper(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _loading
                      ? const ListTileSkeleton(count: 6)
                      : _erreur != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  _erreur!,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            12,
                            12,
                            12,
                            12 + DraggableAiFab.degagement,
                          ),
                          itemCount: _messages.length + (_contactEcrit ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i >= _messages.length) {
                              return const _BulleFrappe();
                            }
                            final m = _messages[i];
                            final estMoi = moiId != null && m.auteurId == moiId;
                            final t = context.tokens;
                            final precedent = i > 0 ? _messages[i - 1] : null;
                            final nouveauJour = m.createdAt != null &&
                                (precedent?.createdAt == null ||
                                    !memeJour(
                                        precedent!.createdAt!, m.createdAt!));

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (nouveauJour)
                                  DateSeparatorPill(date: m.createdAt!),
                                Align(
                                  alignment: estMoi
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (!estMoi && m.auteurId.isNotEmpty) ...[
                                        GestureDetector(
                                          onTap: () => context.push(
                                            '/app/profil/${m.auteurId}',
                                            extra: Contact(
                                              id: m.auteurId,
                                              nom: m.auteurNom ?? tr(context, 'Utilisateur'),
                                              rang: m.auteurRang,
                                              photoUrl: m.auteurPhotoUrl,
                                            ),
                                          ),
                                          child: UniverseAvatar(
                                            initiale: (m.auteurNom ?? '?')
                                                .substring(0, 1),
                                            photoUrl: m.auteurPhotoUrl,
                                            radius: 14,
                                            backgroundColor: t.surfaceElevated,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Flexible(
                                          child: Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.fromLTRB(
                                            14, 10, 10, 8),
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              MediaQuery.sizeOf(context).width *
                                                  0.76,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: estMoi
                                              ? UniverseColors.brandGradient
                                              : null,
                                          color:
                                              estMoi ? null : t.surfaceElevated,
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(16),
                                            topRight: const Radius.circular(16),
                                            bottomLeft:
                                                Radius.circular(estMoi ? 16 : 4),
                                            bottomRight:
                                                Radius.circular(estMoi ? 4 : 16),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: t.shadow,
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (!estMoi && m.auteurNom != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 2),
                                                child: Text(
                                                  m.auteurNom!,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: t.textMuted,
                                                  ),
                                                ),
                                              ),
                                            if (m.aUnePieceJointe) ...[
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: m.pieceJointeEstImage &&
                                                        m.pieceJointeBytes !=
                                                            null
                                                    ? Image.memory(
                                                        m.pieceJointeBytes!,
                                                        height: 150,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Container(
                                                        height: 56,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 10),
                                                        color: (estMoi
                                                                ? Colors.white
                                                                : t.surface)
                                                            .withValues(
                                                                alpha: 0.14),
                                                        alignment:
                                                            Alignment.centerLeft,
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .picture_as_pdf_outlined,
                                                              size: 18,
                                                              color: estMoi
                                                                  ? Colors.white
                                                                  : t.textMuted,
                                                            ),
                                                            const SizedBox(
                                                                width: 8),
                                                            Flexible(
                                                              child: Text(
                                                                m.pieceJointeNom ??
                                                                    '',
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: estMoi
                                                                      ? Colors
                                                                          .white
                                                                      : t.textMuted,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                              ),
                                              if (m.contenu.isNotEmpty)
                                                const SizedBox(height: 6),
                                            ],
                                            if (m.contenu.isNotEmpty)
                                              Text(
                                                m.contenu,
                                                style: TextStyle(
                                                  color: estMoi
                                                      ? Colors.white
                                                      : t.textPrimary,
                                                  height: 1.35,
                                                ),
                                              ),
                                            const SizedBox(height: 3),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  m.createdAt != null
                                                      ? heureCourte(m.createdAt!)
                                                      : '',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    color: estMoi
                                                        ? Colors.white
                                                            .withValues(
                                                                alpha: 0.75)
                                                        : t.textMuted,
                                                  ),
                                                ),
                                                if (estMoi) ...[
                                                  const SizedBox(width: 3),
                                                  Icon(
                                                    m.lu
                                                        ? Icons.done_all_rounded
                                                        : Icons.done_rounded,
                                                    size: 14,
                                                    color: m.lu
                                                        ? const Color(0xFF5AC8FA)
                                                        : Colors.white
                                                            .withValues(alpha: 0.75),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      )),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                if (enAttenteDecision)
                  _DemandeContact(
                    contact: contact,
                    onAccepter: () => ref
                        .read(contactsProvider.notifier)
                        .memoriser(contact),
                    onBloquer: () async {
                      await ref
                          .read(blockedContactsProvider.notifier)
                          .bloquer(contact);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  )
                else ...[
                  if (_pieceJointe != null)
                    _ApercuPieceJointe(
                      fichier: _pieceJointe!,
                      octets: _pieceJointeOctets,
                      estImage: _pieceJointeEstImage,
                      onRetirer: _retirerPieceJointe,
                    ),
                  MessageInputBar(
                    controller: _ctrl,
                    onEnvoyer: _send,
                    onChanged: (_) => _signalerFrappe(),
                    onJoindreFichier: _choisirPieceJointe,
                  ),
                ],
              ],
            ),
            const DraggableAiFab(
              bottomInset: _ConversationPageState._barreSaisieHauteur,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bannière remplaçant la barre de saisie tant que le destinataire n'a pas
/// choisi d'accepter ou de bloquer un premier contact (ex. via identifiant).
class _DemandeContact extends StatelessWidget {
  const _DemandeContact({
    required this.contact,
    required this.onAccepter,
    required this.onBloquer,
  });

  final Contact contact;
  final VoidCallback onAccepter;
  final VoidCallback onBloquer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_add_alt_1_rounded,
                    size: 18, color: UniverseColors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${contact.nom} ${tr(context, "veut te contacter")}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tr(context,
                  'Cette personne t\'a écrit pour la première fois. Accepte pour '
                  'discuter avec elle, ou bloque-la si tu ne la connais pas.'),
              style: TextStyle(fontSize: 12.5, color: t.textMuted, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onBloquer,
                    icon: const Icon(Icons.block_rounded, size: 16),
                    label: Text(tr(context, 'Bloquer')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: UniverseColors.danger,
                      side: const BorderSide(color: UniverseColors.danger),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAccepter,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(tr(context, 'Accepter')),
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

/// Aperçu de la pièce jointe choisie avant envoi — miniature pour une
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
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
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
                ? Image.memory(octets!, width: 40, height: 40, fit: BoxFit.cover)
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
            child: Text(
              fichier.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
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

/// Rappel clair pour un Enseignant en attente de validation (§3) : son
/// compte reste un compte étudiant limité en attendant, y compris pour la
/// messagerie. Texte simple, sans jargon — public souvent plus âgé.
class _BandeauEnseignantEnAttente extends StatelessWidget {
  const _BandeauEnseignantEnAttente();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UniverseColors.violet.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UniverseColors.violet.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: UniverseColors.violet),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr(context,
                  'Ton dossier enseignant est en cours d\'examen. En attendant, '
                  'tu écris ici comme un étudiant : certains contacts (par '
                  'exemple un autre enseignant) répondent seulement sous 24 h.'),
              style: TextStyle(fontSize: 12.5, height: 1.4, color: t.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bulle « en train d'écrire » — trois points animés, alignés comme un
/// message reçu.
class _BulleFrappe extends StatefulWidget {
  const _BulleFrappe();

  @override
  State<_BulleFrappe> createState() => _BulleFrappeState();
}

class _BulleFrappeState extends State<_BulleFrappe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final phase = (_c.value - i * 0.18) % 1.0;
              final intensite = phase < 0.5 ? (phase * 2) : (2 - phase * 2);
              return Container(
                width: 6,
                height: 6,
                margin: EdgeInsets.only(right: i == 2 ? 0 : 5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.textMuted.withValues(alpha: 0.35 + 0.55 * intensite),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

