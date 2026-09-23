import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/widgets/universe_ui.dart';

/// Changement de mot de passe — une vraie feuille avec jauge de robustesse
/// et retour d'erreur clair, plutôt qu'une AlertDialog à deux champs nus.
Future<void> ouvrirChangerMotDePasse(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ChangerMotDePasseSheet(),
  );
}

class _ChangerMotDePasseSheet extends ConsumerStatefulWidget {
  const _ChangerMotDePasseSheet();

  @override
  ConsumerState<_ChangerMotDePasseSheet> createState() => _ChangerMotDePasseSheetState();
}

class _ChangerMotDePasseSheetState extends ConsumerState<_ChangerMotDePasseSheet> {
  final _ancien = TextEditingController();
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscureAncien = true;
  bool _obscureNouveau = true;
  bool _envoi = false;
  String? _erreur;
  bool _reussi = false;

  @override
  void dispose() {
    _ancien.dispose();
    _nouveau.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  static bool _fort(String v) =>
      v.length >= 8 &&
      RegExp(r'[A-Z]').hasMatch(v) &&
      RegExp(r'[a-z]').hasMatch(v) &&
      RegExp(r'[0-9]').hasMatch(v) &&
      RegExp(r'[^A-Za-z0-9]').hasMatch(v);

  bool get _valide =>
      _ancien.text.isNotEmpty &&
      _fort(_nouveau.text) &&
      _nouveau.text == _confirmation.text;

  Future<void> _valider() async {
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).changePassword(
            ancien: _ancien.text,
            nouveau: _nouveau.text,
          );
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _reussi = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = tr(context, 'Ancien mot de passe incorrect.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
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
              SheetHeader(
                titre: tr(context, 'Changer le mot de passe'),
                sousTitre: tr(context, 'Choisis un mot de passe robuste — 8 caractères, '
                    'majuscule, chiffre et symbole.'),
              ),
              const SizedBox(height: 20),
              if (_reussi) ...[
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: UniverseColors.brandGradient,
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        tr(context, 'Mot de passe mis à jour. Tes autres appareils ont été '
                            'déconnectés.'),
                        style: TextStyle(color: t.textPrimary, height: 1.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                UniversePrimaryButton(
                  label: tr(context, 'Fermer'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ] else ...[
                _Champ(
                  controller: _ancien,
                  label: tr(context, 'Mot de passe actuel'),
                  obscure: _obscureAncien,
                  onToggle: () => setState(() => _obscureAncien = !_obscureAncien),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                _Champ(
                  controller: _nouveau,
                  label: tr(context, 'Nouveau mot de passe'),
                  obscure: _obscureNouveau,
                  onToggle: () => setState(() => _obscureNouveau = !_obscureNouveau),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                _Jauge(motDePasse: _nouveau.text),
                const SizedBox(height: 16),
                _Champ(
                  controller: _confirmation,
                  label: tr(context, 'Confirme le nouveau mot de passe'),
                  obscure: _obscureNouveau,
                  onToggle: () => setState(() => _obscureNouveau = !_obscureNouveau),
                  onChanged: (_) => setState(() {}),
                ),
                if (_confirmation.text.isNotEmpty &&
                    _confirmation.text != _nouveau.text) ...[
                  const SizedBox(height: 6),
                  Text(
                    tr(context, 'Les mots de passe ne correspondent pas.'),
                    style: const TextStyle(color: UniverseColors.danger, fontSize: 12.5),
                  ),
                ],
                if (_erreur != null) ...[
                  const SizedBox(height: 12),
                  UniverseBanner(_erreur!, tone: BannerTone.danger),
                ],
                const SizedBox(height: 22),
                UniversePrimaryButton(
                  label: tr(context, 'Mettre à jour'),
                  icon: Icons.lock_reset_rounded,
                  loading: _envoi,
                  onPressed: _valide ? _valider : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Champ extends StatelessWidget {
  const _Champ({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

class _Jauge extends StatelessWidget {
  const _Jauge({required this.motDePasse});

  final String motDePasse;

  int get _score {
    var s = 0;
    if (motDePasse.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(motDePasse) && RegExp(r'[a-z]').hasMatch(motDePasse)) s++;
    if (RegExp(r'[0-9]').hasMatch(motDePasse)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(motDePasse)) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final score = _score;
    final couleur = switch (score) {
      <= 1 => UniverseColors.danger,
      2 || 3 => const Color(0xFFF59E0B),
      _ => UniverseColors.success,
    };
    return Row(
      children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
              decoration: BoxDecoration(
                color: i < score ? couleur : t.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}
