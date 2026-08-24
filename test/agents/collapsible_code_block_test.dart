import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

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
///   completo, coloreado y ajustado al ancho; (c) tocar "Cerrar" hace que la
///   tarjeta desaparezca del árbol.
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

    expect(find.byType(CodeField), findsNothing);
    final viewer = find.byKey(const Key('syntax-highlighted-code'));
    expect(viewer, findsOneWidget);
    final selectable = tester.widget<SelectableText>(
      find.descendant(of: viewer, matching: find.byType(SelectableText)),
    );
    expect(selectable.textSpan!.toPlainText(), '$codigoLargo\n');
  });

  testWidgets('normaliza el alias del lenguaje antes de resaltar código', (
    tester,
  ) async {
    await pump(tester, '```js\nconst answer = 42;\n```');
    await tester.pump();

    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('syntax-highlighted-code')), findsOneWidget);
    expect(find.text('javascript'), findsOneWidget);
    expect(find.textContaining('const answer = 42;'), findsOneWidget);
  });

  testWidgets('Dart conserva toda la fuente y usa colores de sintaxis', (
    tester,
  ) async {
    const source = '''
void onAuthChanged() => ref.invalidateSelf();
final listener = AuthService.instance.notifier;
listener.addListener(onAuthChanged);
''';
    await pump(tester, '```dart\n$source```');
    await tester.pump();

    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();

    final viewer = find.byKey(const Key('syntax-highlighted-code'));
    final selectable = tester.widget<SelectableText>(
      find.descendant(of: viewer, matching: find.byType(SelectableText)),
    );
    final span = selectable.textSpan!;
    expect(span.toPlainText(), source);
    final colors = <Color>{};
    if (span.style?.color != null) colors.add(span.style!.color!);
    span.visitChildren((child) {
      if (child is TextSpan && child.style?.color != null) {
        colors.add(child.style!.color!);
      }
      return true;
    });
    expect(colors.length, greaterThan(1));
  });

  testWidgets('una línea larga se ajusta al panel sin ocultar texto', (
    tester,
  ) async {
    final source = List.generate(
      18,
      (index) => 'R$index AuthHeaderInterceptor conserva el texto completo',
    ).join(' — ');
    await pump(tester, '```\n$source\n```');
    await tester.pump();

    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();

    final viewer = find.byKey(const Key('syntax-highlighted-code'));
    final selectableFinder = find.descendant(
      of: viewer,
      matching: find.byType(SelectableText),
    );
    final selectable = tester.widget<SelectableText>(selectableFinder);
    expect(selectable.textSpan!.toPlainText(), '$source\n');
    expect(
      tester.getSize(selectableFinder).width,
      lessThanOrEqualTo(tester.getSize(viewer).width),
    );
    expect(tester.getSize(selectableFinder).height, greaterThan(40));
    expect(
      find.descendant(
        of: viewer,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'tocar "Ver" en un bloque workflow muestra una ficha declarativa',
    (tester) async {
      await pump(tester, '''
```workflow
nombre: nuiapp-tdd
cuando: Para bugs y cambios acotados en NUI App.
tipo: bug
responsable: implementador
skills: nui-app-tdd-orchestrator, nui-test-agent
```
''');
      await tester.pump();

      await tester.tap(find.text('Ver'));
      await tester.pumpAndSettle();

      expect(find.byType(CodeField), findsNothing);
      expect(find.text('nuiapp-tdd'), findsOneWidget);
      final documents = tester
          .widgetList<GptMarkdown>(find.byType(GptMarkdown))
          .map((widget) => widget.data);
      expect(
        documents,
        contains(
          contains(
            '### Cuándo se aplica\nPara bugs y cambios acotados en NUI App.',
          ),
        ),
      );
      expect(
        documents,
        contains(
          contains(
            '### Skills\n- `nui-app-tdd-orchestrator`\n- `nui-test-agent`',
          ),
        ),
      );
    },
  );

  testWidgets('tocar "Ver" en markdown lo renderiza, no lo trata como código', (
    tester,
  ) async {
    await pump(tester, '''
```markdown
# Resultado

- Prueba focalizada aprobada
- Sin regresiones
```
''');
    await tester.pump();

    await tester.tap(find.text('Ver'));
    await tester.pumpAndSettle();

    expect(find.byType(CodeField), findsNothing);
    final documents = tester
        .widgetList<GptMarkdown>(find.byType(GptMarkdown))
        .map((widget) => widget.data);
    expect(documents, contains(contains('# Resultado')));
    expect(documents, contains(contains('- Prueba focalizada aprobada')));
    expect(documents, contains(contains('- Sin regresiones')));
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
