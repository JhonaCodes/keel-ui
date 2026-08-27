import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/task_runner/task_runner.dart';

void main() {
  test('la credencial API sobrevive el mensaje hacia el isolate', () {
    final message = const TaskRunSpec(
      prompt: 'hola',
      workingDirectory: '.',
      model: 'deepseek-chat',
      fullFileSystemAccess: false,
      effort: 'medium',
      provider: 'deepseek',
      providerApiKey: 'secret-del-turno',
    ).toMessage();

    final restored = TaskRunSpec.fromMessage(message);

    expect(restored.providerApiKey, 'secret-del-turno');
  });

  group('modo plan', () {
    test('sobrevive el viaje al isolate', () {
      const spec = TaskRunSpec(
        prompt: 'Planificá',
        workingDirectory: '/tmp',
        model: 'sonnet',
        fullFileSystemAccess: false,
        effort: 'medium',
        planMode: true,
      );

      expect(TaskRunSpec.fromMessage(spec.toMessage()).planMode, isTrue);
    });

    test('un mensaje sin la clave se lee como apagado', () {
      // Un turno armado antes de que el modo plan existiera no trae la
      // clave, y eso no es un turno roto.
      final spec = TaskRunSpec.fromMessage(const {
        'prompt': 'Hola',
        'workingDirectory': '/tmp',
        'model': 'sonnet',
        'fullFileSystemAccess': false,
        'effort': 'medium',
      });

      expect(spec.planMode, isFalse);
    });
  });
}
