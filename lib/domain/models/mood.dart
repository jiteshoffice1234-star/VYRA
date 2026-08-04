/// Moods a journal entry can carry. Pure domain enum (colors live in UI layer).
enum Mood {
  happy('happy', 'Happy', '😄'),
  excited('excited', 'Excited', '🤩'),
  grateful('grateful', 'Grateful', '🙏'),
  calm('calm', 'Calm', '😌'),
  focused('focused', 'Focused', '🎯'),
  neutral('neutral', 'Neutral', '😐'),
  tired('tired', 'Tired', '😪'),
  anxious('anxious', 'Anxious', '😰'),
  sad('sad', 'Sad', '😢'),
  angry('angry', 'Angry', '😠');

  const Mood(this.id, this.label, this.emoji);

  final String id;
  final String label;
  final String emoji;

  static Mood fromId(String id) =>
      Mood.values.firstWhere((m) => m.id == id, orElse: () => Mood.neutral);
}
