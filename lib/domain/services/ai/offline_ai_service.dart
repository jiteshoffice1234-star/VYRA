import '../models/ai/ai_conversation.dart';
import 'ai_service.dart';

/// Local, dependency-free fallback implementation of [AIService].
///
/// Never makes a network call. It echoes a clearly-labeled local response so
/// the app remains fully functional before any real backend is configured.
/// The provider can swap this out for a remote implementation later without
/// touching any UI.
class OfflineAIService implements AIService {
  const OfflineAIService();

  @override
  String get id => 'offline';

  @override
  String get displayName => 'Offline';

  @override
  bool get supportsStreaming => true;

  @override
  bool get isConfigured => false;

  @override
  Future<AiResponse> complete(AiRequest request) async {
    return AiResponse(
      content: _offlineReply(request),
      model: null,
      latencyMs: 0,
      fallback: true,
    );
  }

  @override
  Stream<AiStreamEvent> stream(AiRequest request) async* {
    yield const AiStreamStart();
    // Emit the reply in word-sized chunks so streaming UI paths can be
    // exercised and tested even without a backend.
    final reply = _offlineReply(request);
    final words = reply.split(' ');
    for (var i = 0; i < words.length; i++) {
      yield AiStreamChunk(words[i] + (i < words.length - 1 ? ' ' : ''));
    }
    yield AiStreamDone(
      AiResponse(content: reply, model: null, latencyMs: 0, fallback: true),
    );
  }

  /// Deterministic local reply derived from the request. Uses the last user
  /// message so the returned text is at least relevant to what was asked.
  static String _offlineReply(AiRequest request) {
    final lastUser = request.messages.lastWhere(
      (m) => m.role == AiRole.user,
      orElse: () => const AiMessage(role: AiRole.user, content: '', createdAt: 0),
    );
    final question = lastUser.content.trim();
    final subject = question.isEmpty
        ? 'your question'
        : question.length > 60
            ? '${question.substring(0, 60)}…'
            : question;

    return 'This is an offline placeholder reply to “$subject”. '
        'AI assistance is not configured yet — connect a service in a future '
        'update to get real answers. Your data is always stored locally.';
  }
}
