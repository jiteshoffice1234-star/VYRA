import 'package:sqflite/sqflite.dart';

import '../../domain/models/ai/ai_conversation.dart';
import '../../domain/models/ai/ai_usage_record.dart';

/// Persistence for AI conversation history and usage tracking.
///
/// Follows the same shape as the other repositories: plain `Database`
/// dependency, mapped models, transactions for multi-row writes.
class AiRepository {
  AiRepository(this._db);

  final Database _db;

  /// Creates a conversation (and any messages it already carries) atomically.
  /// Returns the new conversation id.
  Future<int> createConversation(AiConversation conversation) async {
    final map = conversation.toMap()..remove('id');
    return _db.transaction((txn) async {
      final id = await txn.insert('ai_conversations', map);
      for (final message in conversation.messages) {
        await _insertMessage(txn, id, message);
      }
      return id;
    });
  }

  /// Appends a message to a conversation and bumps `updated_at`.
  Future<void> addMessage(int conversationId, AiMessage message) async {
    await _db.transaction((txn) async {
      await _insertMessage(txn, conversationId, message);
      await txn.update(
        'ai_conversations',
        {'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [conversationId],
      );
    });
  }

  Future<void> _insertMessage(
    DatabaseExecutor txn,
    int conversationId,
    AiMessage message,
  ) async {
    await txn.insert('ai_messages', {
      ...message.toMap()..remove('id'),
      'conversation_id': conversationId,
    });
  }

  /// Loads one conversation with its full message history.
  Future<AiConversation?> getConversation(int id) async {
    final rows = await _db.query(
      'ai_conversations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AiConversation.fromMap(rows.first, messages: await messagesFor(id));
  }

  /// All conversations, newest first, without their messages.
  Future<List<AiConversation>> conversations({int limit = 100}) async {
    final rows = await _db.query(
      'ai_conversations',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return [for (final r in rows) AiConversation.fromMap(r)];
  }

  /// A conversation's messages, oldest first.
  Future<List<AiMessage>> messagesFor(int conversationId) async {
    final rows = await _db.query(
      'ai_messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC, id ASC',
    );
    return [for (final r in rows) AiMessage.fromMap(r)];
  }

  /// Renames a conversation (used when a title is refined later).
  Future<void> renameConversation(int id, String title) => _db.update(
        'ai_conversations',
        {'title': title, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> deleteConversation(int id) => _db.delete(
        'ai_conversations',
        where: 'id = ?',
        whereArgs: [id],
      );

  /// Clears all AI history (conversations, messages and usage).
  Future<void> clearHistory() => _db.transaction((txn) async {
        await txn.delete('ai_messages');
        await txn.delete('ai_conversations');
        await txn.delete('ai_usage');
      });

  /// Records one usage event.
  Future<void> recordUsage(AiUsageRecord usage) => _db.insert(
        'ai_usage',
        usage.toMap()..remove('id'),
      );

  /// Recent usage records, newest first.
  Future<List<AiUsageRecord>> usage({int limit = 100}) async {
    final rows = await _db.query('ai_usage', orderBy: 'created_at DESC', limit: limit);
    return [for (final r in rows) AiUsageRecord.fromMap(r)];
  }

  /// Summed token usage grouped by service id.
  Future<Map<String, int>> usageTotals() async {
    final rows = await _db.rawQuery('''
      SELECT service_id,
             SUM(prompt_tokens) AS prompt,
             SUM(completion_tokens) AS completion
      FROM ai_usage
      GROUP BY service_id
    ''');
    return {
      for (final r in rows)
        (r['service_id'] as String): ((r['prompt'] as int? ?? 0) +
            (r['completion'] as int? ?? 0)),
    };
  }
}
