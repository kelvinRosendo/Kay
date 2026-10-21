import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'ai_service.dart';
import 'conversation_memory.dart';
import 'ollama_ai_service.dart';
import 'preferences_service.dart';

/// Only the personal proxy session token lives in memory. Provider keys never
/// enter Flutter, SharedPreferences, build flags, or Android resources.
class ProxyAiService implements AiService {
  ProxyAiService(this.prefs, {http.Client? client})
      : _client = client ?? http.Client();
  final PreferencesService prefs;
  final http.Client _client;
  void close() => _client.close();

  static bool validUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty ||
        uri.hasQuery || uri.hasFragment || (uri.path.isNotEmpty && uri.path != '/')) {
      return false;
    }
    return uri.scheme == 'https' ||
        (kDebugMode && uri.scheme == 'http' &&
            ['127.0.0.1', 'localhost', '10.0.2.2'].contains(uri.host));
  }

  @override
  Future<String> answer(String prompt, {
    List<ChatMessage>? history, String? userName,
  }) async {
    if (!prefs.initialized) throw const AiError.unavailable();
    if (!prefs.cloudEnabled) {
      final local = OllamaAiService(baseUrl: prefs.aiUrl, model: prefs.aiModel);
      try {
        return await local.answer(prompt, history: history, userName: userName);
      } finally {
        local.close();
      }
    }
    if (!validUrl(prefs.proxyUrl) || prefs.proxyToken.length < 32) {
      throw const AiError.unavailable();
    }
    try {
      final response = await _client.send(http.Request(
        'POST', Uri.parse('${prefs.proxyUrl.replaceFirst(RegExp(r'/$'), '')}/v1/chat'),
      )
        ..followRedirects = false
        ..headers.addAll({'content-type': 'application/json',
          'authorization': 'Bearer ${prefs.proxyToken}'})
        ..body = jsonEncode({'prompt': prompt, 'provider': prefs.llmProvider,
          'history': [for (final m in history ?? <ChatMessage>[])
            {'role': m.role, 'content': m.content}]}))
        .timeout(const Duration(seconds: 42));
      if (response.statusCode != 200) throw AiError.httpError(response.statusCode);
      final data = jsonDecode(await response.stream.bytesToString()
          .timeout(const Duration(seconds: 5)));
      if (data is! Map || data['text'] is! String ||
          (data['text'] as String).trim().isEmpty) {
        throw const AiError.emptyResponse();
      }
      return (data['text'] as String).trim();
    } on AiError {
      rethrow;
    } on TimeoutException {
      throw const AiError.timeout();
    } on FormatException {
      throw const AiError.emptyResponse();
    } catch (_) {
      throw const AiError.network();
    }
  }
}
