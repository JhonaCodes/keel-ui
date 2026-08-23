part of '../machine.dart';

/// Un CLI que Keel busca en la máquina.
class CliService {
  /// El binario, tal como se invoca.
  final String binary;

  /// Cómo se llama para una persona.
  final String label;

  /// Si Keel sabe correrlo. Los que no, se listan igual: saber que están
  /// instalados es la mitad de la respuesta a "¿por qué no puedo usarlo?".
  final bool supported;

  /// La ruta donde apareció, o vacío si no está en el PATH.
  final String path;

  /// Lo que contestó `--version`, en una línea, o vacío.
  final String version;

  const CliService({
    required this.binary,
    required this.label,
    required this.supported,
    this.path = '',
    this.version = '',
  });

  bool get installed => path.isNotEmpty;

  CliService seen({required String path, required String version}) =>
      CliService(
        binary: binary,
        label: label,
        supported: supported,
        path: path,
        version: version,
      );
}

/// Los CLIs que se buscan.
///
/// Los dos primeros tienen adaptador en `core/services` y son los que un
/// agente puede usar. El resto está acá porque el usuario los tiene, y
/// listarlos es más honesto que hacer de cuenta que no existen: la lista de
/// "detectado, sin adaptador" es, además, la lista de lo que falta.
const _known = <CliService>[
  CliService(binary: 'claude', label: 'Claude Code', supported: true),
  CliService(binary: 'codex', label: 'Codex', supported: true),
  CliService(binary: 'opencode', label: 'opencode', supported: false),
  CliService(binary: 'gemini', label: 'Gemini CLI', supported: false),
  CliService(binary: 'cursor-agent', label: 'Cursor Agent', supported: false),
  CliService(binary: 'amp', label: 'Amp', supported: false),
  CliService(binary: 'aider', label: 'Aider', supported: false),
  CliService(binary: 'ollama', label: 'Ollama', supported: false),
];

/// Cuánto se le da a un `--version` antes de darlo por colgado. Alguno abre
/// una conexión al arrancar y tarda; ninguno tarda cinco segundos.
const _versionTimeout = Duration(seconds: 5);

/// Busca los CLIs conocidos, en paralelo.
///
/// Los que Keel sí sabe correr van primero, después los detectados, y al
/// final los que no están: es el orden en que sirve leerlos.
Future<List<CliService>> detectServices() async {
  final found = await Future.wait(_known.map(_probeService));
  found.sort((a, b) {
    int rank(CliService service) => switch (service) {
      CliService(installed: true, supported: true) => 0,
      CliService(installed: true) => 1,
      _ => 2,
    };
    final byRank = rank(a).compareTo(rank(b));
    return byRank != 0 ? byRank : a.label.compareTo(b.label);
  });
  return found;
}

Future<CliService> _probeService(CliService service) async {
  // Se busca en el PATH del usuario, no con `which`: `which` heredaba el PATH
  // mínimo de `launchd` y en la app instalada no encontraba ni uno solo de
  // estos binarios, así que la máquina se veía vacía.
  final path = await UserShellPath.locate(service.binary);
  if (path == null) return service;

  final version = await _readVersion(path);
  return service.seen(path: path, version: version);
}

/// [executable] es la ruta ABSOLUTA: `Process.run` resuelve los nombres
/// sueltos contra el PATH de la app, que es justamente el que no sirve.
Future<String> _readVersion(String executable) async {
  try {
    final result = await Process.run(executable, const [
      '--version',
    ]).timeout(_versionTimeout);
    // Alguno escribe la versión en stderr. Da igual de dónde salga: lo que
    // se muestra es la primera línea con algo escrito.
    final output = '${result.stdout}\n${result.stderr}';
    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
  } on Object {
    // Un binario que no entiende --version, o que se cuelga, sigue estando
    // instalado. La ruta ya lo dice; la versión es un extra.
  }
  return '';
}

/// El proveedor de Keel que corresponde a un binario, o null si es uno de
/// los que todavía no tienen adaptador.
AgentProvider? providerFor(String binary) => AgentProvider.tryFromAlias(binary);
