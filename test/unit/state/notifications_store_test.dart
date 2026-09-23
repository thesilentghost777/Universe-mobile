import 'package:flutter_test/flutter_test.dart';
import 'package:universe_frontend/core/notifications/notifications_store.dart';
import 'package:universe_frontend/shared/models/models.dart';

void main() {
  group('Notifications Store & Model Tests', () {
    test('NotificationItem parsing and default status', () {
      final json = {
        'id': 'notif-1',
        'type': TypesNotification.nouveauMessageDirect,
        'titre': 'Nouveau message de Jean',
        'lu': false,
        'createdAt': '2026-08-31T10:00:00Z',
      };

      final notif = NotificationItem.fromJson(json);

      expect(notif.id, 'notif-1');
      expect(notif.type, 'nouveau_message_direct');
      expect(notif.titre, 'Nouveau message de Jean');
      expect(notif.lu, isFalse);
      expect(notif.createdAt, isNotNull);
    });

    test('EtatNotifications counts unread items correctly', () {
      final items = [
        const NotificationItem(
          id: '1',
          type: TypesNotification.nouveauMessageDirect,
          titre: 'Msg 1',
          lu: false,
        ),
        const NotificationItem(
          id: '2',
          type: TypesNotification.nouveauMessageDirect,
          titre: 'Msg 2',
          lu: true,
        ),
        const NotificationItem(
          id: '3',
          type: TypesNotification.statutDemande,
          titre: 'Demande approuvée',
          lu: false,
        ),
        const NotificationItem(
          id: '4',
          type: TypesNotification.nouvelleRessource,
          titre: 'Nouveau cours algo',
          lu: false,
        ),
      ];

      final etat = EtatNotifications(items: items);

      expect(etat.total, 3);
      expect(etat.messages, 1);
      expect(etat.compte(TypesNotification.statutDemande), 1);
      expect(etat.compte(TypesNotification.nouvelleRessource), 1);
      expect(etat.nonLues.length, 3);
    });

    test('EtatNotifications copyWith maintains consistency', () {
      const etat = EtatNotifications(chargement: true);
      expect(etat.chargement, isTrue);
      expect(etat.items, isEmpty);

      final updated = etat.copyWith(
        chargement: false,
        items: [
          const NotificationItem(
            id: '1',
            type: TypesNotification.reponseRecue,
            titre: 'Réponse forum',
            lu: false,
          ),
        ],
      );

      expect(updated.chargement, isFalse);
      expect(updated.total, 1);
    });
  });
}
