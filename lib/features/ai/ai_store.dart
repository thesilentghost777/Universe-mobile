import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';

/// Un message dans une conversation avec l'assistant.
class AiMessage {
  const AiMessage({
    required this.role,
    required this.content,
    required this.at,
    this.pieceJointeNom,
    this.pieceJointeBytes,
    this.pieceJointeEstImage = true,
  });

  /// `user`, `assistant` ou `error`.
  final String role;
  final String content;
  final DateTime at;

  /// Pièce jointe (§7.5). `pieceJointeBytes` n'est jamais persisté (voir
  /// [toJson]) : après un rechargement, seul le nom du fichier reste comme
  /// trace dans l'historique. **Contrat à transmettre** : `POST /ai/ask`
  /// devra accepter un envoi `multipart/form-data` (champ `fichier`) pour
  /// que l'assistant l'analyse réellement — pour l'instant seul le texte
  /// part au serveur, la pièce jointe reste un aperçu côté client.
  final String? pieceJointeNom;
  final Uint8List? pieceJointeBytes;
  final bool pieceJointeEstImage;

  bool get isUser => role == 'user';
  bool get isError => role == 'error';
  bool get aUnePieceJointe => pieceJointeNom != null;

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'at': at.toIso8601String(),
        if (pieceJointeNom != null) 'pieceJointeNom': pieceJointeNom,
        'pieceJointeEstImage': pieceJointeEstImage,
      };

  factory AiMessage.fromJson(Map<String, dynamic> j) => AiMessage(
        role: j['role'] as String? ?? 'assistant',
        content: j['content'] as String? ?? '',
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
        pieceJointeNom: j['pieceJointeNom'] as String?,
        pieceJointeEstImage: j['pieceJointeEstImage'] as bool? ?? true,
      );
}

/// Une conversation, telle qu'elle apparaît dans l'historique.
class AiConversation {
  const AiConversation({
    required this.id,
    required this.titre,
    required this.messages,
    required this.majLe,
  });

  final String id;
  final String titre;
  final List<AiMessage> messages;
  final DateTime majLe;

  AiConversation copyWith({
    String? titre,
    List<AiMessage>? messages,
    DateTime? majLe,
  }) =>
      AiConversation(
        id: id,
        titre: titre ?? this.titre,
        messages: messages ?? this.messages,
        majLe: majLe ?? this.majLe,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'titre': titre,
        'majLe': majLe.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory AiConversation.fromJson(Map<String, dynamic> j) => AiConversation(
        id: j['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        titre: j['titre'] as String? ?? 'Conversation',
        majLe: DateTime.tryParse(j['majLe'] as String? ?? '') ?? DateTime.now(),
        messages: (j['messages'] as List? ?? [])
            .map((e) => AiMessage.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class AiChatState {
  const AiChatState({
    this.conversations = const [],
    this.couranteId,
    this.envoiEnCours = false,
  });

  final List<AiConversation> conversations;
  final String? couranteId;
  final bool envoiEnCours;

  AiConversation? get courante {
    for (final c in conversations) {
      if (c.id == couranteId) return c;
    }
    return null;
  }

  List<AiMessage> get messages => courante?.messages ?? const [];

  AiChatState copyWith({
    List<AiConversation>? conversations,
    String? couranteId,
    bool? envoiEnCours,
    bool effacerCourante = false,
  }) =>
      AiChatState(
        conversations: conversations ?? this.conversations,
        couranteId: effacerCourante ? null : (couranteId ?? this.couranteId),
        envoiEnCours: envoiEnCours ?? this.envoiEnCours,
      );
}

final aiChatProvider =
    NotifierProvider<AiChatController, AiChatState>(AiChatController.new);

class AiChatController extends Notifier<AiChatState> {
  static const _key = 'universe_ai_conversations';
  static const _maxConversations = 30;

  @override
  AiChatState build() {
    _restaurer();
    return const AiChatState();
  }

  Future<void> _restaurer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(_key);
      if (brut == null) return;
      final list = (jsonDecode(brut) as List)
          .map((e) =>
              AiConversation.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      state = state.copyWith(conversations: list);
    } catch (_) {
      // Historique illisible : on repart d'une liste vide.
    }
  }

  Future<void> _persister() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = state.conversations.take(_maxConversations).toList();
      await prefs.setString(
        _key,
        jsonEncode(list.map((c) => c.toJson()).toList()),
      );
    } catch (_) {
      // Echec d'écriture : l'historique reste en mémoire pour la session.
    }
  }

  /// Repart d'une conversation vierge (rien n'est créé tant qu'aucun
  /// message n'est envoyé, pour ne pas polluer l'historique).
  void nouvelleConversation() {
    state = state.copyWith(effacerCourante: true);
  }

  void ouvrir(String id) {
    state = state.copyWith(couranteId: id);
  }

  Future<void> supprimer(String id) async {
    final restantes =
        state.conversations.where((c) => c.id != id).toList();
    state = AiChatState(
      conversations: restantes,
      couranteId: state.couranteId == id ? null : state.couranteId,
      envoiEnCours: state.envoiEnCours,
    );
    await _persister();
  }

  Future<void> toutSupprimer() async {
    state = const AiChatState();
    await _persister();
  }

  /// Envoie une question à l'assistant et ajoute la réponse au fil.
  ///
  /// `pieceJointeNom`/`pieceJointeBytes`/`pieceJointeEstImage` décrivent une
  /// pièce jointe déjà validée (taille, type) par l'écran — voir le contrat
  /// documenté sur [AiMessage.pieceJointeNom].
  Future<void> envoyer(
    String texte, {
    String? pieceJointeNom,
    Uint8List? pieceJointeBytes,
    bool pieceJointeEstImage = true,
  }) async {
    final question = texte.trim();
    if ((question.isEmpty && pieceJointeNom == null) || state.envoiEnCours) {
      return;
    }

    final maintenant = DateTime.now();
    var conv = state.courante;

    conv ??= AiConversation(
        id: maintenant.microsecondsSinceEpoch.toString(),
        titre: _titreDepuis(question.isEmpty ? (pieceJointeNom ?? '') : question),
        messages: const [],
        majLe: maintenant,
      );

    // 1. On affiche tout de suite la question de l'utilisateur.
    conv = conv.copyWith(
      messages: [
        ...conv.messages,
        AiMessage(
          role: 'user',
          content: question,
          at: maintenant,
          pieceJointeNom: pieceJointeNom,
          pieceJointeBytes: pieceJointeBytes,
          pieceJointeEstImage: pieceJointeEstImage,
        ),
      ],
      majLe: maintenant,
    );
    _remplacer(conv, envoiEnCours: true);

    // 2. Appel serveur — texte seul pour l'instant (voir contrat ci-dessus
    // pour l'envoi effectif de la pièce jointe).
    String? reponse;
    String? erreur;
    try {
      final texteEnvoye = question.isNotEmpty
          ? question
          : 'Voici une pièce jointe : ${pieceJointeNom ?? 'fichier'}.';
      reponse = await _demanderAuServeur(texteEnvoye);
    } catch (e) {
      erreur = _messageErreur(e);
    }

    // 3. On ajoute la réponse (ou l'erreur) au fil.
    final courante = state.courante ?? conv;
    final maj = courante.copyWith(
      messages: [
        ...courante.messages,
        AiMessage(
          role: erreur == null ? 'assistant' : 'error',
          content: erreur ?? (reponse ?? ''),
          at: DateTime.now(),
        ),
      ],
      majLe: DateTime.now(),
    );
    _remplacer(maj, envoiEnCours: false);
    await _persister();
  }

  /// Relance la dernière question après une erreur.
  Future<void> reessayer() async {
    final conv = state.courante;
    if (conv == null || conv.messages.isEmpty) return;

    // On retire l'erreur et la question, puis on renvoie la question.
    final msgs = [...conv.messages];
    if (msgs.isNotEmpty && msgs.last.isError) msgs.removeLast();
    if (msgs.isEmpty || !msgs.last.isUser) return;
    final question = msgs.removeLast().content;

    _remplacer(conv.copyWith(messages: msgs));
    await envoyer(question);
  }

  void _remplacer(AiConversation conv, {bool? envoiEnCours}) {
    final autres = state.conversations.where((c) => c.id != conv.id).toList();
    state = AiChatState(
      conversations: [conv, ...autres],
      couranteId: conv.id,
      envoiEnCours: envoiEnCours ?? state.envoiEnCours,
    );
  }

  /// Appelle `POST /ai/ask`.
  ///
  /// Le nom exact du champ attendu par le backend n'est pas figé dans les
  /// documents : on tente `question`, puis `message`, puis `prompt`, et on
  /// s'arrête au premier qui n'est pas rejeté par la validation (400/422).
  /// Une fois le bon nom confirmé sur le Swagger, cette liste peut être
  /// réduite à une seule entrée.
  Future<String> _demanderAuServeur(String question) async {
    final api = ref.read(apiClientProvider);
    Object? derniereErreur;

    for (final champ in ['question', 'message', 'prompt']) {
      try {
        final res = await api.post('/ai/ask', data: {champ: question});
        return _extraireReponse(res.data);
      } catch (e) {
        derniereErreur = e;
        if (!_estErreurDeValidation(e)) rethrow;
      }
    }
    throw derniereErreur ?? Exception('Réponse illisible');
  }

  static bool _estErreurDeValidation(Object e) {
    final texte = e.toString();
    return texte.contains('400') || texte.contains('422');
  }

  static String extraireReponse(dynamic data) {
    if (data is String) return data.trim();
    if (data is Map) {
      for (final cle in ['reponse', 'answer', 'response', 'content', 'texte']) {
        final v = data[cle];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
      if (message is Map && message['content'] is String) {
        return (message['content'] as String).trim();
      }
      final choices = data['choices'];
      if (choices is List && choices.isNotEmpty) {
        final premier = choices.first;
        if (premier is Map && premier['message'] is Map) {
          final c = (premier['message'] as Map)['content'];
          if (c is String) return c.trim();
        }
      }
    }
    throw Exception('Réponse illisible');
  }

  static String _extraireReponse(dynamic data) => extraireReponse(data);

  static String messageErreur(Object e) {
    final texte = e.toString();
    if (texte.contains('429')) {
      return 'Trop de questions d\'affilée. Attends quelques secondes '
          'avant de réessayer.';
    }
    if (texte.contains('401') || texte.contains('403')) {
      return 'Session expirée. Reconnecte-toi pour utiliser l\'assistant.';
    }
    if (texte.contains('SocketException') ||
        texte.contains('timeout') ||
        texte.contains('Timeout')) {
      return 'Connexion indisponible. Vérifie ton réseau et réessaie.';
    }
    return 'L\'assistant n\'a pas pu répondre. Réessaie dans un instant.';
  }

  static String _messageErreur(Object e) => messageErreur(e);

  static String _titreDepuis(String question) {
    final propre = question.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (propre.length <= 42) return propre;
    return '${propre.substring(0, 42)}…';
  }
}
