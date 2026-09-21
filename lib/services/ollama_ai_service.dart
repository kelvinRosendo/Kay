import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_service.dart';
import 'conversation_memory.dart';

class OllamaAiService implements AiService {
  OllamaAiService({
    http.Client? client,
    String? baseUrl,
    this.model = 'llama3.2:3b',
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ??
            const String.fromEnvironment(
              'KAY_AI_URL',
              defaultValue: 'http://10.0.2.2:11434',
            );

  final http.Client _client;
  final String baseUrl;
  final String model;

  /// Lightweight connectivity check against the Ollama server. Never returns
  /// an error; reports success only when the server answers `/api/tags`.
  Future<bool> ping({Duration timeout = const Duration(seconds: 4)}) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api/tags'),
            headers: const {'content-type': 'application/json'},
          )
          .timeout(timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// System prompt sent once at the beginning of each conversation.
  static const _systemPrompt =
      'Você é Kay, um assistente pessoal. Responda em português do Brasil, '
      'de forma breve e natural, adequada para fala. '
      'Em no máximo três frases, sem markdown.';

  static String _buildSystemPrompt(String? userName) {
    if (userName == null || userName.trim().isEmpty) return _systemPrompt;
    return '$_systemPrompt '
        'Quando for natural ou apropriado, trate o usuário pelo nome '
        '"${userName.trim()}".';
  }

  @override
  Future<String> answer(
    String prompt, {
    List<ChatMessage>? history,
    String? userName,
  }) async {
    try {
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': _buildSystemPrompt(userName)},
        if (history != null)
          ...history.map((m) => {'role': m.role, 'content': m.content}),
        {'role': 'user', 'content': prompt},
      ];

      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/chat'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'messages': messages,
              'stream': false,
              'options': {'temperature': 0.4, 'num_predict': 120},
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        if (response.statusCode == 404) {
          throw AiError.modelNotFound(model);
        }
        throw AiError.httpError(response.statusCode);
      }

      final data = jsonDecode(response.body);
      if (data is! Map) throw const AiError.emptyResponse();

      // Check for Ollama error field
      final error = data['error']?.toString();
      if (error != null && error.isNotEmpty) {
        if (error.contains('model') && error.contains('not found')) {
          throw AiError.modelNotFound(model);
        }
        throw const AiError.emptyResponse();
      }

      final text = data['message']?['content']?.toString().trim() ?? '';
      if (text.isEmpty) throw const AiError.emptyResponse();
      return text;
    } on AiError {
      rethrow;
    } on TimeoutException {
      throw const AiError.timeout();
    } on http.ClientException {
      throw const AiError.serverUnreachable();
    } on FormatException {
      throw const AiError.emptyResponse();
    } catch (e) {
      // SocketException, OSError, etc. — treat as network/server issue
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') ||
          msg.contains('connection refused') ||
          msg.contains('os error')) {
        throw const AiError.serverUnreachable();
      }
      if (msg.contains('network')) {
        throw const AiError.network();
      }
      throw const AiError.unavailable();
    }
  }
}
