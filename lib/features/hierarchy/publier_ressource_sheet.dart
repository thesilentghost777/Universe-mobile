import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/demo/demo_content.dart';
import '../../core/i18n/locale_controller.dart';

/// Les quatre types de ressource prévus par le cahier des charges (MOD-1).
enum TypeRessource {
  epreuve('epreuve', 'Épreuve', Icons.description_outlined,
      'Sujet d\'examen ou de devoir', FileType.custom),
  texte('texte', 'Texte', Icons.article_outlined,
      'Annonce, consigne ou support écrit', null),
  video('video', 'Vidéo', Icons.videocam_outlined,
      'Enregistrement de cours ou de TD', FileType.video),
  audio('audio', 'Audio', Icons.mic_none_outlined,
      'Enregistrement sonore', FileType.audio);

  const TypeRessource(
      this.cle, this.libelle, this.icone, this.aide, this.filtreFichier);

  final String cle;
  final String libelle;
  final IconData icone;
  final String aide;

  /// `null` = pas de pièce jointe, le contenu est saisi directement.
  final FileType? filtreFichier;

  bool get demandeFichier => filtreFichier != null;
}

/// Publier une ressource dans un canal (MOD-1).
///
/// Le système crée automatiquement le fil de discussion associé — aucune
/// action manuelle n'est requise côté modérateur.
///
/// L'assignation au canal reste vérifiée par le serveur : un modérateur ne
/// peut publier que dans les canaux qui lui sont attribués, et jamais dans
/// une autre université. L'interface n'essaie pas de deviner cette règle,
/// elle affiche proprement le refus s'il tombe.
Future<bool?> ouvrirPublicationRessource(
  BuildContext context, {
  required String canalId,
  String? nomCanal,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PublierRessourceSheet(
      canalId: canalId,
      nomCanal: nomCanal,
    ),
  );
}

class _PublierRessourceSheet extends ConsumerStatefulWidget {
  const _PublierRessourceSheet({required this.canalId, this.nomCanal});

  final String canalId;
  final String? nomCanal;

  @override
  ConsumerState<_PublierRessourceSheet> createState() =>
      _PublierRessourceSheetState();
}

class _PublierRessourceSheetState
    extends ConsumerState<_PublierRessourceSheet> {
  final _titre = TextEditingController();
  final _contenu = TextEditingController();

  TypeRessource _type = TypeRessource.epreuve;
  PlatformFile? _fichier;
  bool _envoi = false;
  String? _etape;

  @override
  void dispose() {
    _titre.dispose();
    _contenu.dispose();
    super.dispose();
  }

  bool get _valide {
    if (_titre.text.trim().isEmpty) return false;
    if (_type.demandeFichier) return _fichier != null;
    return _contenu.text.trim().isNotEmpty;
  }

  Future<void> _choisirFichier() async {
    final fichier = await FilePicker.pickFile(
      type: _type.filtreFichier!,
      allowedExtensions: _type == TypeRessource.epreuve
          ? ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx']
          : null,
    );
    if (fichier == null) return;
    setState(() => _fichier = fichier);
  }

  /// Envoie le fichier sur le stockage objet et renvoie sa clé.
  ///
  /// Reprend exactement le flux déjà utilisé pour les vidéos créateur :
  /// on demande une URL pré-signée, on y dépose le fichier, puis on
  /// transmet la clé au serveur — le fichier ne transite jamais par l'API.
  Future<String?> _televerser(PlatformFile file) async {
    final api = ref.read(apiClientProvider);
    final cle =
        'ressources/${DateTime.now().millisecondsSinceEpoch}_${file.name}';

    final taille = file.lengthSync() ?? await file.length() ?? 0;
    final presign = await api.post('/storage/presign/upload', data: {
      'bucket': 'resources',
      'cle': cle,
      'tailleOctets': taille > 0 ? taille : 1,
      'contentType': _contentType(file.extension),
    });

    final data = Map<String, dynamic>.from(presign.data as Map);
    final url = data['url'] as String? ?? data['postURL'] as String;
    final fields = Map<String, dynamic>.from(
      (data['fields'] ?? data['formData'] ?? const {}) as Map,
    );

    // Mode Test : pas de stockage objet — la clé suffit, l'intercepteur
    // démo enregistre la ressource sans dépôt de fichier.
    if (estCompteDemo(ref.read(authNotifierProvider).user?.id)) {
      return fields['key'] as String? ?? data['cle'] as String? ?? cle;
    }

    final form = FormData.fromMap({
      ...fields,
      // Sur le web, `file.path` n'existe pas : on lit les octets depuis le
      // navigateur. Ailleurs, on lit depuis le disque pour ne pas garder
      // tout le fichier en mémoire.
      'file': file.path != null
          ? await MultipartFile.fromFile(file.path!, filename: file.name)
          : MultipartFile.fromBytes(await file.readAsBytes(),
              filename: file.name),
    });
    await Dio().post(url, data: form);

    return fields['key'] as String? ?? data['cle'] as String? ?? cle;
  }

  Future<void> _publier() async {
    setState(() {
      _envoi = true;
      _etape = _type.demandeFichier
          ? tr(context, 'Envoi du fichier…')
          : tr(context, 'Publication…');
    });

    try {
      String? cleFichier;
      if (_type.demandeFichier && _fichier != null) {
        cleFichier = await _televerser(_fichier!);
        if (mounted) setState(() => _etape = tr(context, 'Publication…'));
      }

      await ref.read(apiClientProvider).post('/ressources', data: {
        'canalId': widget.canalId,
        'type': _type.cle,
        'titre': _titre.text.trim(),
        if (!_type.demandeFichier) 'contenu': _contenu.text.trim(),
        if (cleFichier != null) 'fichierCle': cleFichier,
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(context, 'Ressource publiée. Les étudiants du canal '
              'sont notifiés.')),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _etape = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageErreur(context, e))),
      );
    }
  }

  static String _messageErreur(BuildContext context, Object e) {
    final texte = e.toString();
    if (texte.contains('403')) {
      return tr(context, 'Tu n\'es pas assigné à ce canal. Demande son attribution '
          'à l\'administration de ton université.');
    }
    if (texte.contains('401')) {
      return tr(context, 'Session expirée. Reconnecte-toi pour publier.');
    }
    if (texte.contains('413')) {
      return tr(context, 'Fichier trop volumineux pour être envoyé.');
    }
    return tr(context, 'Publication impossible. Réessaie dans un instant.');
  }

  static String _contentType(String? extension) => switch (extension) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'doc' => 'application/msword',
        'docx' =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'mp4' => 'video/mp4',
        'mp3' => 'audio/mpeg',
        'm4a' => 'audio/mp4',
        _ => 'application/octet-stream',
      };

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                Text(
                  tr(context, 'Publier une ressource'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (widget.nomCanal != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.tag_rounded, size: 15, color: t.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        widget.nomCanal!,
                        style: TextStyle(fontSize: 13, color: t.textMuted),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),

                _Label(tr(context, 'Type de ressource')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final type in TypeRessource.values)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: type == TypeRessource.values.last ? 0 : 8,
                          ),
                          child: _CarteType(
                            type: type,
                            selectionne: _type == type,
                            onTap: () => setState(() {
                              _type = type;
                              _fichier = null;
                            }),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  tr(context, _type.aide),
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
                const SizedBox(height: 18),

                _Label(tr(context, 'Titre')),
                const SizedBox(height: 8),
                TextField(
                  controller: _titre,
                  maxLength: 120,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: tr(context, 'Ex. Épreuve de Physique 101 — session 2025'),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),

                if (_type.demandeFichier) ...[
                  _Label(tr(context, 'Fichier')),
                  const SizedBox(height: 8),
                  _ZoneFichier(
                    fichier: _fichier,
                    type: _type,
                    onChoisir: _choisirFichier,
                    onRetirer: () => setState(() => _fichier = null),
                  ),
                ] else ...[
                  _Label(tr(context, 'Contenu')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _contenu,
                    maxLines: 6,
                    maxLength: 2000,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: tr(context, 'Rédige l\'annonce ou la consigne…'),
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.forum_outlined, size: 15, color: t.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr(context,
                            'Un fil de discussion sera créé automatiquement sous '
                            'cette ressource, où les étudiants pourront poser '
                            'leurs questions.'),
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                ElevatedButton(
                  onPressed: (_valide && !_envoi) ? _publier : null,
                  child: _envoi
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Text(_etape ?? tr(context, 'Publication…')),
                          ],
                        )
                      : Text(tr(context, 'Publier')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CarteType extends StatelessWidget {
  const _CarteType({
    required this.type,
    required this.selectionne,
    required this.onTap,
  });

  final TypeRessource type;
  final bool selectionne;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selectionne
              ? UniverseColors.blue.withValues(alpha: 0.12)
              : t.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectionne ? UniverseColors.blue : t.border,
            width: selectionne ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              type.icone,
              size: 20,
              color: selectionne ? UniverseColors.blue : t.textMuted,
            ),
            const SizedBox(height: 5),
            Text(
              tr(context, type.libelle),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selectionne ? FontWeight.w700 : FontWeight.w500,
                color: selectionne ? UniverseColors.blue : t.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneFichier extends StatelessWidget {
  const _ZoneFichier({
    required this.fichier,
    required this.type,
    required this.onChoisir,
    required this.onRetirer,
  });

  final PlatformFile? fichier;
  final TypeRessource type;
  final VoidCallback onChoisir;
  final VoidCallback onRetirer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (fichier == null) {
      return InkWell(
        onTap: onChoisir,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 26),
          decoration: BoxDecoration(
            color: t.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: UniverseColors.blue.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            children: [
              Icon(type.icone, size: 26, color: UniverseColors.blue),
              const SizedBox(height: 8),
              Text(
                tr(context, 'Choisir un fichier'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: UniverseColors.blue,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: t.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Icon(type.icone, size: 20, color: t.textMuted),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fichier!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _taille(fichier!.lengthSync()),
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRetirer,
            icon: const Icon(Icons.close_rounded, size: 19),
            tooltip: tr(context, 'Retirer'),
          ),
        ],
      ),
    );
  }

  /// `null` quand le sélecteur natif n'a pas annoncé de taille : on préfère
  /// un tiret à une lecture disque pour un simple libellé.
  static String _taille(int? octets) {
    if (octets == null) return '—';
    if (octets < 1024) return '$octets o';
    if (octets < 1024 * 1024) return '${(octets / 1024).toStringAsFixed(0)} Ko';
    return '${(octets / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
}

class _Label extends StatelessWidget {
  const _Label(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Text(
      texte.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: context.tokens.textMuted,
      ),
    );
  }
}
