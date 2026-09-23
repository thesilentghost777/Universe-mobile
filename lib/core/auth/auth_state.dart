import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `StateNotifierProvider` est déprécié depuis Riverpod 3 et vit désormais
// dans cet import dédié ; il reste pris en charge.
import 'package:flutter_riverpod/legacy.dart';

import '../api/api_client.dart';
import '../demo/demo_session.dart';
import '../../shared/models/models.dart';
import 'token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
  });

  final AuthStatus status;
  final UserProfile? user;
  final String? error;

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? user,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState()) {
    bootstrap();
  }

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);
  TokenStorage get _tokens => _ref.read(tokenStorageProvider);

  /// Ouvre une session simulée pour un rôle du Mode Test (voir
  /// [DemoSession.roles]). Aucun réseau : le profil est construit
  /// localement et toutes les requêtes suivantes sont servies par
  /// `DemoApiInterceptor`.
  Future<void> simulerRole(String role) async {
    final user = await DemoSession.activer(role);
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> bootstrap() async {
    // Session du Mode Test persistée : restaurée sans toucher au réseau.
    final demo = await DemoSession.restaurer();
    if (demo != null) {
      state = AuthState(status: AuthStatus.authenticated, user: demo);
      return;
    }
    try {
      final access = await _tokens.readAccess().timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      if (access == null || access.isEmpty) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      final user = await _chargerProfil().timeout(const Duration(seconds: 8));
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      // Session réellement invalide (401/403 après échec du refresh) : on purge.
      // Panne réseau / serveur injoignable : on garde les jetons pour retenter
      // au prochain lancement plutôt que de déconnecter l'utilisateur.
      final code = e is DioException ? e.response?.statusCode : null;
      if (code == 401 || code == 403) {
        await _tokens.clear();
      }
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Inscription email + mot de passe (`POST /auth/register`).
  ///
  /// Le backend exige `sexe` ('masculin' | 'feminin') pour tous les rôles et
  /// répond 200 sans ouvrir de session : le compte doit d'abord confirmer
  /// son email (jeton envoyé par mail ; `verificationToken` exposé en dev).
  Future<Map<String, dynamic>> register({
    required String email,
    required String motDePasse,
    required String nom,
    required String sexe,
    String? prenom,
    String? niveauId,
    String? rangInscription,
    String? dateNaissance,
    String? photoProfilCle,
    String? cniRectoCle,
    String? cniVersoCle,
    String? logoFormationCle,
    String? dossierToken,
  }) async {
    final res = await _api.post('/auth/register', data: {
      'email': email,
      'motDePasse': motDePasse,
      'nom': nom,
      'sexe': sexe,
      if (prenom != null && prenom.trim().isNotEmpty) 'prenom': prenom.trim(),
      'niveauId': ?niveauId,
      'rangInscription': ?rangInscription,
      'dateNaissance': ?dateNaissance,
      'photoProfilCle': ?photoProfilCle,
      'cniRectoCle': ?cniRectoCle,
      'cniVersoCle': ?cniVersoCle,
      'logoFormationCle': ?logoFormationCle,
      'dossierToken': ?dossierToken,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> verifyEmail(String token) async {
    await _api.post('/auth/verify-email', data: {'token': token});
  }

  Future<void> resendVerification(String email) async {
    await _api.post('/auth/resend-verification', data: {'email': email});
  }

  /// Connexion par mot de passe — **email uniquement** : le backend
  /// (`LoginDto`) n'accepte pas le téléphone ici. Un compte téléphone se
  /// connecte par OTP ([demanderCode] + [verifierCode]).
  Future<void> login({
    required String email,
    required String motDePasse,
  }) async {
    state = state.copyWith(clearError: true);
    try {
      final res = await _api.post('/auth/login', data: {
        'email': email.trim(),
        'motDePasse': motDePasse,
        'deviceLabel': 'Flutter UniVerse',
      });
      await _ouvrirSession(res.data as Map<String, dynamic>);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _msg(e),
      );
      rethrow;
    }
  }

  // ------------------------------------------------------ OTP et Google

  static String _normaliserTelephone(String destination) =>
      destination.startsWith('+') ? destination.trim() : '+${destination.trim()}';

  /// Code OTP reçu dans la réponse quand le serveur tourne en mode
  /// simulation (pas de fournisseur WhatsApp configuré) — utile en dev.
  String? dernierOtpSimulation;

  /// Demande l'envoi d'un code OTP à 6 chiffres par WhatsApp/SMS.
  ///
  /// `POST /auth/otp/send`  { telephone, captchaToken? } — téléphone
  /// uniquement : le backend (`SendOtpDto`) ne gère pas d'OTP email.
  /// Renvoie la durée de validité en secondes (défaut 300).
  Future<int> demanderCode({
    required String destination,
    String? captchaToken,
  }) async {
    final res = await _api.post('/auth/otp/send', data: {
      'telephone': _normaliserTelephone(destination),
      'captchaToken': ?captchaToken,
    });
    final data = res.data;
    if (data is Map) {
      dernierOtpSimulation = data['simulationCode'] as String?;
      for (final cle in ['expiresIn', 'expiration', 'ttl', 'validiteSecondes']) {
        final v = data[cle];
        if (v is num && v > 0) return v.toInt();
      }
    }
    return 300;
  }

  /// Vérifie le code OTP et ouvre la session (connexion **ou** création du
  /// compte : le backend crée l'utilisateur au premier OTP validé).
  ///
  /// `POST /auth/otp/verify`
  ///   { telephone, code, nom?, prenom?, niveauId?, email?, sexe?,
  ///     rangInscription?, dateNaissance?, cniRectoCle?, ... }
  /// Réponse : { accessToken, utilisateur } (+ cookie refresh HttpOnly).
  Future<void> verifierCode({
    required String destination,
    required String code,
    String? nom,
    String? prenom,
    String? niveauId,
    Map<String, dynamic>? champsInscription,
  }) async {
    state = state.copyWith(clearError: true);
    try {
      final res = await _api.post('/auth/otp/verify', data: {
        'telephone': _normaliserTelephone(destination),
        'code': code,
        if (nom != null && nom.trim().isNotEmpty) 'nom': nom.trim(),
        if (prenom != null && prenom.trim().isNotEmpty) 'prenom': prenom.trim(),
        if (niveauId != null && niveauId.isNotEmpty) 'niveauId': niveauId,
        ...?champsInscription,
      });
      await _ouvrirSession(res.data as Map<String, dynamic>);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _msg(e),
      );
      rethrow;
    }
  }

  /// Connexion Google.
  ///
  /// `POST /auth/google`  { idToken, niveauId?, sexe?, rangInscription?, ... }
  /// Le serveur verifie le jeton aupres de Google, cree le compte s'il
  /// n'existe pas, et repond comme /auth/login.
  Future<void> connexionGoogle(
    String idToken, {
    Map<String, dynamic>? champsInscription,
  }) async {
    state = state.copyWith(clearError: true);
    try {
      final res = await _api.post('/auth/google', data: {
        'idToken': idToken,
        ...?champsInscription,
      });
      await _ouvrirSession(res.data as Map<String, dynamic>);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _msg(e),
      );
      rethrow;
    }
  }

  /// `/auth/me` (identité de session) enrichi par `/utilisateurs/:id`
  /// (nom, prénom, compte créateur, groupe TDS) — le premier ne renvoie
  /// pas ces champs de profil.
  Future<UserProfile> _chargerProfil() async {
    final me = await _api.get('/auth/me');
    final data = Map<String, dynamic>.from(me.data as Map);
    final id = data['id'] as String?;
    if (id != null) {
      try {
        final res = await _api.get('/utilisateurs/$id');
        final profil = Map<String, dynamic>.from(res.data as Map);
        for (final entree in profil.entries) {
          data.putIfAbsent(entree.key, () => entree.value);
        }
        data['nom'] = profil['nom'] ?? data['nom'];
        data['prenom'] = profil['prenom'] ?? data['prenom'];
        if (profil['compteCreateur'] != null) {
          data['compteCreateur'] = profil['compteCreateur'];
        }
        if (profil['groupeTds'] != null) {
          data['groupeTds'] = profil['groupeTds'];
        }
      } catch (_) {
        // Enrichissement non bloquant : la session reste valide sans lui.
      }
    }
    return UserProfile.fromJson(data);
  }

  /// Enregistre les jetons puis charge le profil — commun a toutes les
  /// methodes de connexion.
  Future<void> _ouvrirSession(Map<String, dynamic> data) async {
    final access = data['accessToken'] as String;
    final refresh = data['refreshToken'] as String? ?? '';
    await _tokens.saveTokens(access: access, refresh: refresh);
    state = AuthState(
      status: AuthStatus.authenticated,
      user: await _chargerProfil(),
    );
  }

  Future<void> setNiveau(String niveauId) async {
    await _api.patch('/utilisateurs/moi/niveau', data: {'niveauId': niveauId});
    state = AuthState(
      status: AuthStatus.authenticated,
      user: await _chargerProfil(),
    );
  }

  Future<void> enregistrerBio(String bio) async {
    await _api.patch('/utilisateurs/moi/profil', data: {'bio': bio});
    state = AuthState(
      status: AuthStatus.authenticated,
      user: await _chargerProfil(),
    );
  }

  Future<void> enregistrerPhotoProfil(String photoProfilCle) async {
    await _api.patch(
      '/utilisateurs/moi/identite',
      data: {'photoProfilCle': photoProfilCle},
    );
    state = AuthState(
      status: AuthStatus.authenticated,
      user: await _chargerProfil(),
    );
  }

  Future<void> changePassword({
    required String ancien,
    required String nouveau,
  }) async {
    await _api.post('/auth/change-password', data: {
      'motDePasseActuel': ancien,
      'nouveauMotDePasse': nouveau,
    });
  }

  Future<void> logout() async {
    if (DemoSession.active) {
      await DemoSession.desactiver();
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      await _api.post('/auth/logout');
    } catch (_) {}
    await _tokens.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> refreshMe() async {
    state = AuthState(
      status: AuthStatus.authenticated,
      user: await _chargerProfil(),
    );
  }

  String _msg(Object e) {
    final s = e.toString();
    if (s.contains('401')) return 'Identifiants incorrects';
    if (s.contains('429')) return 'Trop de tentatives — réessayez plus tard';
    return 'Connexion impossible';
  }
}
