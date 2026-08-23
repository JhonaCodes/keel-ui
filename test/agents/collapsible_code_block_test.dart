import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';

import 'package:keel_ui/src/modules/agents/ui/widget/markdown_text.dart';

/// TEST_CHARTER
/// - Requisito: un bloque ```código``` de un mensaje se renderiza siempre
///   como una tarjeta compacta de máximo 2 filas (encabezado + botones Ver/
///   Cerrar), nunca con el código expandido inline — eso es lo que atrapaba
///   el scroll del chat.
/// - Falla a prevenir: un `git diff` o un Read completo pegado en la
///   respuesta de un agente revienta el alto del bloque en el chat.
/// - Trigger: MarkdownText con un fence ``` de 200 líneas.
/// - Oráculo observable: (a) `tester.getSize` de la tarjeta colapsada es
///   chico e independiente de las líneas; (b) tocar "Ver" abre un panel
///   (`showFormPanel`, el mismo patrón que un end drawer) con el código
///   completo (`CodeField`) adentro; (c) tocar "Cerrar" hace que la tarjeta
///   desaparezca del árbol.
/// - Contrafactual: sin este widget (con `CodeField` directo), no hay
///   botones "Ver"/"Cerrar" y el alto crece con las 200 líneas.
void main() {
  final codigoLargo = List.generate(
    200,
    (i) => 'final linea$i = "contenido de la línea $i";',
  ).join('\n');

  Future<void> pump(WidgetTester tester, String text) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarkdownText(text, color: Colors.black),
        ),
      ),
    ),
  );

  testWidgets(
    'un bloque de código largo se renderiza como tarjeta compacta (máx. 2 filas)',
    (tester) async {
      await pump(tester, '```dart\n$codigoLargo\n```');
      await tester.pump();

      final size = tester.getSize(find.byType(MarkdownText));

      // Dos filas de header + botones, nunca el código: no puede depender
      // de las 200 líneas del fence.
      expect(size.height, lessThan(100));
      expect(find.text('Ver'), findsOneWidget);
      expect(find.text('Cerrar'), findsOneWidget);
      // El código no está en el árbol mientras está colapsado.
      expect(find.byType(CodeField), findsNothing);
    },
  );

  testWidgets('tocar "Ver" abre el panel con el código completo', (
    tester,
  ) async {
    await pump(tester, '```dart\n$codigoLargo\n```');
    await tester.pump();

    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();

    expect(find.byType(CodeField), findsOneWidget);
    final codeField = tester.widget<CodeField>(find.byType(CodeField));
    expect(codeField.codes, contains('linea0'));
    expect(codeField.codes, contains('linea199'));
  });

  testWidgets('tocar "Cerrar" hace desaparecer la tarjeta', (tester) async {
    await pump(tester, '```dart\n$codigoLargo\n```');
    await tester.pump();

    await tester.tap(find.text('Cerrar'));
    await tester.pump();

    expect(find.text('Ver'), findsNothing);
    expect(find.text('Cerrar'), findsNothing);
  });
}
