import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

/// Envoie les cookies HttpOnly du navigateur (refresh `universe_refresh`).
void activerCredentialsWeb(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter()..withCredentials = true;
}
