import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universe_frontend/app/theme.dart';
import 'package:universe_frontend/app/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeModeController & Theme Tokens', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Default theme mode follows the system', () {
      final controller = ThemeModeController();
      expect(controller.build(), ThemeMode.system);
    });

    test('Encoding and decoding of ThemeMode values', () {
      expect(ThemeModeController.encode(ThemeMode.light), 'light');
      expect(ThemeModeController.encode(ThemeMode.dark), 'dark');
      expect(ThemeModeController.encode(ThemeMode.system), 'system');

      expect(ThemeModeController.decode('light'), ThemeMode.light);
      expect(ThemeModeController.decode('dark'), ThemeMode.dark);
      expect(ThemeModeController.decode('system'), ThemeMode.system);
      expect(ThemeModeController.decode('unknown'), ThemeMode.system);
    });

    test('Theme mode labels are clear in French', () {
      expect(themeModeLabel(ThemeMode.light), 'Clair');
      expect(themeModeLabel(ThemeMode.dark), 'Sombre');
      expect(themeModeLabel(ThemeMode.system), 'Système');
    });

    test('UniverseTheme light & dark configurations maintain contrast and palette', () {
      final darkTheme = buildUniverseTheme();
      final lightTheme = buildUniverseLightTheme();

      expect(darkTheme.brightness, Brightness.dark);
      expect(lightTheme.brightness, Brightness.light);

      expect(darkTheme.scaffoldBackgroundColor, isNotNull);
      expect(lightTheme.scaffoldBackgroundColor, isNotNull);

      // Le clair doit rester lisible : texte foncé sur fond clair.
      expect(
        ThemeData.estimateBrightnessForColor(UniverseTokens.light.canvas),
        Brightness.light,
      );
      expect(
        ThemeData.estimateBrightnessForColor(UniverseTokens.light.textPrimary),
        Brightness.dark,
      );
      expect(
        ThemeData.estimateBrightnessForColor(UniverseTokens.dark.canvas),
        Brightness.dark,
      );
      expect(
        ThemeData.estimateBrightnessForColor(UniverseTokens.dark.textPrimary),
        Brightness.light,
      );

      // Verify brand primary colors
      expect(UniverseColors.blue, const Color(0xFF2563EB));
      expect(UniverseColors.navy, const Color(0xFF0B1220));
      expect(UniverseColors.success, const Color(0xFF22C55E));
      expect(UniverseColors.danger, const Color(0xFFEF4444));
    });
  });
}
