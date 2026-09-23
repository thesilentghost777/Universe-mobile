import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../core/widgets/universe_skeleton.dart';
import '../../../core/widgets/universe_ui.dart';
import '../../../shared/models/models.dart';
import 'floating_nav_bar.dart';

/// Barre latérale gauche, façon Discord.
///
/// De haut en bas : les conversations, un séparateur, les universités
/// épinglées, un séparateur, le bouton d'ajout.
///
/// Les conversations sont placées **en haut** : c'est la convention Discord,
/// et ça garde le bouton d'ajout collé au bas de la liste qu'il alimente.
class UniversityRail extends StatelessWidget {
  const UniversityRail({
    super.key,
    required this.loading,
    required this.univs,
    required this.selectedId,
    required this.onSelect,
    required this.onAddUniversity,
    this.onOpenMessages,
    this.roleConsole,
    this.unreadMessages = 0,
    this.bottomInset,
  });

  final bool loading;
  final List<UniversiteItem> univs;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  /// Hauteur à réserver sous la liste pour la barre de navigation du bas —
  /// celle-ci diffère selon le rôle ([FloatingNavBar] ou
  /// `EnseignantNavBar`). `null` retombe sur [FloatingNavBar.reservedHeight].
  final double? bottomInset;

  /// `null` quand les conversations sont accessibles ailleurs (barre du bas) :
  /// le bouton du rail est alors masqué.
  final VoidCallback? onOpenMessages;
  final VoidCallback onAddUniversity;

  /// Raccourci vers la console du rôle, `null` pour un simple étudiant.
  final RailConsole? roleConsole;
  final int unreadMessages;

  static const double width = 76;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Container(
      width: width,
      color: t.rail,
      child: SafeArea(
        right: false,
        // La barre flottante du bas est peinte par-dessus ce rail (même
        // Stack) : sans cette marge, son bouton « + » se retrouvait caché
        // derrière elle.
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: bottomInset ?? FloatingNavBar.reservedHeight(context),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              if (onOpenMessages != null) ...[
                _RailButton(
                  tooltip: tr(context, 'Conversations'),
                  onTap: onOpenMessages!,
                  badge: unreadMessages,
                  // Carré arrondi plutôt que rond : distingue l'action des
                  // espaces universitaires, qui sont tous ronds.
                  borderRadius: 16,
                  child: Icon(
                    Icons.forum_rounded,
                    color: t.textPrimary.withValues(alpha: 0.9),
                  ),
                ),
                _RailDivider(color: t.railDivider),
              ],
              Expanded(
                child: loading
                    ? const RailSkeleton()
                    : univs.isEmpty
                        ? const SizedBox.shrink()
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: univs.length,
                            itemBuilder: (context, i) {
                              final u = univs[i];
                              return _UniversityDot(
                                universite: u,
                                selected: u.id == selectedId,
                                onTap: () => onSelect(u.id),
                              );
                            },
                          ),
              ),
              _RailDivider(color: t.railDivider),
              if (roleConsole != null) ...[
                _RailButton(
                  tooltip: roleConsole!.tooltip,
                  onTap: roleConsole!.onTap,
                  borderRadius: 16,
                  accent: roleConsole!.couleur,
                  child: Icon(roleConsole!.icone, color: roleConsole!.couleur),
                ),
                const SizedBox(height: 10),
              ],
              _RailButton(
                tooltip: tr(context, 'Ajouter une université'),
                onTap: onAddUniversity,
                borderRadius: 24,
                outlined: true,
                child:
                    const Icon(Icons.add_rounded, color: UniverseColors.blue),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Raccourci de rôle affiché en bas du rail (console modérateur, admin…).
class RailConsole {
  const RailConsole({
    required this.tooltip,
    required this.icone,
    required this.couleur,
    required this.onTap,
  });

  final String tooltip;
  final IconData icone;
  final Color couleur;
  final VoidCallback onTap;
}

class _RailDivider extends StatelessWidget {
  const _RailDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
    required this.borderRadius,
    this.outlined = false,
    this.badge = 0,
    this.accent,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;
  final double borderRadius;
  final bool outlined;
  final int badge;

  /// Teinte de fond optionnelle (utilisée par le raccourci de rôle).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: outlined
                      ? Colors.transparent
                      : (accent?.withValues(alpha: 0.18) ?? t.surfaceElevated),
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: outlined
                      ? Border.all(
                          color: UniverseColors.blue.withValues(alpha: 0.55),
                          width: 1.5,
                        )
                      : accent != null
                          ? Border.all(
                              color: accent!.withValues(alpha: 0.45),
                            )
                          : null,
                ),
                child: child,
              ),
              if (badge > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: UniverseColors.danger,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: t.rail, width: 2),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une université dans le rail, avec l'indicateur en pilule à gauche —
/// le repère visuel que les utilisateurs de Discord lisent sans réfléchir.
class _UniversityDot extends StatelessWidget {
  const _UniversityDot({
    required this.universite,
    required this.selected,
    required this.onTap,
  });

  final UniversiteItem universite;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Tooltip(
      message: universite.nom,
      child: Semantics(
        button: true,
        selected: selected,
        label: universite.nom,
        child: SizedBox(
          height: 60,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: 4,
                height: selected ? 30 : 0,
                decoration: BoxDecoration(
                  color: t.textPrimary,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(4),
                  ),
                ),
              ),
              Center(
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: selected ? UniverseColors.brandGradient : null,
                      color: selected ? null : t.surfaceElevated,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color:
                                    UniverseColors.blue.withValues(alpha: 0.45),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: UniverseFitLabel(
                        universite.shortLabel,
                        alignment: Alignment.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : t.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
