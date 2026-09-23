import 'package:flutter_test/flutter_test.dart';
import 'package:universe_frontend/core/auth/auth_state.dart';
import 'package:universe_frontend/shared/models/models.dart';

void main() {
  group('Routing & Redirect Logic Tests', () {
    String? computeRedirect({
      required AuthStatus authStatus,
      required UserProfile? user,
      required String matchedLocation,
    }) {
      if (matchedLocation == '/') return null;

      final public = matchedLocation == '/login' ||
          matchedLocation == '/register' ||
          matchedLocation == '/verify-email';

      if (authStatus == AuthStatus.unknown || authStatus == AuthStatus.unauthenticated) {
        return public ? null : '/login';
      }

      if (user != null && user.needsOnboarding) {
        if (matchedLocation == '/onboarding') return null;
        return '/onboarding';
      }

      if (public) return '/app';
      return null;
    }

    test('Initial splash route is not redirected', () {
      final res = computeRedirect(
        authStatus: AuthStatus.unknown,
        user: null,
        matchedLocation: '/',
      );
      expect(res, isNull);
    });

    test('Unauthenticated user attempting private route is redirected to /login', () {
      final res = computeRedirect(
        authStatus: AuthStatus.unauthenticated,
        user: null,
        matchedLocation: '/app',
      );
      expect(res, '/login');

      final res2 = computeRedirect(
        authStatus: AuthStatus.unauthenticated,
        user: null,
        matchedLocation: '/app/console',
      );
      expect(res2, '/login');
    });

    test('Unauthenticated user accessing public auth pages is allowed', () {
      expect(
        computeRedirect(
          authStatus: AuthStatus.unauthenticated,
          user: null,
          matchedLocation: '/login',
        ),
        isNull,
      );

      expect(
        computeRedirect(
          authStatus: AuthStatus.unauthenticated,
          user: null,
          matchedLocation: '/register',
        ),
        isNull,
      );

      expect(
        computeRedirect(
          authStatus: AuthStatus.unauthenticated,
          user: null,
          matchedLocation: '/verify-email',
        ),
        isNull,
      );
    });

    test('Student without niveau is redirected to /onboarding', () {
      const studentNoNiveau = UserProfile(
        id: '1',
        email: 'e@u.cm',
        nom: 'Etu',
        prenom: 'Diant',
        rang: 'etudiant',
        niveauId: null,
      );

      final res = computeRedirect(
        authStatus: AuthStatus.authenticated,
        user: studentNoNiveau,
        matchedLocation: '/app',
      );
      expect(res, '/onboarding');

      final onOnboarding = computeRedirect(
        authStatus: AuthStatus.authenticated,
        user: studentNoNiveau,
        matchedLocation: '/onboarding',
      );
      expect(onOnboarding, isNull);
    });

    test('Authenticated user on public page is redirected to /app', () {
      const studentWithNiveau = UserProfile(
        id: '2',
        email: 'e2@u.cm',
        nom: 'Etu',
        prenom: 'Diant',
        rang: 'etudiant',
        niveauId: 'niv-123',
      );

      final res = computeRedirect(
        authStatus: AuthStatus.authenticated,
        user: studentWithNiveau,
        matchedLocation: '/login',
      );
      expect(res, '/app');
    });

    test('Authenticated user accessing private app routes is allowed directly', () {
      const moderateur = UserProfile(
        id: '3',
        email: 'mod@u.cm',
        nom: 'Modo',
        prenom: 'Rateur',
        rang: 'moderateur',
      );

      final res = computeRedirect(
        authStatus: AuthStatus.authenticated,
        user: moderateur,
        matchedLocation: '/app/admin',
      );
      expect(res, isNull);
    });
  });
}
