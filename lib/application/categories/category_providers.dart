import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/category.dart';
import '../providers/app_providers.dart';

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<Category>>(CategoriesNotifier.new);

class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() async {
    final repo = await ref.watch(categoryRepositoryProvider.future);
    return repo.getAll();
  }

  /// Creates a category and returns its new database id.
  Future<int> add(String name, int color, CategoryKind kind) async {
    final repo = await ref.read(categoryRepositoryProvider.future);
    final id = await repo.insert(name, color, kind);
    ref.invalidateSelf();
    return id;
  }

  Future<void> delete(int id) async {
    final repo = await ref.read(categoryRepositoryProvider.future);
    await repo.delete(id);
    ref.invalidateSelf();
  }
}
