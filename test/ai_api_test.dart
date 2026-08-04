import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/domain/models/ai/ai_conversation.dart';
import 'package:vyra/domain/models/ai/ai_usage_record.dart';
import 'package:vyra/domain/services/ai/ai_api.dart';
import 'package:vyra/domain/services/ai/ai_service.dart';
import 'package:vyra/domain/services/ai/offline_ai_service.dart';
import 'package:vyra/domain/services/ai/prompt_manager.dart';

void main() {
  late List<AiConversation> saved;
  late List<AiMessage> appended;
  late List<AiUsageRecord> usage;

  AiApi _api({AIService? service}) {
    saved = [];
    appended = [];
    usage = [];
    return AiApi(
      service: service ?? const OfflineAIService(),
      prompts: PromptManager(),
      persistConversation: (c) async {
        saved.add(c);
        return saved.length;
      },
      appendMessage: (id, m) async => appended.add(m),
      recordUsage: (u) async => usage.add(u),
    );
  }

  group('AiApi', () {
    test('ask returns an offline reply without a conversation but records usage',
        () async {
      final api = _api();
      final response = await api.ask('What is my longest streak?');

      expect(response.fallback, isTrue);
      expect(response.content, contains('What is my longest streak?'));
      expect(saved, isEmpty);
      expect(appended, isEmpty);
      expect(usage, hasLength(1));
      expect(usage.single.conversationId, isNull);
      expect(usage.single.serviceId, 'offline');
    });

    test('chat persists conversation, messages and usage', () async {
      final api = _api();
      final id = await api.chat(
        title: 'Streak question',
        prompt: 'What is my longest streak?',
      );

      expect(id, 1);
      expect(saved.single.title, 'Streak question');
      expect(saved.single.messages, isEmpty); // created before messages
      expect(appended, hasLength(2)); // user + assistant
      expect(appended.first.role, AiRole.user);
      expect(appended.last.role, AiRole.assistant);
      expect(appended.last.content, isNotEmpty);
      expect(usage.single.conversationId, id);
      expect(usage.single.serviceId, 'offline');
    });

    test('chat reuses an existing conversation id', () async {
      final api = _api();
      final id = await api.chat(conversationId: 7, prompt: 'Hello');

      expect(id, 7);
      expect(saved, isEmpty);
      expect(appended, hasLength(2));
    });

    test('chat derives a title from the prompt when none given', () async {
      final api = _api();
      await api.chat(prompt: 'A very long prompt that should be truncated for the title of this conversation');
      expect(saved.single.title, endsWith('…'));
    });

    test('renderPrompt delegates to the prompt manager', () {
      final api = AiApi(
        service: const OfflineAIService(),
        prompts: PromptManager(initialTemplates: [
          const PromptTemplate(
            id: 'greet',
            name: 'Greet',
            description: 'x',
            template: 'Hello {name}',
          ),
        ]),
        persistConversation: (c) async => 1,
        appendMessage: (id, m) async {},
        recordUsage: (u) async {},
      );
      expect(api.renderPrompt('greet', {'name': 'Ada'}), 'Hello Ada');
    });
  });
}
