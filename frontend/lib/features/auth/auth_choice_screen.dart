import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/widgets/universe_ui.dart';
import 'demo_mode_sheet.dart';
import 'google_auth.dart';
import 'mot_de_passe_oublie_sheet.dart';
import 'otp_screen.dart';
import 'widgets/auth_scaffold.dart';

/// Indicatifs proposés, Cameroun en tête (université pilote : UY1).
class Indicatif {
  const Indicatif(this.drapeau, this.pays, this.code, this.longueur);

  final String drapeau;
  final String pays;
  final String code;

  /// Nombre de chiffres attendus après l'indicatif.
  final int longueur;

  static const tous = <Indicatif>[
    Indicatif('🇨🇲', 'Cameroun', '+237', 9),
    Indicatif('🇨🇮', 'Côte d\'Ivoire', '+225', 10),
    Indicatif('🇸🇳', 'Sénégal', '+221', 9),
    Indicatif('🇧🇯', 'Bénin', '+229', 8),
    Indicatif('🇹🇬', 'Togo', '+228', 8),
    Indicatif('🇬🇦', 'Gabon', '+241', 8),
    Indicatif('🇨🇬', 'Congo', '+242', 9),
    Indicatif('🇧🇫', 'Burkina Faso', '+226', 8),
    Indicatif('🇲🇱', 'Mali', '+223', 8),
    Indicatif('🇫🇷', 'France', '+33', 9),
  ];
}

/// Écran de **connexion** — le point d'entrée de l'application (§2.1).
///
/// Trois méthodes sur un seul écran : Google, téléphone (code OTP WhatsApp,
/// seul canal téléphone accepté par le backend) et email + mot de passe.
class AuthChoiceScreen extends ConsumerStatefulWidget {
  const AuthChoiceScreen({super.key});

  @override
  ConsumerState<AuthChoiceScreen> createState() => _AuthChoiceScreenState();
}

class _AuthChoiceScreenState extends ConsumerState<AuthChoiceScreen> {
  final _telephone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  Indicatif _indicatif = Indicatif.tous.first;
  bool _parTelephone = true;
  bool _obscure = true;
  bool _envoi = false;
  String? _erreur;

  @override
  void dispose() {
    _telephone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String get _destination => _parTelephone
      ? '${_indicatif.code}${_telephone.text.replaceAll(RegExp(r'\D'), '')}'
      : _email.text.trim();

  bool get _identifiantValide {
    if (_parTelephone) {
      final chiffres = _telephone.text.replaceAll(RegExp(r'\D'), '');
      return chiffres.length >= _indicatif.longueur - 1 &&
          chiffres.length <= _indicatif.longueur + 1;
    }
    final e = _email.text.trim();
    return e.contains('@') && e.contains('.') && e.length > 5;
  }

  bool get _valide =>
      _identifiantValide && (_parTelephone || _password.text.isNotEmpty);

  Future<void> _seConnecter() async {
    if (_parTelephone) {
      return _envoyerOtp();
    }
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).login(
            email: _destination,
            motDePasse: _password.text,
          );
      if (!mounted) return;
      final user = ref.read(authNotifierProvider).user;
      context.go((user?.needsOnboarding ?? false) ? '/onboarding' : '/app');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = ref.read(authNotifierProvider).error ?? _messageErreur(e);
      });
    }
  }

  /// Connexion téléphone : le backend n'accepte pas de mot de passe sur ce
  /// canal — on envoie un code OTP (WhatsApp) puis on ouvre l'écran de
  /// saisie, qui valide et ouvre la session.
  Future<void> _envoyerOtp() async {
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    final destination = _destination;
    try {
      final delai = await ref
          .read(authNotifierProvider.notifier)
          .demanderCode(destination: destination);
      if (!mounted) return;
      setState(() => _envoi = false);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            canal: 'sms',
            destination: destination,
            expiresIn: delai,
            onSucces: () {
              final user = ref.read(authNotifierProvider).user;
              context.go(
                  (user?.needsOnboarding ?? false) ? '/onboarding' : '/app');
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = _messageErreur(e);
      });
    }
  }

  static String _messageErreur(Object e) {
    final code = e is DioException ? e.response?.statusCode : null;
    return switch (code) {
      401 => 'Identifiants invalides. Vérifie ton mot de passe.',
      404 => 'Aucun compte ne correspond à ces informations.',
      403 => 'Ce compte n\'est pas encore vérifié.',
      429 => 'Trop de tentatives. Patiente une minute avant de réessayer.',
      _ => 'Connexion impossible. Vérifie ta connexion et réessaie.',
    };
  }

  Future<void> _google() async {
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      final idToken = await GoogleAuth.connecter();
      if (idToken == null) {
        setState(() => _envoi = false);
        return; // L'utilisateur a annulé.
      }
      await ref.read(authNotifierProvider.notifier).connexionGoogle(idToken);
      if (mounted) context.go('/app');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = GoogleAuth.estNonConfigure(e)
            ? 'Connexion Google pas encore configurée sur cette version.'
            : 'Connexion Google impossible. Réessaie.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AuthScaffold(
      title: tr(context, 'Connexion'),
      subtitle: tr(context,
          'Retrouve les épreuves, TD et cours de ta filière. Connecte-toi en '
          '10 secondes.'),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  tr(context, 'Nouveau sur UniVerse ?'),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/register'),
                child: Text(tr(context, 'Créer un compte')),
              ),
            ],
          ),
          // Mode Test : session simulée par rôle, avec des données fictives
          // — pour découvrir l'application sans compte ni serveur.
          TextButton.icon(
            onPressed: () => ouvrirModeDemo(context),
            icon: Icon(Icons.science_outlined,
                size: 16, color: Colors.white.withValues(alpha: 0.55)),
            label: Text(
              tr(context, 'Explorer en mode test (données fictives)'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
      children: [
        // ---------------------------------------------------------- Google
        _GoogleButton(onPressed: _envoi ? null : _google),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: _hair()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                tr(context, 'ou'),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
            Expanded(child: _hair()),
          ],
        ),
        const SizedBox(height: 18),

        // ------------------------------------------ Bascule téléphone / email
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

        if (!_parTelephone) ...[
          const SizedBox(height: 14),
          AuthField(
            controller: _password,
            hint: tr(context, 'Mot de passe'),
            icon: Icons.lock_outline_rounded,
            obscure: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _valide ? _seConnecter() : null,
            suffix: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: Colors.white.withValues(alpha: 0.45),
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => ouvrirMotDePasseOublie(context),
              child: Text(
                tr(context, 'Mot de passe oublié ?'),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12.5),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            tr(context, 'Un code de connexion à 6 chiffres te sera envoyé '
                'sur WhatsApp.'),
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],

        if (_erreur != null) ...[
          const SizedBox(height: 4),
          AuthErrorBanner(_erreur!),
        ],

        const SizedBox(height: 10),
        AuthPrimaryButton(
          label: _parTelephone
              ? tr(context, 'Recevoir le code')
              : tr(context, 'Se connecter'),
          icon: Icons.arrow_forward_rounded,
          loading: _envoi,
          onPressed: _valide ? _seConnecter : null,
        ),
      ],
        ),
        const Positioned(top: 0, left: 0, right: 0, child: SafeArea(child: _LangSwitch())),
      ],
    );
  }

  Widget _hair() =>
      Container(height: 1, color: Colors.white.withValues(alpha: 0.12));
}

/// Deux carrés « FR » / « EN » en haut de l'écran de connexion — bascule
/// immédiate, toute l'app se retraduit (voir [tr]).
class _LangSwitch extends ConsumerWidget {
  const _LangSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _CarreLangue(
            label: 'FR',
            actif: locale.languageCode == 'fr',
            onTap: () => ref
                .read(localeProvider.notifier)
                .definir(const Locale('fr')),
          ),
          const SizedBox(width: 8),
          _CarreLangue(
            label: 'EN',
            actif: locale.languageCode == 'en',
            onTap: () => ref
                .read(localeProvider.notifier)
                .definir(const Locale('en')),
          ),
        ],
      ),
    );
  }
}

class _CarreLangue extends StatelessWidget {
  const _CarreLangue({
    required this.label,
    required this.actif,
    required this.onTap,
  });

  final String label;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 36,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: actif ? UniverseColors.brandGradient : null,
          color: actif ? null : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: actif
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.16),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: actif ? Colors.white : Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ),
      ),
    );
  }
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
                      tr(context, 'Continuer avec Google'),
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
                    leading:
                        Text(i.drapeau, style: const TextStyle(fontSize: 22)),
                    title: Text(i.pays, style: const TextStyle(color: Colors.white)),
                    trailing: Text(
                      i.code,
                      style: const TextStyle(color: Colors.white54),
                    ),
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
            Text(
              valeur.code,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Icon(Icons.arrow_drop_down,
                size: 20, color: Colors.white.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

