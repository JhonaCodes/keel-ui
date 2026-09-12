import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_decision.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';

final _epoch = DateTime(2026, 9, 5);

void main() {
  LocalDatabase.markUnavailable();

  Project project(String sessionId) => Project(
    id: 'project',
    name: 'keel-ui',
    purpose: '',
    workingDirectory: '/tmp',
    createdAt: _epoch,
    activeSessionId: sessionId,
    sessions: [
      Session(
        id: sessionId,
        title: 'Sesión',
        createdAt: _epoch,
        isRunning: true,
      ),
    ],
  );

  ProjectsViewModel vm() => ProjectsService.instance.notifier;

  Session session() => vm().data.projects.single.sessions.single;

  // Un id de sesión por test: un Stop deja la sesión marcada como detenida
  // hasta su próxima corrida, y el segundo test no debe heredar esa marca.
  Future<void> open(String sessionId) async {
    // La carga inicial del ViewModel (vacía, sin base) termina DESPUÉS de
    // que el test pone su estado y lo pisaría: se espera antes.
    await vm().ready;
    final fixture = project(sessionId);
    vm().updateState(
      ProjectsState(projects: [fixture], selectedProjectId: fixture.id),
    );
  }

  test('las decisiones hacen cola; contestar una no toca a la otra, y '
      'conceder por sesión queda anotado', () async {
    const sessionId = 's-queue';
    await open(sessionId);
    final first = vm().decideToolUse(
      projectId: 'project',
      sessionId: sessionId,
      profileId: 'dev',
      toolName: 'Bash',
      toolInput: 'git push',
    );
    final second = vm().decideToolUse(
      projectId: 'project',
      sessionId: sessionId,
      profileId: 'dev',
      toolName: 'Write',
      toolInput: 'lib/a.dart',
    );
    await Future<void>.delayed(Duration.zero);

    final pending = session().pendingDecisions;
    expect(pending, hasLength(2));
    expect(pending.first.kind, SessionDecisionKind.permission);
    expect(pending.first.toolName, 'Bash');
    expect(pending.last.toolName, 'Write');

    await vm().answerSessionDecision(
      'project',
      sessionId,
      pending.first.id,
      approve: true,
      scope: 'session',
    );

    final firstDecision = await first;
    expect(firstDecision.allow, isTrue);
    expect(session().grantedTools, contains('Bash'));
    expect(session().pendingDecisions, hasLength(1));
    expect(session().pendingDecisions.single.toolName, 'Write');

    // Con el permiso de sesión anotado, el mismo tool ya no pregunta.
    final again = await vm().decideToolUse(
      projectId: 'project',
      sessionId: sessionId,
      profileId: 'dev',
      toolName: 'Bash',
      toolInput: 'git status',
    );
    expect(again.allow, isTrue);
    expect(session().pendingDecisions, hasLength(1));

    // Parar la sesión contesta lo que quedó: nadie se queda esperando.
    vm().stopSession('project', sessionId);
    final secondDecision = await second;
    expect(secondDecision.allow, isFalse);
    expect(session().pendingDecisions, isEmpty);
    expect(
      session().decisions.last.status,
      SessionDecisionStatus.cancelled,
    );
  });

  test(
    'una sesión antigua recupera el pedido del hilo y respeta Stop',
    () async {
      const sessionId = 's-legacy-context';
      await open(sessionId);
      final current = vm().data.projects.single;
      vm().updateState(
        vm().data.copyWith(
          projects: [
            current.copyWith(
              sessions: [
                session().copyWith(
                  messages: [
                    ChatMessage(
                      role: .user,
                      text: 'Corregir el error 500 al crear una actividad.',
                      timestamp: _epoch,
                    ),
                    ChatMessage(
                      role: .user,
                      text: 'Corrección: no crear worktrees; usar main.',
                      timestamp: _epoch,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      final context = await vm().askUser(
        projectId: 'project',
        sessionId: sessionId,
        profileId: 'planner',
        question: 'Which task should I work on?',
      );
      expect(context, contains('error 500'));
      expect(context, contains('no crear worktrees; usar main'));
      expect(session().pendingDecisions, isEmpty);
      vm().stopSession('project', sessionId);
      final stopped = await vm().askUser(
        projectId: 'project',
        sessionId: sessionId,
        profileId: 'planner',
        question: '¿Qué tarea hago?',
      );
      expect(stopped, 'El turno fue detenido.');
      expect(session().pendingDecisions, isEmpty);
    },
  );

  test('una pregunta bloqueante devuelve el texto que contestaste', () async {
    const sessionId = 's-ask';
    await open(sessionId);
    final answer = vm().askUser(
      projectId: 'project',
      sessionId: sessionId,
      profileId: 'dev',
      question: '¿main o develop?',
      options: const ['main', 'develop'],
    );
    await Future<void>.delayed(Duration.zero);
    final decision = session().pendingDecisions.single;
    expect(decision.kind, SessionDecisionKind.question);
    expect(decision.options, ['main', 'develop']);

    await vm().answerSessionDecision(
      'project',
      sessionId,
      decision.id,
      answer: 'develop',
    );

    expect(await answer, 'develop');
    expect(session().waitingForUser, isFalse);
  });

  test(
    'recupera el bug existente antes de preguntar y conserva las decisiones reales',
    () async {
      const sessionId = 's-recover-context';
      await open(sessionId);
      final current = vm().data.projects.single;
      vm().updateState(
        vm().data.copyWith(
          projects: [
            current.copyWith(
              sessions: [
                session().copyWith(
                  request:
                      'Corregir el error 500 al crear la actividad Estudiar un tema. Trabajar en main.',
                  resolutionCase: const ResolutionCase(
                    id: 'case',
                    ownerRole: 'dev',
                    nodes: [
                      WorkNode(
                        id: 'plan',
                        kind: .custom,
                        ownerRole: 'planner',
                        ownerProfileId: 'planner',
                        instruction: 'Planificar la corrección del error 500.',
                        status: .pending,
                      ),
                      WorkNode(
                        id: 'implement',
                        kind: .implementation,
                        ownerRole: 'dev',
                        ownerProfileId: 'dev',
                        instruction: 'Implementar el arreglo.',
                        status: .running,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      addTearDown(() => vm().stopSession('project', sessionId));

      final recovered = vm().askUser(
        projectId: 'project',
        sessionId: sessionId,
        profileId: 'planner',
        question:
            'Se perdió el contexto de esta sesión. ¿Sobre qué tarea armo el plan?',
        options: ['Otra tarea del roadmap'],
      );
      await Future<void>.delayed(Duration.zero);
      expect(session().pendingDecisions, isEmpty);
      final context = await recovered;
      expect(context, contains('error 500'));
      expect(context, contains('Trabajar en main'));
      expect(context, contains('Planificar la corrección'));
      expect(
        context,
        contains('no es una respuesta ni una autorización del usuario'),
      );
      expect(session().waitingForUser, isFalse);

      final realQuestion = vm().askUser(
        projectId: 'project',
        sessionId: sessionId,
        profileId: 'planner',
        question:
            'El bug tiene dos comportamientos válidos. ¿Se permite repetir la actividad?',
        options: ['Permitir', 'Rechazar'],
      );
      await Future<void>.delayed(Duration.zero);
      final decision = session().pendingDecisions.single;
      expect(decision.workNodeId, 'plan');
      expect(decision.profileId, 'planner');
      expect(decision.options, ['Permitir', 'Rechazar']);
      await vm().answerSessionDecision(
        'project',
        sessionId,
        decision.id,
        answer: 'Rechazar',
      );
      expect(await realQuestion, 'Rechazar');
    },
  );
}
