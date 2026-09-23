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
import '../../core/notifications/notifications_store.dart';
import '../../core/socket/socket_service.dart';
import '../../core/utils/texte_affichage.dart';
import '../../core/widgets/draggable_ai_fab.dart';
import '../../core/widgets/universe_skeleton.dart';
import '../../core/widgets/universe_ui.dart';
import '../../shared/models/models.dart';
import '../library/library_page.dart';
import '../messaging/messages_page.dart';
import '../settings/settings_page.dart';
import '../hierarchy/channel_page.dart';
import '../hierarchy/publier_ressource_sheet.dart';
import '../signalements/signalement_sheet.dart';
import '../tutorial/role_tutorial_steps.dart';
import '../tutorial/tutorial_overlay.dart';
import '../tutorial/tutorial_service.dart';
import '../videos/video_feed_page.dart';
import 'followed_universites.dart';
import 'widgets/canal_rail.dart';
import 'widgets/enseignant_nav_bar.dart';
import 'widgets/floating_nav_bar.dart';
import 'widgets/role_home.dart';
import 'widgets/university_picker_sheet.dart';
import 'widgets/university_rail.dart';

final selectedUniversiteProvider = StateProvider<String?>((_) => null);
final selectedCanalProvider = StateProvider<String?>((_) => null);

/// Navigation directe vers un canal depuis un écran hors d'[AppShell] (ex.
/// résultat de recherche) : renseigné puis consommé une fois par
/// [_AppShellState], qui se charge d'aller chercher l'arbre de
/// l'université avant de sélectionner le canal.
final pendingCanalNavigationProvider =
    StateProvider<({String universiteId, String canalId})?>((_) => null);

/// Incrementé après une publication pour recharger la liste du canal.
final rechargerCanalProvider = StateProvider<int>((_) => 0);

/// Demande de relancer le tutoriel depuis Paramètres > Aide & Support — vu
/// depuis un écran poussé au-dessus d'[AppShell], on ne peut pas y changer
/// d'onglet directement : on revient d'abord à [AppShell] (`pop`), puis on
/// passe par ce provider pour que le tutoriel démarre avec le vrai bascule
/// d'onglets (voir [OngletTutoriel]), comme au premier lancement.
final tutorielRelanceProvider = StateProvider<bool>((_) => false);

/// Les trois visages possibles de l'onglet Accueil (§5.1) : le fil UniTube
/// (défaut pour tous les rôles), l'espace universitaire (arborescence des
/// canaux), et le tableau de bord du rôle pour ceux qui en ont un.
enum VueAccueil { uniTube, universite, monEspace }

/// `null` = valeur par défaut du rôle (UniTube, sauf pour le Tuteur qui
/// atterrit sur son tableau de bord — UniTube est déjà son propre onglet).
final accueilVueProvider = StateProvider<VueAccueil?>((_) => null);

/// Écran principal.
///
/// Deux axes de navigation, comme demandé dans les notes UI :
///   - le **rail de gauche** choisit *où* on est (conversations, université) ;
///   - la **barre flottante du bas** choisit *quoi* on regarde.
///
/// Les conversations quittent la barre du bas pour rejoindre le rail (façon
/// Discord), ce qui libère la place d'UniTube.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

/// Un onglet du footer. Seul le Tuteur voit `_TabKey.uniTube` — pour tous
/// les autres rôles, UniTube est déjà la vue par défaut de l'onglet Accueil
/// (§5.1/§5.2).
enum _TabKey { accueil, biblio, uniTube, messages, parametres }

class _AppShellState extends ConsumerState<AppShell> {
  /// Ordre des onglets du footer selon le rôle.
  List<_TabKey> _tabs(bool estTuteur) => estTuteur
      ? const [
          _TabKey.accueil,
          _TabKey.biblio,
          _TabKey.uniTube,
          _TabKey.messages,
          _TabKey.parametres,
        ]
      : const [
          _TabKey.accueil,
          _TabKey.biblio,
          _TabKey.messages,
          _TabKey.parametres,
        ];

  NavItem _navItem(_TabKey key, int messagesNonLus) => switch (key) {
        _TabKey.accueil => NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: tr(context, 'Accueil'),
          ),
        _TabKey.biblio => NavItem(
            icon: Icons.menu_book_outlined,
            activeIcon: Icons.menu_book_rounded,
            label: tr(context, 'Biblio'),
          ),
        _TabKey.uniTube => NavItem(
            icon: Icons.play_circle_outline,
            activeIcon: Icons.play_circle_fill_rounded,
            label: tr(context, 'UniTube'),
            prominent: true,
          ),
        _TabKey.messages => NavItem(
            icon: Icons.forum_outlined,
            activeIcon: Icons.forum_rounded,
            label: tr(context, 'Messages'),
            badge: messagesNonLus,
          ),
        _TabKey.parametres => NavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: tr(context, 'Paramètres'),
          ),
      };

  int _tab = 0;
  List<UniversiteItem> _univs = [];
  bool _railLoading = true;
  bool _arbreLoading = false;
  Map<String, dynamic>? _arbre;

  @override
  void initState() {
    super.initState();
    _loadRail();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(socketServiceProvider).connect();
      // Alimente la pastille du bouton conversations.
      ref.read(notificationsProvider.notifier).demarrer();
      await _tutorielSiPremiereFois();
    });
  }

  /// Tutoriel guidé (§9) — une fois par rôle, sauf s'il a déjà été vu ou
  /// explicitement relancé depuis les Paramètres.
  Future<void> _tutorielSiPremiereFois() async {
    final user = ref.read(authNotifierProvider).user;
    if (user == null) return;
    final dejaVu = await const TutorialService().aDejaVu(user.id, user.rang);
    if (dejaVu || !mounted) return;
    await _lancerTutoriel(user);
  }

  Future<void> _lancerTutoriel(UserProfile user) async {
    final rang = Rang.depuis(user.rang);
    await demarrerTutoriel(
      context,
      etapes: etapesPour(rang),
      userId: user.id,
      rang: user.rang,
      lent: rang == Rang.enseignant,
      onChangerOnglet: _allerAOnglet,
    );
  }

  /// Bascule réellement d'onglet pendant le tutoriel (voir
  /// [OngletTutoriel]) — le voile n'étant pas opaque, l'utilisateur voit le
  /// vrai contenu de chaque onglet s'afficher derrière le spotlight.
  void _allerAOnglet(OngletTutoriel cible) {
    final estTuteur =
        RoleAccess.depuis(ref.read(authNotifierProvider).user).rang ==
            Rang.tuteur;
    final key = switch (cible) {
      OngletTutoriel.accueil => _TabKey.accueil,
      OngletTutoriel.biblio => _TabKey.biblio,
      OngletTutoriel.uniTube => _TabKey.uniTube,
      OngletTutoriel.messages => _TabKey.messages,
      OngletTutoriel.parametres => _TabKey.parametres,
    };
    final index = _tabs(estTuteur).indexOf(key);
    if (index == -1 || !mounted) return;
    setState(() {
      _tab = index;
      if (key == _TabKey.accueil) {
        ref.read(selectedCanalProvider.notifier).state = null;
      }
    });
  }

  Future<void> _loadRail() async {
    try {
      final res = await ref.read(apiClientProvider).get('/universites');
      final list = (res.data as List)
          .map((e) => UniversiteItem.fromJson(e as Map<String, dynamic>))
          .where((u) => u.statut == 'actif')
          .toList();
      if (!mounted) return;
      setState(() {
        _univs = list;
        _railLoading = false;
      });

      // Premier lancement : on épingle tout, l'utilisateur élaguera ensuite.
      await ref
          .read(followedUniversitesProvider.notifier)
          .seedIfEmpty(list.map((u) => u.id).toList());

      if (!mounted) return;
      final pinned = _pinned(list, ref.read(followedUniversitesProvider));
      if (pinned.isNotEmpty && ref.read(selectedUniversiteProvider) == null) {
        _selectUniv(pinned.first.id);
      }
    } catch (_) {
      if (mounted) setState(() => _railLoading = false);
    }
  }

  /// Universités épinglées, dans l'ordre choisi par l'utilisateur.
  List<UniversiteItem> _pinned(
    List<UniversiteItem> all,
    List<String> followed,
  ) {
    final byId = {for (final u in all) u.id: u};
    return [
      for (final id in followed)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<void> _selectUniv(String id) async {
    ref.read(selectedUniversiteProvider.notifier).state = id;
    ref.read(selectedCanalProvider.notifier).state = null;
    setState(() {
      _tab = 0; // Accueil est toujours le premier onglet, pour tous les rôles.
      _arbre = null;
      _arbreLoading = true;
    });
    try {
      final res =
          await ref.read(apiClientProvider).get('/universites/$id/arbre');
      if (mounted) {
        setState(() {
          _arbre = res.data as Map<String, dynamic>;
          _arbreLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _arbreLoading = false);
    }
  }

  /// Accès direct à un canal depuis la colonne des canaux (§5.1) — pas
  /// besoin de passer par le sélecteur UniTube/Université puis de
  /// descendre l'arborescence.
  void _selectCanalDirect(String canalId) {
    setState(() => _tab = 0);
    ref.read(selectedCanalProvider.notifier).state = canalId;
  }

  void _onNavSelect(int i, List<_TabKey> tabs) {
    final key = tabs[i];
    setState(() {
      _tab = i;
      if (key == _TabKey.accueil) {
        ref.read(selectedCanalProvider.notifier).state = null;
      }
    });
    if (key == _TabKey.messages) {
      // L'onglet ouvert, les messages ne sont plus « non lus ».
      ref
          .read(notificationsProvider.notifier)
          .marquerTypeLu(TypesNotification.nouveauMessageDirect);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingCanalNavigationProvider, (_, next) {
      if (next == null) return;
      setState(() => _tab = 0);
      _selectUniv(next.universiteId).then((_) {
        ref.read(selectedCanalProvider.notifier).state = next.canalId;
      });
      ref.read(pendingCanalNavigationProvider.notifier).state = null;
    });

    ref.listen(tutorielRelanceProvider, (_, next) {
      if (next != true) return;
      ref.read(tutorielRelanceProvider.notifier).state = false;
      final user = ref.read(authNotifierProvider).user;
      if (user != null) _lancerTutoriel(user);
    });

    final followed = ref.watch(followedUniversitesProvider);
    final pinned = _pinned(_univs, followed);
    final selectedUnivId = ref.watch(selectedUniversiteProvider);
    final canalId = ref.watch(selectedCanalProvider);

    // Le raccourci de rôle n'apparaît que pour ceux qui ont réellement des
    // droits au-delà de la consultation : un simple étudiant ne voit rien.
    final acces = RoleAccess.depuis(ref.watch(authNotifierProvider).user);
    final estTuteur = acces.rang == Rang.tuteur;
    // Dossier validé uniquement : un enseignant en attente reste en version
    // étudiante limitée (§3) et n'a donc pas encore droit à cette interface.
    final estEnseignantValide =
        acces.rang == Rang.enseignant && !acces.estEnseignantEnAttente;
    final nonLus = ref.watch(notificationsProvider).messages;
    final console = acces.aUneConsole
        ? RailConsole(
            tooltip: '${tr(context, 'Mon espace')} — ${acces.libelle}',
            icone: acces.icone,
            couleur: acces.couleur,
            onTap: () => context.push('/app/console'),
          )
        : null;

    final tabs = _tabs(estTuteur);
    final tabIndex = _tab.clamp(0, tabs.length - 1);
    final navReserved = estEnseignantValide
        ? EnseignantNavBar.reservedHeight(context, facteur: 1.12)
        : FloatingNavBar.reservedHeight(context);
    final canauxRail = CanalRailItem.depuisArbre(_arbre);
    final montrerCanal = tabs[tabIndex] == _TabKey.accueil &&
        selectedUnivId != null &&
        (_arbreLoading || canauxRail.isNotEmpty);

    Widget scaffold = Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              UniversityRail(
                loading: _railLoading,
                univs: pinned,
                selectedId: selectedUnivId,
                onSelect: _selectUniv,
                // Les conversations sont dans la barre du bas : pas de doublon
                // dans le rail.
                onAddUniversity: () =>
                    showUniversityPicker(context, universites: _univs),
                roleConsole: console,
                bottomInset: navReserved,
              ),
              Expanded(
                child: _ZonePrincipale(
                  railCanaux: montrerCanal
                      ? CanalRail(
                          loading: _arbreLoading,
                          canaux: canauxRail,
                          selectedId: canalId,
                          onSelect: _selectCanalDirect,
                          bottomInset: navReserved,
                        )
                      : null,
                  child: Padding(
                  // Le contenu ne doit pas passer sous la barre flottante.
                  padding: EdgeInsets.only(bottom: navReserved),
                  child: switch (tabs[tabIndex]) {
                    _TabKey.accueil => _AccueilTab(
                        arbre: _arbre,
                        canalId: canalId,
                        universite: _univById(selectedUnivId),
                        railLoading: _railLoading,
                        hasPinned: pinned.isNotEmpty,
                        onAjouterUniversite: () => showUniversityPicker(
                          context,
                          universites: _univs,
                        ),
                      ),
                    _TabKey.biblio => const LibraryPage(),
                    _TabKey.uniTube => const VideoFeedPage(),
                    _TabKey.messages => const MessagesPage(),
                    _TabKey.parametres => const SettingsPage(),
                  },
                ),
              ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: estEnseignantValide
                ? EnseignantNavBar(
                    items: [for (final k in tabs) _navItem(k, nonLus)],
                    currentIndex: tabIndex,
                    onSelect: (i) => _onNavSelect(i, tabs),
                  )
                : FloatingNavBar(
                    items: [for (final k in tabs) _navItem(k, nonLus)],
                    currentIndex: tabIndex,
                    onSelect: (i) => _onNavSelect(i, tabs),
                  ),
          ),
          DraggableAiFab(bottomInset: navReserved),
        ],
      ),
    );

    if (estEnseignantValide) {
      // Interface volontairement séparée (§6) : typographie agrandie sur
      // tout l'écran, sans avoir à retoucher chaque taille de police une à
      // une — public plus âgé, on privilégie la lisibilité au compactage.
      final mq = MediaQuery.of(context);
      final ambiant = mq.textScaler.scale(1.0);
      scaffold = MediaQuery(
        data: mq.copyWith(textScaler: TextScaler.linear(ambiant * 1.12)),
        child: scaffold,
      );
    }

    return scaffold;
  }

  UniversiteItem? _univById(String? id) {
    if (id == null) return null;
    for (final u in _univs) {
      if (u.id == id) return u;
    }
    return null;
  }
}

/// Onglet Accueil : l'espace universitaire.
///
/// Sans canal sélectionné, on affiche l'arborescence de l'université.
/// Avec un canal, on affiche son contenu, précédé d'un en-tête de retour.
class _AccueilTab extends ConsumerWidget {
  const _AccueilTab({
    required this.arbre,
    required this.canalId,
    required this.universite,
    required this.railLoading,
    required this.hasPinned,
    required this.onAjouterUniversite,
  });

  final Map<String, dynamic>? arbre;
  final String? canalId;
  final UniversiteItem? universite;
  final bool railLoading;
  final bool hasPinned;
  final VoidCallback onAjouterUniversite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (canalId != null) {
      final nom = _canalNom(arbre, canalId!);
      final acces = RoleAccess.depuis(ref.watch(authNotifierProvider).user);
      final rechargement = ref.watch(rechargerCanalProvider);

      return Column(
        children: [
          _ChannelHeader(
            title: nom ?? tr(context, 'Canal'),
            onBack: () =>
                ref.read(selectedCanalProvider.notifier).state = null,
            onSignaler: () => ouvrirSignalementProbleme(
              context,
              canalId: canalId,
              nomCanal: nom,
            ),
            // Le bouton n'apparaît que pour les rangs autorisés à publier ;
            // l'assignation exacte au canal reste vérifiée par le serveur.
            onPublier: acces.peutPublierRessource
                ? () async {
                    final publie = await ouvrirPublicationRessource(
                      context,
                      canalId: canalId!,
                      nomCanal: nom,
                    );
                    if (publie == true) {
                      ref.read(rechargerCanalProvider.notifier).state++;
                    }
                  }
                : null,
          ),
          Expanded(
            child: ChannelPage(
              // Change de clé après une publication pour forcer le rechargement.
              key: ValueKey('$canalId-$rechargement'),
              canalId: canalId!,
            ),
          ),
        ],
      );
    }

    // UniTube en accueil pour tous (§5.1), sauf le Tuteur qui a déjà UniTube
    // comme onglet à part (§5.2) : son Accueil reste Mon espace <-> Université.
    final acces = RoleAccess.depuis(ref.watch(authNotifierProvider).user);
    final estTuteur = acces.rang == Rang.tuteur;
    final aUnTableauDeBord = RoleHome.aUnTableauDeBord(acces);

    final options = estTuteur
        ? const [VueAccueil.monEspace, VueAccueil.universite]
        : [
            VueAccueil.uniTube,
            VueAccueil.universite,
            if (aUnTableauDeBord) VueAccueil.monEspace,
          ];
    final defaut = estTuteur ? VueAccueil.monEspace : VueAccueil.uniTube;
    final vue = ref.watch(accueilVueProvider) ?? defaut;

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _VueAccueilToggle(
              options: options,
              valeur: vue,
              couleur: acces.couleur,
              onChange: (v) => ref.read(accueilVueProvider.notifier).state = v,
            ),
          ),
        ),
        Expanded(
          child: switch (vue) {
            VueAccueil.uniTube => const VideoFeedPage(),
            VueAccueil.universite => _espaceUniversitaire(context),
            VueAccueil.monEspace => RoleHome(acces: acces),
          },
        ),
      ],
    );
  }

  /// Espace universitaire : l'arborescence Faculté → … → Canal, ou un état
  /// vide explicite selon ce qui est disponible.
  Widget _espaceUniversitaire(BuildContext context) {
    if (railLoading) return const ListTileSkeleton();

    if (!hasPinned) {
      // Le "+" du rail est compact et facile à manquer (§7.1) : ici, le
      // bouton est pleine largeur et bien contrasté, impossible à rater.
      return UniverseEmptyState(
        icon: Icons.school_outlined,
        title: tr(context, 'Aucune université épinglée'),
        message: tr(context,
            'Ajoute ta première université pour accéder à ses cours, '
            'épreuves et canaux.'),
        action: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: UniversePrimaryButton(
            label: tr(context, 'Ajouter une université'),
            icon: Icons.add_rounded,
            onPressed: onAjouterUniversite,
          ),
        ),
      );
    }

    if (arbre == null) {
      return _EmptyState(
        icon: Icons.account_tree_outlined,
        title: tr(context, 'Espace indisponible'),
        message: tr(context, 'Impossible de charger la structure de cette université.'),
      );
    }

    return _EspaceUniversitaire(arbre: arbre!, universite: universite);
  }

  /// Retrouve le nom d'un canal dans l'arbre, pour l'en-tête.
  static String? _canalNom(Map<String, dynamic>? arbre, String id) {
    if (arbre == null) return null;
    for (final f in (arbre['facultes'] as List? ?? [])) {
      for (final fil in ((f as Map)['filieres'] as List? ?? [])) {
        for (final n in ((fil as Map)['niveaux'] as List? ?? [])) {
          for (final m in ((n as Map)['matieres'] as List? ?? [])) {
            for (final c in ((m as Map)['canaux'] as List? ?? [])) {
              if ((c as Map)['id'] == id) return c['nom'] as String?;
            }
          }
        }
      }
    }
    return null;
  }
}

/// Réserve la largeur compacte du rail de canaux. Ouvert, le rail passe
/// par-dessus le contenu au lieu de le comprimer.
class _ZonePrincipale extends StatelessWidget {
  const _ZonePrincipale({required this.child, this.railCanaux});

  final Widget child;
  final Widget? railCanaux;

  @override
  Widget build(BuildContext context) {
    final rail = railCanaux;
    if (rail == null) return child;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: CanalRail.largeurCompacte),
          child: child,
        ),
        Positioned(left: 0, top: 0, bottom: 0, child: rail),
      ],
    );
  }
}

class _ChannelHeader extends StatelessWidget {
  const _ChannelHeader({
    required this.title,
    required this.onBack,
    required this.onSignaler,
    this.onPublier,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onSignaler;

  /// `null` pour les rangs qui ne publient pas.
  final VoidCallback? onPublier;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      bottom: false,
      child: Container(
        height: 52,
        padding: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.border)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: tr(context, 'Retour à l\'espace'),
            ),
            Icon(Icons.tag_rounded, size: 18, color: t.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (onPublier != null)
              IconButton(
                onPressed: onPublier,
                tooltip: tr(context, 'Publier une ressource'),
                icon: const Icon(Icons.add_circle_outline),
                color: UniverseColors.blue,
              ),
            // Seule voie de contact d'un etudiant vers un moderateur (ET-13).
            IconButton(
              onPressed: onSignaler,
              tooltip: tr(context, 'Signaler un problème'),
              icon: const Icon(Icons.flag_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

/// Arborescence Faculté → Filière → Niveau → Matière → Canal.
///
/// L'ancienne bande horizontale aplatissait tous les canaux d'une université
/// sur une seule ligne : illisible dès qu'une faculté a plusieurs filières.
/// Ici la hiérarchie du cahier des charges est rendue telle quelle.
class _EspaceUniversitaire extends ConsumerWidget {
  const _EspaceUniversitaire({required this.arbre, required this.universite});

  final Map<String, dynamic> arbre;
  final UniversiteItem? universite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final facultes = (arbre['facultes'] as List? ?? []);

    if (facultes.isEmpty) {
      return _EmptyState(
        icon: Icons.account_tree_outlined,
        title: tr(context, 'Espace vide'),
        message: tr(context, 'Cette université n\'a pas encore de structure publiée.'),
      );
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            eviterMotOrphelin(
              universite?.nom ?? tr(context, 'Espace universitaire'),
            ),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(context, 'Choisis un canal pour voir ses épreuves, corrigés et supports.'),
            style: TextStyle(fontSize: 13, color: t.textMuted),
          ),
          const SizedBox(height: 16),
          for (final f in facultes) ..._faculte(context, ref, f as Map),
        ],
      ),
    );
  }

  List<Widget> _faculte(BuildContext context, WidgetRef ref, Map f) {
    final t = context.tokens;
    final filieres = f['filieres'] as List? ?? [];

    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(
          (f['nom'] as String? ?? tr(context, 'Faculté')).toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: t.textMuted,
          ),
        ),
      ),
      for (final fil in filieres)
        for (final n in ((fil as Map)['niveaux'] as List? ?? []))
          _niveau(context, ref, fil, n as Map),
    ];
  }

  Widget _niveau(BuildContext context, WidgetRef ref, Map filiere, Map niveau) {
    final t = context.tokens;
    final matieres = niveau['matieres'] as List? ?? [];
    final titre =
        '${filiere['nom'] ?? tr(context, 'Filière')} · ${niveau['nom'] ?? tr(context, 'Niveau')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Theme(
        // Retire les liserés par défaut de l'ExpansionTile.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.only(bottom: 6),
          leading: Icon(Icons.folder_outlined, color: t.textMuted),
          title: Text(
            titre,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            LocaleScope.of(context)
                ? '${matieres.length} ${matieres.length > 1 ? 'subjects' : 'subject'}'
                : '${matieres.length} matière${matieres.length > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 12, color: t.textMuted),
          ),
          children: [
            for (final m in matieres) _matiere(context, ref, m as Map),
          ],
        ),
      ),
    );
  }

  /// Une matière = une catégorie façon Discord : libellé en petites
  /// capitales, puis ses canaux en rangées pleine largeur (pas des puces en
  /// vrac — plus lisible, et l'icône dédiée remplace le simple « # » que
  /// certains lisaient comme du texte de code plutôt qu'un symbole de
  /// canal).
  Widget _matiere(BuildContext context, WidgetRef ref, Map matiere) {
    final t = context.tokens;
    final canaux = matiere['canaux'] as List? ?? [];
    final nomMatiere = matiere['nom'] as String? ?? tr(context, 'Matière');

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.expand_more_rounded, size: 14, color: t.textMuted),
              const SizedBox(width: 2),
              Text(
                nomMatiere.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: t.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (canaux.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 4),
              child: Text(
                tr(context, 'Aucun canal'),
                style: TextStyle(fontSize: 12, color: t.textMuted),
              ),
            )
          else
            for (final c in canaux)
              _CanalRow(
                nom: (c as Map)['nom'] as String? ?? tr(context, 'Canal'),
                matiere: nomMatiere,
                nonLus: c['nombreNonLus'] as int? ?? 0,
                onTap: () =>
                    ref.read(selectedCanalProvider.notifier).state =
                        c['id'] as String,
              ),
        ],
      ),
    );
  }
}

/// Une rangée de canal, façon Discord : icône carrée arrondie colorée par
/// matière (plutôt qu'un « # » nu), nom, badge de non-lus, chevron.
class _CanalRow extends StatelessWidget {
  const _CanalRow({
    required this.nom,
    required this.matiere,
    required this.onTap,
    this.nonLus = 0,
  });

  final String nom;
  final String matiere;
  final int nonLus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final couleur = UniverseColors.accentFor(matiere);
    final nonLu = nonLus > 0;

    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.forum_rounded, size: 15, color: couleur),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: nonLu ? FontWeight.w800 : FontWeight.w600,
                      color: nonLu ? t.textPrimary : t.textMuted,
                    ),
                  ),
                ),
                if (nonLu) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 20),
                    decoration: const BoxDecoration(
                      gradient: UniverseColors.brandGradient,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Text(
                      nonLus > 99 ? '99+' : '$nonLus',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ] else
                  Icon(Icons.chevron_right_rounded, size: 18, color: t.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bascule entre les visages de l'Accueil (§5.1) : UniTube, Université, et
/// Mon espace pour les rôles qui en ont un. 2 ou 3 segments selon le rôle.
class _VueAccueilToggle extends StatelessWidget {
  const _VueAccueilToggle({
    required this.options,
    required this.valeur,
    required this.couleur,
    required this.onChange,
  });

  final List<VueAccueil> options;
  final VueAccueil valeur;
  final Color couleur;
  final ValueChanged<VueAccueil> onChange;

  static const (IconData, String) _uniTube = (
    Icons.play_circle_outline,
    'UniTube',
  );
  static const (IconData, String) _universite = (
    Icons.account_tree_rounded,
    'Université',
  );
  static const (IconData, String) _monEspace = (
    Icons.dashboard_rounded,
    'Mon espace',
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          for (final option in options)
            _seg(
              context,
              switch (option) {
                VueAccueil.uniTube => _uniTube.$2,
                VueAccueil.universite => _universite.$2,
                VueAccueil.monEspace => _monEspace.$2,
              },
              switch (option) {
                VueAccueil.uniTube => _uniTube.$1,
                VueAccueil.universite => _universite.$1,
                VueAccueil.monEspace => _monEspace.$1,
              },
              valeur == option,
              () => onChange(option),
            ),
        ],
      ),
    );
  }

  /// À l'échelle standard, icône et mot restent sur une ligne. Dès que la
  /// police grandit, le mot passe sous l'icône : il dispose alors de toute
  /// la largeur du segment au lieu d'être écrasé à côté de l'icône.
  Widget _labelSegment(
    BuildContext context,
    String label,
    IconData icon,
    bool actif,
    UniverseTokens t,
  ) {
    final style = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: actif ? couleur : t.textMuted,
    );
    final teinte = actif ? couleur : t.textMuted;
    final texte = tr(context, label);
    if (MediaQuery.textScalerOf(context).scale(1) < 1.12) {
      return UniverseIconLabel(
        icon: icon,
        label: texte,
        iconSize: 15,
        iconColor: teinte,
        style: style,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: teinte),
        const SizedBox(height: 2),
        UniverseFitLabel(
          texte,
          alignment: Alignment.center,
          textAlign: TextAlign.center,
          style: style,
        ),
      ],
    );
  }

  Widget _seg(BuildContext context, String label, IconData icon, bool actif,
      VoidCallback onTap) {
    final t = context.tokens;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
          decoration: BoxDecoration(
            color: actif ? couleur.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: _labelSegment(context, label, icon, actif, t),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: t.textMuted),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: t.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
