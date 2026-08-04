/// The app's theme styles, switchable from Settings and persisted.
enum AppThemeStyle {
  modern('modern', 'Modern'),
  neobrutalism('neobrutalism', 'NeoBrutalism'),
  glass('glass', 'Glass');

  const AppThemeStyle(this.id, this.label);

  final String id;
  final String label;

  static AppThemeStyle fromId(String id) =>
      values.firstWhere((s) => s.id == id, orElse: () => AppThemeStyle.modern);
}
