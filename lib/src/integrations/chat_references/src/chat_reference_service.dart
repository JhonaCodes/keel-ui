part of '../chat_references.dart';

const _maximumSuggestions = 8;
const _maximumReferenceContext = 40000;
const _maximumItemContext = 16000;
const _directoryCacheLifetime = Duration(seconds: 15);
const _maximumDirectories = 3000;

/// Cuántas carpetas se traen POR RAÍZ cuando hay varias. Sin el tope, un
/// monorepo se come la lista entera y los otros proyectos no aparecen nunca.
const _maximumDirectoriesPerRoot = 600;

const _skippedDirectoryNames = {
  '.git',
  '.dart_tool',
  'build',
  'node_modules',
  'Pods',
  'DerivedData',
  '__pycache__',
};

typedef _DirectoryCacheEntry = ({DateTime scannedAt, List<String> paths});

/// Catálogo determinista de recursos que el usuario puede mencionar.
///
/// La selección inserta enlaces `keel://` tipados. El texto sigue siendo
/// Markdown legible, mientras el runtime resuelve IDs y rutas sin adivinar
/// nombres ni confiar en contenido escrito a mano.
class ChatReferenceService {
  ChatReferenceService._();

  static final Map<String, _DirectoryCacheEntry> _directoryCache = {};
  static final RegExp _referenceLinkPattern = RegExp(r'\((keel://[^)\s]+)\)');
  static final RegExp _referenceMarkdownPattern = RegExp(
    r'\[((?:\\.|[^\]])+)\]\((keel://[^)\s]+)\)',
  );
  static final RegExp _agentPattern = RegExp(
    r'@([a-z0-9_-]{1,16})(?![a-z0-9_-])',
  );

  static ChatReferenceQuery? queryAt(String text, int caretOffset) {
    if (caretOffset < 0 || caretOffset > text.length) return null;
    var start = caretOffset;
    while (start > 0 && !_isWhitespace(text.codeUnitAt(start - 1))) {
      start--;
    }
    if (start == caretOffset) return null;
    final token = text.substring(start, caretOffset);
    final kind = switch (token.codeUnitAt(0)) {
      0x2F => ChatReferenceKind.directory,
      0x40 => ChatReferenceKind.agent,
      0x24 => ChatReferenceKind.skill,
      0x23 => ChatReferenceKind.knowledge,
      _ => null,
    };
    if (kind == null || token.length > 80) return null;
    return ChatReferenceQuery(
      kind: kind,
      text: token.substring(1),
      start: start,
      end: caretOffset,
    );
  }

  static Future<List<ChatReferenceSuggestion>> suggestions({
    required ChatReferenceScope scope,
    required ChatReferenceQuery query,
  }) async {
    final candidates = switch (query.kind) {
      ChatReferenceKind.directory => await _directorySuggestions(scope),
      ChatReferenceKind.agent => _agentSuggestions(scope.agents),
      ChatReferenceKind.skill => _instructionSuggestions(),
      ChatReferenceKind.rule => const <ChatReferenceSuggestion>[],
      ChatReferenceKind.knowledge => _knowledgeSuggestions(),
    };
    final wanted = query.text.trim().toLowerCase();
    final filtered =
        candidates
            .where(
              (candidate) =>
                  wanted.isEmpty ||
                  candidate.searchText.toLowerCase().contains(wanted),
            )
            .toList()
          ..sort((left, right) {
            final leftStarts = left.searchText.toLowerCase().startsWith(wanted);
            final rightStarts = right.searchText.toLowerCase().startsWith(
              wanted,
            );
            if (leftStarts != rightStarts) return leftStarts ? -1 : 1;
            return left.title.toLowerCase().compareTo(
              right.title.toLowerCase(),
            );
          });
    return filtered.take(_maximumSuggestions).toList();
  }

  static AgentProfile? explicitlyMentionedMember(
    String text,
    List<AgentProfile> members,
  ) {
    final prose = stripCodeSpans(text);
    for (final match in _agentPattern.allMatches(prose)) {
      final handle = match.group(1);
      final member = members
          .where((candidate) => candidate.name == handle)
          .firstOrNull;
      if (member != null) return member;
    }
    return null;
  }

  /// Texto legible para superficies sin renderer Markdown, como la cola.
  static String visibleText(String text) => text.replaceAllMapped(
    _referenceMarkdownPattern,
    (match) => _unescapeLabel(match.group(1) ?? ''),
  );

  /// Conserva los IDs ocultos al editar una espera, siempre que el usuario
  /// no haya borrado ni cambiado el token visible que los representaba.
  static String restoreReferencesAfterEdit(String original, String edited) {
    var restored = edited;
    for (final match in _referenceMarkdownPattern.allMatches(original)) {
      final insertion = match.group(0);
      final label = _unescapeLabel(match.group(1) ?? '');
      if (insertion == null || label.isEmpty) continue;
      final token = RegExp.escape(label);
      restored = restored.replaceAllMapped(
        RegExp('(^|\\s)($token)(?=\\s|\$|[.,;:!?])', multiLine: true),
        (visibleMatch) => '${visibleMatch.group(1)}$insertion',
      );
    }
    return restored;
  }

  /// Materializa solo los recursos enlazados explícitamente en este mensaje.
  /// Los links inválidos o borrados se ignoran; nunca permiten escapar de las
  /// raíces del scope ni inventar contenido de catálogo.
  static Future<String> promptContext(
    ChatReferenceScope scope,
    String text,
  ) async {
    final uris = <Uri>[];
    final seen = <String>{};
    for (final match in _referenceLinkPattern.allMatches(text)) {
      final raw = match.group(1);
      if (raw == null || !seen.add(raw)) continue;
      final uri = Uri.tryParse(raw);
      if (uri != null && uri.scheme == 'keel') uris.add(uri);
    }
    if (uris.isEmpty) return '';

    final sections = <String>[];
    for (final uri in uris) {
      final section = await _sectionFor(scope, uri);
      if (section.isEmpty) continue;
      final used = sections.fold<int>(0, (total, item) => total + item.length);
      if (used >= _maximumReferenceContext) break;
      sections.add(
        section.length > _maximumItemContext
            ? '${section.substring(0, _maximumItemContext)}\n…'
            : section,
      );
    }
    if (sections.isEmpty) return '';
    final joined = sections.join('\n\n');
    final bounded = joined.length > _maximumReferenceContext
        ? '${joined.substring(0, _maximumReferenceContext)}\n…'
        : joined;
    return 'REFERENCIAS EXPLÍCITAS DEL USUARIO\n$bounded';
  }

  static bool _isWhitespace(int codeUnit) =>
      codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0D;

  static List<ChatReferenceSuggestion> _agentSuggestions(
    List<AgentProfile> members,
  ) => [
    for (final member in members)
      ChatReferenceSuggestion(
        kind: ChatReferenceKind.agent,
        title: '@${member.name}',
        subtitle: 'Agente · ${member.role}',
        insertion: '@${member.name}',
        searchText: '${member.name} ${member.role}',
      ),
  ];

  static List<ChatReferenceSuggestion> _instructionSuggestions() {
    final skills = SkillsService.instance.notifier.data.skills;
    final rules = RulesService.instance.notifier.data.rules;
    return [
      for (final skill in skills)
        ChatReferenceSuggestion(
          kind: ChatReferenceKind.skill,
          title: '\$${skill.name}',
          subtitle: skill.isGlobal ? 'Skill · global' : 'Skill',
          insertion:
              '[\$${_escapeLabel(skill.name)}](keel://skill/${skill.id})',
          searchText: '${skill.name} skill',
        ),
      for (final rule in rules)
        ChatReferenceSuggestion(
          kind: ChatReferenceKind.rule,
          title: '\$${rule.name}',
          subtitle: 'Regla',
          insertion: '[\$${_escapeLabel(rule.name)}](keel://rule/${rule.id})',
          searchText: '${rule.name} regla',
        ),
    ];
  }

  /// Las carpetas ofrecidas por `/`.
  ///
  /// Con una sola raíz —una sesión de proyecto— el enlace guarda la ruta
  /// relativa a secas, igual que siempre: los mensajes en cola escritos
  /// antes de esto siguen resolviendo. Con varias, el enlace tiene que decir
  /// TAMBIÉN de qué raíz cuelga, porque `lib/src` existe en los diez.
  static Future<List<ChatReferenceSuggestion>> _directorySuggestions(
    ChatReferenceScope scope,
  ) async {
    final roots = scope.directoryRoots;
    final suggestions = <ChatReferenceSuggestion>[];
    final perRoot = roots.length > 1
        ? _maximumDirectoriesPerRoot
        : _maximumDirectories;

    for (final entry in roots) {
      final labelled = entry.label.isNotEmpty;
      if (labelled) {
        // La raíz misma también se puede nombrar: pedir "mirá keel-ui" es
        // más común que pedir una subcarpeta suya.
        suggestions.add(
          ChatReferenceSuggestion(
            kind: ChatReferenceKind.directory,
            title: '/${entry.label}',
            subtitle: entry.root,
            insertion:
                '[/${_escapeLabel(entry.label)}]'
                '(keel://directory?path=.'
                '&root=${Uri.encodeQueryComponent(entry.root)})',
            searchText: entry.label,
          ),
        );
      }
      final paths = await _directoriesUnder(
        entry.root,
        depth: scope.directoryDepth,
        limit: perRoot,
      );
      for (final relativePath in paths) {
        final visible = labelled
            ? '${entry.label}/$relativePath'
            : relativePath;
        suggestions.add(
          ChatReferenceSuggestion(
            kind: ChatReferenceKind.directory,
            title: '/$visible',
            subtitle: labelled ? entry.root : 'Directorio del proyecto',
            insertion:
                '[/${_escapeLabel(visible)}]'
                '(keel://directory?path=${Uri.encodeQueryComponent(relativePath)}'
                '${labelled ? '&root=${Uri.encodeQueryComponent(entry.root)}' : ''})',
            searchText: visible,
          ),
        );
      }
    }
    return suggestions;
  }

  static List<ChatReferenceSuggestion> _knowledgeSuggestions() {
    final knowledge = KnowledgeService.instance.notifier;
    final suggestions = <ChatReferenceSuggestion>[];
    for (final base in knowledge.data.bases) {
      suggestions.add(
        ChatReferenceSuggestion(
          kind: ChatReferenceKind.knowledge,
          title: '#${base.name}',
          subtitle: 'Base de Saber · ${base.description}',
          insertion:
              '[#${_escapeLabel(base.name)}](keel://knowledge/${base.id})',
          searchText: '${base.name} ${base.description}',
        ),
      );
      final index = knowledge.indexOf(base.id);
      if (index == null) continue;
      for (final node in _flattenKnowledge(index.nodes)) {
        if (node.isDirectory) continue;
        suggestions.add(
          ChatReferenceSuggestion(
            kind: ChatReferenceKind.knowledge,
            title: '#${base.name}/${node.relativePath}',
            subtitle: 'Documento de Saber',
            insertion:
                '[#${_escapeLabel(base.name)}/${_escapeLabel(node.relativePath)}]'
                '(keel://knowledge/${base.id}?path=${Uri.encodeQueryComponent(node.relativePath)})',
            searchText: '${base.name} ${node.relativePath}',
          ),
        );
      }
    }
    return suggestions;
  }

  static Iterable<KnowledgeNode> _flattenKnowledge(
    Iterable<KnowledgeNode> nodes,
  ) sync* {
    for (final node in nodes) {
      yield node;
      yield* _flattenKnowledge(node.children);
    }
  }

  static Future<List<String>> _directoriesUnder(
    String root, {
    required int depth,
    required int limit,
  }) async {
    final normalizedRoot = path.normalize(path.absolute(root));
    final cacheKey = '$normalizedRoot|$depth|$limit';
    final cached = _directoryCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.scannedAt) < _directoryCacheLifetime) {
      return cached.paths;
    }
    final rootDirectory = Directory(normalizedRoot);
    if (!await rootDirectory.exists()) return const [];

    final result = <String>[];
    final pending = <({Directory directory, int level})>[
      (directory: rootDirectory, level: 0),
    ];
    while (pending.isNotEmpty && result.length < limit) {
      final current = pending.removeLast();
      try {
        await for (final entity in current.directory.list(followLinks: false)) {
          if (entity is! Directory) continue;
          final name = path.basename(entity.path);
          if (_skippedDirectoryNames.contains(name)) continue;
          final relativePath = path.relative(entity.path, from: normalizedRoot);
          if (relativePath.startsWith('..')) continue;
          result.add(relativePath);
          if (depth == _unlimitedDepth || current.level + 1 < depth) {
            pending.add((directory: entity, level: current.level + 1));
          }
          if (result.length >= limit) break;
        }
      } on FileSystemException {
        // Un subdirectorio sin permisos no invalida el resto del proyecto.
      }
    }
    result.sort();
    _directoryCache[cacheKey] = (scannedAt: DateTime.now(), paths: result);
    return result;
  }

  static Future<String> _sectionFor(ChatReferenceScope scope, Uri uri) async {
    return switch (uri.host) {
      'directory' => await _directorySection(scope, uri),
      'skill' => _skillSection(uri),
      'rule' => _ruleSection(uri),
      'knowledge' => await _knowledgeSection(uri),
      _ => '',
    };
  }

  static Future<String> _directorySection(
    ChatReferenceScope scope,
    Uri uri,
  ) async {
    final relativePath = uri.queryParameters['path']?.trim() ?? '';
    if (relativePath.isEmpty) return '';

    // La raíz declarada en el enlace vale SOLO si sigue siendo una raíz de
    // este scope: un enlace fabricado a mano apuntando a `/etc` no lo es.
    final declaredRoot = uri.queryParameters['root']?.trim() ?? '';
    final roots = scope.directoryRoots;
    final rootValue = declaredRoot.isEmpty
        ? (roots.length == 1 ? roots.single.root : '')
        : (roots.any((entry) => entry.root == declaredRoot)
              ? declaredRoot
              : '');
    if (rootValue.isEmpty) return '';

    final lexicalRoot = path.normalize(path.absolute(rootValue));
    final lexicalTarget = path.normalize(path.join(lexicalRoot, relativePath));
    if (lexicalTarget != lexicalRoot &&
        !path.isWithin(lexicalRoot, lexicalTarget)) {
      return '';
    }
    try {
      final target = Directory(lexicalTarget);
      if (!await target.exists()) return '';
      final resolvedRoot = await Directory(lexicalRoot).resolveSymbolicLinks();
      final resolvedTarget = await target.resolveSymbolicLinks();
      if (resolvedTarget != resolvedRoot &&
          !path.isWithin(resolvedRoot, resolvedTarget)) {
        return '';
      }
      return 'DIRECTORIO ENLAZADO: $resolvedTarget\n'
          'Trabajá sobre esta carpeta cuando el pedido se refiera a ella.';
    } on FileSystemException {
      return '';
    }
  }

  static String _skillSection(Uri uri) {
    final id = uri.pathSegments.firstOrNull;
    final skill = SkillsService.instance.notifier.data.skills
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    if (skill == null || skill.content.trim().isEmpty) return '';
    return 'SKILL ENLAZADA: ${skill.name}\n${skill.content.trim()}';
  }

  static String _ruleSection(Uri uri) {
    final id = uri.pathSegments.firstOrNull;
    final rule = RulesService.instance.notifier.data.rules
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    if (rule == null || rule.content.trim().isEmpty) return '';
    return 'REGLA ENLAZADA: ${rule.name}\n${rule.content.trim()}';
  }

  static Future<String> _knowledgeSection(Uri uri) async {
    final id = uri.pathSegments.firstOrNull;
    final knowledge = KnowledgeService.instance.notifier;
    final base = knowledge.data.bases
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    if (base == null) return '';
    final relativePath = uri.queryParameters['path']?.trim() ?? '';
    if (relativePath.isEmpty) {
      final brief = knowledge.briefFor([base.name]);
      return brief.isEmpty ? '' : 'SABER ENLAZADO: ${base.name}\n$brief';
    }
    final rootValue = knowledge.rootPathOf(base).trim();
    if (rootValue.isEmpty) return '';
    final lexicalRoot = path.normalize(path.absolute(rootValue));
    final lexicalTarget = path.normalize(path.join(lexicalRoot, relativePath));
    if (!path.isWithin(lexicalRoot, lexicalTarget)) {
      return '';
    }
    try {
      final file = File(lexicalTarget);
      if (!await file.exists()) return '';
      final resolvedRoot = await Directory(lexicalRoot).resolveSymbolicLinks();
      final resolvedTarget = await file.resolveSymbolicLinks();
      if (!path.isWithin(resolvedRoot, resolvedTarget)) return '';
      final kind = KnowledgeDocument.kindOf(relativePath);
      if (kind == KnowledgeDocumentKind.image ||
          kind == KnowledgeDocumentKind.unsupported) {
        return 'DOCUMENTO DE SABER ENLAZADO: ${base.name}/$relativePath\n'
            'Ruta: $resolvedTarget';
      }
      final handle = await File(resolvedTarget).open();
      late final List<int> bytes;
      try {
        bytes = await handle.read(_maximumItemContext + 1);
      } finally {
        await handle.close();
      }
      final content = utf8.decode(bytes, allowMalformed: true);
      return 'DOCUMENTO DE SABER ENLAZADO: ${base.name}/$relativePath\n'
          '$content';
    } on FileSystemException {
      return '';
    }
  }

  static String _escapeLabel(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('[', '\\[')
      .replaceAll(']', '\\]');

  static String _unescapeLabel(String value) =>
      value.replaceAllMapped(RegExp(r'\\(.)'), (match) => match.group(1) ?? '');
}
