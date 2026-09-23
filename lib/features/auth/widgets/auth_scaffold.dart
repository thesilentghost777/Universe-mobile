import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../core/i18n/locale_controller.dart';
import '../../../core/widgets/universe_ui.dart';

/// Charpente commune à tous les écrans d'authentification.
///
/// Direction visuelle « audacieuse » : une photo de campus plein cadre, un
/// voile dégradé qui ramène la scène au navy de la marque, puis une carte en
/// verre dépoli qui porte le contenu. Chaque écran d'auth passe par ici, ce
/// qui garantit un titre lisible, un bouton retour au même endroit et des
/// marges identiques partout.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.onBack,
    this.footer,
    this.progress,
    this.scrollable = true,
    this.heroTag = 'universe-auth-emblem',
  });

  /// Grand titre affiché en tête de carte, en dégradé de marque.
  final String title;

  /// Ligne d'explication sous le titre.
  final String? subtitle;

  /// Corps de la carte.
  final List<Widget> children;

  /// Action du bouton retour. `null` masque le bouton (écran racine).
  final VoidCallback? onBack;

  /// Bloc collé en bas de l'écran, hors carte (liens secondaires).
  final Widget? footer;

  /// Avancement 0→1 d'un parcours multi-étapes ; `null` = pas de barre.
  final double? progress;

  /// Quand `false`, le contenu ne défile pas (utile si un champ gère lui-même
  /// son défilement, ex. écran OTP).
  final bool scrollable;

  final String heroTag;

  static const _photo = 'assets/branding/campus/uy1.jpg';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final card = _GlassCard(
      title: title,
      subtitle: subtitle,
      heroTag: heroTag,
      children: children,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF040814),
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1 — Photo de campus, légèrement zoomée pour éviter les bords.
          Transform.scale(
            scale: 1.08,
            child: Image.asset(
              _photo,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const _AnimatedFallback(),
            ),
          ),
          // 2 — Voile dégradé : lisible en haut, dense en bas.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC040814),
                  Color(0xE6060B18),
                  Color(0xFF04070F),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          // Halo de marque derrière la carte.
          Positioned(
            top: media.size.height * 0.06,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      UniverseColors.blue.withValues(alpha: 0.30),
                      UniverseColors.violet.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 3 — Contenu.
          SafeArea(
            child: Column(
              children: [
                _TopBar(onBack: onBack, progress: progress),
                Expanded(
                  child: scrollable
                      ? SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            8,
                            20,
                            24 + media.viewInsets.bottom * 0,
                          ),
                          child: card,
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                          child: card,
                        ),
                ),
                if (footer != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      4,
                      20,
                      12 + media.padding.bottom * 0,
                    ),
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(color: Colors.white),
                      child: footer!,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.onBack, this.progress});

  final VoidCallback? onBack;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          if (onBack != null)
            _CircleButton(
              icon: Icons.arrow_back_rounded,
              onTap: onBack!,
              tooltip: tr(context, 'Retour'),
            )
          else
            const SizedBox(width: 40),
          const Spacer(),
          if (progress != null)
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  valueColor: const AlwaysStoppedAnimation(UniverseColors.blue),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.white.withValues(alpha: 0.10),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.title,
    required this.subtitle,
    required this.heroTag,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final String heroTag;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: const Color(0xFF0B1220).withValues(alpha: 0.72),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Hero(
                    tag: heroTag,
                    child: Image.asset(
                      'assets/branding/universe_emblem.png',
                      height: 40,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 40,
                        width: 40,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'UniVerse',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AuthGradientTitle(title),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.68),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Grand titre en dégradé bleu→violet, comme le « V » du logo.
class AuthGradientTitle extends StatelessWidget {
  const AuthGradientTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFFEAF0FF), Color(0xFF9FC0FF), Color(0xFFC9A7FF)],
      ).createShader(rect),
      child: UniverseFitLabel(
        text,
        style: const TextStyle(
          fontSize: 30,
          height: 1.1,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

/// Bandeau d'erreur cohérent, réutilisé sur tous les écrans d'auth.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: UniverseColors.danger.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: UniverseColors.danger.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: UniverseColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFFB4B4),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Champ de saisie stylé pour fond sombre en verre dépoli.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    this.label,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.suffix,
    this.enabled = true,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final String? label;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          inputFormatters: inputFormatters,
          enabled: enabled,
          autofocus: autofocus,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          cursorColor: UniverseColors.blue,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
            prefixIcon: icon == null
                ? null
                : Icon(icon,
                    color: Colors.white.withValues(alpha: 0.45), size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: UniverseColors.blue, width: 1.6),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bouton principal plein largeur, dégradé de marque, avec état de chargement.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: UniverseColors.brandGradient,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: UniverseColors.violet.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 52,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: UniverseIconLabel(
                          icon: icon,
                          label: label,
                          iconSize: 19,
                          gap: 8,
                          iconColor: Colors.white,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le « G » Google — une vraie lettre (rendue par la police), coloriée avec
/// un dégradé aux couleurs de marque. Un dessin main levée (arcs + barre)
/// s'est révélé peu fiable à corriger sans pouvoir revérifier le rendu à
/// l'écran (deux essais ratés) ; du texte ne peut, par construction, pas se
/// retrouver « à l'envers ».
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const SweepGradient(
        colors: [
          Color(0xFF4285F4), // bleu
          Color(0xFF34A853), // vert
          Color(0xFFFBBC05), // jaune
          Color(0xFFEA4335), // rouge
          Color(0xFF4285F4),
        ],
      ).createShader(rect),
      child: Text(
        'G',
        style: TextStyle(
          fontSize: size,
          height: 1,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Fond de secours animé si la photo de campus est absente.
class _AnimatedFallback extends StatefulWidget {
  const _AnimatedFallback();

  @override
  State<_AnimatedFallback> createState() => _AnimatedFallbackState();
}

class _AnimatedFallbackState extends State<_AnimatedFallback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 20))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final a = _c.value * 2 * math.pi;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.5 * math.cos(a), -0.3 + 0.4 * math.sin(a)),
              radius: 1.2,
              colors: const [Color(0xFF16255A), Color(0xFF04070F)],
            ),
          ),
        );
      },
    );
  }
}
