import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Identité UniVerse — navy + dégradé bleu→violet (logo).
///
/// Ces constantes restent la **marque** : elles ne changent jamais d'un mode à
/// l'autre. Pour tout ce qui dépend du mode clair/sombre (fonds, rail, bordures,
/// texte), passer par [UniverseTokens] via `context.tokens`.
class UniverseColors {
  UniverseColors._();

  static const Color navy = Color(0xFF0B1220);
  static const Color surface = Color(0xFF121A2B);
  static const Color surfaceElevated = Color(0xFF1A2438);
  static const Color blue = Color(0xFF2563EB);
  static const Color violet = Color(0xFF7C3AED);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);
  static const Color amber = Color(0xFFF59E0B);
  static const Color teal = Color(0xFF14B8A6);

  /// Petite palette d'accents pour distinguer visuellement des catégories
  /// (matières, types de contenu…) sans sortir de l'identité de marque.
  static const List<Color> accents = [blue, violet, teal, amber];

  /// Accent stable pour une même étiquette (ex. une matière garde toujours
  /// la même couleur d'un rendu à l'autre).
  static Color accentFor(String? label) {
    if (label == null || label.isEmpty) return blue;
    return accents[label.hashCode.abs() % accents.length];
  }

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [blue, violet],
  );
}

/// Couleurs dépendantes du mode clair/sombre.
///
/// Lecture : `context.tokens.rail`, `context.tokens.border`, etc.
@immutable
class UniverseTokens extends ThemeExtension<UniverseTokens> {
  const UniverseTokens({
    required this.rail,
    required this.railDivider,
    required this.canvas,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.floatingBar,
    required this.shadow,
  });

  /// Barre latérale gauche (style Discord).
  /// Volontairement **plus sombre que le canvas** en dark mode, et
  /// **légèrement bleutée** en light mode.
  final Color rail;
  final Color railDivider;

  /// Fond général de l'application.
  final Color canvas;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color textPrimary;
  final Color textMuted;

  /// Fond de la barre de navigation flottante.
  final Color floatingBar;
  final Color shadow;

  static const UniverseTokens dark = UniverseTokens(
    rail: Color(0xFF06090F),
    railDivider: Color(0xFF162033),
    canvas: Color(0xFF0B1220),
    surface: Color(0xFF121A2B),
    surfaceElevated: Color(0xFF1A2438),
    border: Color(0xFF223049),
    textPrimary: Color(0xFFF8FAFC),
    textMuted: Color(0xFF94A3B8),
    floatingBar: Color(0xFF131C2E),
    shadow: Color(0x99000000),
  );

  static const UniverseTokens light = UniverseTokens(
    rail: Color(0xFFD7E0F5),
    railDivider: Color(0xFFC2CFEA),
    canvas: Color(0xFFF6F8FD),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEDF2FD),
    border: Color(0xFFDCE4F3),
    textPrimary: Color(0xFF0F172A),
    textMuted: Color(0xFF5B6B85),
    floatingBar: Color(0xFFFFFFFF),
    shadow: Color(0x1A0F172A),
  );

  @override
  UniverseTokens copyWith({
    Color? rail,
    Color? railDivider,
    Color? canvas,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? textPrimary,
    Color? textMuted,
    Color? floatingBar,
    Color? shadow,
  }) {
    return UniverseTokens(
      rail: rail ?? this.rail,
      railDivider: railDivider ?? this.railDivider,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      floatingBar: floatingBar ?? this.floatingBar,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  UniverseTokens lerp(ThemeExtension<UniverseTokens>? other, double t) {
    if (other is! UniverseTokens) return this;
    return UniverseTokens(
      rail: Color.lerp(rail, other.rail, t)!,
      railDivider: Color.lerp(railDivider, other.railDivider, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated:
          Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      floatingBar: Color.lerp(floatingBar, other.floatingBar, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension UniverseThemeX on BuildContext {
  /// Raccourci : `context.tokens.rail`.
  UniverseTokens get tokens =>
      Theme.of(this).extension<UniverseTokens>() ?? UniverseTokens.dark;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

/// Thème sombre (défaut historique de UniVerse).
ThemeData buildUniverseTheme() => _buildTheme(UniverseTokens.dark, Brightness.dark);

/// Thème clair — fonds bleutés, rail légèrement bleu.
ThemeData buildUniverseLightTheme() =>
    _buildTheme(UniverseTokens.light, Brightness.light);

ThemeData _buildTheme(UniverseTokens t, Brightness brightness) {
  // Evite un ecran blanc si le CDN Google Fonts est lent / bloque.
  GoogleFonts.config.allowRuntimeFetching = true;

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: t.canvas,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: UniverseColors.blue,
      secondary: UniverseColors.violet,
      surface: t.surface,
      error: UniverseColors.danger,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: t.textPrimary,
      onError: Colors.white,
    ),
  );

  TextTheme textTheme;
  TextTheme primaryTextTheme;
  TextStyle? appBarTitle;
  try {
    textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: t.textPrimary,
      displayColor: t.textPrimary,
    );
    primaryTextTheme = GoogleFonts.outfitTextTheme(base.primaryTextTheme);
    appBarTitle = GoogleFonts.outfit(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: t.textPrimary,
    );
  } catch (_) {
    textTheme = base.textTheme.apply(
      bodyColor: t.textPrimary,
      displayColor: t.textPrimary,
    );
    primaryTextTheme = base.primaryTextTheme;
    appBarTitle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: t.textPrimary,
    );
  }

  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[t],
    textTheme: textTheme,
    primaryTextTheme: primaryTextTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: t.canvas,
      foregroundColor: t.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: appBarTitle,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: t.floatingBar,
      selectedItemColor: UniverseColors.blue,
      unselectedItemColor: t.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.surfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: t.textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: UniverseColors.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    cardTheme: CardThemeData(
      color: t.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerColor: t.border,
  );
}
