import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Universités épinglées dans le rail de gauche.
///
/// Le cahier des charges ouvre la **lecture** de tous les espaces à tout
/// utilisateur (ET-9bis). Le rail ne montre donc pas « les universités
/// autorisées » — elles le sont toutes — mais celles que l'utilisateur a
/// choisi de garder sous la main. C'est un réglage local, propre à l'appareil.
final followedUniversitesProvider =
    NotifierProvider<FollowedUniversites, List<String>>(
  FollowedUniversites.new,
);

class FollowedUniversites extends Notifier<List<String>> {
  static const _key = 'universe_rail_universites';

  @override
  List<String> build() {
    _restore();
    return const [];
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_key);
      if (saved != null && saved.isNotEmpty) state = saved;
    } catch (_) {
      // Préférence illisible : le rail se remplira au premier chargement.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, state);
    } catch (_) {
      // Echec d'écriture : le choix reste actif pour la session en cours.
    }
  }

  bool contains(String id) => state.contains(id);

  Future<void> add(String id) async {
    if (state.contains(id)) return;
    state = [...state, id];
    await _persist();
  }

  Future<void> remove(String id) async {
    if (!state.contains(id)) return;
    state = state.where((e) => e != id).toList();
    await _persist();
  }

  Future<void> toggle(String id) =>
      state.contains(id) ? remove(id) : add(id);

  /// Premier lancement : on épingle d'office les universités données, sans
  /// écraser un choix déjà fait par l'utilisateur.
  Future<void> seedIfEmpty(List<String> ids) async {
    if (state.isNotEmpty || ids.isEmpty) return;
    state = ids;
    await _persist();
  }
}
