part of '../catalog_bridge.dart';

/// Lo que Ajustes necesita saber para que alguien instale el MCP del
/// catálogo en un cliente de escritorio.
///
/// Estado puramente transitorio: se arma en cada arranque a partir del
/// puerto efímero del servidor y de qué hay compilado en el disco, así que
/// no lleva `toJson`/`fromJson` — persistirlo sería guardar un puerto que
/// mañana no existe.
class CatalogBridgeState {
  const CatalogBridgeState({
    this.isServing = false,
    this.command = const CatalogWorkerCommand(
      executable: '',
      arguments: [],
    ),
    this.endpointPath = '',
  });

  /// El catálogo MCP está arriba y su enganche quedó publicado.
  final bool isServing;

  /// El comando a copiar. Puede venir sin resolver aunque [isServing] sea
  /// cierto: el servidor está, pero el binario del worker todavía no se
  /// compiló en esta máquina.
  final CatalogWorkerCommand command;

  final String endpointPath;

  /// Las dos mitades listas: hay con qué conectarse y hay qué lanzar.
  bool get isInstallable => isServing && command.isResolved;

  CatalogBridgeState copyWith({
    bool? isServing,
    CatalogWorkerCommand? command,
    String? endpointPath,
  }) => CatalogBridgeState(
    isServing: isServing ?? this.isServing,
    command: command ?? this.command,
    endpointPath: endpointPath ?? this.endpointPath,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogBridgeState &&
          runtimeType == other.runtimeType &&
          isServing == other.isServing &&
          command == other.command &&
          endpointPath == other.endpointPath;

  @override
  int get hashCode => Object.hash(isServing, command, endpointPath);

  @override
  String toString() =>
      'CatalogBridgeState(isServing: $isServing, command: $command)';
}

/// Publica cómo alcanzar el catálogo de ESTA instancia de Keel, y arma el
/// comando que hay que pegar en un cliente MCP de escritorio.
///
/// La frontera con `assistant_mcp`, que conviene no confundir: aquel sirve
/// al asistente interno de la app (HTTP en loopback, una ruta por agente, y
/// sí expone tools que abren sesiones). Este puente sirve a un cliente
/// AJENO y solo expone el catálogo. Un cliente de escritorio no toca
/// `assistant_mcp` nunca.
class CatalogBridgeViewModel extends ViewModel<CatalogBridgeState> {
  CatalogBridgeViewModel() : super(const CatalogBridgeState());

  @override
  void init() {
    // Nada hasta que `main()` llame a [start]: el puerto todavía no existe,
    // y montar la pantalla de ajustes dispara un init() más. Guardado igual
    // que el resto de los VM del arranque, para que ese segundo init no
    // borre el enganche ya publicado.
    if (!data.isServing) updateSilently(const CatalogBridgeState());
  }

  /// Levanta el catálogo MCP si no estaba, y deja su puerto y su token en
  /// un archivo que el worker pueda leer.
  ///
  /// Se llama desde `main()`, después de `KeelCoreRuntime.start`. Es
  /// idempotente porque `ensureStarted` lo es.
  Future<void> start() async {
    await CatalogMcpServer.ensureStarted();
    final port = CatalogMcpServer.port;
    final token = CatalogMcpServer.token;
    if (port == null || token == null) {
      // No es recuperable desde acá y no justifica tumbar el arranque: lo
      // único que se pierde es poder instalar el MCP en un cliente externo,
      // y Ajustes ya lo dice con `isServing` en falso.
      Log.w(
        'Catalog MCP bridge: el servidor del catálogo no expuso puerto ni '
        'token; ChatGPT desktop no va a poder conectarse.',
      );
      return;
    }

    final directory = await getApplicationSupportDirectory();
    final endpointPath = CatalogEndpointFile.pathIn(directory.path);
    await CatalogEndpointFile.publish(
      endpointPath,
      CatalogEndpoint(port: port, token: token, pid: pid),
    );

    updateState(
      CatalogBridgeState(
        isServing: true,
        endpointPath: endpointPath,
        command: CatalogWorkerCommand.resolve(endpointPath: endpointPath),
      ),
    );
    Log.i('Catalog MCP bridge publicado en $endpointPath');
  }

  /// Vuelve a mirar el disco por si el worker se compiló con la app ya
  /// abierta — que es el orden normal la primera vez.
  void refreshCommand() {
    if (!data.isServing) return;
    updateState(
      data.copyWith(
        command: CatalogWorkerCommand.resolve(
          endpointPath: data.endpointPath,
        ),
      ),
    );
  }
}

mixin CatalogBridgeService {
  static final ReactiveNotifier<CatalogBridgeViewModel> instance =
      ReactiveNotifier<CatalogBridgeViewModel>(() => CatalogBridgeViewModel());
}
