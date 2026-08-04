import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/ai_repository.dart';
import '../../domain/services/ai/ai_api.dart';
import '../../domain/services/ai/ai_service.dart';
import '../../domain/services/ai/offline_ai_service.dart';
import '../../domain/services/ai/prompt_manager.dart';
import '../providers/app_providers.dart';

/// Persistence for AI conversations and usage.
final aiRepositoryProvider = FutureProvider<AiRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return AiRepository(db.db);
});

/// The active AI backend. Swapping this single provider upgrades the whole
/// app to a real service (e.g. NVIDIA NIM) without touching any UI — the
/// offline fallback keeps everything working until then.
final aiServiceProvider = Provider<AIService>((ref) => const OfflineAIService());

/// Prompt template registry. Register feature templates here as AI features
/// land (journal summaries, habit insights, assistant prompts, ...).
final promptManagerProvider = Provider<PromptManager>((ref) => PromptManager());

/// The app-facing AI facade the UI will consume.
final aiApiProvider = FutureProvider<AiApi>((ref) async {
  final repo = await ref.watch(aiRepositoryProvider.future);
  return AiApi(
    service: ref.watch(aiServiceProvider),
    prompts: ref.watch(promptManagerProvider),
    persistConversation: repo.createConversation,
    appendMessage: repo.addMessage,
    recordUsage: repo.recordUsage,
  );
});
