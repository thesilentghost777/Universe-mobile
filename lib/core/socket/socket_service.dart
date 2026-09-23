import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../api/api_client.dart';
import '../config.dart';
import '../auth/token_storage.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  final svc = SocketService(
    ref.watch(tokenStorageProvider),
    ref.watch(apiClientProvider),
  );
  ref.onDispose(svc.dispose);
  return svc;
});

class SocketService {
  SocketService(this._tokens, this._api);

  final TokenStorage _tokens;
  final ApiClient _api;
  io.Socket? _socket;

  /// Un handler par événement (dernier enregistré) — évite les doublons
  /// quand une page se reconstruite.
  final Map<String, void Function(dynamic)> _handlers = {};
  final Set<String> _conversations = {};
  final Set<String> _ressources = {};
  Future<void>? _connecting;
  bool _reconnexionEnCours = false;

  bool get connected => _socket?.connected ?? false;

  Set<String> get conversationsRejointes => Set.unmodifiable(_conversations);

  Future<void> connect() {
    if (_socket?.connected == true) return Future.value();
    return _connecting ??= _doConnect().whenComplete(() => _connecting = null);
  }

  Future<String?> _jetonAcces() async {
    var token = await _tokens.readAccess();
    if (token != null && token.isNotEmpty) return token;
    final ok = await _api.renouvelerSession();
    if (!ok) return null;
    return _tokens.readAccess();
  }

  Future<void> _doConnect() async {
    final token = await _jetonAcces();
    if (token == null) return;

    _socket?.dispose();
    final socket = io.io(
      AppConfig.apiBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionAttempts(12)
          .setReconnectionDelay(800)
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    socket.onConnect((_) {
      _attacherHandlers(socket);
      _reabonner();
    });
    socket.onReconnect((_) {
      _attacherHandlers(socket);
      _reabonner();
    });
    socket.onConnectError((_) {
      _tenterReconnecterAvecRefresh();
    });
    _socket = socket;
    socket.connect();
  }

  Future<void> _tenterReconnecterAvecRefresh() async {
    if (_reconnexionEnCours) return;
    _reconnexionEnCours = true;
    try {
      final ok = await _api.renouvelerSession();
      if (!ok) return;
      final token = await _tokens.readAccess();
      if (token == null || _socket == null) return;
      _socket!.io.options?['auth'] = {'token': token};
      if (_socket?.connected != true) {
        _socket!.connect();
      }
    } finally {
      _reconnexionEnCours = false;
    }
  }

  void _attacherHandlers(io.Socket socket) {
    _handlers.forEach((event, fn) {
      socket.off(event);
      socket.on(event, fn);
    });
  }

  void _reabonner() {
    for (final id in _conversations) {
      _socket?.emit('rejoindre_conversation', {'conversationId': id});
    }
    for (final id in _ressources) {
      _socket?.emit('rejoindre_ressource', {'ressourceId': id});
    }
  }

  void _register(String event, void Function(dynamic) handler) {
    _handlers[event] = handler;
    _socket?.off(event);
    _socket?.on(event, handler);
  }

  void onNotification(void Function(dynamic) handler) =>
      _register('notification', handler);

  void onRessourceMessage(void Function(dynamic) handler) =>
      _register('message_ressource', handler);

  void onConversationMessage(void Function(dynamic) handler) =>
      _register('message_conversation', handler);

  void onTypingConversation(void Function(dynamic) handler) =>
      _register('typing_conversation', handler);

  void emitTypingConversation(String conversationId) {
    _socket?.emit('typing_conversation', {'conversationId': conversationId});
  }

  void onMessageLu(void Function(dynamic) handler) =>
      _register('message_lu', handler);

  void emitMessageLu(String conversationId, String messageId) {
    _socket?.emit('message_lu', {
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }

  void joinConversation(String conversationId) {
    _conversations.add(conversationId);
    _socket?.emit('rejoindre_conversation', {'conversationId': conversationId});
  }

  void joinRessource(String ressourceId) {
    _ressources.add(ressourceId);
    _socket?.emit('rejoindre_ressource', {'ressourceId': ressourceId});
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    _conversations.clear();
    _ressources.clear();
    _handlers.clear();
  }
}
