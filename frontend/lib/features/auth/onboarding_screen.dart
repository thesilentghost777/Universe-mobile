import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/locale_controller.dart';
import '../../shared/models/models.dart';
import 'widgets/auth_scaffold.dart';

/// Orientation post-inscription : université → faculté → filière → niveau.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  List<UniversiteItem> _univs = [];
  Map<String, dynamic>? _arbre;
  String? _univId;
  String? _faculteId;
  String? _filiereId;
  String? _niveauId;
  bool _loading = true;
  bool _loadingArbre = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUnivs();
  }

  Future<void> _loadUnivs() async {
    try {
      final res = await ref.read(apiClientProvider).get('/universites');
      final list = (res.data as List)
          .map((e) => UniversiteItem.fromJson(e as Map<String, dynamic>))
          .where((u) => u.statut == 'actif')
          .toList();
      if (!mounted) return;
      setState(() {
        _univs = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = tr(context, 'Impossible de charger les universités.');
      });
    }
  }

  Future<void> _selectUniv(String id) async {
    setState(() {
      _univId = id;
      _faculteId = null;
      _filiereId = null;
      _niveauId = null;
      _arbre = null;
      _loadingArbre = true;
      _error = null;
    });
    try {
      final res =
          await ref.read(apiClientProvider).get('/universites/$id/arbre');
      if (!mounted) return;
      setState(() {
        _arbre = res.data as Map<String, dynamic>;
        _loadingArbre = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingArbre = false;
        _error = tr(context, 'Structure de cette université indisponible.');
      });
    }
  }

  List<Map<String, dynamic>> get _facultes =>
      (_arbre?['facultes'] as List? ?? []).cast<Map<String, dynamic>>();

  List<Map<String, dynamic>> get _filieres {
    final fac = _facultes.where((f) => f['id'] == _faculteId).toList();
    if (fac.isEmpty) return [];
    return (fac.first['filieres'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> get _niveaux {
    final fil = _filieres.where((f) => f['id'] == _filiereId).toList();
    if (fil.isEmpty) return [];
    return (fil.first['niveaux'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<void> _finish() async {
    if (_niveauId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(authNotifierProvider.notifier).setNiveau(_niveauId!);
      if (mounted) context.go('/app');
    } catch (_) {
      if (mounted) {
        setState(() => _error = tr(context, 'Enregistrement impossible.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: tr(context, 'Ton orientation'),
      subtitle: tr(context, 'Choisis ton université, ta filière et ton niveau pour '
          'recevoir les bons contenus.'),
      onBack: () async {
        await ref.read(authNotifierProvider.notifier).logout();
        if (context.mounted) context.go('/login');
      },
      progress: _niveauId != null
          ? 1
          : _filiereId != null
              ? 0.75
              : _faculteId != null
                  ? 0.5
                  : _univId != null
                      ? 0.3
                      : 0.1,
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          _Section(
            'Université',
            child: _Chips(
              options: [for (final u in _univs) (u.id, u.nom)],
              selected: _univId,
              onSelect: _selectUniv,
            ),
          ),
          if (_loadingArbre)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_arbre != null && _facultes.isNotEmpty) ...[
            const SizedBox(height: 18),
            _Section(
              'Faculté',
              child: _Chips(
                options: [
                  for (final f in _facultes)
                    (f['id'] as String, f['nom'] as String? ?? '—'),
                ],
                selected: _faculteId,
                onSelect: (v) => setState(() {
                  _faculteId = v;
                  _filiereId = null;
                  _niveauId = null;
                }),
              ),
            ),
          ],
          if (_faculteId != null && _filieres.isNotEmpty) ...[
            const SizedBox(height: 18),
            _Section(
              'Filière',
              child: _Chips(
                options: [
                  for (final f in _filieres)
                    (f['id'] as String, f['nom'] as String? ?? '—'),
                ],
                selected: _filiereId,
                onSelect: (v) => setState(() {
                  _filiereId = v;
                  _niveauId = null;
                }),
              ),
            ),
          ],
          if (_filiereId != null && _niveaux.isNotEmpty) ...[
            const SizedBox(height: 18),
            _Section(
              'Niveau',
              child: _Chips(
                options: [
                  for (final n in _niveaux)
                    (n['id'] as String, n['nom'] as String? ?? '—'),
                ],
                selected: _niveauId,
                onSelect: (v) => setState(() => _niveauId = v),
              ),
            ),
          ],
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          AuthErrorBanner(_error!),
        ],
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: tr(context, 'Terminer'),
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _niveauId == null ? null : _finish,
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.titre, {required this.child});

  final String titre;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, titre).toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<(String, String)> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (id, label) in options)
          GestureDetector(
            onTap: () => onSelect(id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: id == selected
                    ? const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF7C3AED)])
                    : null,
                color: id == selected
                    ? null
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: id == selected
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white
                      .withValues(alpha: id == selected ? 1 : 0.75),
                  fontWeight:
                      id == selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
