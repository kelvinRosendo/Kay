/// In-memory conversation history limited to recent exchanges.
///
/// Architecture decision: The conversation history lives exclusively in Dart
/// and is owned by [KayController]. The native VoiceInteractionSession does
/// not have AI integration (it only handles local commands), so there is no
/// need to share state across the Flutter/Android boundary. When the native
/// session matures to include AI, a MethodChannel bridge can relay the
/// history at that point.
class ConversationMemory {
  ConversationMemory({
    int maxExchanges = 6,
    this.maxMessageBytes = 4096,
    DateTime Function()? now,
  })  : _maxExchanges = maxExchanges,
        _now = now ?? DateTime.now;

  final int _maxExchanges;
  final int maxMessageBytes;
  final DateTime Function() _now;

  final List<ChatMessage> _messages = [];
  DateTime? _lastActivity;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isEmpty => _messages.isEmpty;
  DateTime? get lastActivity => _lastActivity;

  /// Adds a user/assistant exchange pair. Old pairs beyond [_maxExchanges]
  /// are discarded. Each message is truncated to [maxMessageBytes].
  void addExchange({required String user, required String assistant}) {
    _touch();
    _messages.add(ChatMessage('user', _truncate(user)));
    _messages.add(ChatMessage('assistant', _truncate(assistant)));
    _trim();
  }

  /// Returns true if the history has expired (more than [inactivityLimit]
  /// since last activity).
  bool isExpired({Duration inactivityLimit = const Duration(minutes: 15)}) {
    if (_lastActivity == null) return true;
    return _now().difference(_lastActivity!) > inactivityLimit;
  }

  /// Clears all stored messages and resets activity timestamp.
  void clear() {
    _messages.clear();
    _lastActivity = null;
  }

  /// Prunes expired messages if [inactivityLimit] has passed since
  /// last activity. Returns true if anything was pruned.
  bool pruneIfExpired({Duration inactivityLimit = const Duration(minutes: 15)}) {
    if (!isExpired(inactivityLimit: inactivityLimit) || _messages.isEmpty) {
      return false;
    }
    clear();
    return true;
  }

  void _touch() => _lastActivity = _now();

  void _trim() {
    // Each exchange is 2 messages; keep at most _maxExchanges pairs.
    final maxMessages = _maxExchanges * 2;
    while (_messages.length > maxMessages) {
      _messages.removeAt(0);
      _messages.removeAt(0); // remove the pair
    }
  }

  String _truncate(String text) {
    final bytes = text.codeUnits.length; // rough byte estimate
    if (bytes <= maxMessageBytes) return text;
    return text.substring(0, maxMessageBytes);
  }
}

class ChatMessage {
  const ChatMessage(this.role, this.content);
  final String role; // 'user' or 'assistant'
  final String content;

  @override
  String toString() => 'ChatMessage($role: $content)';
}
