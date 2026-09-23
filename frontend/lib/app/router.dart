import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_state.dart';
import '../core/auth/role_access.dart';
import '../core/i18n/locale_controller.dart';
import '../features/auth/auth_choice_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/verify_email_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/roles/role_console_page.dart';
import '../features/help/help_page.dart';
import '../features/creator/creator_surface.dart';
import '../features/creator/creator_videos_page.dart';
import '../features/creator/creator_stats_page.dart';
import '../features/creator/creator_followers_page.dart';
import '../features/creator/publish_video_page.dart';
import '../features/home/app_shell.dart';
import '../features/videos/video_detail_page.dart';
import '../features/search/global_search_page.dart';
import '../features/messaging/messages_page.dart';
import '../features/creator/creator_hub_page.dart';
import '../features/admin/admin_hub_page.dart';
import '../features/admin/demandes_page.dart';
import '../features/profile/profil_page.dart';
import '../features/messaging/contacts_store.dart';
import '../shared/models/models.dart';

/// Un seul GoRouter (pas de recreation a chaque changement d'auth).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authNotifierProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  CreatorSurface surfaceActuelle() =>
      CreatorSurfaceX.depuis(Rang.depuis(ref.read(authNotifierProvider).user?.rang));

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;

      // Le lancement gère lui-même sa sortie : on ne le redirige jamais,
      // sinon l'animation serait coupée dès que /auth/me répond.
      if (loc == '/') return null;

      final public =
          loc == '/login' || loc == '/register' || loc == '/verify-email';

      // Pendant le bootstrap : laisser /login visible (pas d'ecran vide).
      if (auth.status == AuthStatus.unknown) {
        return public ? null : '/login';
      }

      if (auth.status == AuthStatus.unauthenticated) {
        return public ? null : '/login';
      }

      final user = auth.user;
      if (user != null && user.needsOnboarding) {
        if (loc == '/onboarding') return null;
        return '/onboarding';
      }

      if (public) return '/app';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      // Entree par defaut : Google, telephone ou email (code a 6 chiffres).
      GoRoute(path: '/login', builder: (_, __) => const AuthChoiceScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/verify-email',
        builder: (_, state) => VerifyEmailScreen(
          initialToken: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(path: '/app', builder: (_, __) => const AppShell()),
      GoRoute(
        path: '/app/search',
        builder: (_, __) => const GlobalSearchPage(),
      ),
      GoRoute(
        path: '/app/video/:id',
        builder: (context, state) {
          final video = state.extra as VideoItem?;
          if (video == null) {
            return Scaffold(
              body: Center(child: Text(tr(context, 'Vidéo introuvable'))),
            );
          }
          return VideoDetailPage(video: video);
        },
      ),
      GoRoute(
        path: '/app/groupe-tds',
        builder: (_, __) => const CreatorVideosPage(
          surface: CreatorSurface.tuteur,
          infoBanner: 'Ton groupe est indépendant des universités. Tes '
              'vidéos sont visibles par les étudiants et les modérateurs — '
              'pas par les formateurs TDS ni les enseignants.',
        ),
      ),
      GoRoute(
        path: '/app/groupe-tds/publier',
        builder: (_, __) => const PublishVideoPage(surface: CreatorSurface.tuteur),
      ),
      GoRoute(
        path: '/app/groupe-tds/stats',
        builder: (_, __) => const CreatorStatsPage(surface: CreatorSurface.tuteur),
      ),
      GoRoute(
        path: '/app/groupe-tds/abonnes',
        builder: (_, __) => const CreatorFollowersPage(surface: CreatorSurface.tuteur),
      ),
      GoRoute(
        path: '/app/creator/publier',
        builder: (_, __) => PublishVideoPage(surface: surfaceActuelle()),
      ),
      GoRoute(
        path: '/app/creator/videos',
        builder: (_, __) => CreatorVideosPage(surface: surfaceActuelle()),
      ),
      GoRoute(
        path: '/app/creator/stats',
        builder: (_, __) => CreatorStatsPage(surface: surfaceActuelle()),
      ),
      GoRoute(
        path: '/app/creator/abonnes',
        builder: (_, __) => CreatorFollowersPage(surface: surfaceActuelle()),
      ),
      // Section Aide (notes UI) — contenu statique, sans appel reseau.
      GoRoute(
        path: '/app/aide/faq',
        builder: (_, __) => const HelpPage(section: SectionAide.faq),
      ),
      GoRoute(
        path: '/app/aide/fonctionnalites',
        builder: (_, __) =>
            const HelpPage(section: SectionAide.fonctionnalites),
      ),
      GoRoute(
        path: '/app/aide/confidentialite',
        builder: (_, __) =>
            const HelpPage(section: SectionAide.confidentialite),
      ),
      // Console adaptee au rang : ouverte depuis le rail de gauche.
      GoRoute(
        path: '/app/console',
        builder: (_, __) => const RoleConsolePage(),
      ),
      // Ouverte depuis le bouton conversations du rail de gauche.
      // MessagesPage a été écrite comme onglet (elle renvoie une Column avec
      // son propre AppBar) : le Scaffold lui fournit le fond et le Material
      // qui lui manquent en route poussée. Son AppBar affiche alors seule la
      // flèche de retour, puisque la route est empilable.
      GoRoute(
        path: '/app/messages',
        builder: (_, __) => const Scaffold(
          body: MessagesPage(embedded: false),
        ),
      ),
      GoRoute(
        path: '/app/conversation/:id',
        builder: (_, state) => ConversationPage(
          conversationId: state.pathParameters['id']!,
          contactRepli: state.extra as Contact?,
        ),
      ),
      GoRoute(
        path: '/app/creator',
        builder: (_, __) => const CreatorHubPage(),
      ),
      GoRoute(
        path: '/app/admin',
        builder: (_, __) => const AdminHubPage(),
      ),
      GoRoute(
        path: '/app/demandes',
        builder: (_, __) => const DemandesPage(),
      ),
      // Profil consultable (§7.4) — ouvert avec le Contact déjà connu comme
      // repli d'affichage pendant que /utilisateurs/:id répond.
      GoRoute(
        path: '/app/profil/:id',
        builder: (_, state) {
          final contact = state.extra as Contact?;
          return ProfilPage(
            id: state.pathParameters['id']!,
            nomRepli: contact?.nom ?? '',
            rangRepli: contact?.rang,
            photoUrlRepli: contact?.photoUrl,
          );
        },
      ),
    ],
  );
});
