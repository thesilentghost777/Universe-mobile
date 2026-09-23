import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/widgets/draggable_ai_fab.dart';
import '../../core/widgets/universe_glass.dart';
import '../../core/widgets/universe_skeleton.dart';
import '../../shared/models/models.dart';
import '../signalements/signalement_sheet.dart';

/// Quatre couvertures tiennent sur un écran large. Sur la colonne étroite
/// d'un téléphone (rails compris), quatre colonnes cassent les titres au
/// milieu des mots : on passe à deux.
int _livresParEtagere(double largeur) => largeur < 520 ? 2 : 4;

/// Bibliothèque — les livres posés sur des étagères plutôt qu'une liste plate
/// (§7.2) : couvertures alignées par rangée de 4, ombres portées pour la
/// profondeur, légère animation d'apparition au défilement.
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  List<LivreItem> _livres = [];
  bool _loading = true;
  final _q = TextEditingController();
  final _qFocus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    _qFocus.dispose();
    super.dispose();
  }

  /// Suggestions au fil de la frappe plutôt qu'à la seule validation —
  /// débounce court pour ne pas relancer une recherche à chaque caractère.
  void _chercherAuFilDeLaFrappe(String motCle) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _load(motCle: motCle),
    );
  }

  Future<void> _load({String? motCle}) async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get(
        '/livres',
        queryParameters: {
          if (motCle != null && motCle.isNotEmpty) 'motCle': motCle,
          'limit': 40,
        },
      );
      final raw = res.data;
      final list = raw is List ? raw : (raw as Map)['items'] as List? ?? [];
      setState(() {
        _livres = list
            .map((e) => LivreItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _open(LivreItem livre) async {
    if (livre.fichierCle == null) return;
    try {
      final res = await ref.read(apiClientProvider).post(
        '/storage/presign/download',
        data: {'bucket': 'library', 'cle': livre.fichierCle},
      );
      final url = (res.data as Map)['url'] as String?;
      if (url != null) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'Téléchargement impossible'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final parEtagere = _livresParEtagere(contraintes.maxWidth);
        return _corps(context, parEtagere);
      },
    );
  }

  Widget _corps(BuildContext context, int parEtagere) {
    return Column(
      children: [
        AppBar(
          title: Text(tr(context, 'Bibliothèque')),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              tooltip: tr(context, 'Rechercher'),
              icon: const Icon(Icons.search_rounded),
              onPressed: () => _qFocus.requestFocus(),
            ),
            const SizedBox(width: 8),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _q,
            focusNode: _qFocus,
            decoration: InputDecoration(
              hintText: tr(context, 'Rechercher un livre'),
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: context.tokens.surfaceElevated,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _chercherAuFilDeLaFrappe,
            onSubmitted: (v) => _load(motCle: v),
          ),
        ),
        Expanded(
          child: _loading
              ? const ListTileSkeleton()
              : RefreshIndicator(
                  onRefresh: () => _load(motCle: _q.text),
                  child: _livres.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                tr(context,
                                    'Aucun livre pour l\'instant — les étagères '
                                    'se rempliront au fur et à mesure.'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.tokens.textMuted,
                                ),
                              ),
                            ),
                            for (var i = 0; i < 2; i++)
                              _Etagere(
                                livres: const [],
                                parEtagere: parEtagere,
                                indexEtagere: i,
                                onOuvrir: _open,
                              ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            4,
                            16,
                            24 + DraggableAiFab.degagement,
                          ),
                          itemCount: (_livres.length / parEtagere).ceil(),
                          itemBuilder: (context, etagere) {
                            final debut = etagere * parEtagere;
                            final livres = _livres.sublist(
                              debut,
                              (debut + parEtagere).clamp(0, _livres.length),
                            );
                            return _Etagere(
                              livres: livres,
                              parEtagere: parEtagere,
                              indexEtagere: etagere,
                              onOuvrir: _open,
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

/// Une rangée de livres posée sur un rebord d'étagère.
class _Etagere extends StatelessWidget {
  const _Etagere({
    required this.livres,
    required this.parEtagere,
    required this.indexEtagere,
    required this.onOuvrir,
  });

  final List<LivreItem> livres;
  final int parEtagere;
  final int indexEtagere;
  final ValueChanged<LivreItem> onOuvrir;

  @override
  Widget build(BuildContext context) {
    return _EntreeAnimee(
      delai: Duration(milliseconds: 60 * indexEtagere),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final l in livres)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: _Couverture(livre: l, onTap: () => onOuvrir(l)),
                      ),
                    ),
                  // Complète la rangée avec des emplacements vides visibles
                  // (pas un simple espace blanc) — l'étagère reste lisible
                  // même sans livre, et se remplit au fur et à mesure.
                  for (var i = livres.length; i < parEtagere; i++)
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        child: _EmplacementVide(),
                      ),
                    ),
                ],
              ),
            ),
            const _RebordEtagere(),
          ],
        ),
      ),
    );
  }
}

/// Emplacement vide sur une étagère — un contour discret plutôt qu'un
/// blanc, pour que la forme de l'étagère reste visible tant qu'aucun livre
/// n'y est posé.
class _EmplacementVide extends StatelessWidget {
  const _EmplacementVide();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AspectRatio(
      aspectRatio: 0.68,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(6),
            bottom: Radius.circular(2),
          ),
          border: Border.all(
            color: t.border,
            width: 1.4,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.menu_book_outlined,
            size: 22,
            color: t.textMuted.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// Rebord d'étagère : un simple bandeau avec une ombre portée dessous, dans
/// le même langage glass que le reste de l'app plutôt qu'une texture bois
/// littérale qui jurerait avec le dégradé bleu/violet de marque.
class _RebordEtagere extends StatelessWidget {
  const _RebordEtagere();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            t.surfaceElevated,
            t.surfaceElevated.withValues(alpha: 0.4),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.5 : 0.18),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
    );
  }
}

/// Couverture d'un livre — dégradé propre au titre, ombre, coins arrondis en
/// haut seulement (le livre « repose » sur l'étagère).
class _Couverture extends StatelessWidget {
  const _Couverture({required this.livre, required this.onTap});

  final LivreItem livre;
  final VoidCallback onTap;

  static const _palette = [
    [Color(0xFF3B82F6), Color(0xFF6366F1)],
    [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    [Color(0xFF10B981), Color(0xFF0EA5A5)],
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
    [Color(0xFF0EA5A5), Color(0xFF3B82F6)],
    [Color(0xFFEC4899), Color(0xFF8B5CF6)],
  ];

  List<Color> get _couleurs =>
      _palette[livre.id.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    final couleurs = _couleurs;
    return Pressable(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 0.68,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                  bottom: Radius.circular(2),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: couleurs,
                ),
                boxShadow: [
                  BoxShadow(
                    color: couleurs.last.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Tranche : liseré plus sombre sur le bord gauche, comme
                  // une reliure.
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          color: Colors.black.withValues(alpha: 0.18),
                        ),
                        Expanded(
                          child: Center(
                            child: Icon(
                              Icons.menu_book_rounded,
                              color: Colors.white.withValues(alpha: 0.22),
                              size: 36,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          livre.titre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            height: 1.2,
                          ),
                        ),
                        if (livre.auteur != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            livre.auteur!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  tooltip: tr(context, 'Signaler ce livre'),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.flag_outlined,
                      size: 15, color: Colors.white70),
                  onPressed: () => ouvrirSignalementContenu(
                    context,
                    type: 'livre',
                    cibleId: livre.id,
                    titreContenu: livre.titre,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fondu + léger glissement vers le haut à l'apparition — anime l'étagère
/// une seule fois, pas à chaque rebuild.
class _EntreeAnimee extends StatelessWidget {
  const _EntreeAnimee({required this.child, required this.delai});

  final Widget child;
  final Duration delai;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delai.inMilliseconds),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 16),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
