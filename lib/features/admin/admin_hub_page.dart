import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/widgets/universe_glass.dart';
import '../../core/widgets/universe_ui.dart';

/// Espace Modérateur — signalements reçus, en cours et déjà traités.
///
/// Repensé avec un bandeau de statistiques et deux onglets (en attente /
/// historique) plutôt qu'une liste plate unique (§ retour utilisateur :
/// une interface plus belle, plus dynamique, avec des statistiques).
class AdminHubPage extends ConsumerStatefulWidget {
  const AdminHubPage({super.key});

  @override
  ConsumerState<AdminHubPage> createState() => _AdminHubPageState();
}

class _AdminHubPageState extends ConsumerState<AdminHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  List<Map<String, dynamic>> _signalements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);
    try {
      final sig = await api.get('/signalements/recus');
      final raw = sig.data;
      final list =
          raw is List ? raw : (raw as Map)['items'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _signalements = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateSignalement(String id, String statut) async {
    await ref
        .read(apiClientProvider)
        .patch('/signalements/$id/statut', data: {'statut': statut});
    _load();
  }

  static String _statutDe(Map<String, dynamic> s) =>
      s['statut'] as String? ?? 'nouveau';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final nouveaux = _signalements.where((s) => _statutDe(s) == 'nouveau').length;
    final enCours = _signalements.where((s) => _statutDe(s) == 'en_cours').length;
    final traites = _signalements
        .where((s) => ['traite', 'rejete'].contains(_statutDe(s)))
        .length;
    final enAttente =
        _signalements.where((s) => !['traite', 'rejete'].contains(_statutDe(s))).toList();
    final historique =
        _signalements.where((s) => ['traite', 'rejete'].contains(_statutDe(s))).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Espace Modérateur')),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: '${tr(context, 'En attente')}${enAttente.isEmpty ? '' : ' (${enAttente.length})'}'),
            Tab(text: tr(context, 'Historique')),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Row(
                    children: [
                      _StatMini(label: tr(context, 'Nouveaux'), valeur: nouveaux, couleur: UniverseColors.blue),
                      const SizedBox(width: 10),
                      _StatMini(label: tr(context, 'En cours'), valeur: enCours, couleur: UniverseColors.amber),
                      const SizedBox(width: 10),
                      _StatMini(label: tr(context, 'Traités'), valeur: traites, couleur: UniverseColors.success),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _liste(t, enAttente, tr(context, 'Aucun signalement en attente. Rien à traiter pour le moment.')),
                      _liste(t, historique, tr(context, 'Aucune décision prise pour l\'instant.')),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _liste(UniverseTokens t, List<Map<String, dynamic>> items, String messageVide) {
    return RefreshIndicator(
      onRefresh: _load,
      child: items.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 40),
                UniverseBanner(messageVide),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: items.length,
              itemBuilder: (_, i) => _SignalementCard(
                signalement: items[i],
                onStatut: (statut) => _updateSignalement(items[i]['id'] as String, statut),
              ),
            ),
    );
  }
}

class _StatMini extends StatelessWidget {
  const _StatMini({required this.label, required this.valeur, required this.couleur});

  final String label;
  final int valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassSurface(
        accentColor: couleur,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        borderRadius: 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$valeur', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(fontSize: 10.5, color: context.tokens.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _SignalementCard extends StatelessWidget {
  const _SignalementCard({
    required this.signalement,
    required this.onStatut,
  });

  final Map<String, dynamic> signalement;
  final ValueChanged<String> onStatut;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final titre = signalement['sujet'] as String? ??
        signalement['motif'] as String? ??
        signalement['type'] as String? ??
        tr(context, 'Signalement');
    final description = signalement['description'] as String?;
    final statut = signalement['statut'] as String? ?? 'nouveau';
    final gravite = signalement['gravite'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: t.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: gravite == 'urgente' ? UniverseColors.danger : _PastilleStatut.couleurDe(statut),
            width: 4,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    titre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (gravite == 'urgente') ...[
                  const Icon(Icons.priority_high_rounded,
                      size: 15, color: UniverseColors.danger),
                  const SizedBox(width: 4),
                ],
                _PastilleStatut(statut: statut),
              ],
            ),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: t.textMuted),
              ),
            ],
            if (statut != 'traite' && statut != 'rejete')
              Align(
                alignment: Alignment.centerRight,
                child: PopupMenuButton<String>(
                  onSelected: onStatut,
                  icon: const Icon(Icons.more_horiz_rounded),
                  itemBuilder: (ctx) => [
                    PopupMenuItem(value: 'en_cours', child: Text(tr(ctx, 'Marquer en cours'))),
                    PopupMenuItem(value: 'traite', child: Text(tr(ctx, 'Marquer traité'))),
                    PopupMenuItem(value: 'rejete', child: Text(tr(ctx, 'Rejeter'))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PastilleStatut extends StatelessWidget {
  const _PastilleStatut({required this.statut});

  final String statut;

  static Color couleurDe(String statut) => switch (statut) {
        'traite' => UniverseColors.success,
        'rejete' => UniverseColors.blue,
        'en_cours' => UniverseColors.amber,
        _ => UniverseColors.blue,
      };

  @override
  Widget build(BuildContext context) {
    final (couleur, libelle) = switch (statut) {
      'traite' => (UniverseColors.success, tr(context, 'Traité')),
      'rejete' => (context.tokens.textMuted, tr(context, 'Rejeté')),
      'en_cours' => (UniverseColors.amber, tr(context, 'En cours')),
      _ => (UniverseColors.blue, tr(context, 'Nouveau')),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        libelle,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: couleur,
        ),
      ),
    );
  }
}
