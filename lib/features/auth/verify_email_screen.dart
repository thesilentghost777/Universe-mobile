import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_state.dart';
import '../../core/i18n/locale_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Confirmation d'adresse email — saisie du jeton reçu, ou renvoi du mail.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.initialToken});

  final String? initialToken;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  late final TextEditingController _token;
  final _email = TextEditingController();
  bool _loading = false;
  bool _ok = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _token = TextEditingController(text: widget.initialToken ?? '');
  }

  @override
  void dispose() {
    _token.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .verifyEmail(_token.text.trim());
      setState(() {
        _ok = true;
        _message = tr(context, 'Email vérifié — tu peux te connecter.');
      });
    } catch (_) {
      setState(() {
        _ok = false;
        _message = tr(context, 'Jeton invalide ou expiré.');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_email.text.trim().isEmpty) return;
    await ref
        .read(authNotifierProvider.notifier)
        .resendVerification(_email.text.trim());
    if (!mounted) return;
    setState(() {
      _ok = true;
      _message = tr(context, 'Si le compte existe, un email a été renvoyé.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: tr(context, 'Vérifier mon email'),
      subtitle: tr(context, 'Colle le jeton reçu par email, ou demande un nouvel envoi.'),
      onBack: () => context.canPop() ? context.pop() : context.go('/login'),
      footer: TextButton(
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/login'),
        child: Text(tr(context, 'Aller à la connexion')),
      ),
      children: [
        AuthField(
          controller: _token,
          label: tr(context, 'Jeton de vérification'),
          hint: tr(context, 'Collé automatiquement si tu viens de t\'inscrire'),
          icon: Icons.vpn_key_outlined,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        AuthPrimaryButton(
          label: tr(context, 'Valider'),
          icon: Icons.check_rounded,
          loading: _loading,
          onPressed: _token.text.trim().isEmpty ? null : _verify,
        ),
        const SizedBox(height: 24),
        Text(
          tr(context, 'Renvoyer le mail de vérification'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        AuthField(
          controller: _email,
          hint: 'ton.email@exemple.cm',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _email.text.trim().isEmpty ? null : _resend,
            child: Text(tr(context, 'Renvoyer')),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          _ok
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Color(0xFF22C55E), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _message!,
                          style: const TextStyle(
                            color: Color(0xFFB6F0C6),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : AuthErrorBanner(_message!),
        ],
      ],
    );
  }
}
