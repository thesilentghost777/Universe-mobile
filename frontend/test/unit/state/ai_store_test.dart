import 'package:flutter_test/flutter_test.dart';
import 'package:universe_frontend/features/ai/ai_store.dart';

void main() {
  group('AI Store, Chat State & Serialization Tests', () {
    test('AiMessage serialization and role identification', () {
      final message = AiMessage(
        role: 'user',
        content: 'Explique-moi la récursivité en algorithmique.',
        at: DateTime.parse('2026-08-31T12:00:00Z'),
      );

      expect(message.isUser, isTrue);
      expect(message.isError, isFalse);

      final json = message.toJson();
      expect(json['role'], 'user');
      expect(json['content'], 'Explique-moi la récursivité en algorithmique.');

      final parsed = AiMessage.fromJson(json);
      expect(parsed.role, message.role);
      expect(parsed.content, message.content);
      expect(parsed.isUser, isTrue);
    });

    test('AiConversation history creation and copyWith', () {
      final conv = AiConversation(
        id: 'conv-001',
        titre: 'Cours Algorithmique',
        messages: [
          AiMessage(
            role: 'user',
            content: 'Bonjour',
            at: DateTime.now(),
          ),
          AiMessage(
            role: 'assistant',
            content: 'Bonjour ! Comment puis-je vous aider ?',
            at: DateTime.now(),
          ),
        ],
        majLe: DateTime.now(),
      );

      expect(conv.id, 'conv-001');
      expect(conv.titre, 'Cours Algorithmique');
      expect(conv.messages.length, 2);

      final updated = conv.copyWith(
        titre: 'Arbres binaires',
        messages: [
          ...conv.messages,
          AiMessage(
            role: 'user',
            content: 'Qu\'est-ce qu\'un arbre binaire ?',
            at: DateTime.now(),
          ),
        ],
      );

      expect(updated.titre, 'Arbres binaires');
      expect(updated.messages.length, 3);

      final json = updated.toJson();
      final decoded = AiConversation.fromJson(json);
      expect(decoded.id, 'conv-001');
      expect(decoded.titre, 'Arbres binaires');
      expect(decoded.messages.length, 3);
    });

    test('AiChatState active conversation tracking', () {
      final c1 = AiConversation(
        id: '1',
        titre: 'Conv 1',
        messages: const [],
        majLe: DateTime.now(),
      );
      final c2 = AiConversation(
        id: '2',
        titre: 'Conv 2',
        messages: [
          AiMessage(
            role: 'user',
            content: 'Question 2',
            at: DateTime.now(),
          ),
        ],
        majLe: DateTime.now(),
      );

      final state = AiChatState(
        conversations: [c1, c2],
        couranteId: '2',
        envoiEnCours: false,
      );

      expect(state.courante, isNotNull);
      expect(state.courante?.id, '2');
      expect(state.messages.length, 1);
      expect(state.messages.first.content, 'Question 2');
    });

    test('Prompt & server answer format parsing resilience', () {
      expect(AiChatController.extraireReponse('Texte direct'), 'Texte direct');

      expect(
        AiChatController.extraireReponse({'reponse': 'Réponse structurée'}),
        'Réponse structurée',
      );

      expect(
        AiChatController.extraireReponse({'answer': 'English response'}),
        'English response',
      );

      expect(
        AiChatController.extraireReponse({
          'choices': [
            {
              'message': {'content': 'OpenAI style answer'}
            }
          ]
        }),
        'OpenAI style answer',
      );
    });
  });
}
