// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
//
// `dart:html` est la seule API pour les notifications navigateur avec le
// SDK actuel ; `package:web` + `dart:js_interop` sont la voie recommandée
// à terme, mais ce fichier reste isolé derrière `browser_notifications.dart`
// (import conditionnel) donc son remplacement futur n'impacte aucun appelant.
import 'dart:html' as html;

/// Notifications natives du navigateur (Web Notifications API).
///
/// Ce sont des notifications **locales** : déclenchées côté client quand un
/// évènement arrive par le socket déjà ouvert (page active ou onglet en
/// arrière-plan). Ce n'est pas du push serveur — pour recevoir une
/// notification quand l'onglet est complètement fermé, il faudra un
/// service worker + un serveur de push (VAPID), côté back : contrat à
/// transmettre, `POST /notifications/abonnements-push` avec la souscription
/// `PushSubscription` sérialisée.
class BrowserNotifications {
  const BrowserNotifications._();

  static bool get disponible => html.Notification.supported;

  static String get permission =>
      disponible ? (html.Notification.permission ?? 'default') : 'default';

  static Future<bool> demanderPermission() async {
    if (!disponible) return false;
    final reponse = await html.Notification.requestPermission();
    return reponse == 'granted';
  }

  static void afficher(String titre, {String? corps}) {
    if (!disponible || html.Notification.permission != 'granted') return;
    html.Notification(titre, body: corps, icon: 'icons/Icon-192.png');
  }
}
