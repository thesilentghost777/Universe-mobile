import 'package:flutter_test/flutter_test.dart';
import 'package:universe_frontend/core/auth/auth_state.dart';
import 'package:universe_frontend/core/auth/role_access.dart';
import 'package:universe_frontend/shared/models/models.dart';

void main() {
  group('AuthState & UserProfile Models', () {
    test('UserProfile deserialization with standard fields', () {
      final json = {
        'id': 'usr-123',
        'email': 'etudiant@univ.cm',
        'nom': 'Kamga',
        'prenom': 'Jean',
        'rang': 'etudiant',
        'niveauId': 'niv-001',
        'badgeEnseignant': false,
        'emailVerifie': true,
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'usr-123');
      expect(profile.email, 'etudiant@univ.cm');
      expect(profile.displayName, 'Jean Kamga');
      expect(profile.rang, 'etudiant');
      expect(profile.niveauId, 'niv-001');
      expect(profile.needsOnboarding, isFalse);
      expect(RoleAccess.depuis(profile).peutCreerContenu, isFalse);
    });

    test('UserProfile onboarding requirement detection', () {
      final etudiantSansNiveau = UserProfile.fromJson({
        'id': 'usr-124',
        'nom': 'Nouveau',
        'prenom': 'Etudiant',
        'rang': 'etudiant',
        'niveauId': null,
      });

      expect(etudiantSansNiveau.needsOnboarding, isTrue);

      final formateurSansNiveau = UserProfile.fromJson({
        'id': 'usr-125',
        'nom': 'Prof',
        'prenom': 'Formateur',
        'rang': 'formateur',
        'niveauId': null,
      });

      // Formateurs don't get blocked by student onboarding
      expect(formateurSansNiveau.needsOnboarding, isFalse);
    });

    test('AuthState immutability and copyWith helpers', () {
      const state = AuthState(status: AuthStatus.unauthenticated);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.user, isNull);
      expect(state.error, isNull);

      final updated = state.copyWith(
        status: AuthStatus.authenticated,
        user: const UserProfile(
          id: '1',
          email: 'test@univ.cm',
          nom: 'Test',
          prenom: 'User',
          rang: 'enseignant',
          badgeEnseignant: true,
        ),
      );

      expect(updated.status, AuthStatus.authenticated);
      expect(updated.user?.displayName, 'User Test');
      expect(RoleAccess.depuis(updated.user).peutCreerContenu, isTrue);

      final cleared = updated.copyWith(clearUser: true, clearError: true);
      expect(cleared.user, isNull);
      expect(cleared.error, isNull);
    });
  });

  group('RoleAccess & Hierarchical Permissions Matrix', () {
    test('Student permissions (etudiant)', () {
      final etudiant = RoleAccess.depuis(const UserProfile(
        id: '1',
        email: 'e@u.cm',
        nom: 'Etu',
        prenom: 'Diant',
        rang: 'etudiant',
      ));

      expect(etudiant.peutCreerContenu, isFalse);
      expect(etudiant.peutPublierRessource, isFalse);
      expect(etudiant.peutTraiterSignalements, isFalse);
      expect(etudiant.peutDemanderStatut, isTrue);

      // Messaging Matrix (Section 3.8 CDC)
      expect(etudiant.modeContactVers(Rang.etudiant), ModeContact.conversation);
      expect(etudiant.modeContactVers(Rang.tuteur), ModeContact.conversation);
      expect(etudiant.modeContactVers(Rang.formateur), ModeContact.conversation);
      expect(etudiant.modeContactVers(Rang.enseignant), ModeContact.fenetreReponse);
      expect(etudiant.modeContactVers(Rang.moderateur), ModeContact.signalement);
    });

    test('Trainer permissions (formateur)', () {
      final formateur = RoleAccess.depuis(const UserProfile(
        id: '2',
        email: 'f@u.cm',
        nom: 'Forma',
        prenom: 'Teur',
        rang: 'formateur',
      ));

      expect(formateur.peutCreerContenu, isTrue);
      expect(formateur.peutPublierRessource, isFalse);
      expect(formateur.peutDemanderStatut, isTrue);
      expect(formateur.modeContactVers(Rang.etudiant), ModeContact.conversation);
    });

    test('Teacher permissions (enseignant - wide initiate)', () {
      final enseignant = RoleAccess.depuis(const UserProfile(
        id: '3',
        email: 'ens@u.cm',
        nom: 'Enseig',
        prenom: 'Nant',
        rang: 'enseignant',
        badgeEnseignant: true,
      ));

      expect(enseignant.peutCreerContenu, isTrue);
      expect(enseignant.peutEcrireATous, isTrue);
      expect(enseignant.peutDemanderStatut, isFalse);

      // Teacher can initiate direct conversation to everyone
      expect(enseignant.modeContactVers(Rang.etudiant), ModeContact.conversation);
      expect(enseignant.modeContactVers(Rang.moderateur), ModeContact.conversation);
    });

    test('Moderateur never creates content (DV rule)', () {
      final moderateur = RoleAccess.depuis(const UserProfile(
        id: '4',
        email: 'mod@u.cm',
        nom: 'Modo',
        prenom: 'Rateur',
        rang: 'moderateur',
      ));

      expect(moderateur.peutTraiterSignalements, isTrue);
      expect(moderateur.peutPublierRessource, isTrue);
      expect(moderateur.peutMasquerVideo, isTrue);
      expect(moderateur.peutCreerContenu, isFalse);
    });

    test('Enseignant en attente de validation reste limité comme un étudiant', () {
      final enAttente = RoleAccess.depuis(const UserProfile(
        id: '7',
        email: 'futur.ens@u.cm',
        nom: 'Futur',
        prenom: 'Enseignant',
        rang: 'enseignant',
        // badgeEnseignant par défaut = false : dossier pas encore validé.
      ));

      expect(enAttente.estEnseignantEnAttente, isTrue);
      expect(enAttente.effectif, Rang.etudiant);
      expect(enAttente.peutCreerContenu, isFalse);
      expect(enAttente.peutEcrireATous, isFalse);
      expect(enAttente.libelle, 'Étudiant');
      expect(enAttente.modeContactVers(Rang.moderateur), ModeContact.signalement);
    });

    test('Tuteur is a real, standalone rank', () {
      final tuteur = RoleAccess.depuis(const UserProfile(
        id: '6',
        email: 'tuteur@u.cm',
        nom: 'Tuteur',
        prenom: 'Guy',
        rang: 'tuteur',
      ));

      expect(tuteur.rang, Rang.tuteur);
      expect(tuteur.peutCreerContenu, isTrue);
      expect(tuteur.peutDemanderStatut, isTrue);
      expect(tuteur.modeContactVers(Rang.etudiant), ModeContact.conversation);
    });
  });
}
