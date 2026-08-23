part of '../catalog_bundle.dart';

/// Qué tan grave es lo que se encontró.
enum BundleRisk {
  alta('alta'),
  media('media'),
  baja('baja');

  const BundleRisk(this.label);
  final String label;
}

/// Una cosa encontrada en un paquete que alguien más armó.
class BundleFinding {
  const BundleFinding({
    required this.risk,
    required this.kind,
    required this.where,
    required this.what,
    this.excerpt = '',
  });

  final BundleRisk risk;

  /// Qué clase de hallazgo es: «comando peligroso», «ruta personal»…
  final String kind;

  /// En qué entidad del paquete: `tool «desplegar»`, `skill «revisión»`.
  final String where;

  /// Qué pasaría, en una línea y en castellano.
  final String what;

  /// El texto exacto que lo disparó. Va SIEMPRE que haya: una alerta sin el
  /// fragmento obliga a creerle a la app, y de eso se trata justamente lo
  /// que estamos revisando.
  final String excerpt;

  String get id => '$kind|$where|$excerpt';
}

/// El resultado de revisar un paquete antes de instalarlo.
class BundleAudit {
  const BundleAudit({required this.findings, required this.scannedTexts});

  final List<BundleFinding> findings;

  /// Cuántos textos se miraron. Sirve para decir «revisé 34 textos y no
  /// encontré nada», que es distinto de «no revisé».
  final int scannedTexts;

  bool get isClean => findings.isEmpty;

  List<BundleFinding> at(BundleRisk risk) =>
      findings.where((finding) => finding.risk == risk).toList();

  bool get hasHighRisk => findings.any((f) => f.risk == BundleRisk.alta);

  int countAt(BundleRisk risk) => at(risk).length;
}

/// Un patrón de texto que enciende una alerta.
class _Pattern {
  _Pattern(String source, this.risk, this.kind, this.what)
    : expression = RegExp(source, caseSensitive: false);

  final RegExp expression;
  final BundleRisk risk;
  final String kind;
  final String what;
}

/// Lo que puede correr en tu máquina.
///
/// Se buscan en el código de las tools y los comandos de los hooks —donde se
/// ejecutan— pero TAMBIÉN en las skills, reglas y prompts: un texto que le
/// dice al agente «corré `curl … | sh`» termina en el mismo lugar que un
/// script, solo que pasando por un modelo que quiere ayudar.
final _dangerousCommands = <_Pattern>[
  _Pattern(
    r'\bsudo\b',
    BundleRisk.alta,
    'comando privilegiado',
    'Pide permisos de administrador de tu máquina.',
  ),
  _Pattern(
    r'\brm\s+-[a-z]*[rf][a-z]*\s+[^\s]',
    BundleRisk.alta,
    'borrado recursivo',
    'Borra archivos sin preguntar.',
  ),
  _Pattern(
    r'(curl|wget|fetch)[^\n|]{0,200}\|\s*(sudo\s+)?(ba|z|k)?sh',
    BundleRisk.alta,
    'descarga y ejecuta',
    'Baja algo de internet y lo corre sin que vos lo veas.',
  ),
  _Pattern(
    r'\bbase64\s+(-d|-D|--decode)\b',
    BundleRisk.alta,
    'código escondido',
    'Decodifica algo antes de usarlo: lo que corre no es lo que se lee.',
  ),
  _Pattern(
    // Sin anclar al `>`: se escribe `>&`, `0>&1`, `exec 3<>`… y ninguna
    // línea legítima nombra /dev/tcp.
    r'/dev/(tcp|udp)/',
    BundleRisk.alta,
    'conexión inversa',
    'Abre una conexión de red cruda hacia afuera.',
  ),
  _Pattern(
    r'\bnc\s+[^\n]{0,80}-e\b',
    BundleRisk.alta,
    'conexión inversa',
    'Entrega una shell por la red.',
  ),
  _Pattern(
    r'(\.ssh/|id_rsa|id_ed25519|\.aws/credentials|\.netrc|\.npmrc|'
        r'\.docker/config\.json|security\s+find-generic-password|'
        r'login\.keychain)',
    BundleRisk.alta,
    'lee credenciales',
    'Toca archivos donde vive tu identidad, no la del proyecto.',
  ),
  _Pattern(
    r'(launchctl|crontab|systemctl\s+enable|defaults\s+write|osascript)',
    BundleRisk.alta,
    'se instala en el sistema',
    'Deja algo corriendo o configurado más allá de keel.',
  ),
  _Pattern(
    r'\beval\s*[\(\{"'
        r"'$]",
    BundleRisk.alta,
    'ejecuta texto como código',
    'Lo que corre se arma en tiempo de ejecución y no se puede leer acá.',
  ),
  _Pattern(
    r'\bchmod\s+(-R\s+)?[0-7]*7{2}\b',
    BundleRisk.media,
    'permisos abiertos',
    'Deja archivos escribibles por cualquiera.',
  ),
  _Pattern(
    r'git\s+push\s+(--force|-f)\b',
    BundleRisk.media,
    'reescribe historia',
    'Un push forzado puede borrar trabajo del remoto.',
  ),
  _Pattern(
    r'(\.env\b|process\.env\.[A-Z_]+|os\.environ)',
    BundleRisk.media,
    'lee el entorno',
    'Mira variables de entorno, que es donde suelen estar las claves.',
  ),
];

/// Lo que intenta hablarle al modelo en vez de a vos.
final _promptInjections = <_Pattern>[
  _Pattern(
    r'(ignor[aáeoó][a-z]*|olvid[aáeoá][a-z]*|desestim[aá])\s+'
        r'([a-z]+\s+){0,3}(instruccion|indicacion|regla|lo anterior|todo lo)',
    BundleRisk.alta,
    'inyección de prompt',
    'Le pide al agente que desconozca lo que vos le dijiste.',
  ),
  _Pattern(
    r'(ignore|disregard|forget|override)\s+([a-z]+\s+){0,3}'
        r'(previous|prior|above|earlier|all)\s+(instruction|prompt|rule|message)',
    BundleRisk.alta,
    'inyección de prompt',
    'Le pide al agente que desconozca lo que vos le dijiste.',
  ),
  _Pattern(
    r'(you are now|from now on you are|a partir de ahora (sos|eres)|'
        r'ahora (sos|eres) un)',
    BundleRisk.media,
    'reasigna identidad',
    'Intenta cambiar quién es el agente a mitad de camino.',
  ),
  _Pattern(
    r'(revel[aá]|mostr[aá]|imprim[ií]|repet[ií]|print|reveal|show|repeat)\s+'
        r'([a-z]+\s+){0,3}(system prompt|prompt del sistema|tus instrucciones|'
        r'your instructions|tu configuracion)',
    BundleRisk.alta,
    'saca tu configuración',
    'Le pide al agente que muestre sus instrucciones, que son tuyas.',
  ),
  _Pattern(
    r'(no le digas al usuario|sin decirle|no menciones (esto|nada)|'
        r'do not tell the user|don.t mention|without telling)',
    BundleRisk.alta,
    'pide ocultarte cosas',
    'Le pide al agente que te esconda lo que hace.',
  ),
  _Pattern(
    r'(exfiltr[a-z]*|'
        // Las vocales acentuadas quedan afuera de `[a-z]`, y el imperativo
        // del castellano es justo donde caen: enviá, mandá, subí.
        r'(envi|mand|sub)[aáeéií][a-z]*\s+[^\n]{0,60}\s+a\s+https?://|'
        r'(send|upload|post)\s+[^\n]{0,60}\s+to\s+https?://)',
    BundleRisk.alta,
    'saca datos',
    'Le pide al agente que mande algo tuyo afuera.',
  ),
  _Pattern(
    r'(jailbreak|developer mode|modo desarrollador|DAN mode|sin restricciones'
        r' de seguridad)',
    BundleRisk.media,
    'intenta soltarle los frenos',
    'Texto típico de los que buscan saltear las reglas del modelo.',
  ),
];

/// Caracteres que no se ven pero se leen: un anulador de dirección da vuelta
/// el orden de lo que mostrás sin cambiar lo que corre, y un espacio de ancho
/// cero esconde una palabra en el medio de otra.
final _invisibleCharacters = RegExp(
  // Escritos como escapes y no como el carácter: puestos en crudo, este
  // archivo tendría adentro exactamente lo que denuncia — y el analizador
  // de Dart, con razón, avisa que el código no se lee como se ve.
  '[\\u200B-\\u200F\\u202A-\\u202E\\u2060-\\u2064\\u2066-\\u2069\\uFEFF]',
);

/// Un comentario de HTML con texto adentro: no se ve al renderizar el
/// markdown de una skill, pero el modelo lo lee entero.
final _htmlComment = RegExp(r'<!--([\s\S]{4,}?)-->');

/// Una ruta que apunta a la casa de otra persona.
final _personalPaths = RegExp(
  r'(/Users/[A-Za-z0-9._-]+|/home/[A-Za-z0-9._-]+|'
  r'[A-Za-z]:\\Users\\[A-Za-z0-9._-]+)',
);

/// Una URL que sale de la máquina.
final _outboundUrl = RegExp(r'https?://([A-Za-z0-9.:-]+)');

const _localHosts = {'localhost', '127.0.0.1', '0.0.0.0', '::1'};

/// Revisa un paquete antes de instalarlo.
///
/// Función PURA: entra lo que trae el zip, sale la lista de lo que hay que
/// mirar. No pide red, no toca disco y no decide nada — decidir es del que
/// mira la pantalla. Esto solo se ocupa de que no tenga que leer 40 archivos
/// JSON para enterarse.
///
/// **No promete que un paquete limpio sea seguro.** Un buscador de patrones
/// encuentra lo conocido; lo que la revisión sí garantiza es que nada se
/// instala sin que se haya listado antes qué corre, qué lee y a dónde
/// escribe.
BundleAudit auditBundle(BundleContents contents) {
  final findings = <String, BundleFinding>{};
  var scanned = 0;

  void add(BundleFinding finding) =>
      findings.putIfAbsent(finding.id, () => finding);

  /// Pasa [text] por [patterns] y por los chequeos que valen para cualquier
  /// texto: rutas personales, caracteres invisibles y texto escondido.
  void scan(
    String? text,
    String where, {
    required List<_Pattern> patterns,
    bool checkUrls = false,
  }) {
    if (text == null || text.isEmpty) return;
    scanned++;

    for (final pattern in patterns) {
      final match = pattern.expression.firstMatch(text);
      if (match == null) continue;
      add(
        BundleFinding(
          risk: pattern.risk,
          kind: pattern.kind,
          where: where,
          what: pattern.what,
          excerpt: _excerptAround(text, match.start, match.end),
        ),
      );
    }

    for (final match in _personalPaths.allMatches(text).take(3)) {
      add(
        BundleFinding(
          risk: BundleRisk.media,
          kind: 'ruta personal',
          where: where,
          what:
              'Apunta a la carpeta personal de quien lo exportó. De tu lado '
              'esa ruta no existe, y si existe no es la misma.',
          excerpt: _excerptAround(text, match.start, match.end),
        ),
      );
    }

    if (_invisibleCharacters.hasMatch(text)) {
      add(
        BundleFinding(
          risk: BundleRisk.alta,
          kind: 'caracteres invisibles',
          where: where,
          what:
              'Trae caracteres que no se ven pero que el modelo lee. Es la '
              'forma barata de esconder una instrucción a plena vista.',
          excerpt: _visibleEscape(text),
        ),
      );
    }

    for (final match in _htmlComment.allMatches(text).take(2)) {
      add(
        BundleFinding(
          risk: BundleRisk.media,
          kind: 'texto escondido',
          where: where,
          what:
              'Un comentario de HTML no se ve al leer el markdown, pero al '
              'agente le llega igual.',
          excerpt: _clip(match.group(1) ?? ''),
        ),
      );
    }

    if (!checkUrls) return;
    for (final match in _outboundUrl.allMatches(text).take(5)) {
      final host = (match.group(1) ?? '').split(':').first;
      if (_localHosts.contains(host)) continue;
      add(
        BundleFinding(
          risk: BundleRisk.media,
          kind: 'sale a internet',
          where: where,
          what: 'Habla con $host. Mirá que sea un lugar que conocés.',
          excerpt: _excerptAround(text, match.start, match.end),
        ),
      );
    }
  }

  // ── lo que se ejecuta ────────────────────────────────────────────────
  for (final tool in contents.of('tools')) {
    final where = 'tool «${tool['name']}»';
    add(
      BundleFinding(
        risk: BundleRisk.media,
        kind: 'corre código',
        where: where,
        what:
            'Una tool es un script que el agente puede ejecutar en tu '
            'máquina cuando quiera. Leelo antes de instalarlo.',
        excerpt: _clip(tool['code'] as String? ?? ''),
      ),
    );
    scan(
      tool['code'] as String?,
      where,
      patterns: _dangerousCommands,
      checkUrls: true,
    );
    scan(tool['description'] as String?, where, patterns: _promptInjections);
  }

  for (final hook in contents.of('hooks')) {
    final where = 'hook «${hook['name']}»';
    final body = hook['body'];
    final command = body is Map ? body['command'] as String? ?? '' : '';
    add(
      BundleFinding(
        // Más grave que una tool a propósito: una tool la llama el agente
        // cuando decide; un hook lo dispara el CLI solo, en cada turno que
        // encaje con su evento, sin que nadie lo pida.
        risk: BundleRisk.alta,
        kind: 'corre solo',
        where: where,
        what:
            'Un hook lo ejecuta el CLI sin que el agente ni vos lo pidan, '
            'en el evento «${hook['event']}».',
        excerpt: _clip(
          command.isEmpty ? '${body is Map ? body : ''}' : command,
        ),
      ),
    );
    scan(command, where, patterns: _dangerousCommands, checkUrls: true);
  }

  for (final server in contents.of('mcp_servers')) {
    final where = 'servidor MCP «${server['name']}»';
    final command = [
      server['command'] as String? ?? '',
      for (final arg in server['args'] as List? ?? const []) '$arg',
    ].where((part) => part.isNotEmpty).join(' ');

    if (command.isNotEmpty) {
      add(
        BundleFinding(
          risk: BundleRisk.media,
          kind: 'levanta un programa',
          where: where,
          what:
              'Para usarlo, keel corre este comando en tu máquina. Si baja '
              'un paquete, ese paquete es código de otro.',
          excerpt: _clip(command),
        ),
      );
      scan(command, where, patterns: _dangerousCommands);
    }
    scan(server['url'] as String?, where, patterns: const [], checkUrls: true);
  }

  // ── lo que lee el modelo ─────────────────────────────────────────────
  for (final profile in contents.of('profiles')) {
    final where = 'agente «${profile['name']}»';
    scan(
      profile['systemPrompt'] as String?,
      where,
      patterns: [..._promptInjections, ..._dangerousCommands],
      checkUrls: true,
    );
    if (profile['canManageSystem'] == true) {
      add(
        BundleFinding(
          risk: BundleRisk.alta,
          kind: 'puede modificar keel',
          where: where,
          what:
              'Viene marcado como constructor: sus turnos pueden crear y '
              'cambiar skills, reglas, tools, agentes y proyectos tuyos.',
        ),
      );
    }
  }

  for (final skill in contents.of('skills')) {
    scan(
      skill['content'] as String?,
      'skill «${skill['name']}»',
      patterns: [..._promptInjections, ..._dangerousCommands],
      checkUrls: true,
    );
  }

  for (final rule in contents.of('rules')) {
    scan(
      rule['content'] as String?,
      'regla «${rule['name']}»',
      patterns: [..._promptInjections, ..._dangerousCommands],
      checkUrls: true,
    );
  }

  for (final workflow in contents.of('workflows')) {
    for (final step in workflow['steps'] as List? ?? const []) {
      if (step is! Map) continue;
      scan(
        step['instruction'] as String?,
        'workflow «${workflow['name']}» · paso «${step['title']}»',
        patterns: [..._promptInjections, ..._dangerousCommands],
        checkUrls: true,
      );
    }
  }

  for (final base in contents.knowledgeDocs.entries) {
    for (final doc in base.value.entries) {
      final text = _asText(doc.value);
      if (text == null) {
        add(
          BundleFinding(
            risk: BundleRisk.media,
            kind: 'documento binario',
            where: 'saber «${base.key}» · ${doc.key}',
            what:
                'No es texto. Un paquete de conocimiento que trae binarios '
                'trae algo que nadie va a leer antes de usarlo.',
          ),
        );
        continue;
      }
      scan(
        text,
        'saber «${base.key}» · ${doc.key}',
        patterns: [..._promptInjections, ..._dangerousCommands],
      );
    }
  }

  final ordered = findings.values.toList()
    ..sort((a, b) => a.risk.index.compareTo(b.risk.index));
  return BundleAudit(findings: ordered, scannedTexts: scanned);
}

/// El texto de un documento, o null si no es texto.
String? _asText(Uint8List bytes) {
  if (bytes.contains(0)) return null;
  try {
    return utf8.decode(bytes);
  } catch (_) {
    return null;
  }
}

String _excerptAround(String text, int start, int end) {
  const margin = 40;
  final from = (start - margin).clamp(0, text.length);
  final to = (end + margin).clamp(0, text.length);
  final prefix = from > 0 ? '…' : '';
  final suffix = to < text.length ? '…' : '';
  return '$prefix${_flatten(text.substring(from, to))}$suffix';
}

String _clip(String text, {int max = 220}) {
  final flat = _flatten(text);
  return flat.length <= max ? flat : '${flat.substring(0, max)}…';
}

String _flatten(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// El texto con los invisibles hechos visibles. Mostrar el fragmento tal
/// cual sería mostrar exactamente lo que no se ve.
String _visibleEscape(String text) {
  final marked = text.replaceAllMapped(
    _invisibleCharacters,
    (match) =>
        '\\u${match.group(0)!.codeUnitAt(0).toRadixString(16).padLeft(4, '0')}',
  );
  return _clip(marked);
}
