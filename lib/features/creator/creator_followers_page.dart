import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/widgets/universe_skeleton.dart';
import '../../core/widgets/universe_ui.dart';
import '../../shared/models/models.dart';
import 'creator_surface.dart';

/// Liste des abonnés du compte créateur.
/// `GET /comptes-createurs/moi/abonnes` → liste d'abonnés au même format
/// que [ConversationItem] (destinataireNom, destinatairePhotoUrl,
/// destinataireRang).
class CreatorFollowersPage extends ConsumerStatefulWidget {
  const CreatorFollowersPage({super.key, required this.surface});

  final CreatorSurface surface;

  @override
  ConsumerState<CreatorFollowersPage> createState() => _CreatorFollowersPageState();
}

class _CreatorFollowersPageState extends ConsumerState<CreatorFollowersPage> {
  List<ConversationItem> _abonnes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res =
          await ref.read(apiClientProvider).get('/comptes-createurs/moi/abonnes');
      final raw = res.data;
      final list = raw is List ? raw : (raw as Map)['items'] as List? ?? [];
      setState(() {
        _abonnes = list
            .map((e) => ConversationItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text('${tr(context, 'Mes abonnés')} (${_abonnes.length})')),
      body: _loading
          ? const ListTileSkeleton()
          : RefreshIndicator(
              onRefresh: _load,
              child: _abonnes.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 60),
                        UniverseEmptyState(
                          icon: Icons.people_outline,
                          title: tr(context, 'Pas encore d\'abonné'),
                          message: '${tr(context, 'Dès que quelqu\'un suivra')} '
                              '${widget.surface == CreatorSurface.tuteur ? tr(context, 'ton groupe') : tr(context, 'ton compte')}'
                              '${tr(context, ', il apparaîtra ici.')}',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _abonnes.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, indent: 78, color: t.border),
                      itemBuilder: (_, i) {
                        final c = _abonnes[i];
                        return ListTile(
                          leading: UniverseAvatar(
                            initiale: c.destinataireNom ?? '?',
                            photoUrl: c.destinatairePhotoUrl,
                            radius: 22,
                            backgroundColor: t.surfaceElevated,
                          ),
                          title: Text(c.destinataireNom ?? tr(context, 'Abonné')),
                          subtitle: c.destinataireRang != null
                              ? Text(c.destinataireRang!, style: TextStyle(color: t.textMuted))
                              : null,
                        );
                      },
                    ),
            ),
    );
  }
}
