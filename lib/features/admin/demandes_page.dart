import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/role_access.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/widgets/universe_skeleton.dart';

/// Demandes de statut — dépose une demande et suit son état (ET-6).
///
/// L'approbation se fait désormais depuis le site web d'administration (hors
/// périmètre de l'app mobile) : cet écran ne gère plus que le dépôt et le
/// suivi côté demandeur.
class DemandesPage extends ConsumerStatefulWidget {
  const DemandesPage({super.key});

  @override
  ConsumerState<DemandesPage> createState() => _DemandesPageState();
}

/// Statuts qu'on peut demander via cet écran — jamais « enseignant »
/// (accréditation vérifiée à part, avec CNI + diplôme, dès l'inscription)
/// ni « étudiant » (rang de base, pas un objectif de demande).
const _statutsDemandables = ['tuteur', 'formateur', 'moderateur'];

class _DemandesPageState extends ConsumerState<DemandesPage> {
  List<Map<String, dynamic>> _demandes = [];
  bool _loading = true;
  bool _envoi = false;
  String? _type;
  final _motivation = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _motivation.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res =
          await ref.read(apiClientProvider).get('/demandes-statut/mes-demandes');
      final raw = res.data;
      final list = raw is List ? raw : (raw as Map)['items'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _demandes = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _envoyer() async {
    if (_type == null) return;
    setState(() => _envoi = true);
    try {
      await ref.read(apiClientProvider).post(
        '/demandes-statut',
        data: {
          'type': _type,
          if (_motivation.text.trim().isNotEmpty) 'motif': _motivation.text.trim(),
        },
      );
      _motivation.clear();
      if (mounted) {
        _toast(tr(context, 'Demande envoyée. Tu seras notifié de la décision.'));
      }
      await _load();
    } catch (_) {
      if (mounted) {
        _toast(tr(context, 'Envoi impossible. Tu as peut-être déjà une demande en cours.'));
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;

    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Demander un statut'))),
      body: _loading
          ? const ListTileSkeleton()
          : RefreshIndicator(
              onRefresh: _load,
              child: _vueDemandeur(user),
            ),
    );
  }

  Widget _vueDemandeur(dynamic user) {
    final t = context.tokens;
    final rang = user?.rang as String? ?? 'etudiant';
    final acces = RoleAccess(Rang.depuis(rang));
    final options = _statutsDemandables.where((s) => s != rang).toList();
    _type ??= options.isNotEmpty ? options.first : null;
    final aUneDemandeEnCours =
        _demandes.any((d) => _statut(d) == 'en_attente');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: acces.couleur.withValues(alpha: 0.35)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                acces.couleur.withValues(alpha: 0.16),
                acces.couleur.withValues(alpha: 0.03),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: acces.couleur.withValues(alpha: 0.2),
                ),
                child: Icon(acces.icone, color: acces.couleur),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'Statut actuel'),
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                    Text(
                      _libelleRang(context, rang),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (options.isEmpty)
          _Vide(
            texte: tr(context, 'Il n\'y a pas de nouveau statut à demander depuis ton '
                'rang actuel.'),
          )
        else if (aUneDemandeEnCours)
          _Vide(
            texte: tr(context, 'Ta demande est en cours d\'examen. '
                'Tu ne peux pas en déposer une seconde tant qu\'elle '
                'n\'a pas été traitée.'),
          )
        else ...[
          _SectionTitle(tr(context, 'Nouvelle demande')),
          const SizedBox(height: 4),
          Text(
            tr(context, 'Choisis le statut que tu souhaites obtenir.'),
            style: TextStyle(fontSize: 13, color: t.textMuted),
          ),
          const SizedBox(height: 12),
          _ChoixType(
            options: options,
            valeur: _type!,
            onChange: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 18),
          _SectionTitle(tr(context, 'Motivation')),
          const SizedBox(height: 4),
          TextField(
            controller: _motivation,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: tr(context, 'Explique en quelques lignes pourquoi tu demandes '
                  'ce statut, et ce que tu comptes publier.'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _envoi ? null : _envoyer,
              icon: _envoi
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_envoi ? tr(context, 'Envoi…') : tr(context, 'Envoyer la demande')),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),
        _SectionTitle('${tr(context, 'Mes demandes')} (${_demandes.length})'),
        if (_demandes.isEmpty)
          _Vide(texte: tr(context, 'Tu n\'as encore déposé aucune demande.'))
        else
          ..._demandes.map((d) => _CarteDemande(demande: d)),
      ],
    );
  }

  // ------------------------------------------------------------------ Helpers

  static String _statut(Map<String, dynamic> d) =>
      (d['statut'] as String? ?? 'en_attente').toLowerCase();

  static String _libelleRang(BuildContext context, String rang) => switch (rang) {
        'tuteur' => tr(context, 'Tuteur'),
        'formateur' => tr(context, 'Formateur TDS'),
        'enseignant' => tr(context, 'Enseignant'),
        'moderateur' => tr(context, 'Modérateur'),
        _ => tr(context, 'Étudiant'),
      };
}

String _descriptionStatut(BuildContext context, String cle) => switch (cle) {
      'tuteur' => tr(context, 'Accompagne un groupe d\'étudiants et publie tes propres '
          'vidéos, indépendamment des universités.'),
      'formateur' => tr(context, 'Publie tes propres vidéos pédagogiques sur ton profil '
          'créateur — email uniquement.'),
      'moderateur' => tr(context, 'Traite les signalements et gère les ressources des '
          'canaux qui te sont assignés. Ne publie pas de contenu.'),
      _ => '',
    };

class _ChoixType extends StatelessWidget {
  const _ChoixType({
    required this.options,
    required this.valeur,
    required this.onChange,
  });

  final List<String> options;
  final String valeur;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final cle in options) ...[
          _OptionType(
            cle: cle,
            description: _descriptionStatut(context, cle),
            selectionne: valeur == cle,
            onTap: () => onChange(cle),
          ),
          if (cle != options.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _OptionType extends StatelessWidget {
  const _OptionType({
    required this.cle,
    required this.description,
    required this.selectionne,
    required this.onTap,
  });

  final String cle;
  final String description;
  final bool selectionne;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final acces = RoleAccess(Rang.depuis(cle));
    final couleur = acces.couleur;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selectionne ? couleur.withValues(alpha: 0.10) : t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectionne ? couleur : t.border,
            width: selectionne ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: couleur.withValues(alpha: selectionne ? 0.2 : 0.12),
              ),
              child: Icon(acces.icone, size: 18, color: couleur),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    acces.libelle,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12.5, color: t.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selectionne
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selectionne ? couleur : t.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _CarteDemande extends StatelessWidget {
  const _CarteDemande({required this.demande});

  final Map<String, dynamic> demande;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final statut = (demande['statut'] as String? ?? 'en_attente').toLowerCase();
    final type = demande['type'] as String? ?? 'formateur';
    final message = demande['message'] as String?;
    final auteur = demande['demandeur'] ?? demande['utilisateur'];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    type == 'enseignant'
                        ? tr(context, 'Accréditation enseignant')
                        : tr(context, 'Statut formateur'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _Pastille(statut: statut),
              ],
            ),
            if (auteur is Map) ...[
              const SizedBox(height: 4),
              Text(
                [auteur['prenom'], auteur['nom'], auteur['email']]
                    .whereType<String>()
                    .join(' · '),
                style: TextStyle(fontSize: 12, color: t.textMuted),
              ),
            ],
            if (message != null && message.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({required this.statut});

  final String statut;

  @override
  Widget build(BuildContext context) {
    final (couleur, libelle) = switch (statut) {
      'approuvee' || 'approuve' => (UniverseColors.success, tr(context, 'Approuvée')),
      'refusee' || 'refuse' => (UniverseColors.danger, tr(context, 'Refusée')),
      _ => (UniverseColors.blue, tr(context, 'En attente')),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        libelle,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: couleur,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        texte.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: context.tokens.textMuted,
        ),
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Text(
        texte,
        style: TextStyle(fontSize: 13, color: t.textMuted),
      ),
    );
  }
}
