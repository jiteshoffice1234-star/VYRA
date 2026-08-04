import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/core/database/app_database.dart';
import 'package:vyra/data/repositories/category_repository.dart';
import 'package:vyra/data/repositories/habit_repository.dart';
import 'package:vyra/data/repositories/journal_repository.dart';
import 'package:vyra/data/repositories/note_repository.dart';
import 'package:vyra/data/repositories/tag_repository.dart';
import 'package:vyra/domain/models/category.dart';
import 'package:vyra/domain/models/checklist_item.dart';
import 'package:vyra/domain/models/habit.dart';
import 'package:vyra/domain/models/journal_entry.dart';
import 'package:vyra/domain/models/mood.dart';
import 'package:vyra/domain/models/note.dart';

void main() {
  late AppDatabase database;
  late JournalRepository journals;
  late HabitRepository habits;
  late NoteRepository notes;
  late TagRepository tags;
  late CategoryRepository categories;

  setUp(() async {
    database = await AppDatabase.openInMemory();
    tags = TagRepository(database.db);
    journals = JournalRepository(database.db, tags);
    habits = HabitRepository(database.db);
    notes = NoteRepository(database.db, tags);
    categories = CategoryRepository(database.db);
  });

  tearDown(() async {
    await database.close();
  });

  test('journal round-trip with tags and favorite', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await journals.insert(
      JournalEntry(
        title: 'First entry',
        content: 'A great day',
        mood: Mood.happy,
        isFavorite: false,
        entryDate: DateTime(2026, 8, 4),
        createdAt: now,
        updatedAt: now,
      ),
      const ['work', 'ideas'],
    );

    final all = await journals.getAll();
    expect(all, hasLength(1));
    expect(all.first.title, 'First entry');
    expect(all.first.mood, Mood.happy);
    expect(all.first.tags, containsAll(['work', 'ideas']));

    await journals.setFavorite(id, true);
    final fav = await journals.getById(id);
    expect(fav!.isFavorite, isTrue);

    await journals.update(
      fav.copyWith(title: 'Renamed', content: 'New content'),
      const ['personal'],
    );
    final updated = await journals.getById(id);
    expect(updated!.title, 'Renamed');
    expect(updated.tags, ['personal']);

    await journals.delete(id);
    expect(await journals.getAll(), isEmpty);
  });

  test('habit logs upsert and grouped counts', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await habits.insert(
      Habit(
        name: 'Read',
        description: '30 minutes',
        type: HabitType.good,
        color: 0xFF10B981,
        iconIndex: 0,
        targetPerDay: 1,
        reminderEnabled: false,
        createdAt: now,
      ),
    );

    await habits.setCount(id, DateTime(2026, 8, 3), 1);
    await habits.setCount(id, DateTime(2026, 8, 4), 1);
    // Upsert same day.
    await habits.setCount(id, DateTime(2026, 8, 4), 2);

    final counts = await habits.countsForHabit(id);
    expect(counts['2026-08-03'], 1);
    expect(counts['2026-08-04'], 2);

    final grouped = await habits.countsGrouped();
    expect(grouped[id]!['2026-08-04'], 2);

    await habits.delete(id);
    final groupedAfterDelete = await habits.countsGrouped();
    expect(groupedAfterDelete.containsKey(id), isFalse);
  });

  test('note round-trip with checklist items and pin', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await notes.insert(
      Note(
        title: 'Groceries',
        content: '',
        type: NoteType.checklist,
        color: 0xFFF59E0B,
        isPinned: false,
        isFavorite: false,
        createdAt: now,
        updatedAt: now,
        items: const [
          ChecklistItem(text: 'Milk', isChecked: true, position: 0),
          ChecklistItem(text: 'Eggs', isChecked: false, position: 1),
        ],
      ),
      const ['home'],
    );

    final all = await notes.getAll();
    expect(all, hasLength(1));
    expect(all.first.items, hasLength(2));
    expect(all.first.checkedCount, 1);
    expect(all.first.tags, ['home']);

    await notes.setPinned(id, true);
    final pinned = await notes.getById(id);
    expect(pinned!.isPinned, isTrue);

    await notes.delete(id);
    expect(await notes.getAll(), isEmpty);
  });

  test('categories are filtered by kind', () async {
    await categories.insert('Health', 0xFF10B981, CategoryKind.habit);
    await categories.insert('Work', 0xFF6C5CE7, CategoryKind.note);

    final habitCats = await categories.getAll(kind: CategoryKind.habit);
    final noteCats = await categories.getAll(kind: CategoryKind.note);

    expect(habitCats.map((c) => c.name), ['Health']);
    expect(noteCats.map((c) => c.name), ['Work']);
  });
}
