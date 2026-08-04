import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/tag.dart';
import '../providers/app_providers.dart';

final tagProvider =
    AsyncNotifierProvider<TagsNotifier, List<Tag>>(TagsNotifier.new);

class TagsNotifier extends AsyncNotifier<List<Tag>> {
  @override
  Future<List<Tag>> build() async {
    final repo = await ref.watch(tagRepositoryProvider.future);
    return repo.allTags();
  }
}
