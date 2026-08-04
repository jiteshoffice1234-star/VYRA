import '../models/ai/ai_conversation.dart';
import '../models/ai/ai_usage_record.dart';
import 'ai_service.dart';
import 'prompt_manager.dart';

/// High-level, app-facing AI facade — the layer the UI will talk to.
///
/// Combines an [AIService] backend, the [PromptManager] and persisted
/// conversation / usage records into one API so future screens (AI journal
/// summaries, habit insights, chat assistant) never touch the transport
/// layer directly. The default wiring (see `ai_providers.dart`) uses the
/// offline fallback; swapping the injected [AIService] upgrades the whole
/// app without changing this class.
class AiApi {
  AiApi({
    required AIService service,
    required PromptManager prompts,
    required Future<int> Function(AiConversation conversation) persistConversation,
    required Future<void> Function(int conversationId, AiMessage message) appendMessage,
    required Future<void> Function(AiUsageRecord usage) recordUsage,
  })  : _service = service,
        _prompts = prompts,
        _persistConversation = persistConversation,
        _appendMessage = appendMessage,
        _recordUsage = recordUsage;

  final AIService _service;
  final PromptManager _prompts;
  final Future<int> Function(AiConversation) _persistConversation;
  final Future<void> Function(int, AiMessage) _appendMessage;
  final Future<void> Function(AiUsageRecord) _recordUsage;

  AIService get service => _service;
  PromptManager get prompts => _prompts;

  /// Renders a named prompt template (see [PromptManager.render]).
  String renderPrompt(String templateId, Map<String, String> values) =>
      _prompts.render(templateId, values);

  /// Sends a one-shot prompt and returns the reply. No conversation is
  /// created; usage is still recorded.
  Future<AiResponse> ask(String prompt, {String? systemPrompt}) async {
    final stopwatch = Stopwatch()..start();
    final request = AiRequest(
      messages: [AiMessage(role: AiRole.user, content: prompt, createdAt: DateTime.now().millisecondsSinceEpoch)],
      systemPrompt: systemPrompt,
    );
    final response = await _service.complete(request);
    stopwatch.stop();
    await _recordUsage(
      AiUsageRecord(
        serviceId: _service.id,
        model: response.model,
        promptTokens: response.promptTokens,
        completionTokens: response.completionTokens,
        latencyMs: stopwatch.elapsedMilliseconds,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    return response;
  }

  /// Sends a prompt inside a persisted conversation: appends the user message,
  /// streams (or completes) the reply, persists the assistant message and
  /// records usage. Returns the created conversation id when [conversationId]
  /// is null.
  Future<int> chat({
    int? conversationId,
    required String prompt,
    String? title,
    bool stream = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    var cid = conversationId;
    if (cid == null) {
      cid = await _persistConversation(
        AiConversation(
          title: title ?? _defaultTitle(prompt),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    final userMessage = AiMessage(
      role: AiRole.user,
      content: prompt,
      createdAt: now,
    );
    await _appendMessage(cid, userMessage);

    final stopwatch = Stopwatch()..start();
    final request = AiRequest(
      messages: [userMessage],
      conversationId: cid,
      stream: stream,
    );

    // Streamed calls drain the event stream into the final response so the
    // backend is hit exactly once. Callers that need per-chunk UI can consume
    // [AIService.stream] directly; the facade only persists the end result.
    final AiResponse response;
    if (stream) {
      final buffer = StringBuffer();
      AiResponse? streamed;
      AiException? streamError;
      await for (final event in _service.stream(request)) {
        if (event is AiStreamChunk) {
          buffer.write(event.text);
        } else if (event is AiStreamDone) {
          streamed = event.response;
        } else if (event is AiStreamError) {
          streamError = AiServiceException('${event.error}');
        }
      }
      if (streamError != null) {
        throw streamError;
      }
      if (streamed != null && streamed.content.isNotEmpty) {
        response = streamed;
      } else {
        // Fallback: no usable payload arrived, rebuild from drained chunks.
        response = AiResponse(
          content: buffer.toString(),
          model: streamed?.model,
          latencyMs: stopwatch.elapsedMilliseconds,
          fallback: streamed?.fallback ?? true,
        );
      }
    } else {
      response = await _service.complete(request);
    }
    stopwatch.stop();

    await _appendMessage(
      cid,
      AiMessage(
        role: AiRole.assistant,
        content: response.content,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        tokens: response.totalTokens,
      ),
    );
    await _recordUsage(
      AiUsageRecord(
        conversationId: cid,
        serviceId: _service.id,
        model: response.model,
        promptTokens: response.promptTokens,
        completionTokens: response.completionTokens,
        latencyMs: stopwatch.elapsedMilliseconds,
        streamed: stream,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    return cid;
  }

  static String _defaultTitle(String prompt) {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return 'Conversation';
    final firstLine = trimmed.split('\n').first.trim();
    return firstLine.length > 40 ? '${firstLine.substring(0, 40)}…' : firstLine;
  }
}
