import 'package:flutter_test/flutter_test.dart';
import 'package:kay/services/conversation_memory.dart';

void main() {
  late ConversationMemory memory;

  setUp(() {
    memory = ConversationMemory(maxExchanges: 3);
  });

  group('ConversationMemory', () {
    test('starts empty', () {
      expect(memory.isEmpty, isTrue);
      expect(memory.messages, isEmpty);
    });

    test('addExchange stores user and assistant messages', () {
      memory.addExchange(user: 'Olá', assistant: 'Olá! Como posso ajudar?');
      expect(memory.messages.length, 2);
      expect(memory.messages[0].role, 'user');
      expect(memory.messages[0].content, 'Olá');
      expect(memory.messages[1].role, 'assistant');
      expect(memory.messages[1].content, 'Olá! Como posso ajudar?');
    });

    test('addExchange trims old exchanges beyond max', () {
      memory.addExchange(user: 'Primeira', assistant: 'Resposta 1');
      memory.addExchange(user: 'Segunda', assistant: 'Resposta 2');
      memory.addExchange(user: 'Terceira', assistant: 'Resposta 3');
      expect(memory.messages.length, 6);

      // Adding a 4th exchange should remove the first pair
      memory.addExchange(user: 'Quarta', assistant: 'Resposta 4');
      expect(memory.messages.length, 6); // still 6 (3 pairs)
      expect(memory.messages[0].role, 'user');
      expect(memory.messages[0].content, 'Segunda'); // second pair starts
      expect(memory.messages[1].content, 'Resposta 2');
    });

    test('clear removes all messages', () {
      memory.addExchange(user: 'Test', assistant: 'Reply');
      memory.clear();
      expect(memory.isEmpty, isTrue);
      expect(memory.messages, isEmpty);
    });

    test('messages list is immutable', () {
      memory.addExchange(user: 'Test', assistant: 'Reply');
      final msgs = memory.messages;
      expect(() => msgs.add(ChatMessage('user', 'x')),
          throwsA(isA<UnsupportedError>()));
    });

    test('isExpired returns true when no activity', () {
      expect(memory.isExpired(), isTrue);
    });

    test('pruneIfExpired clears when expired', () {
      var now = DateTime(2026, 9, 20, 12, 0);
      final mem = ConversationMemory(maxExchanges: 3, now: () => now);
      mem.addExchange(user: 'Test', assistant: 'Reply');
      // Move time forward past 15 minutes
      now = now.add(const Duration(minutes: 16));
      expect(mem.pruneIfExpired(inactivityLimit: const Duration(minutes: 15)),
          isTrue);
      expect(mem.isEmpty, isTrue);
    });

    test('pruneIfExpired does not clear when recent', () {
      memory.addExchange(user: 'Test', assistant: 'Reply');
      expect(
          memory.pruneIfExpired(inactivityLimit: const Duration(hours: 1)),
          isFalse);
      expect(memory.isEmpty, isFalse);
    });
  });
}
