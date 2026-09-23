import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/role_access.dart';
import '../../core/i18n/locale_controller.dart';
import '../signalements/signalement_sheet.dart';
import 'contacts_store.dart';

/// Ouvre une conversation avec [contact], en respectant la matrice §4.2.
///
/// Si la règle interdit la messagerie directe vers ce rang, on n'essaie même
/// pas d'appeler le serveur : on bascule vers le formulaire de signalement,
/// ou on explique pourquoi le contact est impossible. Le cahier des charges
/// (DV-03) demande que l'interface **ne propose pas** une conversation qui
/// serait de toute façon refusée.
Future<void> ouvrirConversationAvec(
  BuildContext context,
  WidgetRef ref,
  Contact contact,
) async {
  if (ref.read(blockedContactsProvider.notifier).estBloque(contact.id)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(context,
                'Tu as bloqué ce compte — débloque-le depuis Paramètres > '
                'Confidentialité pour lui écrire à nouveau.'),
          ),
        ),
      );
    }
    return;
  }

  final moi = RoleAccess.depuis(ref.read(authNotifierProvider).user);
  final cible = Rang.depuis(contact.rang);
  final mode = moi.modeContactVers(cible);

  switch (mode) {
    case ModeContact.signalement:
      await ouvrirSignalementProbleme(context, destinataireId: contact.id);
      return;

    case ModeContact.interdit:
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(context, 'La messagerie directe n\'est pas ouverte vers ce rôle.'),
            ),
          ),
        );
      }
      return;

    case ModeContact.conversation:
    case ModeContact.fenetreReponse:
      break;
  }

  try {
    final res = await ref.read(apiClientProvider).post(
      '/conversations',
      data: {'destinataireId': contact.id},
    );
    final id = (res.data as Map)['id'] as String;
    if (context.mounted) {
      context.push('/app/conversation/$id', extra: contact);
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(context, 'Conversation refusée par le serveur.')),
        ),
      );
    }
  }
}

/// Feuille « Nouveau message » — remplace la saisie d'identifiant brut.
Future<void> ouvrirNouveauMessage(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _NouveauMessageSheet(),
  );
}

class _NouveauMessageSheet extends ConsumerStatefulWidget {
  const _NouveauMessageSheet();

  @override
  ConsumerState<_NouveauMessageSheet> createState() =>
      _NouveauMessageSheetState();
}

class _NouveauMessageSheetState
    extends ConsumerState<_NouveauMessageSheet> {
  final _recherche = TextEditingController();
  final _identifiant = TextEditingController();
  bool _saisieId = false;
  List<Contact> _distants = const [];
  bool _rechercheServeur = false;

  @override
  void dispose() {
    _recherche.dispose();
    _identifiant.dispose();
    super.dispose();
  }

  Future<void> _chercherServeur(String motCle) async {
    if (motCle.trim().length < 2) {
      setState(() {
        _distants = const [];
        _rechercheServeur = false;
      });
      return;
    }
    setState(() => _rechercheServeur = true);
    try {
      final res = await ref.read(apiClientProvider).get(
        '/utilisateurs/recherche',
        queryParameters: {'motCle': motCle.trim(), 'limit': 20},
      );
      final raw = res.data;
      final list = raw is List ? raw : (raw as Map)['items'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _distants = list.map((e) {
          final m = e as Map<String, dynamic>;
          final nom = '${m['prenom'] ?? ''} ${m['nom'] ?? ''}'.trim();
          return Contact(
            id: m['id'] as String,
            nom: nom.isEmpty ? 'Utilisateur' : nom,
            rang: m['rang'] as String?,
          );
        }).toList();
        _rechercheServeur = false;
      });
    } catch (_) {
      if (mounted) setState(() => _rechercheServeur = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final user = ref.watch(authNotifierProvider).user;
    final moi = RoleAccess.depuis(user);
    final tous = ref.watch(contactsProvider);
    final clavier = MediaQuery.viewInsetsOf(context).bottom;

    final q = _recherche.text.trim().toLowerCase();
    final locaux = q.isEmpty
        ? tous
        : tous.where((c) => c.nom.toLowerCase().contains(q)).toList();
    final idsLocaux = locaux.map((c) => c.id).toSet();
    final resultats = [
      ...locaux,
      ..._distants.where((c) => !idsLocaux.contains(c.id)),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: clavier),
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr(context, 'Nouveau message'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  tr(context, 'Cherche un nom, ou choisis quelqu\'un déjà croisé.'),
                  style: TextStyle(fontSize: 13, color: t.textMuted),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _recherche,
                  onChanged: (v) {
                    setState(() {});
                    _chercherServeur(v);
                  },
                  decoration: InputDecoration(
                    hintText: tr(context, 'Rechercher un nom'),
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _rechercheServeur && resultats.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : resultats.isEmpty
                    ? _Vide(recherche: q.isNotEmpty)
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: resultats.length,
                        itemBuilder: (context, i) {
                          final c = resultats[i];
                          final acces = RoleAccess(Rang.depuis(c.rang));
                          final mode =
                              moi.modeContactVers(Rang.depuis(c.rang));
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  acces.couleur.withValues(alpha: 0.20),
                              child: Text(
                                c.nom.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: acces.couleur,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            title: Text(c.nom),
                            subtitle: Text(
                              _sousTitre(context, mode, acces),
                              style:
                                  TextStyle(fontSize: 12, color: t.textMuted),
                            ),
                            trailing: Icon(
                              switch (mode) {
                                ModeContact.signalement => Icons.flag_outlined,
                                ModeContact.interdit => Icons.block,
                                _ => Icons.chevron_right_rounded,
                              },
                              size: 19,
                              color: mode == ModeContact.interdit
                                  ? t.textMuted
                                  : null,
                            ),
                            onTap: () async {
                              await ref.read(contactsProvider.notifier).memoriser(c);
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                              await ouvrirConversationAvec(context, ref, c);
                            },
                          );
                        },
                      ),
              ),

              // Repli : coller un identifiant, utile en test ou quand la
              // personne n'a encore rien écrit dans un fil.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_saisieId)
                      TextButton.icon(
                        onPressed: () => setState(() => _saisieId = true),
                        icon: const Icon(Icons.tag, size: 17),
                        label: Text(tr(context, 'Utiliser un identifiant')),
                      )
                    else ...[
                      TextField(
                        controller: _identifiant,
                        decoration: InputDecoration(
                          hintText: tr(context, 'Identifiant du destinataire'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final id = _identifiant.text.trim();
                            if (id.isEmpty) return;
                            // Traduit avant l'appel réseau : `context` ne
                            // doit pas être utilisé après un `await` sans
                            // revérifier `mounted`.
                            final utilisateurParDefaut = tr(context, 'Utilisateur');
                            // Le rang réel doit venir du serveur : le
                            // supposer (ex. « étudiant » par défaut) ouvre
                            // la messagerie vers un rang qu'on n'a pas le
                            // droit de contacter directement (DV-03).
                            Contact? contact;
                            try {
                              final res = await ref
                                  .read(apiClientProvider)
                                  .get('/utilisateurs/$id');
                              final data = res.data as Map<String, dynamic>;
                              final nom = [data['prenom'], data['nom']]
                                  .whereType<String>()
                                  .join(' ')
                                  .trim();
                              contact = Contact(
                                id: id,
                                nom: nom.isEmpty ? utilisateurParDefaut : nom,
                                rang: data['rang'] as String?,
                              );
                            } catch (_) {
                              contact = null;
                            }
                            if (!context.mounted) return;
                            if (contact == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(tr(context, 'Identifiant introuvable.')),
                                ),
                              );
                              return;
                            }
                            Navigator.of(context).pop();
                            await ouvrirConversationAvec(
                              context,
                              ref,
                              contact,
                            );
                          },
                          child: Text(tr(context, 'Ouvrir la conversation')),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _sousTitre(BuildContext context, ModeContact mode, RoleAccess acces) =>
      switch (mode) {
        ModeContact.conversation => acces.libelle,
        ModeContact.fenetreReponse =>
          '${acces.libelle} · ${tr(context, "répond sous 24 h")}',
        ModeContact.signalement =>
          '${acces.libelle} · ${tr(context, "par signalement uniquement")}',
        ModeContact.interdit => '${acces.libelle} · ${tr(context, "contact fermé")}',
      };
}

class _Vide extends StatelessWidget {
  const _Vide({required this.recherche});

  final bool recherche;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_outlined, size: 40, color: t.textMuted),
            const SizedBox(height: 14),
            Text(
              recherche
                  ? tr(context, 'Aucun résultat.')
                  : tr(context, 'Personne pour le moment.'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              recherche
                  ? tr(context, 'Essaie un autre nom.')
                  : tr(context,
                      'Ouvre la discussion d\'une ressource : les auteurs des '
                      'messages que tu lis apparaîtront ici.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: t.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
