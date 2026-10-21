import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kay/services/ai_service.dart';
import 'package:kay/services/preferences_service.dart';
import 'package:kay/services/proxy_ai_service.dart';
import 'package:kay/services/conversation_memory.dart';

void main() {
  late PreferencesService prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = PreferencesService();
    await prefs.init();
    prefs.cloudEnabled = true;
    prefs.proxyUrl = 'https://kay.example';
    prefs.proxyToken = 't' * 64;
  });
  test('sends history, manual choice and session authorization to proxy', () async {
    prefs.llmProvider = 'gemini';
    final service = ProxyAiService(prefs, client: MockClient((req) async {
      expect(req.url.toString(), 'https://kay.example/v1/chat');
      expect(req.followRedirects, false);
      expect(req.headers['authorization'], 'Bearer ${prefs.proxyToken}');
      final body = jsonDecode(req.body) as Map;
      expect(body['provider'], 'gemini');
      expect(body['history'], [{'role': 'user', 'content': 'anterior'}]);
      return http.Response('{"text":"Resposta"}', 200);
    }));
    expect(await service.answer('oi', history: [ChatMessage('user', 'anterior')]), 'Resposta');
    service.close();
  });
  test('token is not persisted', () async {
    final other = PreferencesService(); await other.init();
    expect(other.proxyToken, isEmpty);
    expect(other.proxyUrl, prefs.proxyUrl);
  });
  test('rejects insecure remote URL and invalid token before sending', () async {
    final service = ProxyAiService(prefs, client: MockClient((_) async => fail('No request expected')));
    prefs.proxyUrl = 'http://remote.example';
    await expectLater(service.answer('oi'), throwsA(isA<AiUnavailable>()));
    prefs.proxyUrl = 'https://kay.example'; prefs.proxyToken = '';
    await expectLater(service.answer('oi'), throwsA(isA<AiUnavailable>()));
    service.close();
  });
  test('maps HTTP and malformed replies to typed errors', () async {
    for (final status in [401, 429, 503]) {
      final service = ProxyAiService(prefs, client: MockClient((_) async => http.Response('', status)));
      await expectLater(service.answer('oi'), throwsA(isA<HttpError>()));
      service.close();
    }
    final service = ProxyAiService(prefs, client: MockClient((_) async => http.Response('{}', 200)));
    await expectLater(service.answer('oi'), throwsA(isA<EmptyResponse>()));
    service.close();
  });
}
