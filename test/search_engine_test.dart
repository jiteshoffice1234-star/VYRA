import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/domain/models/category.dart';
import 'package:vyra/domain/models/habit.dart';
import 'package:vyra/domain/models/journal_entry.dart';
import 'package:vyra/domain/models/mood.dart';
import 'package:vyra/domain/models/note.dart';
import 'package:vyra/domain/models/search_result.dart';
import 'package:vyra/domain/models/tag.dart';
import 'package:vyra/domain/services/universal_search.dart';

const _now = 1785000000000;

JournalEntry _entry(int id, String title, String content, {List<String> tags = const []}) =>
    JournalEntry(
      id: id,
      title: title,
      content: content,
      mood: Mood.neutral,
      isFavorite: false,
      entryDate: DateTime(2026, 8, 4),
      createdAt: _now,
      updatedAt: _now,
      tags: tags,
    );

Note _note(int id, String title, String content) => Note(
      id: id,
      title: title,
      content: content,
      type: NoteType.text,
      color: 0xFFF59E0B,
      isPinned: false,
      isFavorite: false,
      createdAt: _now,
      updatedAt: _now,
    );

Habit _habit(int id, String name) => Habit(
      id: id,
      name: name,
      description: 'A description',
      type: HabitType.good,
      color: 0xFF10B981,
      iconIndex: 0,
      targetPerDay: 1,
      reminderEnabled: false,
      createdAt: _now,
    );

SearchRequest _request(
  String query, {
  Set<SearchItemType>? types,
  List<JournalEntry>? journals,
}) =>
    SearchRequest(
      query: query,
      types: types ?? SearchItemType.values.toSet(),
      journals: journals ??
          [
            _entry(1, 'Morning run', 'I went for a run in the park.'),
            _entry(2, 'Work notes', 'Focus on the project.'),
          ],
      notes: [_note(10, 'Groceries', 'Milk, eggs, bread')],
      habits: [_habit(20, 'Read')],
      categories: [
        const Category(
            id: 30, name: 'Health', color: 0xFF10B981, kind: CategoryKind.habit),
      ],
      tags: const [Tag(id: 40, name: 'fitness', createdAt: _now)],
      sortNewest: false,
    );

void main() {
  const engine = KeywordSearchEngine();

  group('KeywordSearchEngine', () {
    test('empty or blank query returns nothing', () async {
      expect(await engine.search(_request('')), isEmpty);
      expect(await engine.search(_request('   ')), isEmpty);
    });

    test('matches across all five types', () async {
      final results = await engine.search(_request('e'));
      final types = results.map((r) => r.type).toSet();
      expect(types, SearchItemType.values.toSet());
    });

    test('title matches outrank body matches', () async {
      // 'run' hits journal 1's title (and its body), 'project' only hits
      // journal 2's body — the title match must rank higher.
      final titleResults = await engine.search(_request('run'));
      expect(titleResults, hasLength(1));
      expect(titleResults.single.type, SearchItemType.journal);
      expect(titleResults.single.id, 1);

      final bodyResults = await engine.search(_request('project'));
      expect(bodyResults.single.type, SearchItemType.journal);
      expect(bodyResults.single.id, 2);
      expect(bodyResults.single.score, lessThan(100));

      expect(titleResults.single.score,
          greaterThan(bodyResults.single.score));
    });

    test('journals can be found by their tags', () async {
      final results = await engine.search(
        _request('fitness', journals: [_entry(1, 'Morning run', 'A great run', tags: ['fitness'])]),
      );
      expect(results.any((r) => r.type == SearchItemType.journal && r.id == 1),
          isTrue);
    });

    test('tags are searchable as items', () async {
      final results = await engine.search(_request('fitness'));
      expect(results.any((r) => r.type == SearchItemType.tag), isTrue);
    });

    test('type filter limits results', () async {
      final results = await engine
          .search(_request('e', types: {SearchItemType.journal}));
      expect(results.every((r) => r.type == SearchItemType.journal), isTrue);
    });

    test('newest sort orders by timestamp', () async {
      final request = SearchRequest(
        query: 'e',
        types: SearchItemType.values.toSet(),
        journals: [
          _entry(1, 'Old entry', 'alpha'),
          _entry(2, 'New entry', 'beta'),
        ],
        notes: const [],
        habits: const [],
        categories: const [],
        tags: const [],
        sortNewest: true,
      );
      final results = await engine.search(request);
      expect(results.first.timestamp,
          greaterThanOrEqualTo(results.last.timestamp));
    });
  });
}
