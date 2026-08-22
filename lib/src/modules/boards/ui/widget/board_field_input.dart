import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/boards/model/board.dart';
import 'package:keel_ui/src/modules/secrets/model/secret.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';

/// Un campo del tablero, dibujado según lo que es.
///
/// El de tipo secreto es el único que no se escribe: muestra de qué secret
/// sale y si está cargado. El valor no pasa por acá ni por la corrida
/// guardada — se resuelve en el ViewModel, al momento de disparar.
class BoardFieldInput extends StatelessWidget {
  const BoardFieldInput({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final BoardField field;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, right: 12),
              child: Text(
                field.label,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.outline,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _control(context),
                if (field.hint.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      field.hint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _control(BuildContext context) => switch (field.kind) {
    BoardFieldKind.booleano => Align(
      alignment: Alignment.centerLeft,
      child: Switch(
        value: value == 'true',
        onChanged: (next) => onChanged('$next'),
      ),
    ),
    BoardFieldKind.opcion => DropdownButtonFormField<String>(
      initialValue: field.options.contains(value) ? value : null,
      isDense: true,
      decoration: _decoration(context),
      items: [
        for (final option in field.options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: (next) => onChanged(next ?? ''),
    ),
    BoardFieldKind.secreto => _SecretField(field: field),
    BoardFieldKind.multilinea || BoardFieldKind.json => TextFormField(
      initialValue: value,
      minLines: 3,
      maxLines: 10,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      decoration: _decoration(context),
      onChanged: onChanged,
    ),
    BoardFieldKind.texto || BoardFieldKind.numero => TextFormField(
      initialValue: value,
      keyboardType: field.kind == BoardFieldKind.numero
          ? TextInputType.number
          : null,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
      decoration: _decoration(context),
      onChanged: onChanged,
    ),
  };

  InputDecoration _decoration(BuildContext context) => const InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  );
}

/// El campo que sale de un secret: se ve de cuál, y si está cargado.
class _SecretField extends StatelessWidget {
  const _SecretField({required this.field});

  final BoardField field;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ReactiveViewModelBuilder<SecretsViewModel, SecretsState>(
      viewmodel: SecretsService.instance.notifier,
      build: (state, viewmodel, keep) {
        final falta =
            viewmodel.pendingOf([field.secretName]).isNotEmpty ||
            viewmodel.missingOf([field.secretName]).isNotEmpty;
        final color = falta ? scheme.error : scheme.onSurface;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                falta ? Icons.key_off_outlined : Icons.key_outlined,
                size: 15,
                color: falta ? scheme.error : scheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                field.secretName,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                falta ? 'todavía sin valor' : 'sale de Secrets',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: falta ? scheme.error : scheme.outline,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
