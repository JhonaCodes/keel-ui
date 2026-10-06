import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_core/core/store/keel_store.dart';
import 'package:keel_ui/src/core/services/flutter_local_db_store.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_core/modules/agents/model/agent_model_option.dart';
import 'package:keel_core/modules/agents/model/agent_provider.dart';
import 'package:keel_core/modules/agents/model/chat_message.dart';
import 'package:keel_core/modules/projects/model/project.dart';
import 'package:keel_core/modules/projects/model/session.dart';
import 'package:keel_core/modules/projects/model/session_queued_message.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';

final _epoch = DateTime(2026, 9, 28);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();
  KeelStore.instance = const FlutterLocalDbStore();

  test(
    'con un turno en vuelo, un turno suelto no se abre en paralelo: espera en la cola',
    () async {
      // Caso real: conceder un permiso a mitad de un nodo abría un segundo
      // turno sobre la misma sesión. El primero que terminaba apagaba
      // `isRunning` y soltaba el proceso del otro, que seguía escribiendo
      // sin barra de progreso y sin que Detener pudiera alcanzarlo.
      final profiles = AgentProfilesService.instance.notifier;
      await profiles.ready;
      // Proveedor por API sin clave: si el turno llegara a abrirse, falla
      // sin salir a la red y sin lanzar el CLI de nadie.
      expect(
        profiles.createProfile(
          name: 'impl-en-cola',
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
        (profile) => profile.name == 'impl-en-cola',
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

      await projects.recordManualEdit(
        'project',
        profileId: member.id,
        filePath: '/tmp/lib/main.dart',
      );

      final session = projects.data.projects.single.sessions.single;
      expect(session.isRunning, isTrue);
      expect(session.queuedMessages, hasLength(1));
      expect(
        session.queuedMessages.single.delivery,
        SessionQueuedDelivery.afterCurrentTurn,
      );
      expect(session.queuedMessages.single.text, startsWith('@impl-en-cola '));
    },
  );
}
