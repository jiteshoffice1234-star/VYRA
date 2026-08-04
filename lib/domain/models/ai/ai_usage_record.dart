/// One recorded AI usage event (a completed or failed request).
///
/// Kept as a plain record so the UI can show per-session token consumption
/// without reaching into any service implementation.
class AiUsageRecord {
  const AiUsageRecord({
    this.id,
    this.conversationId,
    required this.serviceId,
    this.model,
    required this.promptTokens,
    required this.completionTokens,
    required this.latencyMs,
    this.streamed = false,
    required this.createdAt,
  });

  final int? id;

  /// Conversation the usage belongs to, if any.
  final int? conversationId;

  /// Stable service id (e.g. 'offline', a future 'nvidia_nim').
  final String serviceId;
  final String? model;
  final int promptTokens;
  final int completionTokens;
  final int latencyMs;
  final bool streamed;
  final int createdAt;

  int get totalTokens => promptTokens + completionTokens;

  factory AiUsageRecord.fromMap(Map<String, Object?> map) => AiUsageRecord(
        id: map['id'] as int?,
        conversationId: map['conversation_id'] as int?,
        serviceId: (map['service_id'] as String?) ?? 'unknown',
        model: map['model'] as String?,
        promptTokens: map['prompt_tokens'] as int? ?? 0,
        completionTokens: map['completion_tokens'] as int? ?? 0,
        latencyMs: map['latency_ms'] as int? ?? 0,
        streamed: (map['streamed'] as int? ?? 0) == 1,
        createdAt: map['created_at'] as int? ?? 0,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'conversation_id': conversationId,
        'service_id': serviceId,
        'model': model,
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'latency_ms': latencyMs,
        'streamed': streamed ? 1 : 0,
        'created_at': createdAt,
      };
}
