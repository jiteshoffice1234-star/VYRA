/// A named, parameterised prompt template.
///
/// Templates use `{placeholder}` syntax; [render] substitutes the supplied
/// values. Unknown placeholders are left untouched so templates degrade
/// gracefully when a future feature stops supplying a value.
class PromptTemplate {
  const PromptTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.template,
  });

  final String id;
  final String name;
  final String description;
  final String template;

  /// Substitutes `{key}` occurrences with the given values.
  String render(Map<String, String> values) {
    var out = template;
    values.forEach((key, value) {
      out = out.replaceAll('{$key}', value);
    });
    return out;
  }
}

/// Registry of prompt templates, one per AI feature (summaries, insights,
/// search expansion, ...). Kept free of Flutter / backend concerns so it is
/// unit-testable and reusable by any future AI UI.
class PromptManager {
  PromptManager({Iterable<PromptTemplate> initialTemplates = const []}) {
    for (final t in initialTemplates) {
      register(t);
    }
  }

  final Map<String, PromptTemplate> _templates = {};

  void register(PromptTemplate template) => _templates[template.id] = template;

  PromptTemplate? template(String id) => _templates[id];

  /// Renders the template with [id]. Throws [StateError] for unknown ids so
  /// wiring mistakes surface loudly instead of producing empty prompts.
  String render(String id, Map<String, String> values) {
    final template = _templates[id];
    if (template == null) {
      throw StateError('Unknown prompt template: $id');
    }
    return template.render(values);
  }

  List<PromptTemplate> get templates => _templates.values.toList(growable: false);
}
