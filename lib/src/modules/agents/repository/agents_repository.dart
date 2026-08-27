import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/agents/model/agent.dart';

class AgentsRepository {
  static const _prefix = 'agent_';

  Future<List<Agent>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    return records.map(Agent.fromJson).toList();
  }

  Future<void> save(List<Agent> agents) async {
    await LocalDatabase.replaceAllWithPrefix(
      _prefix,
      agents.map((agent) => agent.toJson()).toList(),
    );
  }

  /// Guarda UN agente.
  ///
  /// Casi todo lo que pasa en esta app cambia un solo agente: llega un
  /// pedazo de texto, se marca el modelo, se contesta un permiso. Hacer eso
  /// con [save] reescribía la lista entera —cada agente con todos sus
  /// mensajes, y cada mensaje con el contenido completo de los archivos que
  /// tocó— con una llamada FFI bloqueante por registro. Con un hilo largo
  /// eso son megabytes por tecla, sobre el hilo de la interfaz.
  Future<void> saveOne(Agent agent) =>
      LocalDatabase.put('$_prefix${agent.id}', agent.toJson());
}
