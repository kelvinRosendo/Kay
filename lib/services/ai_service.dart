import 'conversation_memory.dart';

abstract class AiService {
  Future<String> answer(
    String prompt, {
    List<ChatMessage>? history,
    String? userName,
  });
}

class UnavailableAiService implements AiService {
  const UnavailableAiService();
  @override
  Future<String> answer(
    String prompt, {
    List<ChatMessage>? history,
    String? userName,
  }) =>
      throw const AiError.unavailable();
}

/// Categorized AI failures with user-friendly messages in Portuguese.
sealed class AiError implements Exception {
  const AiError();

  const factory AiError.unavailable() = AiUnavailable;
  const factory AiError.serverUnreachable() = ServerUnreachable;
  const factory AiError.timeout() = AiTimeout;
  const factory AiError.httpError(int statusCode) = HttpError;
  const factory AiError.modelNotFound(String model) = ModelNotFound;
  const factory AiError.emptyResponse() = EmptyResponse;
  const factory AiError.network() = AiNetworkError;

  /// Human-readable explanation in Portuguese.
  String get message;
}

class AiUnavailable extends AiError {
  const AiUnavailable();
  @override
  String get message =>
      'A IA está indisponível. Verifique se o Ollama está rodando no computador.';
}

class ServerUnreachable extends AiError {
  const ServerUnreachable();
  @override
  String get message =>
      'Não consegui conectar ao servidor de IA. Verifique se o computador está ligado e na mesma rede.';
}

class AiTimeout extends AiError {
  const AiTimeout();
  @override
  String get message =>
      'O servidor demorou muito para responder. Tente uma pergunta mais curta.';
}

class HttpError extends AiError {
  const HttpError(this.statusCode);
  final int statusCode;
  @override
  String get message => 'Erro do servidor de IA (HTTP $statusCode). Tente novamente.';
}

class ModelNotFound extends AiError {
  const ModelNotFound(this.model);
  final String model;
  @override
  String get message =>
      'O modelo "$model" não foi encontrado no Ollama. Baixe-o com: ollama pull $model';
}

class EmptyResponse extends AiError {
  const EmptyResponse();
  @override
  String get message =>
      'O servidor retornou uma resposta vazia. Verifique a configuração do modelo.';
}

class AiNetworkError extends AiError {
  const AiNetworkError();
  @override
  String get message =>
      'Erro de rede ao acessar a IA. Verifique a conexão Wi-Fi.';
}
