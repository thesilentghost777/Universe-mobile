import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_state.dart';
import '../../core/auth/role_access.dart';
import '../../core/i18n/locale_controller.dart';

/// Feuille « Mode Test » — ouvre une session simulée pour n'importe quel
/// rôle, sans back ni compte. Toutes les données affichées ensuite sont
/// fictives (voir `DemoContent`) et repartent de zéro à la déconnexion.
Future<void> ouvrirModeDemo(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0B1220),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _DemoModeSheet(),
  );
}

class _RoleDemo {
  const _RoleDemo(this.cle, this.rang, this.sousTitre);

  /// Clé passée à `AuthNotifier.simulerRole` (peut différer du rang pour
  /// l'enseignant en attente de validation).
  final String cle;
  final Rang rang;
  final String sousTitre;
}

class _DemoModeSheet extends ConsumerStatefulWidget {
  const _DemoModeSheet();

  @override
  ConsumerState<_DemoModeSheet> createState() => _DemoModeSheetState();
}

class _DemoModeSheetState extends ConsumerState<_DemoModeSheet> {
  static const _roles = [
    _RoleDemo('etudiant', Rang.etudiant,
        'Consulte les canaux, la biblio, UniTube et la messagerie.'),
    _RoleDemo('tuteur', Rang.tuteur,
        'Groupe TDS, publication de vidéos, tableau de bord dédié.'),
    _RoleDemo('formateur', Rang.formateur,
        'Espace créateur : publier, statistiques, abonnés.'),
    _RoleDemo('enseignant', Rang.enseignant,
        'Accréditation validée : interface dédiée, messagerie ouverte.'),
    _RoleDemo('enseignant_attente', Rang.enseignant,
        'Dossier en cours d\'examen : compte limité, bandeaux de statut.'),
    _RoleDemo('moderateur', Rang.moderateur,
        'Signalements reçus, modération des contenus.'),
  ];

  String? _chargement;

  Future<void> _choisir(_RoleDemo role) async {
    if (_chargement != null) return;
    setState(() => _chargement = role.cle);
    await ref.read(authNotifierProvider.notifier).simulerRole(role.cle);
    if (!mounted) return;
    // Le routeur est capturé avant de fermer la feuille : après le `pop`,
    // ce `context` est démonté et ne peut plus servir aux lookups.
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go('/app');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.science_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, 'Mode Test'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        tr(context,
                            'Explore l\'application avec des données fictives, '
                            'sans compte ni serveur.'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final role in _roles) _tuile(role),
          ],
        ),
      ),
    );
  }

  Widget _tuile(_RoleDemo role) {
    final acces = RoleAccess(
      role.rang,
      badgeEnseignant: role.cle == 'enseignant',
    );
    final enAttente = role.cle == 'enseignant_attente';
    final libelle = enAttente
        ? '${Rang.enseignant.libelle} — ${tr(context, 'en attente')}'
        : role.rang.libelle;
    final couleur = enAttente ? const Color(0xFF9CA3AF) : acces.couleur;
    final chargement = _chargement == role.cle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _choisir(role),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: couleur.withValues(alpha: 0.18),
                  ),
                  child: Icon(
                    enAttente ? Icons.hourglass_top_rounded : acces.icone,
                    size: 19,
                    color: couleur,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        libelle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr(context, role.sousTitre),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (chargement)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
