import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_message_reference.dart';
import 'package:keel_ui/src/modules/projects/model/session_queued_message.dart';
import 'package:keel_ui/src/modules/projects/model/session_reply_request.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';

final _epoch = DateTime(2026, 9, 4, 14, 32);

const _auditorId = 'profile-auditor';

/// El mensaje que dejó abierta la decisión: es lo que el usuario referencia.
ChatMessage _question() => ChatMessage(
  id: 'msg-question',
  role: ChatRole.assistant,
  text: '¿Migramos la cola a Redis o la dejamos en memoria?',
  timestamp: _epoch,
  authorProfileId: _auditorId,
  workNodeId: 'auditar',
);

/// Sin miembros a propósito: alcanza para que `_sendToSession` escriba el
/// mensaje en el hilo y NO llegue a levantar un CLI. Lo que se afirma es lo
/// que quedó escrito, no que un modelo haya contestado.
Project _project({required bool running}) => Project(
  id: 'project-keel',
  name: 'keel-ui',
  purpose: '',
  workingDirectory: '/tmp',
  createdAt: _epoch,
  activeSessionId: 'session-uno',
  sessions: [
    Session(
      id: 'session-uno',
      title: 'Sesión uno',
      createdAt: _epoch,
      isRunning: running,
      messages: [_question()],
    ),
  ],
);

SessionMessageReference get _reference => const SessionMessageReference(
  projectId: 'project-keel',
  sessionId: 'session-uno',
  messageId: 'msg-question',
);

Future<ProjectsViewModel> _openedOn(Project project) async {
  final viewmodel = ProjectsViewModel();
  await viewmodel.ready;
  viewmodel.updateState(
    ProjectsState(projects: [project], selectedProjectId: project.id),
  );
  return viewmodel;
}

String _replyPrompt(String answer) => assistantReplyRequest(
  authorHandle: 'auditor',
  nodeId: 'auditar',
  askedAt: _epoch,
  quotedText: '¿Migramos la cola a Redis o la dejamos en memoria?',
  answer: answer,
);

void main() {
  LocalDatabase.markUnavailable();

  setUp(() {
    AgentProfilesService.instance.notifier.updateState(
      AgentProfilesState(
        profiles: [
          AgentProfile(
            id: _auditorId,
            name: 'auditor',
            role: 'auditor de código',
            systemPrompt: '',
            skills: const [],
            rules: const [],
            model: 'opus',
            effort: 'high',
            createdAt: _epoch,
          ),
        ],
      ),
    );
  });

  group('la referencia de un mensaje', () {
    test('se copia y se vuelve a leer sin ambigüedad', () {
      expect(SessionMessageReference.tryParse(_reference.token), _reference);
    });

    test('se reconoce aunque venga adentro de una oración o de un enlace', () {
      expect(
        SessionMessageReference.tryParse('mirá esto ${_reference.token} qué es'),
        _reference,
      );
      expect(
        SessionMessageReference.tryParse('[el mensaje](${_reference.token})'),
        _reference,
      );
      expect(SessionMessageReference.tryParse('no hay nada acá'), isNull);
    });
  });

  group('un hilo guardado sin identidad de mensaje', () {
    // El disco está lleno de mensajes escritos antes de que existiera `id`.
    // Si al cargarlos se inventara un uuid nuevo por vez, una referencia
    // copiada dejaría de resolver al reabrir la app — en silencio.
    final persisted = <String, dynamic>{
      'role': 'assistant',
      'text': 'Lo dejé andando.',
      'timestamp': _epoch.toIso8601String(),
      'authorProfileId': _auditorId,
      'workNodeId': 'auditar',
    };

    test('se carga entero, con un id derivado y no vacío', () {
      final message = ChatMessage.fromJson(Map.of(persisted));

      expect(message.id, isNotEmpty);
      expect(message.text, 'Lo dejé andando.');
      expect(message.authorProfileId, _auditorId);
      expect(message.viaKeelAi, isFalse);
    });

    test('da SIEMPRE el mismo id para la misma fila', () {
      expect(
        ChatMessage.fromJson(Map.of(persisted)).id,
        ChatMessage.fromJson(Map.of(persisted)).id,
      );
    });

    test('da ids distintos para mensajes distintos', () {
      final otro = Map.of(persisted)..['text'] = 'Otra cosa.';
      expect(
        ChatMessage.fromJson(Map.of(persisted)).id,
        isNot(ChatMessage.fromJson(otro).id),
      );
    });

    test('un id ya escrito manda sobre la derivación', () {
      final conId = Map.of(persisted)..['id'] = 'msg-fijo';
      expect(ChatMessage.fromJson(conId).id, 'msg-fijo');
    });
  });

  group('responder un mensaje desde Keel AI', () {
    test('entra al hilo citado, dirigido al autor y atribuido', () async {
      final viewmodel = await _openedOn(_project(running: false));

      await viewmodel.replyInSession(
        'project-keel',
        'session-uno',
        _replyPrompt('Dejala en memoria hasta pasar las 100K entradas.'),
      );

      final reply = viewmodel.data.projects.single.activeSession!.messages
          .where((message) => message.role == ChatRole.user)
          .single;

      // Al miembro le tiene que quedar claro que esto contesta SU pregunta.
      expect(reply.text, startsWith('@auditor'));
      expect(
        reply.text,
        contains('> ¿Migramos la cola a Redis o la dejamos en memoria?'),
      );
      expect(reply.text, contains('en el nodo «auditar»'));
      expect(reply.text, contains('a las 14:32'));
      expect(
        reply.text,
        contains('Dejala en memoria hasta pasar las 100K entradas.'),
      );
      // Y al usuario, al releer el hilo, que ese mensaje no lo tipeó él.
      expect(reply.viaKeelAi, isTrue);
    });

    test('con la sesión trabajando espera en la cola sin perder la '
        'atribución', () async {
      final viewmodel = await _openedOn(_project(running: true));

      await viewmodel.replyInSession(
        'project-keel',
        'session-uno',
        _replyPrompt('Dejala en memoria.'),
      );

      final queued =
          viewmodel.data.projects.single.activeSession!.queuedMessages.single;

      expect(queued.viaKeelAi, isTrue);
      expect(queued.text, startsWith('@auditor'));
      expect(
        queued.text,
        contains('> ¿Migramos la cola a Redis o la dejamos en memoria?'),
      );
    });

    test('la atribución sobrevive al ida y vuelta de la cola en disco', () {
      final session = Session(
        id: 'session-uno',
        title: 'Sesión uno',
        createdAt: _epoch,
        queuedMessages: [
          SessionQueuedMessage(
            id: 'pending-1',
            text: '@auditor — respuesta',
            createdAt: _epoch,
            viaKeelAi: true,
          ),
        ],
      );

      expect(
        Session.fromJson(session.toJson()).queuedMessages.single.viaKeelAi,
        isTrue,
      );
    });
  });
}
