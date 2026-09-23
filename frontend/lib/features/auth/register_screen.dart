import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/widgets/universe_ui.dart';
import 'auth_choice_screen.dart' show Indicatif;
import 'complete_profile_screen.dart';
import 'google_auth.dart';
import 'widgets/auth_scaffold.dart';

/// Inscription — première étape : par quel canal on va te joindre (§2.2).
///
/// Le rôle et les champs qui en dépendent (§3) sont demandés tout de suite
/// après — la vérification du canal (OTP) est repoussée à la toute
/// dernière étape, juste avant la connexion, pour ne pas interrompre la
/// saisie du profil : ordre exact — méthode → complétion du profil → OTP →
/// connexion.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _telephone = TextEditingController();
  final _email = TextEditingController();
  Indicatif _indicatif = Indicatif.tous.first;
  bool _parTelephone = true;
  bool _envoi = false;
  String? _erreur;

  @override
  void dispose() {
    _telephone.dispose();
    _email.dispose();
    super.dispose();
  }

  String get _destination => _parTelephone
      ? '${_indicatif.code}${_telephone.text.replaceAll(RegExp(r'\D'), '')}'
      : _email.text.trim();

  bool get _valide {
    if (_parTelephone) {
      final chiffres = _telephone.text.replaceAll(RegExp(r'\D'), '');
      return chiffres.length >= _indicatif.longueur - 1 &&
          chiffres.length <= _indicatif.longueur + 1;
    }
    final e = _email.text.trim();
    return e.contains('@') && e.contains('.') && e.length > 5;
  }

  void _continuer() {
    final canal = _parTelephone ? 'sms' : 'email';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompleteProfileScreen(
          methode: canal,
          destination: _destination,
        ),
      ),
    );
  }

  Future<void> _google() async {
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      final idToken = await GoogleAuth.connecter();
      if (idToken == null) {
        if (mounted) setState(() => _envoi = false);
        return; // Annulé.
      }
      if (!mounted) return;
      setState(() => _envoi = false);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CompleteProfileScreen(
            methode: 'google',
            destination: '',
            idTokenGoogle: idToken,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = GoogleAuth.estNonConfigure(e)
            ? tr(context, 'Inscription Google pas encore configurée sur cette version.')
            : tr(context, 'Inscription Google impossible. Réessaie.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: tr(context, 'Créer un compte'),
      subtitle: tr(context, 'Choisis comment tu veux t\'inscrire. Le rôle et le reste de '
          'ton profil se règlent juste après.'),
      onBack: () => context.canPop() ? context.pop() : context.go('/login'),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            tr(context, 'Déjà un compte ?'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
          TextButton(
            onPressed: () => context.go('/login'),
            child: Text(tr(context, 'Se connecter')),
          ),
        ],
      ),
      children: [
        _GoogleButton(onPressed: _envoi ? null : _google),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: _hair()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(tr(context, 'ou'),
                  style: TextStyle(
                      fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
            ),
            Expanded(child: _hair()),
          ],
        ),
        const SizedBox(height: 18),
        _Segment(
          parTelephone: _parTelephone,
          onChange: (v) => setState(() {
            _parTelephone = v;
            _erreur = null;
          }),
        ),
        const SizedBox(height: 16),
        if (_parTelephone)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SelecteurIndicatif(
                valeur: _indicatif,
                onChange: (v) => setState(() => _indicatif = v),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AuthField(
                  controller: _telephone,
                  hint: '6 90 00 00 00',
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          )
        else
          AuthField(
            controller: _email,
            hint: 'ton.email@exemple.cm',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => setState(() {}),
          ),
        const SizedBox(height: 10),
        Text(
          _parTelephone
              ? tr(context, 'Tu recevras un code à 6 chiffres sur WhatsApp.')
              : tr(context, 'Tu recevras un email de confirmation après l\'inscription.'),
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
        ),
        if (_erreur != null) ...[
          const SizedBox(height: 14),
          AuthErrorBanner(_erreur!),
        ],
        const SizedBox(height: 22),
        AuthPrimaryButton(
          label: tr(context, 'Continuer'),
          icon: Icons.arrow_forward_rounded,
          loading: _envoi,
          onPressed: _valide ? _continuer : null,
        ),
      ],
    );
  }

  Widget _hair() => Container(height: 1, color: Colors.white.withValues(alpha: 0.12));
}

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
          _seg(tr(context, 'Téléphone'), Icons.smartphone_rounded, parTelephone, () => onChange(true)),
          _seg(tr(context, 'Email'), Icons.alternate_email_rounded, !parTelephone, () => onChange(false)),
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
            iconColor: actif ? Colors.white : Colors.white.withValues(alpha: 0.5),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: actif ? Colors.white : Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const GoogleLogo(),
                  const SizedBox(width: 10),
                  Flexible(
                    child: UniverseFitLabel(
                      tr(context, 'S\'inscrire avec Google'),
                      alignment: Alignment.center,
                      style: const TextStyle(
                        color: Color(0xFF1F2430),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelecteurIndicatif extends StatelessWidget {
  const _SelecteurIndicatif({required this.valeur, required this.onChange});

  final Indicatif valeur;
  final ValueChanged<Indicatif> onChange;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final choix = await showModalBottomSheet<Indicatif>(
          context: context,
          backgroundColor: const Color(0xFF0B1220),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final i in Indicatif.tous)
                  ListTile(
                    leading: Text(i.drapeau, style: const TextStyle(fontSize: 22)),
                    title: Text(i.pays, style: const TextStyle(color: Colors.white)),
                    trailing: Text(i.code, style: const TextStyle(color: Colors.white54)),
                    selected: i.code == valeur.code,
                    onTap: () => Navigator.pop(ctx, i),
                  ),
              ],
            ),
          ),
        );
        if (choix != null) onChange(choix);
      },
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Text(valeur.drapeau, style: const TextStyle(fontSize: 19)),
            const SizedBox(width: 6),
            Text(valeur.code, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
            Icon(Icons.arrow_drop_down, size: 20, color: Colors.white.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

