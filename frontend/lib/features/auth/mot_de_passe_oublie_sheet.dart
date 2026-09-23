import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/widgets/universe_ui.dart';
import 'widgets/auth_scaffold.dart';

/// Mot de passe oublié (§2.1).
///
/// 1. `POST /auth/mot-de-passe-oublie` `{ email | telephone }` → même
///    réponse que le compte existe ou non, envoie un OTP.
/// 2. `POST /auth/mot-de-passe-oublie/verifier` `{ email|telephone, code }`
///    → `{ resetToken }` (400 si code invalide).
/// 3. `POST /auth/reinitialiser-mot-de-passe` `{ resetToken, nouveauMotDePasse }`
///    → révoque toutes les sessions.
Future<void> ouvrirMotDePasseOublie(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0B1220),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _MotDePasseOublieSheet(),
  );
}

enum _Etape { identifiant, codeEtMotDePasse, termine }

class _MotDePasseOublieSheet extends ConsumerStatefulWidget {
  const _MotDePasseOublieSheet();

  @override
  ConsumerState<_MotDePasseOublieSheet> createState() => _MotDePasseOublieSheetState();
}

class _MotDePasseOublieSheetState extends ConsumerState<_MotDePasseOublieSheet> {
  _Etape _etape = _Etape.identifiant;

  final _identifiant = TextEditingController();
  bool _parTelephone = true;

  final _code = TextEditingController();
  final _motDePasse = TextEditingController();
  final _motDePasseConfirm = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;

  bool _envoi = false;
  String? _erreur;

  @override
  void dispose() {
    _identifiant.dispose();
    _code.dispose();
    _motDePasse.dispose();
    _motDePasseConfirm.dispose();
    super.dispose();
  }

  Map<String, dynamic> _identifiantPayload() => _parTelephone
      ? {
          'telephone': _identifiant.text.trim().startsWith('+')
              ? _identifiant.text.trim()
              : '+${_identifiant.text.trim()}',
        }
      : {'email': _identifiant.text.trim()};

  Future<void> _envoyer() async {
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      await ref.read(apiClientProvider).post(
        '/auth/mot-de-passe-oublie',
        data: _identifiantPayload(),
      );
    } catch (_) {
      // Le contrat impose une réponse 204 quoi qu'il arrive côté back — on
      // ne révèle jamais si l'échec vient d'un compte inexistant.
    }
    if (!mounted) return;
    setState(() {
      _envoi = false;
      _etape = _Etape.codeEtMotDePasse;
    });
  }

  static bool _motDePasseFort(String v) =>
      v.length >= 12 &&
      RegExp(r'[A-Z]').hasMatch(v) &&
      RegExp(r'[a-z]').hasMatch(v) &&
      RegExp(r'[0-9]').hasMatch(v) &&
      RegExp(r'[^A-Za-z0-9]').hasMatch(v);

  bool get _motDePasseValide =>
      _motDePasseFort(_motDePasse.text) && _motDePasse.text == _motDePasseConfirm.text;

  bool get _formulaireValide => _code.text.trim().length == 6 && _motDePasseValide;

  Future<void> _reinitialiser() async {
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final verif = await api.post(
        '/auth/mot-de-passe-oublie/verifier',
        data: {
          ..._identifiantPayload(),
          'code': _code.text.trim(),
        },
      );
      final resetToken = (verif.data as Map)['resetToken'] as String;
      await api.post(
        '/auth/reinitialiser-mot-de-passe',
        data: {
          'resetToken': resetToken,
          'nouveauMotDePasse': _motDePasse.text,
        },
      );
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _etape = _Etape.termine;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = e.response?.statusCode == 400
            ? tr(context, 'Code incorrect ou expiré.')
            : tr(context, 'Réinitialisation impossible. Réessaie.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = tr(context, 'Réinitialisation impossible. Réessaie.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final clavier = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: clavier),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              switch (_etape) {
                _Etape.identifiant => _etapeIdentifiant(),
                _Etape.codeEtMotDePasse => _etapeCodeEtMotDePasse(),
                _Etape.termine => _etapeTermine(),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _etapeIdentifiant() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tr(context, 'Mot de passe oublié'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19),
        ),
        const SizedBox(height: 8),
        Text(
          tr(context, 'Choisis le canal de ton compte : on t\'envoie un code de '
              'vérification (OTP) pour confirmer que c\'est bien toi, '
              'avant de choisir un nouveau mot de passe.'),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13.5, height: 1.4),
        ),
        const SizedBox(height: 18),
        _Segment(
          parTelephone: _parTelephone,
          onChange: (v) => setState(() {
            _parTelephone = v;
            _identifiant.clear();
          }),
        ),
        const SizedBox(height: 14),
        AuthField(
          key: ValueKey(_parTelephone),
          controller: _identifiant,
          hint: _parTelephone ? tr(context, 'Numéro de téléphone') : tr(context, 'Adresse email'),
          icon: _parTelephone ? Icons.smartphone_rounded : Icons.alternate_email_rounded,
          keyboardType: _parTelephone ? TextInputType.phone : TextInputType.emailAddress,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        AuthPrimaryButton(
          label: tr(context, 'Envoyer le code'),
          icon: Icons.send_rounded,
          loading: _envoi,
          onPressed: _identifiant.text.trim().isEmpty ? null : _envoyer,
        ),
      ],
    );
  }

  Widget _etapeCodeEtMotDePasse() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tr(context, 'Nouveau mot de passe'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19),
        ),
        const SizedBox(height: 8),
        Text(
          '${tr(context, 'Si un compte existe pour')} « ${_identifiant.text.trim()} », '
          '${tr(context, _parTelephone
              ? 'un code de vérification à 6 chiffres vient d\'être envoyé par SMS.'
              : 'un code de vérification à 6 chiffres vient d\'être envoyé par email.')}',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13.5, height: 1.4),
        ),
        const SizedBox(height: 18),
        AuthField(
          controller: _code,
          hint: tr(context, 'Code à 6 chiffres'),
          icon: Icons.pin_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        AuthField(
          controller: _motDePasse,
          hint: tr(context, 'Nouveau mot de passe'),
          icon: Icons.lock_outline_rounded,
          obscure: _obscure1,
          onChanged: (_) => setState(() {}),
          suffix: IconButton(
            icon: Icon(
              _obscure1 ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: Colors.white.withValues(alpha: 0.45),
              size: 20,
            ),
            onPressed: () => setState(() => _obscure1 = !_obscure1),
          ),
        ),
        const SizedBox(height: 14),
        AuthField(
          controller: _motDePasseConfirm,
          hint: tr(context, 'Confirme le mot de passe'),
          icon: Icons.lock_outline_rounded,
          obscure: _obscure2,
          onChanged: (_) => setState(() {}),
          suffix: IconButton(
            icon: Icon(
              _obscure2 ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: Colors.white.withValues(alpha: 0.45),
              size: 20,
            ),
            onPressed: () => setState(() => _obscure2 = !_obscure2),
          ),
        ),
        if (_erreur != null) ...[
          const SizedBox(height: 12),
          AuthErrorBanner(_erreur!),
        ],
        const SizedBox(height: 20),
        AuthPrimaryButton(
          label: tr(context, 'Réinitialiser le mot de passe'),
          icon: Icons.check_rounded,
          loading: _envoi,
          onPressed: _formulaireValide ? _reinitialiser : null,
        ),
      ],
    );
  }

  Widget _etapeTermine() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: UniverseColors.brandGradient,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr(context, 'Mot de passe changé'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          tr(context, 'Connecte-toi avec ton nouveau mot de passe.'),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 20),
        AuthPrimaryButton(
          label: tr(context, 'Fermer'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Bascule Téléphone / Email — même langage visuel que l'écran de connexion,
/// pour que le choix du canal reste cohérent dans toute l'app.
class _Segment extends StatelessWidget {
  const _Segment({required this.parTelephone, required this.onChange});

  final bool parTelephone;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          _seg(tr(context, 'Téléphone'), Icons.smartphone_rounded, parTelephone,
              () => onChange(true)),
          _seg(tr(context, 'Email'), Icons.alternate_email_rounded, !parTelephone,
              () => onChange(false)),
        ],
      ),
    );
  }

  Widget _seg(String label, IconData icon, bool actif, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            gradient: actif ? UniverseColors.brandGradient : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: UniverseIconLabel(
            icon: icon,
            label: label,
            iconSize: 16,
            iconColor: actif
                ? Colors.white
                : Colors.white.withValues(alpha: 0.5),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: actif
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
