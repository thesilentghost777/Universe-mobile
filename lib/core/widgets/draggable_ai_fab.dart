import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';
import '../../features/ai/ai_sheet.dart';

/// Bouton IA déplaçable, visible sur tout l'écran authentifié (y compris DM).
class DraggableAiFab extends ConsumerStatefulWidget {
  const DraggableAiFab({super.key, this.bottomInset = 0});

  /// Hauteur de zone à ne jamais recouvrir en bas de l'écran (barre de
  /// navigation, barre de saisie d'une conversation…). La position est
  /// persistée globalement (un seul bouton pour toute l'app) : sans cette
  /// marge, une position mémorisée sur un écran à faible zone réservée
  /// pouvait retomber exactement sur le bouton d'envoi d'un autre écran.
  final double bottomInset;

  /// Marge laissée aux listes pour que le dernier élément puisse défiler
  /// au-dessus du bouton (il reste flottant, donc il couvre le coin).
  static const double degagement = 80;

  @override
  ConsumerState<DraggableAiFab> createState() => _DraggableAiFabState();
}

class _DraggableAiFabState extends ConsumerState<DraggableAiFab> {
  Offset? _offset;

  /// v2 : une position mémorisée trop haute recouvrait les cartes. On
  /// ignore l'ancienne coordonnée et on repart du coin bas droit.
  static const _keyX = 'ai_fab_x_v2';
  static const _keyY = 'ai_fab_y_v2';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_keyX);
    final y = prefs.getDouble(_keyY);
    if (x != null && y != null && mounted) {
      setState(() => _offset = Offset(x, y));
    }
  }

  Future<void> _save(Offset o) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyX, o.dx);
    await prefs.setDouble(_keyY, o.dy);
  }

  void _openAi() {
    // Plein écran (§ retour utilisateur) : une fois dedans, c'est une vraie
    // conversation, pas un aperçu partiel.
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: const AiChatSheet(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final fabSize = 56.0;
    final basInterdit = pad.bottom + widget.bottomInset + 12;
    final maxTop = size.height - fabSize - basInterdit;
    final defaultOffset = Offset(
      size.width - fabSize - 16,
      maxTop,
    );
    final pos = _offset ?? defaultOffset;

    return Positioned(
      left: pos.dx.clamp(8.0, size.width - fabSize - 8),
      top: pos.dy.clamp(pad.top + 8, maxTop),
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            _offset = Offset(
              (pos.dx + d.delta.dx).clamp(8.0, size.width - fabSize - 8),
              (pos.dy + d.delta.dy).clamp(pad.top + 8, maxTop),
            );
          });
        },
        onPanEnd: (_) {
          if (_offset != null) _save(_offset!);
        },
        onTap: _openAi,
        child: Container(
          width: fabSize,
          height: fabSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: UniverseColors.brandGradient,
            boxShadow: [
              BoxShadow(
                color: UniverseColors.violet.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white),
        ),
      ),
    );
  }
}
