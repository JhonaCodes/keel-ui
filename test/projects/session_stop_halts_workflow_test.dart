import 'package:flutter_test/flutter_test.dart';

import 'package:keel_core/core/host/keel_host.dart';
import 'package:keel_core/core/store/keel_store.dart';
import 'package:keel_core/modules/agents/model/agent_model_option.dart';
import 'package:keel_core/modules/agents/model/agent_provider.dart';
import 'package:keel_core/modules/agents/model/chat_message.dart';
import 'package:keel_core/modules/projects/model/project.dart';
import 'package:keel_core/modules/projects/model/resolution_preflight.dart';
import 'package:keel_core/modules/projects/model/session.dart';
import 'package:keel_core/modules/projects/model/work_node.dart';
import 'package:keel_core/modules/projects/service/resolution_engine.dart';
import 'package:keel_core/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/core/host/keel_host_impl.dart';
import 'package:keel_ui/src/core/services/flutter_local_db_store.dart';
import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';

final _epoch = DateTime(2026, 10, 29);

/// Detener una sesión es tomar el control: el workflow no vuelve a arrancar
/// solo. Caso real: se canceló una sesión y siguió trabajando en segundo
/// plano, porque el siguiente mensaje a un agente terminaba retomando el nodo
/// que se había frenado.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();
  KeelStore.instance = const FlutterLocalDbStore();
  KeelHost.instance = const KeelHostImpl();

  test(
    'after Stop, a message to an agent does not restart the workflow',
    () async {
      final profiles = AgentProfilesService.instance.notifier;
      await profiles.ready;
      // Proveedor por API sin clave: el turno del agente falla sin salir a la
      // red y sin lanzar ningún CLI.
      expect(
        profiles.createProfile(
          name: 'impl-detenido',
          role: 'implementador',
          systemPrompt: 'Implementa.',
          skills: const [],
          rules: const [],
          model: kDefaultOpenRouterModelAlias,
          effort: 'medium',
          provider: AgentProvider.openRouter,
        ),
        isNull,
      );
      final member = profiles.data.profiles.firstWhere(
        (profile) => profile.name == 'impl-detenido',
      );

      final started = ResolutionEngine.start(
        id: 'case',
        kind: WorkflowKind.bug,
        ownerRole: 'implementador',
      ).copyWith(preflight: const ResolutionPreflight(performed: true));
      final resolution = started.copyWith(
        nodes: [
          for (final node in started.nodes)
            node.id == started.nodes.first.id
                ? node.copyWith(status: WorkNodeStatus.running)
                : node,
        ],
      );

      final projects = ProjectsService.instance.notifier;
      await projects.ready;
      projects.updateState(
        ProjectsState(
          projects: [
            Project(
              id: 'project',
              name: 'portal',
              purpose: '',
              workingDirectory: '/tmp',
              createdAt: _epoch,
              profileIds: [member.id],
              activeSessionId: 'session',
              sessions: [
                Session(
                  id: 'session',
                  title: 'Sesión con un nodo corriendo',
                  createdAt: _epoch,
                  isRunning: true,
                  resolutionCase: resolution,
                  messages: [
                    ChatMessage(
                      role: ChatRole.assistant,
                      text: 'Escribo el núcleo.',
                      timestamp: _epoch,
                    ),
                  ],
                ),
              ],
            ),
          ],
          selectedProjectId: 'project',
        ),
      );
      Session session() => projects.data.projects.single.sessions.single;

      projects.stopSession('project', 'session');
      final before = session().messages.length;

      await projects.sendToChannel('project', '@impl-detenido ¿qué quedó?');

      // Lo único nuevo en el hilo es el mensaje y lo que contestó (o falló) el
      // agente. Un arranque del workflow deja su propia huella (el resumen del
      // preflight, o el aviso de que no hay workflow): no tiene que haber
      // ninguna.
      final added = session().messages.skip(before).toList();
      expect(added.first.role, ChatRole.user);
      expect(
        added.where((message) => message.text.contains('workflow')),
        isEmpty,
        reason: added
            .map((message) => '${message.role}: ${message.text}')
            .join('\n'),
      );
      expect(session().isRunning, isFalse);

      // Retomar es explícito: el aviso de Stop trae el paso que se frenó, y
      // reintentarlo desde ahí sí vuelve a arrancar el workflow.
      final notice = session().messages.firstWhere(
        (message) => message.text == 'Detenido por el usuario.',
      );
      expect(notice.workNodeId, started.nodes.first.id);
      final beforeRetry = session().messages.length;
      await projects.retryWorkNode('project', 'session', notice.workNodeId!);
      expect(
        session().messages
            .skip(beforeRetry)
            .where((message) => message.text.contains('workflow')),
        isNotEmpty,
      );
    },
  );
}
