part of '../catalog_bridge_core.dart';

/// Nombre del ejecutable que produce `scripts/build_catalog_mcp_worker.sh`.
const kCatalogWorkerExecutableName = 'catalog_mcp_worker';

/// El comando concreto que hay que pegar en la config MCP de un cliente de
/// escritorio para que lance el worker de esta máquina.
///
/// Existe como modelo y no como un string armado en la vista porque el
/// mismo valor tiene dos consumidores que no pueden divergir: el bloque que
/// se copia desde Ajustes y el documento de instalación. Lo que se muestra
/// es lo que de verdad existe en el disco — [resolve] no inventa una ruta
/// plausible, mira cuál está.
class CatalogWorkerCommand {
  const CatalogWorkerCommand({
    required this.executable,
    required this.arguments,
  });

  /// Ruta absoluta al binario, o vacío cuando todavía no se compiló en esta
  /// máquina. Vacío NO es un error: es el estado del día uno, y la UI tiene
  /// que poder decir "corré el script" en vez de mostrar una ruta falsa.
  final String executable;

  final List<String> arguments;

  bool get isResolved => executable.isNotEmpty;

  /// La entrada de `mcpServers`, con la misma forma que usa el propio
  /// catálogo de MCPs de Keel para un transporte stdio (`command` + `args`).
  Map<String, dynamic> toMcpServerEntry() => {
    'command': executable,
    'args': arguments,
  };

  /// El bloque entero que el cliente espera, listo para pegar.
  Map<String, dynamic> toMcpServersJson() => {
    'mcpServers': {kCatalogMcpServerKey: toMcpServerEntry()},
  };

  String toPrettyJson() =>
      const JsonEncoder.withIndent('  ').convert(toMcpServersJson());

  /// El worker que exista en ESTA máquina, mirando los dos lugares donde
  /// puede estar, en el mismo orden que resuelve el worker de LiteRT:
  /// primero el que viaja dentro del `.app`, después el que deja el script
  /// de build sobre el repo.
  ///
  /// [workingDirectory] solo lo pasa un test; en producción es desde donde
  /// arrancó la app, que corriendo desde el repo es la raíz del repo.
  static CatalogWorkerCommand resolve({
    required String endpointPath,
    Directory? workingDirectory,
  }) {
    final bundled = p.join(
      p.dirname(p.dirname(Platform.resolvedExecutable)),
      'Resources',
      'catalog_mcp',
      'bin',
      kCatalogWorkerExecutableName,
    );
    final built = p.join(
      (workingDirectory ?? Directory.current).path,
      'build',
      kCatalogWorkerExecutableName,
      'bundle',
      'bin',
      kCatalogWorkerExecutableName,
    );
    final executable = File(bundled).existsSync()
        ? bundled
        : File(built).existsSync()
        ? built
        : '';
    return CatalogWorkerCommand(
      executable: executable,
      arguments: executable.isEmpty
          ? const []
          : ['--endpoint', endpointPath],
    );
  }

  CatalogWorkerCommand copyWith({
    String? executable,
    List<String>? arguments,
  }) => CatalogWorkerCommand(
    executable: executable ?? this.executable,
    arguments: arguments ?? this.arguments,
  );

  factory CatalogWorkerCommand.fromJson(Map<String, dynamic> json) =>
      CatalogWorkerCommand(
        executable: json['command'] as String? ?? '',
        arguments: [
          for (final argument in json['args'] as List? ?? const [])
            '$argument',
        ],
      );

  Map<String, dynamic> toJson() => toMcpServerEntry();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogWorkerCommand &&
          runtimeType == other.runtimeType &&
          executable == other.executable &&
          _sameArguments(arguments, other.arguments);

  @override
  int get hashCode => Object.hash(executable, Object.hashAll(arguments));

  static bool _sameArguments(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  @override
  String toString() => 'CatalogWorkerCommand($executable $arguments)';
}
