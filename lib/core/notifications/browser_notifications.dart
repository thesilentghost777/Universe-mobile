// Point d'entrée unique — bascule vers l'implémentation web ou le stub
// neutre selon la plateforme de compilation.
export 'browser_notifications_stub.dart'
    if (dart.library.html) 'browser_notifications_web.dart';
