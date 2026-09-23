import 'package:shared_preferences/shared_preferences.dart';

/// Persistance « tutoriel déjà vu » — une clé par utilisateur et par rôle,
/// pour qu'un changement de rôle (formateur devenu enseignant, par exemple)
/// redéclenche la version adaptée au nouveau rôle.
class TutorialService {
  const TutorialService();

  String _cle(String userId, String rang) => 'universe_tutoriel_vu_${userId}_$rang';

  Future<bool> aDejaVu(String userId, String rang) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_cle(userId, rang)) ?? false;
  }

  Future<void> marquerVu(String userId, String rang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cle(userId, rang), true);
  }

  /// Relance depuis les Paramètres (§9) : oublie que ce rôle a déjà été vu.
  Future<void> reinitialiser(String userId, String rang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cle(userId, rang));
  }
}
