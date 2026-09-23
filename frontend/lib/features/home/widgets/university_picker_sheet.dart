import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../core/widgets/universe_ui.dart';
import '../../../shared/models/models.dart';
import '../followed_universites.dart';

/// Feuille ouverte par le bouton « + » du rail : choisir les universités
/// à garder sous la main.
///
/// Tous les espaces sont consultables (ET-9bis) — épingler ne donne aucun
/// droit supplémentaire, ça évite juste de fouiller à chaque fois.
Future<void> showUniversityPicker(
  BuildContext context, {
  required List<UniversiteItem> universites,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _UniversityPickerSheet(universites: universites),
  );
}

class _UniversityPickerSheet extends ConsumerStatefulWidget {
  const _UniversityPickerSheet({required this.universites});

  final List<UniversiteItem> universites;

  @override
  ConsumerState<_UniversityPickerSheet> createState() =>
      _UniversityPickerSheetState();
}

class _UniversityPickerSheetState
    extends ConsumerState<_UniversityPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final followed = ref.watch(followedUniversitesProvider);

    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? widget.universites
        : widget.universites
            .where((u) =>
                u.nom.toLowerCase().contains(q) ||
                (u.sigle ?? '').toLowerCase().contains(q))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr(context, 'Ajouter une université'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  tr(context,
                      'Les espaces épinglés apparaissent dans la barre de gauche. '
                      'Tu peux consulter toutes les universités, épinglées ou non.'),
                  style: TextStyle(fontSize: 13, color: t.textMuted),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: tr(context, 'Rechercher une université'),
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            q.isEmpty
                                ? tr(context, 'Aucune université disponible pour le moment.')
                                : '${tr(context, 'Aucun résultat pour')} « $_query ».',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: t.textMuted),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final u = results[i];
                          final isFollowed = followed.contains(u.id);
                          return ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isFollowed
                                    ? UniverseColors.brandGradient
                                    : null,
                                color:
                                    isFollowed ? null : t.surfaceElevated,
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: UniverseFitLabel(
                                  u.shortLabel,
                                  alignment: Alignment.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isFollowed
                                        ? Colors.white
                                        : t.textMuted,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(u.nom),
                            subtitle: u.sigle == null ? null : Text(u.sigle!),
                            trailing: TextButton(
                              onPressed: () => ref
                                  .read(followedUniversitesProvider.notifier)
                                  .toggle(u.id),
                              child: Text(
                                isFollowed ? tr(context, 'Retirer') : tr(context, 'Épingler'),
                                style: TextStyle(
                                  color: isFollowed
                                      ? t.textMuted
                                      : UniverseColors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
