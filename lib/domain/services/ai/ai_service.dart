import '../../models/ai/ai_conversation.dart';

/// Parameters for a single AI completion.
///
/// [messages] carries the conversation context; [systemPrompt] is an
/// optional instruction prepended by the service implementation.
class AiRequest {
  const AiRequest({
    required this.messages,
    this.systemPrompt,
    this.model,
    this.temperature,
    this.maxTokens,
    this.stream = false,
    this.conversationId,
  });

  final List<AiMessage> messages;
  final String? systemPrompt;
  final String? model;
  final double? temperature;
  final int? maxTokens;
  final bool stream;
  final int? conversationId;
}

/// A complete (non-streamed) AI response.
class AiResponse {
  const AiResponse({
    required this.content,
    this.model,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.latencyMs = 0,
    this.streamed = false,
    this.fallback = false,
  });

  final String content;
  final String? model;
  final int promptTokens;
  final int completionTokens;
  final int latencyMs;
  final bool streamed;

  /// True when the reply came from the offline fallback instead of a real
  /// backend — lets the UI tell the user the answer is local-only.
  final bool fallback;

  int get totalTokens => promptTokens + completionTokens;
}

/// A single event in a streamed AI reply.
sealed class AiStreamEvent {
  const AiStreamEvent();
}

/// Stream started; carries the request this stream belongs to.
class AiStreamStart extends AiStreamEvent {
  const AiStreamStart();
}

/// One chunk of generated text.
class AiStreamChunk extends AiStreamEvent {
  const AiStreamChunk(this.text);

  final String text;
}

/// Stream finished successfully.
class AiStreamDone extends AiStreamEvent {
  const AiStreamDone(this.response);

  final AiResponse response;
}

/// Stream failed; [error] is the underlying exception.
class AiStreamError extends AiStreamEvent {
  const AiStreamError(this.error);

  final Object error;
}

/// Root for all AI service failures. Typed so callers can distinguish
/// transient backend issues from permanent ones.
sealed class AiException implements Exception {
  const AiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The service is not configured or the backend is unreachable.
class AiUnavailableException extends AiException {
  const AiUnavailableException(super.message);
}

/// The request was rejected (bad input, unsupported model, etc.).
class AiRequestException extends AiException {
  const AiRequestException(super.message);
}

/// The backend timed out while producing a response.
class AiTimeoutException extends AiException {
  const AiTimeoutException(super.message);
}

/// The backend rate-limited the request.
class AiRateLimitException extends AiException {
  const AiRateLimitException(super.message);
}

/// Any other backend failure.
class AiServiceException extends AiException {
  const AiServiceException(super.message);
}

/// App-facing contract for an AI provider.
///
/// This is the seam between the app and the AI world: the UI, prompt manager
/// and repository all depend on [AIService], never on a concrete backend. A
/// future NVIDIA NIM / remote implementation simply implements this interface
/// and is swapped in via the provider — no UI changes needed.
abstract interface class AIService {
  /// Stable identifier (e.g. 'offline', 'nvidia-nim').
  String get id;

  /// Human-readable name for settings/status UI.
  String get displayName;

  /// Whether the backend supports token streaming.
  bool get supportsStreaming;

  /// Whether a real backend is configured (offline fallback returns false
  /// so the UI can show an "AI is not configured" state).
  bool get isConfigured;

  /// One-shot completion.
  Future<AiResponse> complete(AiRequest request);

  /// Streamed completion. Emits [AiStreamStart], zero or more
  /// [AiStreamChunk]s, then exactly one of [AiStreamDone] / [AiStreamError].
  Stream<AiStreamEvent> stream(AiRequest request);
}
