import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme_controller.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/widgets/universe_ui.dart';
import 'settings_widgets.dart';

/// Apparence — thème et taille de texte (§10, accessibilité).
class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final taille = ref.watch(taillePoliceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Apparence'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SettingsSection(
            titre: tr(context, 'Thème'),
            enfants: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: UniverseSegmentedRow(
                  labels: [
                    tr(context, 'Clair'),
                    tr(context, 'Sombre'),
                    tr(context, 'Système'),
                  ],
                  icons: const [
                    Icons.light_mode_outlined,
                    Icons.dark_mode_outlined,
                    Icons.smartphone_outlined,
                  ],
                  selectedIndex: switch (mode) {
                    ThemeMode.light => 0,
                    ThemeMode.dark => 1,
                    ThemeMode.system => 2,
                  },
                  onSelect: (i) {
                    final suivant = switch (i) {
                      0 => ThemeMode.light,
                      1 => ThemeMode.dark,
                      _ => ThemeMode.system,
                    };
                    ref.read(themeModeProvider.notifier).set(suivant);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSection(
            titre: tr(context, 'Taille du texte'),
            enfants: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UniverseSegmentedRow(
                      labels: [
                        tr(context, 'Standard'),
                        tr(context, 'Grande'),
                        tr(context, 'Très grande'),
                      ],
                      selectedIndex: switch (taille) {
                        TaillePolice.standard => 0,
                        TaillePolice.grande => 1,
                        TaillePolice.tresGrande => 2,
                      },
                      onSelect: (i) {
                        final suivant = switch (i) {
                          0 => TaillePolice.standard,
                          1 => TaillePolice.grande,
                          _ => TaillePolice.tresGrande,
                        };
                        ref.read(taillePoliceProvider.notifier).set(suivant);
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      tr(context, 'Aperçu : à quoi ressemblera le texte dans l\'app.'),
                      style: TextStyle(
                        fontSize: 14 * taille.facteur,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
