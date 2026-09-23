import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/role_access.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/notifications/notifications_store.dart';
import '../../core/socket/socket_service.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/chat_wallpaper.dart';
import '../../core/widgets/date_separator_pill.dart';
import '../../core/widgets/message_input_bar.dart';
import '../../core/widgets/universe_skeleton.dart';
import '../messaging/contacts_store.dart';
import '../messaging/nouveau_message_sheet.dart';

/// Apparence par type de ressource — icône et couleur, façon Discord (une
/// annonce épinglée n'a pas le même poids visuel qu'une simple discussion).
(IconData, Color) _apparenceType(String? type) => switch (type) {
      'annonce' => (Icons.campaign_rounded, UniverseColors.danger),
      'cours' => (Icons.menu_book_rounded, UniverseColors.blue),
      'exercice' => (Icons.edit_note_rounded, UniverseColors.violet),
      _ => (Icons.forum_rounded, UniverseColors.teal),
    };

class ChannelPage extends ConsumerStatefulWidget {
  const ChannelPage({super.key, required this.canalId});

  final String canalId;

  @override
  ConsumerState<ChannelPage> createState() => _ChannelPageState();
}

class _ChannelPageState extends ConsumerState<ChannelPage> {
  List<Map<String, dynamic>> _ressources = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Entrer dans le canal vaut lecture : la pastille de réponses reçues
    // ne doit pas rester allumée une fois le fil consulté.
    ref
        .read(notificationsProvider.notifier)
        .marquerTypeLu(TypesNotification.reponseRecue);
  }

  @override
  void didUpdateWidget(covariant ChannelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canalId != widget.canalId) {
      _load();
      ref
          .read(notificationsProvider.notifier)
          .marquerTypeLu(TypesNotification.reponseRecue);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get(
        '/ressources',
        queryParameters: {'canalId': widget.canalId, 'limit': 40},
      );
      final raw = res.data;
      final list = raw is List
          ? raw
          : (raw as Map)['items'] as List? ?? [];
      setState(() {
        _ressources = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const ListTileSkeleton();
    if (_ressources.isEmpty) {
      return Center(
        child: Text(tr(context, 'Aucune ressource dans ce canal'),
            style: TextStyle(color: context.tokens.textMuted)),
      );
    }
    final t = context.tokens;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: _ressources.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final r = _ressources[i];
          final type = r['type'] as String?;
          final (icone, couleur) = _apparenceType(type);
          return Material(
            color: t.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RessourceThreadPage(
                    ressourceId: r['id'] as String,
                    titre: r['titre'] as String? ?? tr(context, 'Discussion'),
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: type == 'annonce'
                        ? couleur.withValues(alpha: 0.35)
                        : t.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: couleur.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icone, size: 18, color: couleur),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['titre'] as String? ?? tr(context, 'Ressource'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (type ?? '').isEmpty
                                ? tr(context, 'Discussion')
                                : type![0].toUpperCase() + type.substring(1),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: couleur,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: t.textMuted),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class RessourceThreadPage extends ConsumerStatefulWidget {
  const RessourceThreadPage({
    super.key,
    required this.ressourceId,
    required this.titre,
  });

  final String ressourceId;
  final String titre;

  @override
  ConsumerState<RessourceThreadPage> createState() =>
      _RessourceThreadPageState();
}

class _RessourceThreadPageState extends ConsumerState<RessourceThreadPage> {
  final _ctrl = TextEditingController();
  /// Message auquel on repond (ET-3, reponse imbriquee facon WhatsApp).
  Map<String, dynamic>? _repondA;
  List<Map<String, dynamic>> _msgs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sock = ref.read(socketServiceProvider);
      sock.connect();
      sock.joinRessource(widget.ressourceId);
      sock.onRessourceMessage((data) {
        if (!mounted || data == null) return;
        try {
          final msg = data is Map ? Map<String, dynamic>.from(data) : null;
          if (msg != null && msg['ressourceId'] == widget.ressourceId) {
            setState(() {
              if (!_msgs.any((m) => m['id'] == msg['id'])) {
                _msgs.add(msg);
              }
            });
          }
        } catch (_) {}
      });
    });
  }

  /// Les auteurs lus dans un fil alimentent le carnet d'adresses local :
  /// c'est la seule source de contacts, faute de route de recherche
  /// d'utilisateurs.
  Iterable<Contact> _contactsDesMessages(List<Map<String, dynamic>> msgs) {
    return msgs.map((m) {
      final a = m['auteur'] as Map<String, dynamic>?;
      final nom = '${a?['prenom'] ?? ''} ${a?['nom'] ?? ''}'.trim();
      return Contact(
        id: (m['auteurId'] as String?) ?? (a?['id'] as String?) ?? '',
        nom: nom,
        rang: a?['rang'] as String?,
      );
    }).where((c) => c.id.isNotEmpty && c.nom.isNotEmpty);
  }

  Future<void> _load() async {
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/ressources/${widget.ressourceId}/messages');
      final raw = res.data;
      final list = raw is List
          ? raw
          : (raw as Map)['items'] as List? ?? [];
      setState(() {
        _msgs = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
      ref
          .read(contactsProvider.notifier)
          .memoriserPlusieurs(_contactsDesMessages(_msgs));
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    await ref.read(apiClientProvider).post(
      '/ressources/${widget.ressourceId}/messages',
      data: {
        'contenu': text,
        if (_repondA != null) 'repondAId': _repondA!['id'],
      },
    );
    _ctrl.clear();
    setState(() => _repondA = null);
    await _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titre)),
      body: ChatWallpaper(
        accentColor: UniverseColors.violet,
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const ListTileSkeleton()
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _msgs.length,
                      itemBuilder: (_, i) {
                        final m = _msgs[i];
                        final auteur = m['auteur'] as Map<String, dynamic>?;
                        final nom = auteur == null
                            ? tr(context, 'Utilisateur')
                            : '${auteur['prenom'] ?? ''} '
                                    '${auteur['nom'] ?? ''}'
                                .trim();
                        final contact = Contact(
                          id: (m['auteurId'] as String?) ??
                              (auteur?['id'] as String?) ??
                              '',
                          nom: nom.isEmpty ? tr(context, 'Utilisateur') : nom,
                          rang: auteur?['rang'] as String?,
                        );
                        final acces = RoleAccess(Rang.depuis(contact.rang));
                        final t = context.tokens;
                        final quand = m['createdAt'] is String
                            ? DateTime.tryParse(m['createdAt'] as String)
                            : null;
                        final precedent = i > 0 ? _msgs[i - 1] : null;
                        final quandPrecedent = precedent?['createdAt'] is String
                            ? DateTime.tryParse(
                                precedent!['createdAt'] as String)
                            : null;
                        final nouveauJour = quand != null &&
                            (quandPrecedent == null ||
                                !memeJour(quandPrecedent, quand));

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (nouveauJour) DateSeparatorPill(date: quand),
                            Padding(
                              // Une réponse est décalée sous son parent.
                              padding: EdgeInsets.only(
                                left: m['repondA'] != null ? 30 : 0,
                                bottom: 12,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  // Appui long : contacter l'auteur du message.
                                  // Appui court : répondre à ce message (ET-3).
                                  onTap: () => setState(() => _repondA = m),
                                  onLongPress: contact.id.isEmpty
                                      ? null
                                      : () => ouvrirConversationAvec(
                                            context,
                                            ref,
                                            contact,
                                          ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: acces.couleur
                                              .withValues(alpha: 0.20),
                                          child: Text(
                                            contact.nom
                                                .substring(0, 1)
                                                .toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: acces.couleur,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      contact.nom,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 13.5,
                                                      ),
                                                    ),
                                                  ),
                                                  if (contact.rang != null &&
                                                      contact.rang !=
                                                          'etudiant') ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: acces.couleur
                                                            .withValues(
                                                                alpha: 0.14),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child: Text(
                                                        acces.libelle,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: acces.couleur,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  if (quand != null) ...[
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      heureCourte(quand),
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        color: t.textMuted,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              if (m['repondA'] != null)
                                                _citation(m),
                                              Text(
                                                m['contenu'] as String? ?? '',
                                                style: TextStyle(
                                                  height: 1.35,
                                                  color: t.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            if (_repondA != null) _bandeauReponse(),
            MessageInputBar(controller: _ctrl, onEnvoyer: _send, hintText: tr(context, 'Répondre…')),
          ],
        ),
      ),
    );
  }
  /// Citation du message auquel celui-ci répond.
  Widget _citation(Map<String, dynamic> m) {
    final parent = _msgs.firstWhere(
      (e) => e['id'] == m['repondA'],
      orElse: () => <String, dynamic>{},
    );
    final texte = parent['contenu'] as String?;
    if (texte == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: context.tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: UniverseColors.blue, width: 3),
        ),
      ),
      child: Text(
        texte,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: context.tokens.textMuted),
      ),
    );
  }

  /// Bandeau affiché au-dessus de la saisie pendant une réponse.
  Widget _bandeauReponse() {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: t.surfaceElevated,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 30, color: UniverseColors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr(context, 'Réponse à'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: UniverseColors.blue,
                  ),
                ),
                Text(
                  _repondA?['contenu'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _repondA = null),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
