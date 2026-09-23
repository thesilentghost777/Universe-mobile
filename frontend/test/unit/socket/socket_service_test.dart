import 'package:flutter_test/flutter_test.dart';
import 'package:universe_frontend/core/api/api_client.dart';
import 'package:universe_frontend/core/auth/token_storage.dart';
import 'package:universe_frontend/core/socket/socket_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('joinConversation retient les rooms pour le réabonnement', () {
    final tokens = TokenStorage();
    final sock = SocketService(tokens, ApiClient(tokens));
    sock.joinConversation('conv-1');
    sock.joinConversation('conv-2');
    expect(sock.conversationsRejointes, {'conv-1', 'conv-2'});
    sock.dispose();
    expect(sock.conversationsRejointes, isEmpty);
  });
}
