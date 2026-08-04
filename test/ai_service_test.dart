import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/domain/models/ai/ai_conversation.dart';
import 'package:vyra/domain/services/ai/ai_service.dart';
import 'package:vyra/domain/services/ai/offline_ai_service.dart';
import 'package:vyra/domain/services/ai/prompt_manager.dart';

void main() {
  group('PromptManager', () {
    test('renders a template with substitutions', () {
      final manager = PromptManager(initialTemplates: [
        const PromptTemplate(
          id: 'summary',
          name: 'Summary',
          description: 'Summarizes a day',
          template: 'Summarize {date} for {name}.',
        ),
      ]);

      expect(
        manager.render('summary', {'date': 'Aug 4', 'name': 'Alex'}),
        'Summarize Aug 4 for Alex.',
      );
    });

    test('unknown placeholders are left untouched', () {
      final manager = PromptManager(initialTemplates: [
        const PromptTemplate(
          id: 't',
          name: 'T',
          description: 'x',
          template: 'Hi {name} ({missing})',
        ),
      ]);
      expect(manager.render('t', {'name': 'Bob'}), 'Hi Bob ({missing})');
    });

    test('unknown template id throws', () {
      final manager = PromptManager();
      expect(() => manager.render('nope', {}), throwsStateError);
    });

    test('register overrides and templates are listed', () {
      final manager = PromptManager();
      manager.register(
        const PromptTemplate(id: 'a', name: 'A', description: 'x', template: 'a'),
      );
      manager.register(
        const PromptTemplate(id: 'b', name: 'B', description: 'y', template: 'b'),
      );
      expect(manager.templates, hasLength(2));
    });
  });

  group('OfflineAIService', () {
    const service = OfflineAIService();

    test('is the unconfigured fallback', () {
      expect(service.id, 'offline');
      expect(service.isConfigured, isFalse);
      expect(service.supportsStreaming, isTrue);
    });

    test('complete returns a local fallback reply', () async {
      final response = await service.complete(
        const AiRequest(
          messages: [AiMessage(role: AiRole.user, content: 'What are my stats?', createdAt: 0)],
        ),
      );
      expect(response.fallback, isTrue);
      expect(response.content, isNotEmpty);
      expect(response.content, contains('What are my stats?'));
    });

    test('stream emits start, chunks and done', () async {
      final events = await service
          .stream(
            const AiRequest(
              messages: [AiMessage(role: AiRole.user, content: 'Hello', createdAt: 0)],
            ),
          )
          .toList();

      expect(events.first, isA<AiStreamStart>());
      expect(events.last, isA<AiStreamDone>());
      final chunks = events.whereType<AiStreamChunk>().map((c) => c.text).join();
      expect(chunks, contains('Hello'));
    });

    test('empty request still yields a usable reply', () async {
      final response = await service.complete(
        const AiRequest(messages: []),
      );
      expect(response.content, isNotEmpty);
    });
  });
}
