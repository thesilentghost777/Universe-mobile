/// Implémentation neutre pour mobile/desktop — l'API `Notification` du
/// navigateur n'existe que sur le web. Rien ne s'affiche ici, mais rien ne
/// casse non plus : les appelants n'ont pas besoin de tester la plateforme.
class BrowserNotifications {
  const BrowserNotifications._();

  static bool get disponible => false;

  static String get permission => 'default';

  static Future<bool> demanderPermission() async => false;

  static void afficher(String titre, {String? corps}) {}
}
