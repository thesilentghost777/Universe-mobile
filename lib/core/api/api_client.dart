import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import '../auth/token_storage.dart';
import '../demo/demo_api.dart';
import 'api_erreur.dart';
import 'dio_web_credentials_stub.dart'
    if (dart.library.html) 'dio_web_credentials_web.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(ref.watch(tokenStorageProvider));
  ref.onDispose(client.dispose);
  return client;
});

class ApiClient {
  ApiClient(this._tokens) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    // Les intercepteurs qui n'ont besoin d'aucune I/O sont posés tout de suite,
    // pour qu'aucune requête ne parte sans en-tête d'auth même si elle est
    // lancée pendant le bootstrap.
    //
    // Mode Test : quand une session démo est active, cet intercepteur
    // résout chaque requête avec des données fictives — rien ne part sur le
    // réseau. Inactif (le cas nominal), il laisse tout passer tel quel.
    if (kIsWeb) {
      activerCredentialsWeb(_dio);
    }
    _dio.interceptors.add(DemoApiInterceptor());
    _dio.interceptors.add(_authInterceptor());
    _ready = _init();
  }

  final TokenStorage _tokens;
  late final Dio _dio;
  Future<bool>? _refreshInFlight;

  /// Résolu une fois le CookieManager attaché : chaque requête l'attend.
  late final Future<void> _ready;

  Dio get dio => _dio;

  Future<void> _init() async {
    // Sur le web, pas de PersistCookieJar fichier — jar mémoire suffit.
    CookieJar jar = CookieJar();
    if (!kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        jar = PersistCookieJar(storage: FileStorage('${dir.path}/.cookies'));
      } catch (_) {}
    }
    // Le CookieManager doit voir la requête avant l'intercepteur d'auth : on
    // l'insère en tête de liste.
    _dio.interceptors.insert(0, CookieManager(jar));
  }

  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
        onRequest: (options, handler) async {
          final access = await _tokens.readAccess();
          if (access != null && access.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $access';
          }
          options.headers['X-Universe-Client'] = kIsWeb ? 'web' : 'native';
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.path != '/auth/refresh') {
            final ok = await _tryRefresh();
            if (ok) {
              final req = error.requestOptions;
              final access = await _tokens.readAccess();
              req.headers['Authorization'] = 'Bearer $access';
              try {
                final clone = await _dio.fetch(req);
                return handler.resolve(clone);
              } catch (_) {
                return handler.next(error);
              }
            }
          }
          handler.next(error);
        },
    );
  }

  Future<bool> _tryRefresh() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _doRefresh() async {
    try {
      final refresh = await _tokens.readRefresh();
      final res = await _dio.post(
        '/auth/refresh',
        data: refresh != null && refresh.isNotEmpty
            ? {'refreshToken': refresh}
            : {},
      );
      final data = res.data as Map<String, dynamic>;
      final access = data['accessToken'] as String?;
      final newRefresh = data['refreshToken'] as String?;
      if (access == null) return false;
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await _tokens.saveTokens(access: access, refresh: newRefresh);
      } else {
        await _tokens.saveAccess(access);
      }
      return true;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        await _tokens.clear();
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> renouvelerSession() => _tryRefresh();

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    await _ready;
    try {
      return await _dio.get<T>(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      if (ApiErreur.estReseau(e)) {
        return _dio.get<T>(path, queryParameters: queryParameters);
      }
      rethrow;
    }
  }

  Future<Response<T>> post<T>(String path, {Object? data}) async {
    await _ready;
    return _dio.post<T>(path, data: data);
  }

  Future<Response<T>> patch<T>(String path, {Object? data}) async {
    await _ready;
    return _dio.patch<T>(path, data: data);
  }

  Future<Response<T>> delete<T>(String path, {Object? data}) async {
    await _ready;
    return _dio.delete<T>(path, data: data);
  }

  void dispose() {
    _dio.close(force: true);
  }
}
