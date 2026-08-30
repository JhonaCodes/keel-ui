import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/integrations/genui/genui.dart';
import 'package:keel_ui/src/modules/boards/model/board.dart';
import 'package:keel_ui/src/modules/boards/viewmodel/boards_viewmodel.dart';

Future<void> openBoardFormScreen(
  BuildContext context, {
  Board? initial,
  String? projectId,
}) {
  return showFormPanel<void>(
    context,
    width: 720,
    child: BoardFormScreen(initial: initial, projectId: projectId),
  );
}

/// Editar un tablero a mano.
///
/// El camino principal es pedírselo a un agente, y por eso este formulario
/// no intenta ser un constructor visual de pasos: sería mucha pantalla para
/// el camino secundario. Lo que hace es dejarte editar la ESPECIFICACIÓN,
/// que es la misma que escribe el agente y pasa por la misma validación. Un
/// error acá dice exactamente lo mismo que le diría a él.
class BoardFormScreen extends StatefulWidget {
  const BoardFormScreen({super.key, this.initial, this.projectId});

  final Board? initial;
  final String? projectId;

  @override
  State<BoardFormScreen> createState() => _BoardFormScreenState();
}

class _BoardFormScreenState extends State<BoardFormScreen> {
  late final _specController = TextEditingController(
    text: _initialSpec(widget.initial),
  );

  List<String> _errors = const [];
  String? _formError;

  static const _plantilla = '''
{
  "name": "Lanzar oferta",
  "note": "contra el ambiente de desarrollo",
  "fields": [
    {"key": "producto", "label": "Producto", "default": "SKU-1183"},
    {"key": "cantidad", "label": "Cantidad", "kind": "numero", "default": "40"}
  ],
  "actions": [
    {
      "label": "Lanzar",
      "steps": [
        {
          "kind": "http",
          "method": "POST",
          "url": "https://api-dev.ejemplo.com/v1/offers",
          "body": "{\\"sku\\": \\"{{producto}}\\", \\"qty\\": {{cantidad}}}"
        }
      ]
    }
  ]
}''';

  /// La especificación de un tablero que ya existe, para poder editarla.
  /// No es su JSON crudo: los ids internos no aportan nada acá y solo
  /// invitan a tocarlos.
  static String _initialSpec(Board? board) {
    if (board == null) return _plantilla;
    return const JsonEncoder.withIndent('  ').convert({
      'name': board.name,
      if (board.note.isNotEmpty) 'note': board.note,
      'fields': [
        for (final field in board.fields)
          {
            'key': field.key,
            'label': field.label,
            if (field.kind != BoardFieldKind.texto) 'kind': field.kind.alias,
            if (field.defaultValue.isNotEmpty) 'default': field.defaultValue,
            if (field.options.isNotEmpty) 'options': field.options,
            if (field.secretName.isNotEmpty) 'secret_name': field.secretName,
            if (field.required) 'required': true,
            if (field.hint.isNotEmpty) 'hint': field.hint,
          },
      ],
      'actions': [
        for (final action in board.actions)
          {
            'label': action.label,
            'steps': [
              for (final step in action.steps)
                {
                  'kind': step.kind.alias,
                  if (step.kind == BoardStepKind.http) ...{
                    'method': step.method,
                    'url': step.url,
                    if (step.headers.isNotEmpty) 'headers': step.headers,
                    if (step.body.isNotEmpty) 'body': step.body,
                  } else ...{
                    'command': step.command,
                    if (step.args.isNotEmpty) 'args': step.args,
                  },
                  if (step.captures.isNotEmpty)
                    'captures': [
                      for (final capture in step.captures)
                        {
                          'as': capture.as,
                          'from': capture.from.alias,
                          if (capture.path.isNotEmpty) 'path': capture.path,
                        },
                    ],
                },
            ],
          },
      ],
    });
  }

  @override
  void dispose() {
    _specController.dispose();
    super.dispose();
  }

  void _submit() {
    final projectId = widget.initial?.projectId ?? widget.projectId;
    if (projectId == null) {
      setState(() => _formError = 'Un tablero tiene que vivir en un proyecto.');
      return;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(_specController.text);
    } on FormatException catch (error) {
      setState(() {
        _errors = ['Eso no es JSON: ${error.message}'];
        _formError = null;
      });
      return;
    }
    if (decoded is! Map<String, dynamic>) {
      setState(() => _errors = ['La especificación tiene que ser un objeto.']);
      return;
    }

    final result = parseBoardSpec(
      decoded,
      projectId: projectId,
      createdByProfileId: '',
      existing: widget.initial,
    );
    if (result.board == null) {
      setState(() {
        _errors = result.errors;
        _formError = null;
      });
      return;
    }

    BoardsService.instance.notifier.upsert(result.board!);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isEditing = widget.initial != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar tablero' : 'Nuevo tablero'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: FilledButton(
              onPressed: _submit,
              child: Text(isEditing ? 'Guardar' : 'Crear'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Lo más rápido es pedírselo a un agente del proyecto: lee tu '
            'código o tu OpenAPI y lo arma solo. Esto es para corregirlo '
            'después, o para escribirlo si ya sabés qué querés.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _specController,
            autofocus: true,
            minLines: 18,
            maxLines: 40,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              labelText: t.labelSpecification,
              alignLabelWithHint: true,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          if (_errors.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final error in _errors)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, size: 15, color: scheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (_formError != null) ...[
            const SizedBox(height: 12),
            Text(_formError!, style: TextStyle(color: scheme.error)),
          ],
        ],
      ),
    );
  }
}
