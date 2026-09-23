import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/demo/demo_content.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/services/media_service.dart';
import '../../core/widgets/universe_glass.dart';
import '../../core/widgets/universe_ui.dart';
import 'creator_surface.dart';

enum _Visibilite { publique, universite }

/// Publication d'une vidéo — écran dédié et soigné (§ retour utilisateur :
/// « une très belle interface designée avec bien plus de détails »),
/// remplace l'ancien formulaire noyé dans le tableau de bord du créateur.
class PublishVideoPage extends ConsumerStatefulWidget {
  const PublishVideoPage({super.key, required this.surface});

  final CreatorSurface surface;

  @override
  ConsumerState<PublishVideoPage> createState() => _PublishVideoPageState();
}

class _PublishVideoPageState extends ConsumerState<PublishVideoPage> {
  final _titre = TextEditingController();
  final _desc = TextEditingController();
  final _matiere = TextEditingController();
  _Visibilite _visibilite = _Visibilite.publique;

  PlatformFile? _miniature;
  Uint8List? _miniatureApercu;
  PlatformFile? _fichierVideo;

  bool _publication = false;
  double _progression = 0;
  String? _status;
  bool _statusEstErreur = false;

  @override
  void dispose() {
    _titre.dispose();
    _desc.dispose();
    _matiere.dispose();
    super.dispose();
  }

  Future<void> _choisirMiniature() async {
    const media = MediaService();
    final res = await media.choisirImage();
    if (!res.estValide) return;
    setState(() {
      _miniature = res.fichier;
      _miniatureApercu = res.octets;
    });
  }

  Future<void> _choisirVideo() async {
    final fichier = await FilePicker.pickFile(type: FileType.video);
    if (fichier == null) return;
    setState(() => _fichierVideo = fichier);
  }

  bool get _pretAPublier =>
      _fichierVideo != null && _titre.text.trim().isNotEmpty && !_publication;

  Future<void> _publier() async {
    final file = _fichierVideo;
    if (file == null) return;
    setState(() {
      _publication = true;
      _progression = 0;
      _status = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final user = ref.read(authNotifierProvider).user;
      final cle = 'videos/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final taille = file.lengthSync() ?? await file.length() ?? 0;
      final presign = await api.post('/storage/presign/upload', data: {
        'bucket': 'resources',
        'cle': cle,
        'tailleOctets': taille > 0 ? taille : 1,
        'contentType': 'video/mp4',
      });
      final data = Map<String, dynamic>.from(presign.data as Map);
      final url = data['url'] as String? ?? data['postURL'] as String;
      final fields = Map<String, dynamic>.from(
        (data['fields'] ?? data['formData'] ?? const {}) as Map,
      );
      final key = fields['key'] as String? ?? data['cle'] as String?;

      if (estCompteDemo(user?.id)) {
        // Mode Test : pas de stockage objet — on simule la progression
        // d'envoi, puis la publication est enregistrée par l'intercepteur
        // démo (la vidéo apparaît réellement dans le fil et « Mes vidéos »).
        for (var i = 1; i <= 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 90));
          if (mounted) setState(() => _progression = i / 10);
        }
      } else {
        final form = FormData.fromMap({
          ...fields,
          // Sur le web, `file.path` n'existe pas : on lit les octets depuis le
          // navigateur. Ailleurs, on lit depuis le disque pour ne pas garder
          // toute la vidéo en mémoire.
          'file': file.path != null
              ? await MultipartFile.fromFile(file.path!, filename: file.name)
              : MultipartFile.fromBytes(await file.readAsBytes(),
                  filename: file.name),
        });
        await Dio().post(
          url,
          data: form,
          onSendProgress: (envoye, total) {
            if (total > 0 && mounted) {
              setState(() => _progression = envoye / total);
            }
          },
        );
      }

      await api.post(widget.surface.endpointPublication, data: {
        'titre': _titre.text.trim(),
        if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
        'sourceObjectKey': key,
        if (_matiere.text.trim().isNotEmpty) 'matiere': _matiere.text.trim(),
        if (_miniature != null) 'miniatureNom': _miniature!.name,
        // Visibilité : pas encore de champ back documenté — transmis à
        // titre indicatif, contrat à confirmer (`visibilite`: 'publique' |
        // 'universite').
        'visibilite': _visibilite.name,
        if (widget.surface == CreatorSurface.tuteur)
          'groupeTdsId': user?.id ?? '',
      });

      if (!mounted) return;
      setState(() {
        _publication = false;
        _status = tr(context, 'Vidéo envoyée — elle apparaîtra dans le fil une fois '
            'traitée.');
        _statusEstErreur = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _publication = false;
        _status = tr(context, 'Échec de la publication. Vérifie ta connexion et réessaie.');
        _statusEstErreur = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final couleur = widget.surface.couleur;

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Nouvelle publication'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // Miniature — grande zone tapable, aperçu 16:9.
          GestureDetector(
            onTap: _publication ? null : _choisirMiniature,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: t.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border),
                  image: _miniatureApercu != null
                      ? DecorationImage(
                          image: MemoryImage(_miniatureApercu!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _miniatureApercu == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: t.textMuted, size: 30),
                          const SizedBox(height: 8),
                          Text(tr(context, 'Ajouter une miniature'),
                              style: TextStyle(color: t.textMuted, fontSize: 13)),
                        ],
                      )
                    : Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          margin: const EdgeInsets.all(10),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit_outlined,
                              size: 16, color: Colors.white),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Fichier vidéo.
          Pressable(
            onTap: _publication ? null : _choisirVideo,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _fichierVideo != null ? couleur : t.border,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: couleur.withValues(alpha: 0.16),
                    ),
                    child: Icon(
                      _fichierVideo != null
                          ? Icons.check_circle_rounded
                          : Icons.video_file_outlined,
                      color: couleur,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _fichierVideo?.name ?? tr(context, 'Choisir le fichier vidéo'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: t.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          SectionLabel(tr(context, 'Détails')),
          const SizedBox(height: 10),
          TextField(
            controller: _titre,
            decoration: InputDecoration(hintText: tr(context, 'Titre de la vidéo')),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _matiere,
            decoration: InputDecoration(hintText: tr(context, 'Matière (optionnelle)')),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _desc,
            maxLines: 4,
            decoration: InputDecoration(hintText: tr(context, 'Description')),
          ),
          const SizedBox(height: 20),

          SectionLabel(tr(context, 'Visibilité')),
          const SizedBox(height: 10),
          UniverseSegmentedRow(
            labels: [
              tr(context, 'Publique'),
              tr(context, 'Université'),
            ],
            icons: const [
              Icons.public_rounded,
              Icons.school_outlined,
            ],
            selectedIndex: _visibilite == _Visibilite.publique ? 0 : 1,
            onSelect: (i) => setState(() {
              _visibilite =
                  i == 0 ? _Visibilite.publique : _Visibilite.universite;
            }),
          ),
          const SizedBox(height: 26),

          if (_publication) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progression > 0 ? _progression : null,
                minHeight: 6,
                color: couleur,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _progression > 0
                  ? '${tr(context, 'Envoi…')} ${(_progression * 100).toStringAsFixed(0)} %'
                  : tr(context, 'Préparation de l\'envoi…'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: t.textMuted),
            ),
            const SizedBox(height: 14),
          ],

          UniversePrimaryButton(
            label: tr(context, 'Publier'),
            icon: Icons.rocket_launch_outlined,
            loading: _publication,
            onPressed: _pretAPublier ? _publier : null,
          ),
          if (_status != null) ...[
            const SizedBox(height: 14),
            UniverseBanner(
              _status!,
              tone: _statusEstErreur ? BannerTone.danger : BannerTone.success,
              action: _statusEstErreur
                  ? null
                  : TextButton(
                      onPressed: () => context.pop(),
                      child: Text(tr(context, 'Retour')),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
