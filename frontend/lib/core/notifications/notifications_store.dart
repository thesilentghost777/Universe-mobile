import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../socket/socket_service.dart';
import 'browser_notifications.dart';
import '../../shared/models/models.dart';

/// Préférence "notifications du navigateur activées", indépendante de la
/// permission navigateur elle-même (qui peut être accordée puis désactivée
/// ici sans avoir à la retirer dans les réglages du navigateur).
const _clePrefActivees = 'notif_navigateur_activees';

/// Les cinq types de notification du cahier des charges (NOTIF-2).
class TypesNotification {
  TypesNotification._();

  static const nouvelleRessource = 'nouvelle_ressource';
  static const reponseRecue = 'reponse_recue';
  static const nouvelleVideoSuivie = 'nouvelle_video_suivie';
  static const statutDemande = 'statut_demande';
  static const nouveauMessageDirect = 'nouveau_message_direct';
}

class EtatNotifications {
  const EtatNotifications({this.items = const [], this.chargement = false});

  final List<NotificationItem> items;
  final bool chargement;

  List<NotificationItem> get nonLues =>
      items.where((n) => !n.lu).toList();

  int get total => nonLues.length;

  /// Non lues d'un type donné — sert notamment à la pastille des messages.
  int compte(String type) =>
      nonLues.where((n) => n.type == type).length;

  /// Messages directs non lus, affichés sur le bouton conversations du rail.
  int get messages => compte(TypesNotification.nouveauMessageDirect);

  EtatNotifications copyWith({
    List<NotificationItem>? items,
    bool? chargement,
  }) =>
      EtatNotifications(
        items: items ?? this.items,
        chargement: chargement ?? this.chargement,
      );
}

final notificationsProvider =
    NotifierProvider<NotificationsController, EtatNotifications>(
  NotificationsController.new,
);

class NotificationsController extends Notifier<EtatNotifications> {
  Timer? _rafraichissement;
  bool _socketBranche = false;

  @override
  EtatNotifications build() {
    ref.onDispose(() => _rafraichissement?.cancel());
    return const EtatNotifications();
  }

  /// À appeler une fois l'utilisateur authentifié.
  ///
  /// Deux sources : le socket pour l'immédiat, et un rafraîchissement
  /// périodique en filet — sur un réseau mobile instable, la connexion
  /// temps réel tombe régulièrement, et une pastille figée à zéro serait
  /// pire que pas de pastille du tout.
  Future<void> demarrer() async {
    await charger();

    if (!_socketBranche) {
      _socketBranche = true;
      final sock = ref.read(socketServiceProvider);
      // Les handlers sont mémorisés côté SocketService et (ré)attachés à chaque
      // connexion : l'ordre entre `connect()` et cet enregistrement n'importe
      // plus.
      sock.onNotification((_) => charger());
      sock.onConversationMessage((_) => charger());
      await sock.connect();
    }

    _rafraichissement?.cancel();
    _rafraichissement = Timer.periodic(
      const Duration(minutes: 2),
      (_) => charger(),
    );
  }

  Future<void> charger() async {
    try {
      final res = await ref.read(apiClientProvider).get('/notifications');
      final brut = res.data;
      final liste =
          brut is List ? brut : (brut as Map)['items'] as List? ?? [];
      final nouveaux = liste
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();

      // Notification navigateur uniquement pour les non-lues qui viennent
      // d'apparaître — sinon chaque rafraîchissement périodique rejouerait
      // toutes les notifications déjà connues.
      final ancienIds = state.items.map((n) => n.id).toSet();
      final arrivees = nouveaux.where(
        (n) => !n.lu && !ancienIds.contains(n.id),
      );
      if (await notifsNavigateurActivees()) {
        for (final n in arrivees) {
          BrowserNotifications.afficher(n.titre);
        }
      }

      state = state.copyWith(items: nouveaux, chargement: false);
    } catch (_) {
      // Réseau indisponible : on garde le dernier état connu plutôt que
      // de faire disparaître la pastille.
    }
  }

  /// Préférence "notifications du navigateur" — activée seulement si
  /// l'utilisateur l'a explicitement demandé ET que la permission
  /// navigateur est accordée (l'un sans l'autre ne suffit pas).
  static Future<bool> notifsNavigateurActivees() async {
    if (BrowserNotifications.permission != 'granted') return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_clePrefActivees) ?? false;
  }

  /// Demande la permission navigateur si besoin, puis active/désactive la
  /// préférence. Retourne l'état final (peut différer de [actif] demandé
  /// si la permission a été refusée).
  static Future<bool> definirNotifsNavigateur(bool actif) async {
    final prefs = await SharedPreferences.getInstance();
    if (!actif) {
      await prefs.setBool(_clePrefActivees, false);
      return false;
    }
    final accordee = BrowserNotifications.permission == 'granted' ||
        await BrowserNotifications.demanderPermission();
    await prefs.setBool(_clePrefActivees, accordee);
    return accordee;
  }

  /// Marque une notification comme lue, en mettant à jour l'affichage
  /// immédiatement plutôt qu'en attendant la réponse du serveur.
  Future<void> marquerLue(String id) async {
    state = state.copyWith(
      items: [
        for (final n in state.items)
          if (n.id == id)
            NotificationItem(
              id: n.id,
              type: n.type,
              titre: n.titre,
              lu: true,
              createdAt: n.createdAt,
            )
          else
            n,
      ],
    );
    try {
      await ref.read(apiClientProvider).patch('/notifications/$id/lu');
    } catch (_) {
      await charger(); // Echec : on resynchronise sur le serveur.
    }
  }

  /// Marque toutes les notifications d'un type comme lues — appelé quand
  /// l'utilisateur ouvre l'écran concerné.
  Future<void> marquerTypeLu(String type) async {
    final cibles =
        state.nonLues.where((n) => n.type == type).map((n) => n.id).toList();
    for (final id in cibles) {
      await marquerLue(id);
    }
  }
}
