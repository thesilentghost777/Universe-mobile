import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_state.dart';

/// Lancement UniVerse — minimaliste (§8) : le logo affiché environ une
/// seconde, à la manière de ChatGPT ou Grok, puis transition immédiate.
///
/// L'écran se ferme dès que l'animation est finie *et* que la session est
/// résolue — le chargement réseau se fait donc pendant la seconde
/// d'animation, sans ajouter d'attente. Un appui n'importe où la passe.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _tryLeave();
      });
    _c.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Accessibilité : animations désactivées sur l'appareil -> logo fixe.
    if (MediaQuery.disableAnimationsOf(context) && _c.value < 1.0) {
      _c.value = 1.0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryLeave());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _skip() {
    if (_c.isAnimating) _c.value = 1.0;
    _tryLeave();
  }

  /// Quitte le lancement une fois la session connue.
  void _tryLeave() {
    if (_left || !mounted) return;
    if (_c.value < 1.0) return;

    final auth = ref.read(authNotifierProvider);
    if (auth.status == AuthStatus.unknown) return; // on attend /auth/me

    _left = true;
    final user = auth.user;
    final target = switch (auth.status) {
      AuthStatus.authenticated =>
        (user?.needsOnboarding ?? false) ? '/onboarding' : '/app',
      _ => '/login',
    };
    context.go(target);
  }

  @override
  Widget build(BuildContext context) {
    // Dès que le bootstrap répond, on retente la sortie.
    ref.listen(authNotifierProvider, (_, __) => _tryLeave());

    return Scaffold(
      backgroundColor: const Color(0xFF040814),
      body: GestureDetector(
        onTap: _skip,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final t = Curves.easeOut.transform(_c.value);
              return Opacity(
                opacity: t,
                child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/branding/universe_emblem.png',
                  width: 84,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    width: 84,
                    height: 84,
                  ),
                ),
                const SizedBox(height: 14),
                ShaderMask(
                  shaderCallback: (rect) =>
                      UniverseColors.brandGradient.createShader(rect),
                  child: const Text(
                    'UniVerse',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
