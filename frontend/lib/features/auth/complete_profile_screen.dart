import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/role_access.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/services/media_service.dart';
import '../../core/services/registration_service.dart';
import 'otp_screen.dart';
import 'privacy_accept_screen.dart';
import 'widgets/auth_scaffold.dart';

/// Complétion du profil (§3) — rôle puis champs propres au rôle.
///
/// Trois issues selon le canal (contrats backend réels) :
/// - **téléphone** : OTP en dernière étape — la validation du code crée le
///   compte **et ouvre la session** (`/auth/otp/verify`) ;
/// - **email** : `/auth/register` puis confirmation de l'email avant la
///   première connexion ;
/// - **Google** : `/auth/google` crée le compte et ouvre la session.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({
    super.key,
    required this.methode,
    required this.destination,
    this.idTokenGoogle,
  });

  /// 'google' | 'sms' | 'email'.
  final String methode;
  final String destination;
  final String? idTokenGoogle;

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

enum _Etape { role, identite, documents, confirmation }

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  static const _media = MediaService();

  RegistrationService get _service =>
      RegistrationService(ref.read(apiClientProvider));

  _Etape _etape = _Etape.role;
  Rang? _role;

  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _politiqueAcceptee = false;
  DateTime? _dateNaissance;
  String? _sexe;

  PlatformFile? _cniRecto;
  PlatformFile? _cniVerso;
  PlatformFile? _logo;
  PlatformFile? _photo;

  bool _envoi = false;
  String? _erreur;

  /// Jeton de vérification email exposé par le serveur en développement
  /// (`EXPOSE_EMAIL_VERIFICATION_TOKEN=true`) — pré-rempli sur l'écran de
  /// vérification pour fluidifier les tests.
  String? _tokenVerificationEmail;

  @override
  void dispose() {
    _nom.dispose();
    _prenom.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  /// Tuteur, Formateur TDS et Enseignant doivent fournir un email + une CNI
  /// (règles d'inscription backend) : leur inscription passe par email ou
  /// Google (qui fournit l'email vérifié). Par téléphone : étudiant
  /// uniquement.
  bool _roleAutorise(Rang r) =>
      r == Rang.etudiant || widget.methode != 'sms';

  /// Google fournit déjà une identité vérifiée : pas de mot de passe à
  /// créer, la connexion se refera toujours par Google. Le téléphone se
  /// reconnectera par OTP : pas de mot de passe non plus.
  bool get _exigeMotDePasse => widget.methode == 'email';

  /// CNI recto/verso : exigée par le backend pour tuteur, formateur TDS et
  /// enseignant.
  bool get _exigeCni =>
      _role == Rang.tuteur || _role == Rang.formateur || _role == Rang.enseignant;
  bool get _exigeLogoEtPhoto => _role == Rang.formateur;
  bool get _aUneEtapeDocuments => _exigeCni || _exigeLogoEtPhoto;

  /// Politique backend (`PASSWORD_REGEX`) : 12 caractères minimum,
  /// majuscule, minuscule, chiffre et symbole.
  static bool _motDePasseFort(String v) =>
      v.length >= 12 &&
      RegExp(r'[A-Z]').hasMatch(v) &&
      RegExp(r'[a-z]').hasMatch(v) &&
      RegExp(r'[0-9]').hasMatch(v) &&
      RegExp(r'[^A-Za-z0-9]').hasMatch(v);

  bool get _motDePasseValide =>
      !_exigeMotDePasse ||
      (_motDePasseFort(_password.text) &&
          _password.text == _passwordConfirm.text);

  /// N'inclut volontairement pas l'acceptation de la politique : celle-ci
  /// est vérifiée séparément dans [_suivantDepuisIdentite] pour pouvoir
  /// afficher un message explicite plutôt que de désactiver le bouton en
  /// silence (une case non cochée ne doit jamais donner l'impression que
  /// l'étape suivante — la vérification par code — a disparu).
  bool get _identiteValide {
    if (_nom.text.trim().isEmpty || _prenom.text.trim().isEmpty) return false;
    if (_sexe == null || _dateNaissance == null) return false;
    final age = DateTime.now().difference(_dateNaissance!).inDays / 365.25;
    if (age < 10 || age > 100) return false;
    return _motDePasseValide;
  }

  bool get _documentsValides =>
      (!_exigeCni || (_cniRecto != null && _cniVerso != null)) &&
      (!_exigeLogoEtPhoto || (_logo != null && _photo != null));

  void _suivantDepuisRole() {
    if (_role == null) return;
    if (!_roleAutorise(_role!)) return;
    setState(() => _etape = _Etape.identite);
  }

  void _suivantDepuisIdentite() {
    if (!_identiteValide) return;
    if (!_politiqueAcceptee) {
      setState(() => _erreur =
          tr(context, 'Coche la case pour accepter la politique de confidentialité avant de continuer.'));
      return;
    }
    setState(() => _erreur = null);
    if (_aUneEtapeDocuments) {
      setState(() => _etape = _Etape.documents);
    } else {
      _versVerificationOuSoumission();
    }
  }

  /// Le backend n'accepte que jpeg/png/webp pour les pièces d'identité
  /// (`TYPES_IMAGE_IDENTITE`) : la CNI se photographie, pas de PDF ici.
  Future<void> _choisirImage(void Function(PlatformFile) assigner) async {
    final res = await _media.choisirImage();
    if (!mounted) return;
    if (res.statut == MediaPickStatut.tropLourd) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(context, 'Image trop lourde (8 Mo maximum). Choisis-en une autre.')),
      ));
      return;
    }
    if (res.estValide) setState(() => assigner(res.fichier!));
  }

  /// Aiguillage final selon le canal d'inscription.
  void _versVerificationOuSoumission() {
    switch (widget.methode) {
      case 'google':
        _soumettreGoogle();
      case 'email':
        _soumettreEmail();
      default:
        _lancerVerificationSms();
    }
  }

  /// Téléverse les pièces (CNI, logo, photo) via `/auth/presign-identite`
  /// et construit le bloc `ChampsIdentiteDto` du payload d'inscription.
  Future<Map<String, dynamic>> _preparerIdentite() async {
    final cniRecto = await _service.televerserIdentite('cni-recto', _cniRecto);
    final cniVerso = await _service.televerserIdentite('cni-verso', _cniVerso);
    final logo = await _service.televerserIdentite('logo-formation', _logo);
    final photo = await _service.televerserIdentite('photo-profil', _photo);
    return _service.champsIdentite(
      role: _role!,
      sexe: _sexe,
      dateNaissance: _dateNaissance,
      cniRectoCle: cniRecto,
      cniVersoCle: cniVerso,
      logoFormationCle: logo,
      photoProfilCle: photo,
    );
  }

  /// Téléphone : le code OTP est la dernière étape — sa validation crée le
  /// compte **et ouvre la session** (`POST /auth/otp/verify`).
  Future<void> _lancerVerificationSms() async {
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      final identite = await _preparerIdentite();
      final delai = await ref
          .read(authNotifierProvider.notifier)
          .demanderCode(destination: widget.destination);
      if (!mounted) return;
      setState(() => _envoi = false);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            canal: 'sms',
            destination: widget.destination,
            expiresIn: delai,
            onValider: (code) =>
                ref.read(authNotifierProvider.notifier).verifierCode(
                      destination: widget.destination,
                      code: code,
                      nom: _nom.text.trim(),
                      prenom: _prenom.text.trim(),
                      champsInscription: identite,
                    ),
            onRenvoyer: () => ref
                .read(authNotifierProvider.notifier)
                .demanderCode(destination: widget.destination),
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
        _erreur = e is RegistrationException
            ? e.message
            : tr(context, 'Envoi du code impossible. Vérifie ta connexion et réessaie.');
      });
    }
  }

  /// Email : `POST /auth/register` — pas de session tant que l'email n'est
  /// pas confirmé. La confirmation invite à valider l'email reçu.
  Future<void> _soumettreEmail() async {
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      final identite = await _preparerIdentite();
      final res = await _service.inscrireParEmail(
        email: widget.destination,
        motDePasse: _password.text,
        nom: _nom.text.trim(),
        prenom: _prenom.text.trim(),
        identite: identite,
      );
      if (!mounted) return;
      setState(() {
        _tokenVerificationEmail = res['verificationToken'] as String?;
        _envoi = false;
        _etape = _Etape.confirmation;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = e is RegistrationException
            ? e.message
            : tr(context, 'Inscription impossible. Vérifie ta connexion et réessaie.');
      });
    }
  }

  /// Google : `POST /auth/google` crée le compte et ouvre la session.
  Future<void> _soumettreGoogle() async {
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      final identite = await _preparerIdentite();
      await ref.read(authNotifierProvider.notifier).connexionGoogle(
            widget.idTokenGoogle!,
            champsInscription: identite,
          );
      if (!mounted) return;
      final user = ref.read(authNotifierProvider).user;
      context.go((user?.needsOnboarding ?? false) ? '/onboarding' : '/app');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = e is RegistrationException
            ? e.message
            : tr(context, 'Inscription impossible. Vérifie ta connexion et réessaie.');
      });
    }
  }

  double get _progression => switch (_etape) {
        _Etape.role => 0.25,
        _Etape.identite => 0.5,
        _Etape.documents => 0.75,
        _Etape.confirmation => 1,
      };

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: switch (_etape) {
        _Etape.role => tr(context, 'Qui es-tu ?'),
        _Etape.identite => tr(context, 'Tes informations'),
        _Etape.documents => _exigeLogoEtPhoto ? tr(context, 'Logo et photo') : tr(context, 'Pièce d\'identité'),
        _Etape.confirmation => tr(context, 'C\'est fait !'),
      },
      subtitle: switch (_etape) {
        _Etape.role => tr(context, 'Choisis comment tu utiliseras UniVerse.'),
        _Etape.identite => tr(context, 'Ces informations restent visibles uniquement par '
            'l\'équipe UniVerse.'),
        _Etape.documents => _exigeLogoEtPhoto
            ? tr(context, 'Le logo apparaîtra sur tes vidéos, la photo sur ton profil.')
            : tr(context, 'Une photo lisible du recto et du verso suffit.'),
        _Etape.confirmation => null,
      },
      onBack: _etape == _Etape.confirmation
          ? null
          : () {
              if (_etape == _Etape.role) {
                context.canPop() ? context.pop() : context.go('/login');
              } else if (_etape == _Etape.identite) {
                setState(() => _etape = _Etape.role);
              } else {
                setState(() => _etape = _Etape.identite);
              }
            },
      progress: _etape == _Etape.confirmation ? null : _progression,
      children: switch (_etape) {
        _Etape.role => _etapeRole(),
        _Etape.identite => _etapeIdentite(),
        _Etape.documents => _etapeDocuments(),
        _Etape.confirmation => _etapeConfirmation(),
      },
    );
  }

  // ------------------------------------------------------------------- Rôle

  List<Widget> _etapeRole() {
    // Modérateur n'est plus proposé à l'inscription — on ne peut le devenir
    // qu'via une demande de statut, une fois le compte créé (comme Tuteur
    // et Formateur TDS le sont déjà).
    const roles = [Rang.etudiant, Rang.tuteur, Rang.formateur, Rang.enseignant];
    final descriptions = {
      Rang.etudiant: tr(context, 'Consulte les cours, vidéos et documents de ta filière.'),
      Rang.tuteur: tr(context, 'Accompagne un groupe d\'étudiants et publie tes vidéos.'),
      Rang.formateur: tr(context, 'Publie des vidéos pédagogiques sous ta propre marque.'),
      Rang.enseignant: tr(context, 'Publie sous accréditation — dossier examiné sous 2 à 3 jours.'),
    };

    return [
      for (final r in roles)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _RoleCard(
            rang: r,
            description: descriptions[r]!,
            selectionne: _role == r,
            desactive: !_roleAutorise(r),
            noteDesactive: tr(context, 'Ce rôle exige un email et une pièce d\'identité — '
                'reviens en arrière et choisis Email (ou Google).'),
            onTap: () => setState(() => _role = r),
          ),
        ),
      const SizedBox(height: 12),
      AuthPrimaryButton(
        label: tr(context, 'Continuer'),
        icon: Icons.arrow_forward_rounded,
        onPressed: (_role != null && _roleAutorise(_role!))
            ? _suivantDepuisRole
            : null,
      ),
    ];
  }

  // --------------------------------------------------------------- Identité

  List<Widget> _etapeIdentite() {
    return [
      AuthField(
        controller: _prenom,
        label: tr(context, 'Prénom'),
        hint: tr(context, 'Ton prénom'),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 14),
      AuthField(
        controller: _nom,
        label: tr(context, 'Nom'),
        hint: tr(context, 'Ton nom'),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 14),
      _ChampDate(
        valeur: _dateNaissance,
        onChange: (d) => setState(() => _dateNaissance = d),
      ),
      const SizedBox(height: 14),
      _ChoixSexe(valeur: _sexe, onChange: (s) => setState(() => _sexe = s)),
      if (_exigeMotDePasse) ...[
        const SizedBox(height: 14),
        AuthField(
          controller: _password,
          label: tr(context, 'Mot de passe'),
          hint: tr(context, '12 caractères min., majuscule, chiffre, symbole'),
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
        const SizedBox(height: 6),
        _JaugeMotDePasse(motDePasse: _password.text),
        const SizedBox(height: 14),
        AuthField(
          controller: _passwordConfirm,
          label: tr(context, 'Confirme le mot de passe'),
          hint: tr(context, 'Retape le même mot de passe'),
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
        if (_passwordConfirm.text.isNotEmpty &&
            _passwordConfirm.text != _password.text) ...[
          const SizedBox(height: 6),
          Text(
            tr(context, 'Les mots de passe ne correspondent pas.'),
            style: TextStyle(color: UniverseColors.danger.withValues(alpha: 0.9), fontSize: 12),
          ),
        ],
      ],
      const SizedBox(height: 18),
      _CaseConfidentialite(
        acceptee: _politiqueAcceptee,
        onChange: (v) => setState(() => _politiqueAcceptee = v),
        onLirePlus: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PrivacyAcceptScreen()),
        ),
      ),
      if (_erreur != null) ...[const SizedBox(height: 14), AuthErrorBanner(_erreur!)],
      const SizedBox(height: 22),
      AuthPrimaryButton(
        label: _aUneEtapeDocuments ? tr(context, 'Continuer') : tr(context, 'Créer mon compte'),
        icon: Icons.arrow_forward_rounded,
        loading: _envoi,
        onPressed: _identiteValide ? _suivantDepuisIdentite : null,
      ),
    ];
  }

  // -------------------------------------------------------------- Documents

  List<Widget> _etapeDocuments() {
    return [
      if (_exigeCni) ...[
        _FichierTile(
          label: tr(context, 'CNI — recto'),
          fichier: _cniRecto,
          onTap: () => _choisirImage((f) => _cniRecto = f),
        ),
        const SizedBox(height: 10),
        _FichierTile(
          label: tr(context, 'CNI — verso'),
          fichier: _cniVerso,
          onTap: () => _choisirImage((f) => _cniVerso = f),
        ),
        if (_exigeLogoEtPhoto) const SizedBox(height: 10),
      ],
      if (_exigeLogoEtPhoto) ...[
        _FichierTile(
          label: tr(context, 'Logo de ta formation'),
          fichier: _logo,
          onTap: () => _choisirImage((f) => _logo = f),
        ),
        const SizedBox(height: 10),
        _FichierTile(
          label: tr(context, 'Ta photo'),
          fichier: _photo,
          onTap: () => _choisirImage((f) => _photo = f),
        ),
      ],
      if (_erreur != null) ...[const SizedBox(height: 14), AuthErrorBanner(_erreur!)],
      const SizedBox(height: 22),
      AuthPrimaryButton(
        label: tr(context, 'Créer mon compte'),
        icon: Icons.check_rounded,
        loading: _envoi,
        onPressed: _documentsValides ? _versVerificationOuSoumission : null,
      ),
    ];
  }

  // ---------------------------------------------------------- Confirmation

  List<Widget> _etapeConfirmation() {
    // Cette étape ne s'affiche que pour l'inscription email : téléphone et
    // Google ouvrent la session directement et filent vers l'application.
    final enAttente = _role == Rang.formateur || _role == Rang.enseignant;
    return [
      Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: UniverseColors.brandGradient,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
      ),
      const SizedBox(height: 20),
      Text(
        tr(context, 'Ton compte est créé. Confirme d\'abord ton adresse email : un '
            'lien de vérification vient de t\'être envoyé à ') +
            widget.destination +
            tr(context, '. Ensuite, connecte-toi avec ton mot de passe.'),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, height: 1.5, color: Colors.white.withValues(alpha: 0.8)),
      ),
      if (enAttente) ...[
        const SizedBox(height: 12),
        Text(
          tr(context, 'Ton dossier (CNI et pièces fournies) sera examiné par l\'équipe '
              'UniVerse : réponse sous 2 à 3 jours ouvrables. En attendant, tu '
              'utiliseras l\'app comme un étudiant.'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.5, color: Colors.white.withValues(alpha: 0.65)),
        ),
      ],
      const SizedBox(height: 26),
      AuthPrimaryButton(
        label: tr(context, 'Vérifier mon email'),
        icon: Icons.mark_email_read_outlined,
        onPressed: () => context.go('/verify-email', extra: _tokenVerificationEmail),
      ),
      const SizedBox(height: 10),
      Center(
        child: TextButton(
          onPressed: () => context.go('/login'),
          child: Text(tr(context, 'Aller à la connexion')),
        ),
      ),
    ];
  }
}

/// Acceptation de la politique de confidentialité (§2.2 bis) — une case à
/// cocher avec un résumé court, au bon moment (juste avant de créer le
/// compte, pas en préalable imposé dès le choix du canal) plutôt qu'un
/// écran plein qui bloque tout avant même d'avoir commencé à s'inscrire.
/// Le texte complet reste à un clic, sur [PrivacyAcceptScreen].
class _CaseConfidentialite extends StatelessWidget {
  const _CaseConfidentialite({
    required this.acceptee,
    required this.onChange,
    required this.onLirePlus,
  });

  final bool acceptee;
  final ValueChanged<bool> onChange;
  final VoidCallback onLirePlus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Checkbox(
              value: acceptee,
              onChanged: (v) => onChange(v ?? false),
              activeColor: UniverseColors.blue,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                  children: [
                    TextSpan(
                      text: tr(context,
                          'J\'accepte que UniVerse stocke et utilise mes '
                          'données et mes contenus. '),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => onChange(!acceptee),
                    ),
                    TextSpan(
                      text: tr(context, 'Lire la politique complète'),
                      style: const TextStyle(
                        color: UniverseColors.blue,
                        fontWeight: FontWeight.w700,
                      ),
                      recognizer: TapGestureRecognizer()..onTap = onLirePlus,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Jauge de robustesse du mot de passe — 4 barres, une par critère
/// satisfait (longueur, majuscule/minuscule, chiffre, symbole).
class _JaugeMotDePasse extends StatelessWidget {
  const _JaugeMotDePasse({required this.motDePasse});

  final String motDePasse;

  int get _score {
    var s = 0;
    if (motDePasse.length >= 12) s++;
    if (RegExp(r'[A-Z]').hasMatch(motDePasse) && RegExp(r'[a-z]').hasMatch(motDePasse)) s++;
    if (RegExp(r'[0-9]').hasMatch(motDePasse)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(motDePasse)) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
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
                color: i < score ? couleur : Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------------- Widgets partagés

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.rang,
    required this.description,
    required this.selectionne,
    required this.onTap,
    this.desactive = false,
    this.noteDesactive,
  });

  final Rang rang;
  final String description;
  final bool selectionne;
  final bool desactive;
  final String? noteDesactive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final acces = RoleAccess(rang);
    return Opacity(
      opacity: desactive ? 0.45 : 1,
      child: InkWell(
        onTap: desactive ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selectionne
                ? acces.couleur.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: selectionne ? acces.couleur : Colors.white.withValues(alpha: 0.12),
              width: selectionne ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(acces.icone, color: acces.couleur),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rang.libelle,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14.5)),
                    const SizedBox(height: 3),
                    Text(
                      desactive && noteDesactive != null ? noteDesactive! : description,
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6), height: 1.3),
                    ),
                  ],
                ),
              ),
              if (selectionne) Icon(Icons.check_circle_rounded, color: acces.couleur, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoixSexe extends StatelessWidget {
  const _ChoixSexe({required this.valeur, required this.onChange});

  final String? valeur;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _option(context, 'M', tr(context, 'Masculin'))),
        const SizedBox(width: 10),
        Expanded(child: _option(context, 'F', tr(context, 'Féminin'))),
      ],
    );
  }

  Widget _option(BuildContext context, String code, String label) {
    final actif = valeur == code;
    return GestureDetector(
      onTap: () => onChange(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: actif ? UniverseColors.blue.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: actif ? UniverseColors.blue : Colors.white.withValues(alpha: 0.12)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: actif ? Colors.white : Colors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChampDate extends StatelessWidget {
  const _ChampDate({required this.valeur, required this.onChange});

  final DateTime? valeur;
  final ValueChanged<DateTime> onChange;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final maintenant = DateTime.now();
        final choix = await showDatePicker(
          context: context,
          initialDate: valeur ?? DateTime(maintenant.year - 20),
          firstDate: DateTime(maintenant.year - 100),
          lastDate: DateTime(maintenant.year - 10),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: UniverseColors.blue),
            ),
            child: child!,
          ),
        );
        if (choix != null) onChange(choix);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(Icons.cake_outlined, color: Colors.white.withValues(alpha: 0.45), size: 20),
            const SizedBox(width: 12),
            Text(
              valeur == null
                  ? tr(context, 'Date de naissance')
                  : '${valeur!.day.toString().padLeft(2, '0')}/'
                      '${valeur!.month.toString().padLeft(2, '0')}/${valeur!.year}',
              style: TextStyle(
                color: valeur == null ? Colors.white.withValues(alpha: 0.35) : Colors.white,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FichierTile extends StatelessWidget {
  const _FichierTile({required this.label, required this.fichier, required this.onTap});

  final String label;
  final PlatformFile? fichier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final choisi = fichier != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: choisi ? UniverseColors.blue.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: choisi ? UniverseColors.blue : Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Icon(
              choisi ? Icons.check_circle_rounded : Icons.upload_file_outlined,
              color: choisi ? UniverseColors.blue : Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(
                    choisi ? fichier!.name : tr(context, 'Choisir une image (JPEG, PNG ou WebP)'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
