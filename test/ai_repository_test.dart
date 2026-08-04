import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/core/database/app_database.dart';
import 'package:vyra/data/repositories/ai_repository.dart';
import 'package:vyra/domain/models/ai/ai_conversation.dart';
import 'package:vyra/domain/models/ai/ai_usage_record.dart';

void main() {
  late AppDatabase database;
  late AiRepository repo;

  setUp(() async {
    database = await AppDatabase.openInMemory();
    repo = AiRepository(database.db);
  });

  tearDown(() async {
    await database.close();
  });

  AiMessage _message(AiRole role, String content, {int at = 1000}) =>
      AiMessage(role: role, content: content, createdAt: at);

  test('conversation round-trip with messages and rename', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await repo.createConversation(
      AiConversation(
        title: 'Daily summary',
        createdAt: now,
        updatedAt: now,
        messages: [
          _message(AiRole.user, 'Summarize my week'),
          _message(AiRole.assistant, 'Here is your week.'),
        ],
      ),
    );

    final convo = await repo.getConversation(id);
    expect(convo, isNotNull);
    expect(convo!.title, 'Daily summary');
    expect(convo.messages, hasLength(2));
    expect(convo.messages.first.role, AiRole.user);
    expect(convo.messages.last.content, 'Here is your week.');

    await repo.renameConversation(id, 'Week in review');
    final renamed = await repo.getConversation(id);
    expect(renamed!.title, 'Week in review');
  });

  test('addMessage appends and bumps updated_at', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await repo.createConversation(
      AiConversation(title: 'T', createdAt: now, updatedAt: now),
    );

    await repo.addMessage(id, _message(AiRole.user, 'Hello'));
    await repo.addMessage(
      id,
      AiMessage(role: AiRole.assistant, content: 'Hi!', createdAt: 2000, tokens: 5),
    );

    final convo = await repo.getConversation(id);
    expect(convo!.messages, hasLength(2));
    expect(convo.messages.last.tokens, 5);
    expect(convo.updatedAt, greaterThanOrEqualTo(now));
  });

  test('conversations lists newest first without messages', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final a = await repo.createConversation(
      AiConversation(title: 'A', createdAt: now, updatedAt: now + 100),
    );
    final b = await repo.createConversation(
      AiConversation(title: 'B', createdAt: now, updatedAt: now + 200),
    );

    final list = await repo.conversations();
    expect(list.map((c) => c.id), [b, a]);
    // Header-only listing carries no messages.
    expect(list.first.messages, isEmpty);
  });

  test('deleteConversation cascades to messages', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await repo.createConversation(
      AiConversation(
        title: 'T',
        createdAt: now,
        updatedAt: now,
        messages: [_message(AiRole.user, 'x')],
      ),
    );

    await repo.deleteConversation(id);
    expect(await repo.getConversation(id), isNull);
    expect(await repo.messagesFor(id), isEmpty);
  });

  test('usage records persist and aggregate by service', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await repo.recordUsage(
      AiUsageRecord(
        serviceId: 'offline',
        promptTokens: 10,
        completionTokens: 20,
        latencyMs: 5,
        createdAt: now,
      ),
    );
    await repo.recordUsage(
      AiUsageRecord(
        serviceId: 'offline',
        promptTokens: 5,
        completionTokens: 5,
        latencyMs: 3,
        createdAt: now + 1,
      ),
    );

    final usage = await repo.usage();
    expect(usage, hasLength(2));
    expect(usage.first.totalTokens, 10);

    final totals = await repo.usageTotals();
    expect(totals['offline'], 40);
  });

  test('clearHistory wipes conversations and usage', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await repo.createConversation(
      AiConversation(title: 'T', createdAt: now, updatedAt: now),
    );
    await repo.addMessage(id, _message(AiRole.user, 'x'));
    await repo.recordUsage(
      AiUsageRecord(serviceId: 'offline', createdAt: now),
    );

    await repo.clearHistory();

    expect(await repo.conversations(), isEmpty);
    expect(await repo.usage(), isEmpty);
  });
}
