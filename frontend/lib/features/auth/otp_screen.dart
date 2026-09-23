import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/locale_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Saisie du code à 6 chiffres reçu par SMS ou par email.
///
/// Un champ unique invisible reçoit la frappe et le collage, ce qui permet à
/// Android de remplir automatiquement le code depuis le SMS ; six cases
/// affichées reflètent l'état.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    super.key,
    required this.canal,
    required this.destination,
    this.nom,
    this.prenom,
    this.expiresIn = 300,
    this.onValider,
    this.onRenvoyer,
    this.onSucces,
  });

  /// `sms` ou `email`.
  final String canal;

  /// Numéro au format international, ou adresse email.
  final String destination;

  final String? nom;
  final String? prenom;
  final int expiresIn;

  /// Personnalise la vérification (par défaut : connexion via
  /// `AuthNotifier.verifierCode`). L'inscription y branche sa propre
  /// validation pour joindre les champs d'identité au `otp/verify`.
  final Future<void> Function(String code)? onValider;

  /// Personnalise le renvoi de code (par défaut : `AuthNotifier.demanderCode`).
  final Future<int> Function()? onRenvoyer;

  /// Appelé après une vérification réussie (par défaut : `context.go('/app')`).
  final VoidCallback? onSucces;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _longueur = 6;

  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _minuteur;
  int _restant = 0;
  bool _envoi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _demarrerCompteARebours(widget.expiresIn);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _demarrerCompteARebours(int secondes) {
    _minuteur?.cancel();
    setState(() => _restant = secondes);
    _minuteur = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _restant--);
      if (_restant <= 0) t.cancel();
    });
  }

  Future<void> _valider() async {
    if (_code.text.length != _longueur) return;
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      if (widget.onValider != null) {
        await widget.onValider!(_code.text);
      } else {
        await ref.read(authNotifierProvider.notifier).verifierCode(
              destination: widget.destination,
              code: _code.text,
              nom: widget.nom,
              prenom: widget.prenom,
            );
      }
      if (!mounted) return;
      if (widget.onSucces != null) {
        widget.onSucces!();
      } else {
        context.go('/app');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erreur = tr(context, 'Code incorrect ou expiré.');
        _envoi = false;
        _code.clear();
      });
    }
  }

  Future<void> _renvoyer() async {
    setState(() => _erreur = null);
    try {
      final delai = widget.onRenvoyer != null
          ? await widget.onRenvoyer!()
          : await ref.read(authNotifierProvider.notifier).demanderCode(
                destination: widget.destination,
              );
      _demarrerCompteARebours(delai);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'Nouveau code envoyé.'))),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _erreur = tr(context, 'Envoi impossible, réessaie.'));
      }
    }
  }

  String get _minuterie {
    final m = (_restant ~/ 60).toString().padLeft(2, '0');
    final s = (_restant % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final parSms = widget.canal == 'sms';

    return AuthScaffold(
      title: tr(context, 'Vérification'),
      subtitle: parSms
          ? '${tr(context, 'Code envoyé par SMS au')} ${widget.destination}.'
          : '${tr(context, 'Code envoyé à')} ${widget.destination}.',
      onBack: () => context.canPop() ? context.pop() : context.go('/login'),
      children: [
        // Champ réel invisible : frappe, collage, autofill SMS.
        SizedBox(
          height: 0,
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: _code,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: _longueur,
              decoration: const InputDecoration(counterText: ''),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_longueur),
              ],
              onChanged: (v) {
                setState(() => _erreur = null);
                if (v.length == _longueur) _valider();
              },
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _focus.requestFocus(),
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_longueur, (i) {
              final rempli = i < _code.text.length;
              final actif = i == _code.text.length && _focus.hasFocus;
              return Container(
                width: 44,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _erreur != null
                        ? UniverseColors.danger
                        : (actif || rempli)
                            ? UniverseColors.blue
                            : Colors.white.withValues(alpha: 0.14),
                    width: actif ? 1.8 : 1.2,
                  ),
                ),
                child: Text(
                  rempli ? _code.text[i] : '',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              );
            }),
          ),
        ),
        if (_erreur != null) ...[
          const SizedBox(height: 16),
          AuthErrorBanner(_erreur!),
        ],
        const SizedBox(height: 22),
        AuthPrimaryButton(
          label: tr(context, 'Vérifier'),
          icon: Icons.check_rounded,
          loading: _envoi,
          onPressed: _code.text.length == _longueur ? _valider : null,
        ),
        const SizedBox(height: 16),
        Center(
          child: _restant > 0
              ? Text(
                  '${tr(context, 'Nouveau code possible dans')} $_minuterie',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                )
              : TextButton(
                  onPressed: _renvoyer,
                  child: Text(tr(context, 'Renvoyer le code')),
                ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            parSms
                ? tr(context, 'Le SMS peut mettre jusqu\'à une minute à arriver.')
                : tr(context, 'Pense à vérifier tes courriers indésirables.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.42),
            ),
          ),
        ),
      ],
    );
  }
}
