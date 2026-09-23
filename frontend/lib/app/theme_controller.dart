import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mode d'affichage choisi par l'utilisateur, conservé entre deux lancements.
///
/// Par défaut : [ThemeMode.system]. Un choix déjà enregistré dans les
/// Paramètres (clair ou sombre) est restauré au lancement.
final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'universe_theme_mode';

  @override
  ThemeMode build() {
    _restore();
    // Suit le réglage du téléphone tant que l'utilisateur n'a rien choisi.
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null) state = _decode(saved);
    } catch (_) {
      // Préférence illisible : on reste sur le mode système.
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, _encode(mode));
    } catch (_) {
      // Echec d'écriture : le choix reste actif pour la session en cours.
    }
  }

  /// Bascule clair ↔ sombre en tenant compte du mode système courant.
  Future<void> toggle(BuildContext context) {
    final effectif = state == ThemeMode.system
        ? (MediaQuery.platformBrightnessOf(context) == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light)
        : state;
    return set(
      effectif == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  static String encode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  static ThemeMode decode(String raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _encode(ThemeMode mode) => encode(mode);
  static ThemeMode _decode(String raw) => decode(raw);
}

/// Libellé affiché dans les paramètres.
String themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'Clair',
      ThemeMode.dark => 'Sombre',
      ThemeMode.system => 'Système',
    };

/// Taille de texte choisie par l'utilisateur (accessibilité, §10) —
/// multiplie le `textScaler` ambiant, appliqué globalement dans
/// `UniverseApp` (voir `main.dart`).
enum TaillePolice { standard, grande, tresGrande }

extension TaillePoliceX on TaillePolice {
  double get facteur => switch (this) {
        TaillePolice.standard => 1.0,
        TaillePolice.grande => 1.15,
        TaillePolice.tresGrande => 1.3,
      };

  String get libelle => switch (this) {
        TaillePolice.standard => 'Standard',
        TaillePolice.grande => 'Grande',
        TaillePolice.tresGrande => 'Très grande',
      };
}

final taillePoliceProvider =
    NotifierProvider<TaillePoliceController, TaillePolice>(TaillePoliceController.new);

class TaillePoliceController extends Notifier<TaillePolice> {
  static const _key = 'universe_taille_police';

  @override
  TaillePolice build() {
    _restore();
    return TaillePolice.standard;
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null) {
        state = TaillePolice.values.firstWhere(
          (v) => v.name == saved,
          orElse: () => TaillePolice.standard,
        );
      }
    } catch (_) {}
  }

  Future<void> set(TaillePolice taille) async {
    state = taille;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, taille.name);
    } catch (_) {}
  }
}
