import 'package:flutter/material.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/hooks/model/hook.dart';
import 'package:keel_ui/src/modules/hooks/model/hook_event.dart';
import 'package:keel_ui/src/modules/hooks/viewmodel/hooks_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/ui/widget/rule_multi_select.dart';
import 'package:keel_ui/src/modules/tools/viewmodel/tools_viewmodel.dart';

Future<void> openHookFormScreen(BuildContext context, {Hook? initial}) {
  return showFormPanel<void>(
    context,
    width: 720,
    child: HookFormScreen(initial: initial),
  );
}

class HookFormScreen extends StatefulWidget {
  const HookFormScreen({super.key, this.initial});

  final Hook? initial;

  @override
  State<HookFormScreen> createState() => _HookFormScreenState();
}

class _HookFormScreenState extends State<HookFormScreen> {
  late final _nameController = TextEditingController(
    text: widget.initial?.name,
  );
  late final _descriptionController = TextEditingController(
    text: widget.initial?.description,
  );
  late final _matcherController = TextEditingController(
    text: widget.initial?.matcher,
  );
  late final _commandController = TextEditingController(
    text: switch (widget.initial?.body) {
      HookCommand(:final command) => command,
      _ => '',
    },
  );
  late final _timeoutController = TextEditingController(
    text: '${widget.initial?.timeoutSeconds ?? kDefaultHookTimeoutSeconds}',
  );

  late HookEvent _event = widget.initial?.event ?? HookEvent.preToolUse;
  late bool _usesTool = widget.initial?.body is HookToolRef;
  late String? _toolName = switch (widget.initial?.body) {
    HookToolRef(:final toolName) => toolName,
    _ => null,
  };
  late List<String> _enforces = [...?widget.initial?.enforces];
  late bool _isGlobal = widget.initial?.isGlobal ?? false;

  String? _nameError;
  String? _formError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _matcherController.dispose();
    _commandController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  void _submit() {
    final t = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final nameError = validateHookName(name, t);
    if (nameError != null) {
      setState(() => _nameError = nameError);
      return;
    }

    final body = _usesTool
        ? HookToolRef(_toolName ?? '')
        : HookCommand(_commandController.text.trim());

    final viewmodel = HooksService.instance.notifier;
    final initial = widget.initial;
    final timeout =
        int.tryParse(_timeoutController.text.trim()) ??
        kDefaultHookTimeoutSeconds;

    final error = initial == null
        ? viewmodel.createHook(
            name: name,
            description: _descriptionController.text,
            event: _event,
            body: body,
            matcher: _matcherController.text,
            timeoutSeconds: timeout,
            enforces: _enforces,
            isGlobal: _isGlobal,
          )
        : viewmodel.updateHook(
            initial.id,
            name: name,
            description: _descriptionController.text,
            event: _event,
            body: body,
            matcher: _matcherController.text,
            timeoutSeconds: timeout,
            enforces: _enforces,
            isGlobal: _isGlobal,
          );

    if (error != null) {
      setState(() => _formError = error);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isEditing = widget.initial != null;
    final tools = ToolsService.instance.notifier.data.tools;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? t.formEditEntity('hook') : t.formRegisterEntity('hook'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _submit,
              child: Text(isEditing ? t.formSave : t.buttonRegister),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: t.formLabelHookName,
              helperText: t.formHintHookScript,
              errorText: _nameError,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            onChanged: (value) => setState(() {
              _nameError = validateHookName(value.trim(), t);
              _formError = null;
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.formLabelWhatHookDoes,
              helperText:
                  'Para vos, no para el modelo: el modelo nunca ve un hook, '
                  'solo su efecto.',
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _EventPicker(
            value: _event,
            onChanged: (event) => setState(() => _event = event),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _matcherController,
            decoration: InputDecoration(
              labelText: 'Acotar a',
              helperText: _event.matcherHint.isEmpty
                  ? AppLocalizations.of(context)!.formMessageNoEventFilter
                  : AppLocalizations.of(
                      context,
                    )!.formHintEventFilter(_event.matcherHint),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _BodyPicker(
            usesTool: _usesTool,
            toolNames: [for (final tool in tools) tool.name],
            selectedTool: _toolName,
            commandController: _commandController,
            onModeChanged: (usesTool) => setState(() => _usesTool = usesTool),
            onToolChanged: (name) => setState(() => _toolName = name),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _timeoutController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.formLabelHookTimeout,
              helperText: AppLocalizations.of(
                context,
              )!.formDescriptionHookScope,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _isGlobal,
            contentPadding: EdgeInsets.zero,
            title: const Text('Aplicar a todos los agentes'),
            subtitle: Text(AppLocalizations.of(context)!.formLabelHookRules),
            onChanged: (value) => setState(() => _isGlobal = value),
          ),
          const Divider(height: 32),
          RuleMultiSelect(
            selectedNames: _enforces,
            onChanged: (rules) => setState(() => _enforces = rules),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              AppLocalizations.of(context)!.formDescriptionHookRules,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (_formError != null) ...[
            const SizedBox(height: 16),
            Text(
              _formError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

/// Elegir el evento, con los portables separados de los que solo existen en
/// Claude. La separación es el punto: un hook en un evento exclusivo NO va a
/// correr con codex, y eso se ve antes de guardarlo, no después.
class _EventPicker extends StatelessWidget {
  final HookEvent value;
  final ValueChanged<HookEvent> onChanged;

  const _EventPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<HookEvent>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.formLabelWhenHookRuns,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
          items: [
            for (final event in HookEvent.ordered)
              DropdownMenuItem(
                value: event,
                child: Text(
                  event.isPortable
                      ? event.label
                      : '${event.label}  ·  solo Claude',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (event) => onChanged(event ?? value),
        ),
        if (value.detail.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              value.detail,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (!value.isPortable)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Este evento existe solo en Claude. Un agente que corra con '
              'codex no va a ejecutar este hook, y el turno lo va a decir.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        if (!value.blocking)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Este evento no puede frenar nada: sirve para reaccionar, no '
              'para bloquear.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// Un comando suelto, o una tool ya registrada.
class _BodyPicker extends StatelessWidget {
  final bool usesTool;
  final List<String> toolNames;
  final String? selectedTool;
  final TextEditingController commandController;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<String?> onToolChanged;

  const _BodyPicker({
    required this.usesTool,
    required this.toolNames,
    required this.selectedTool,
    required this.commandController,
    required this.onModeChanged,
    required this.onToolChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.formLabelWhatHookExecutes,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Un comando')),
            ButtonSegment(value: true, label: Text('Una tool registrada')),
          ],
          selected: {usesTool},
          onSelectionChanged: (selection) => onModeChanged(selection.first),
        ),
        const SizedBox(height: 12),
        if (usesTool) ...[
          if (toolNames.isEmpty)
            Text(AppLocalizations.of(context)!.messageNoToolsRegisteredShort)
          else
            DropdownButtonFormField<String>(
              initialValue: toolNames.contains(selectedTool)
                  ? selectedTool
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Tool',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
              items: [
                for (final name in toolNames)
                  DropdownMenuItem(value: name, child: Text(name)),
              ],
              onChanged: onToolChanged,
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              AppLocalizations.of(context)!.formDescriptionHookCode,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ] else
          TextField(
            controller: commandController,
            minLines: 3,
            maxLines: 12,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Comando',
              helperText: AppLocalizations.of(
                context,
              )!.formDescriptionHookTimeout,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ),
      ],
    );
  }
}
