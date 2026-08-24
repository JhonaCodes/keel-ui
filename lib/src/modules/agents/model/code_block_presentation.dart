/// Decides whether a fenced block is a document, a Keel declaration, or
/// source code. The chat can therefore keep every block compact while the
/// full-screen viewer uses the representation that matches its content.
class CodeBlockPresentation {
  const CodeBlockPresentation._({
    required this.title,
    required this.source,
    required this.language,
    required this.rendersMarkdown,
  });

  final String title;
  final String source;
  final String language;
  final bool rendersMarkdown;

  factory CodeBlockPresentation.from({
    required String fenceName,
    required String source,
  }) {
    final normalized = fenceName.trim().toLowerCase();
    if (_markdownFences.contains(normalized)) {
      return CodeBlockPresentation._(
        title: 'Documento',
        source: source,
        language: 'markdown',
        rendersMarkdown: true,
      );
    }
    if (_declarativeFences.contains(normalized)) {
      return CodeBlockPresentation._(
        title: _titleFor(normalized),
        source: _declarativeMarkdown(normalized, source),
        language: 'markdown',
        rendersMarkdown: true,
      );
    }
    return CodeBlockPresentation._(
      title: normalized.isEmpty ? 'Código' : _titleFor(normalized),
      source: source,
      language: _codeLanguage(normalized),
      rendersMarkdown: false,
    );
  }
}

const _markdownFences = {'md', 'markdown', 'text', 'plaintext'};

const _declarativeFences = {
  'agente',
  'cobertura',
  'cumplido',
  'estacion',
  'plan',
  'proyecto',
  'regla',
  'skill',
  'workflow',
};

const _titles = {
  'agente': 'Agente',
  'cobertura': 'Cobertura de migración',
  'cumplido': 'Trabajo completado',
  'estacion': 'Proyecto',
  'plan': 'Plan',
  'proyecto': 'Proyecto',
  'regla': 'Regla',
  'skill': 'Skill',
  'workflow': 'Workflow',
};

const _fieldLabels = {
  'agentes': 'Agentes',
  'capacidades': 'Capacidades',
  'carpeta': 'Directorio de trabajo',
  'conocimiento': 'Conocimiento',
  'contenido': 'Contenido',
  'cuando': 'Cuándo se aplica',
  'gates': 'Gates de calidad',
  'global': 'Global',
  'handle': 'Handle',
  'instrucciones': 'Instrucciones',
  'max_reformulaciones': 'Máximo de reformulaciones',
  'max_subagentes': 'Máximo de subagentes',
  'mcps': 'MCPs',
  'nombre': 'Nombre',
  'proposito': 'Propósito',
  'puntos': 'Puntos',
  'reglas': 'Reglas',
  'responsable': 'Responsable',
  'rol': 'Rol',
  'saber': 'Conocimiento',
  'skills': 'Skills',
  'tipo': 'Tipo',
  'tools': 'Herramientas',
  'workflows': 'Workflows',
};

const _listFields = {
  'agentes',
  'conocimiento',
  'gates',
  'mcps',
  'reglas',
  'saber',
  'skills',
  'tools',
  'workflows',
};

const _languageAliases = {
  'bash': 'bash',
  'c++': 'cpp',
  'c#': 'cs',
  'js': 'javascript',
  'jsx': 'javascript',
  'md': 'markdown',
  'py': 'python',
  'rb': 'ruby',
  'sh': 'bash',
  'shell': 'bash',
  'ts': 'typescript',
  'tsx': 'typescript',
  'yml': 'yaml',
  'zsh': 'bash',
};

String _titleFor(String name) {
  final known = _titles[name];
  if (known != null) return known;
  if (name.isEmpty) return 'Código';
  return '${name[0].toUpperCase()}${name.substring(1)}';
}

String _codeLanguage(String name) {
  if (name.isEmpty) return 'plaintext';
  return _languageAliases[name] ?? name;
}

String _declarativeMarkdown(String name, String source) {
  final fields = _parseFields(source);
  final title = _titleFor(name);
  _DeclarativeField? identity;
  for (final field in fields) {
    if (field.key == 'nombre' || field.key == 'handle') {
      identity = field;
      break;
    }
  }
  final buffer = StringBuffer('# $title');
  if (identity != null && identity.value.isNotEmpty) {
    buffer.write('\n\n## ${identity.value}');
  }

  for (final field in fields) {
    if (field == identity) continue;
    final label = _fieldLabels[field.key] ?? _titleFor(field.key);
    buffer.write('\n\n### $label\n');
    if (field.key == 'capacidades') {
      buffer.write(_capabilitiesMarkdown(field.value));
    } else if (_listFields.contains(field.key)) {
      buffer.write(_listMarkdown(field.value));
    } else {
      buffer.write(field.value.isEmpty ? '_Sin definir_' : field.value);
    }
  }

  if (fields.isEmpty) {
    buffer.write('\n\n${source.trim()}');
  }
  return buffer.toString();
}

String _listMarkdown(String value) {
  final items = value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
  if (items.isEmpty) return '_Ninguno_';
  return items.map((item) => '- `${item.replaceAll('`', '\\`')}`').join('\n');
}

String _capabilitiesMarkdown(String value) {
  final capabilities = value
      .split(';;')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
  if (capabilities.isEmpty) return '_Ninguna_';

  final sections = <String>[];
  for (var index = 0; index < capabilities.length; index++) {
    final parts = capabilities[index]
        .split('|')
        .map((part) => part.trim())
        .toList();
    if (parts.length < 6) {
      sections.add('${index + 1}. ${capabilities[index]}');
      continue;
    }
    final dependencies = parts[4].isEmpty
        ? 'ninguna'
        : parts[4].replaceAll('+', ', ');
    sections.add(
      '${index + 1}. **${parts[1]}** · `${parts[3]}`\n'
      '   - ID: `${parts[0]}`\n'
      '   - Rol: `${parts[2]}`\n'
      '   - Depende de: $dependencies\n'
      '   - ${parts.sublist(5).join('|')}',
    );
  }
  return sections.join('\n');
}

List<_DeclarativeField> _parseFields(String source) {
  final fields = <_DeclarativeField>[];
  final fieldPattern = RegExp(r'^([a-zA-Z_áéíóúñÁÉÍÓÚÑ]+):\s*(.*)$');
  for (final rawLine in source.split('\n')) {
    final match = fieldPattern.firstMatch(rawLine.trimLeft());
    if (match != null) {
      fields.add(
        _DeclarativeField(
          key: match.group(1)!.toLowerCase(),
          value: match.group(2)!.trimRight(),
        ),
      );
      continue;
    }
    if (fields.isEmpty || rawLine.trim().isEmpty) continue;
    final previous = fields.removeLast();
    fields.add(
      _DeclarativeField(
        key: previous.key,
        value: '${previous.value}\n${rawLine.trimRight()}'.trim(),
      ),
    );
  }
  return fields;
}

class _DeclarativeField {
  const _DeclarativeField({required this.key, required this.value});

  final String key;
  final String value;
}
