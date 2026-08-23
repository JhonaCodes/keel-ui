import 'package:flutter/material.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'package:keel_ui/src/core/services/external_link_service.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/mermaid_diagram.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/svg_diagram.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// Texto de un agente, leído como lo escribió: markdown, no `##` y `**`.
///
/// Todo lo que sale de un modelo viene en markdown — encabezados, listas,
/// negritas, bloques de código— y mostrarlo crudo es mostrar el andamiaje en
/// vez del contenido. Esto era el cuerpo de una burbuja de chat y nada más;
/// ahora es el widget que usan todos los lugares donde se lee lo que dijo un
/// agente: la burbuja, la ficha de un nodo del mapa y el hilo de un
/// requerimiento.
///
/// Lo que aporta arriba de un `GptMarkdown` pelado:
///
/// - **La escala del contenedor.** Sin esto los encabezados salen del
///   `textTheme` de Material y un `#` se pinta como `headlineLarge` (32px)
///   adentro de una caja cuyo párrafo mide 12.6.
/// - **El color de quien habla.** El markdown de un mensaje tuyo vive sobre
///   otro fondo que el de un agente.
/// - **Las URLs peladas.** El renderer solo hace clickeable lo que ya trae
///   sintaxis de enlace, y las que importan llegan crudas: el PR que abre el
///   último paso viene tal como lo imprime `gh`.
/// - **Los diagramas.** Un bloque ```mermaid o ```svg se dibuja en vez de
///   mostrarse como código.
///
/// No trae `SelectionArea`: eso lo pone la pantalla, una sola vez, alrededor
/// de todo lo que se lee de corrido — si no, seleccionar cruzando dos
/// mensajes no funciona.
class MarkdownText extends StatelessWidget {
  const MarkdownText(
    this.text, {
    super.key,
    required this.color,
    this.fontSize = 14,
  });

  final String text;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GptMarkdownTheme(
      gptThemeData: GptMarkdownTheme.of(context).copyWith(
        h1: _heading(fontSize * 1.45),
        h2: _heading(fontSize * 1.28),
        h3: _heading(fontSize * 1.14),
        h4: _heading(fontSize * 1.05),
        h5: _heading(fontSize),
        h6: _heading(fontSize),
        highlightColor: color.withValues(alpha: 0.14),
        hrLineColor: color.withValues(alpha: 0.25),
        linkColor: scheme.primary,
        linkHoverColor: scheme.primary,
      ),
      child: GptMarkdown(
        linkifyBareUrls(text),
        style: TextStyle(color: color, fontSize: fontSize),
        onLinkTap: (url, _) => openExternalUrl(url),
        codeBuilder: (context, name, code, closed) {
          if (closed) {
            switch (name.toLowerCase()) {
              case 'svg':
                return SvgDiagram(code: code);
              case 'mermaid':
                return MermaidDiagram(code: code);
            }
          }
          return CodeField(name: name, codes: code);
        },
      ),
    );
  }

  /// Un encabezado: más grande y más pesado que el párrafo, pero dentro de la
  /// misma escala. Un `#` no es un titular de portada.
  TextStyle _heading(double size) => TextStyle(
    color: color,
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );
}
