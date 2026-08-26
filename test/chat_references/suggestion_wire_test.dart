import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/chat_references/chat_references.dart';

void main() {
  test('una sugerencia sobrevive el viaje a la ventana de Keel AI', () {
    const suggestion = ChatReferenceSuggestion(
      kind: ChatReferenceKind.skill,
      title: '\$tdd-workflow',
      subtitle: 'Skill · global',
      insertion: '[\$tdd-workflow](keel://skill/skill-tdd)',
      searchText: 'tdd-workflow skill',
    );

    final vuelta = ChatReferenceSuggestion.fromJson(suggestion.toJson());

    expect(vuelta.kind, suggestion.kind);
    expect(vuelta.title, suggestion.title);
    expect(vuelta.subtitle, suggestion.subtitle);
    expect(vuelta.insertion, suggestion.insertion);
    expect(vuelta.searchText, suggestion.searchText);
  });

  test('y la consulta también viaja completa', () {
    const query = ChatReferenceQuery(
      kind: ChatReferenceKind.directory,
      text: 'lib',
      start: 4,
      end: 8,
    );

    final vuelta = ChatReferenceQuery.fromJson(query.toJson());

    expect(vuelta.kind, query.kind);
    expect(vuelta.text, query.text);
    expect(vuelta.start, query.start);
    expect(vuelta.end, query.end);
  });
}
