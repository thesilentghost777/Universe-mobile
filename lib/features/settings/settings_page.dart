import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `StateProvider` est déprécié depuis Riverpod 3 et vit désormais dans cet
// import dédié ; il reste pris en charge.
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/role_access.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/services/media_service.dart';
import '../../core/widgets/draggable_ai_fab.dart';
import '../../core/widgets/image_crop_sheet.dart';
import '../../core/widgets/universe_glass.dart';
import '../../core/widgets/universe_skeleton.dart';
import '../../core/widgets/universe_ui.dart';
import '../roles/role_console_page.dart';
import 'account_settings_page.dart';
import 'aide_settings_page.dart';
import 'appearance_settings_page.dart';
import 'notification_settings_page.dart';
import 'privacy_settings_page.dart';
import 'settings_widgets.dart';

/// Photo tout juste choisie, en attendant qu'un endpoint d'upload existe
/// côté back — voir le contrat documenté sur `UserProfile.photoUrl`.
final photoProfilLocaleProvider = StateProvider<Uint8List?>((_) => null);

/// Paramètres — écran d'accueil : profil, puis un ensemble de catégories
/// vers des pages dédiées (§ retour utilisateur : agencement différent,
/// aussi détaillé que possible, pas forcément identique d'un rôle à
/// l'autre — l'Enseignant obtient une seule colonne de tuiles plus grandes
/// plutôt qu'une grille à deux colonnes, cohérent avec le reste de son
/// interface simplifiée).
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  Future<void> _changerPhoto() async {
    const media = MediaService();
    final res = await media.choisirImage();
    if (res.statut == MediaPickStatut.tropLourd) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(context, 'Image trop lourde (8 Mo maximum).')),
        ));
      }
      return;
    }
    if (!res.estValide) return;
    if (!mounted) return;
    final recadree = await ouvrirRecadrageImage(context, res.octets!);
    if (recadree == null || !mounted) return;
    ref.read(photoProfilLocaleProvider.notifier).state = recadree;
    try {
      final type = _contentTypeImage(recadree);
      final api = ref.read(apiClientProvider);
      final presign = await api.post('/storage/presign/identite', data: {
        'fichier': 'photo-profil',
        'tailleOctets': recadree.length,
        'contentType': type,
      });
      final data = Map<String, dynamic>.from(presign.data as Map);
      final url = data['url'] as String;
      final fields = Map<String, dynamic>.from(data['fields'] as Map? ?? {});
      final cle = data['cle'] as String;
      await Dio().post(
        url,
        data: FormData.fromMap({
          ...fields,
          'file': MultipartFile.fromBytes(recadree, filename: 'photo.jpg'),
        }),
      );
      await ref.read(authNotifierProvider.notifier).enregistrerPhotoProfil(cle);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(context, 'Photo de profil mise à jour.')),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(context, 'Impossible d\'enregistrer la photo.')),
      ));
    }
  }

  String _contentTypeImage(Uint8List octets) {
    if (octets.length >= 3 && octets[0] == 0xFF && octets[1] == 0xD8) {
      return 'image/jpeg';
    }
    if (octets.length >= 4 &&
        octets[0] == 0x89 &&
        octets[1] == 0x50 &&
        octets[2] == 0x4E &&
        octets[3] == 0x47) {
      return 'image/png';
    }
    return 'image/jpeg';
  }

  Future<void> _editerBio(
    BuildContext context, {
    required String? bioActuelle,
    required String nom,
    required String? photoUrl,
    required RoleAccess acces,
  }) async {
    final valeur = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BioEditorSheet(
        bioActuelle: bioActuelle,
        nom: nom,
        photoUrl: photoUrl,
        acces: acces,
      ),
    );
    if (valeur == null) return;
    try {
      await ref.read(authNotifierProvider.notifier).enregistrerBio(valeur);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(context, 'Impossible d\'enregistrer la bio.')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final acces = RoleAccess.depuis(user);
    final photoLocale = ref.watch(photoProfilLocaleProvider);
    final t = context.tokens;
    final simplifie = acces.rang == Rang.enseignant && !acces.estEnseignantEnAttente;

    if (user == null) return const ListTileSkeleton();

    final categories = <Widget>[
      SettingsCategoryTile(
        icon: Icons.person_outline,
        titre: tr(context, 'Mon compte'),
        sousTitre: tr(context, 'Identité, scolarité, sécurité, données'),
        couleur: UniverseColors.blue,
        pleineLargeur: simplifie,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AccountSettingsPage()),
        ),
      ),
      SettingsCategoryTile(
        icon: Icons.privacy_tip_outlined,
        titre: tr(context, 'Confidentialité'),
        sousTitre: tr(context, 'Qui peut m\'écrire, visibilité, contacts'),
        couleur: UniverseColors.teal,
        pleineLargeur: simplifie,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PrivacySettingsPage()),
        ),
      ),
      SettingsCategoryTile(
        icon: Icons.notifications_outlined,
        titre: tr(context, 'Notifications'),
        sousTitre: tr(context, 'Alertes et préférences'),
        couleur: UniverseColors.amber,
        pleineLargeur: simplifie,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationSettingsPage()),
        ),
      ),
      SettingsCategoryTile(
        icon: Icons.palette_outlined,
        titre: tr(context, 'Apparence'),
        sousTitre: tr(context, 'Thème et taille du texte'),
        couleur: UniverseColors.violet,
        pleineLargeur: simplifie,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AppearanceSettingsPage()),
        ),
      ),
      if (acces.aUneConsole)
        SettingsCategoryTile(
          icon: acces.icone,
          titre: tr(context, 'Mon espace'),
          sousTitre: acces.libelle,
          couleur: acces.couleur,
          pleineLargeur: simplifie,
          onTap: () => context.push('/app/console'),
        ),
      SettingsCategoryTile(
        icon: Icons.help_outline,
        titre: tr(context, 'Aide & Support'),
        sousTitre: tr(context, 'Tutoriel, FAQ, contact'),
        couleur: UniverseColors.success,
        pleineLargeur: simplifie,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AideSettingsPage()),
        ),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24 + DraggableAiFab.degagement),
      children: [
        AppBar(
          title: Text(tr(context, 'Paramètres')),
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),

        // ------------------------------------------------------- Profil
        GlassSurface(
          accentColor: acces.couleur,
          child: Row(
            children: [
              GestureDetector(
                onTap: _changerPhoto,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UniverseAvatar(
                      initiale: user.prenom,
                      localBytes: photoLocale,
                      photoUrl: user.photoUrl,
                      radius: 30,
                      backgroundColor: acces.couleur,
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.surface,
                          border: Border.all(color: t.border),
                        ),
                        child: Icon(Icons.camera_alt_rounded,
                            size: 13, color: t.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: TextStyle(fontSize: 12.5, color: t.textMuted),
                    ),
                    const SizedBox(height: 6),
                    RoleBadge(acces: acces),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _editerBio(
            context,
            bioActuelle: user.bio,
            nom: user.displayName,
            photoUrl: user.photoUrl,
            acces: acces,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded, size: 16, color: t.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (user.bio?.trim().isNotEmpty ?? false)
                        ? user.bio!.trim()
                        : tr(context, 'Ajouter une bio — visible sur ton profil.'),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontStyle: (user.bio?.trim().isNotEmpty ?? false)
                          ? FontStyle.normal
                          : FontStyle.italic,
                      color: (user.bio?.trim().isNotEmpty ?? false)
                          ? t.textPrimary
                          : t.textMuted,
                    ),
                  ),
                ),
                Icon(Icons.edit_outlined, size: 15, color: t.textMuted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ----------------------------------------------------- Catégories
        LayoutBuilder(
          builder: (context, c) {
            final echelle = MediaQuery.textScalerOf(context).scale(1);
            final largeurTuile = (c.maxWidth - 10) / 2;
            // Deux colonnes sur un téléphone étroit, ou avec une police
            // agrandie, coupent le sous-titre. Une colonne laisse le texte
            // se poser en entier.
            final uneColonne =
                simplifie || echelle >= 1.12 || largeurTuile < 190;
            if (uneColonne) {
              return Column(
                children: [
                  for (final cat in categories) ...[
                    cat,
                    const SizedBox(height: 10),
                  ],
                ],
              );
            }
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.35,
              children: categories,
            );
          },
        ),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: UniverseColors.danger,
              side: BorderSide(color: UniverseColors.danger.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            label: Text(tr(context, 'Se déconnecter')),
          ),
        ),
      ],
    );
  }
}

/// Éditeur de bio — feuille avec aperçu en direct de ce que verront les
/// autres sur le profil, plutôt qu'un dialogue nu (§ retour utilisateur :
/// « une meilleure expérience utilisateur pour l'ajout de la bio »).
class _BioEditorSheet extends StatefulWidget {
  const _BioEditorSheet({
    required this.bioActuelle,
    required this.nom,
    required this.photoUrl,
    required this.acces,
  });

  final String? bioActuelle;
  final String nom;
  final String? photoUrl;
  final RoleAccess acces;

  @override
  State<_BioEditorSheet> createState() => _BioEditorSheetState();
}

class _BioEditorSheetState extends State<_BioEditorSheet> {
  late final _ctrl = TextEditingController(text: widget.bioActuelle);

  List<String> _suggestions(BuildContext context) => [
        tr(context, 'Passionné(e) par ma matière 📚'),
        tr(context, 'Toujours partant(e) pour aider !'),
        tr(context, 'En route vers le diplôme 🎓'),
      ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final clavier = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: clavier),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: UniverseColors.brandGradient,
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: Colors.white, size: 17),
                    ),
                    const SizedBox(width: 12),
                    Text(tr(context, 'Ta bio'), style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tr(context, 'Une courte phrase visible sur ton profil, à la façon de WhatsApp.'),
                  style: TextStyle(fontSize: 13, color: t.textMuted),
                ),
                const SizedBox(height: 20),

                // Aperçu en direct.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.acces.couleur.withValues(alpha: 0.14),
                        UniverseColors.violet.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.acces.couleur.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UniverseAvatar(
                        initiale: widget.nom,
                        photoUrl: widget.photoUrl,
                        radius: 24,
                        backgroundColor: widget.acces.couleur,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.nom,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            AnimatedBuilder(
                              animation: _ctrl,
                              builder: (context, _) => Text(
                                _ctrl.text.trim().isEmpty
                                    ? tr(context, 'Une phrase pour te présenter…')
                                    : _ctrl.text.trim(),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  fontStyle: _ctrl.text.trim().isEmpty
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                  color: t.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                TextField(
                  controller: _ctrl,
                  maxLines: 3,
                  maxLength: 140,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: tr(context, 'Une phrase pour te présenter…'),
                    filled: true,
                    fillColor: t.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(context, 'Quelques idées pour démarrer :'),
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: t.textMuted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in _suggestions(context))
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => setState(() {
                          _ctrl.text = s;
                          _ctrl.selection = TextSelection.collapsed(offset: s.length);
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: widget.acces.couleur.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.acces.couleur.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.acces.couleur,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: UniverseColors.brandGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () =>
                            Navigator.of(context).pop(_ctrl.text.trim()),
                        child: Center(
                          child: Text(
                            tr(context, 'Enregistrer'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
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
