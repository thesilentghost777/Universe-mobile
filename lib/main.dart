import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'app/theme_controller.dart';
import 'core/config.dart';
import 'core/i18n/locale_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Builder (pas de contexte direct dans FlutterErrorDetails) pour suivre le
  // thème ambiant au point de l'erreur, clair ou sombre — avant ce correctif
  // l'écran d'erreur restait toujours sombre même en thème clair.
  ErrorWidget.builder = (details) => Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Material(
            color: theme.scaffoldBackgroundColor,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erreur UI:\n${details.exceptionAsString()}',
                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      );
  runApp(const ProviderScope(child: UniverseApp()));
}

class UniverseApp extends ConsumerWidget {
  const UniverseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final mode = ref.watch(themeModeProvider);
    final taillePolice = ref.watch(taillePoliceProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildUniverseLightTheme(),
      darkTheme: buildUniverseTheme(),
      themeMode: mode,
      routerConfig: router,
      // Taille de texte choisie dans Paramètres > Apparence (§10,
      // accessibilité) — multiplie le textScaler ambiant du système plutôt
      // que de l'écraser, pour respecter aussi les réglages du téléphone.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final ambiant = mq.textScaler.scale(1.0);
        return LocaleScope(
          estAnglais: locale.languageCode == 'en',
          child: MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(ambiant * taillePolice.facteur),
            ),
            child: child!,
          ),
        );
      },
    );
  }
}
