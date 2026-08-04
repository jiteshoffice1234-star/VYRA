/// Who produced a message in a conversation.
enum AiRole {
  system,
  user,
  assistant;

  static AiRole fromId(String id) =>
      values.firstWhere((r) => r.name == id, orElse: () => AiRole.user);
}

/// One message inside an AI conversation.
class AiMessage {
  const AiMessage({
    this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.tokens = 0,
  });

  final int? id;
  final AiRole role;
  final String content;
  final int createdAt;

  /// Approximate token count for this message (0 when unknown).
  final int tokens;

  factory AiMessage.fromMap(Map<String, Object?> map) => AiMessage(
        id: map['id'] as int?,
        role: AiRole.fromId(map['role'] as String? ?? 'user'),
        content: (map['content'] as String?) ?? '',
        createdAt: map['created_at'] as int? ?? 0,
        tokens: map['tokens'] as int? ?? 0,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'role': role.name,
        'content': content,
        'created_at': createdAt,
        'tokens': tokens,
      };

  AiMessage copyWith({
    int? id,
    AiRole? role,
    String? content,
    int? createdAt,
    int? tokens,
  }) =>
      AiMessage(
        id: id ?? this.id,
        role: role ?? this.role,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
        tokens: tokens ?? this.tokens,
      );
}

/// A persisted AI conversation: a title plus an ordered message history.
class AiConversation {
  const AiConversation({
    this.id,
    required this.title,
    this.model,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  final int? id;
  final String title;

  /// Backend model identifier (null when offline/unknown).
  final String? model;
  final int createdAt;
  final int updatedAt;

  /// Ordered history. Header-only listings (e.g. the conversation list)
  /// carry an empty list; [AiConversation.withMessages] fills it.
  final List<AiMessage> messages;

  factory AiConversation.fromMap(
    Map<String, Object?> map, {
    List<AiMessage> messages = const [],
  }) =>
      AiConversation(
        id: map['id'] as int?,
        title: (map['title'] as String?) ?? 'Untitled',
        model: map['model'] as String?,
        createdAt: map['created_at'] as int? ?? 0,
        updatedAt: map['updated_at'] as int? ?? 0,
        messages: messages,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'model': model,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  AiConversation copyWith({
    int? id,
    String? title,
    String? model,
    int? createdAt,
    int? updatedAt,
    List<AiMessage>? messages,
  }) =>
      AiConversation(
        id: id ?? this.id,
        title: title ?? this.title,
        model: model ?? this.model,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        messages: messages ?? this.messages,
      );
}
