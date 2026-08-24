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
}
