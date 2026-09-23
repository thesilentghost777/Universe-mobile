import 'package:dio/dio.dart';

/// No-op hors web : les cookies HttpOnly ne s'appliquent pas.
void activerCredentialsWeb(Dio dio) {}
