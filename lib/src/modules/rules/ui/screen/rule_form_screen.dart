import 'package:flutter/material.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/rules/model/rule.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';

Future<void> openRuleFormScreen(BuildContext context, {Rule? initial}) {
  return showFormPanel<void>(context, child: RuleFormScreen(initial: initial));
}

class RuleFormScreen extends StatefulWidget {
  const RuleFormScreen({super.key, this.initial});

  final Rule? initial;

  @override
  State<RuleFormScreen> createState() => _RuleFormScreenState();
}

class _RuleFormScreenState extends State<RuleFormScreen> {
  late final _nameController = TextEditingController(
    text: widget.initial?.name,
  );
  late final _contentController = TextEditingController(
    text: widget.initial?.content,
  );
  String? _nameError;
  String? _formError;

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    setState(() {
      _nameError = validateRuleName(value.trim());
      _formError = null;
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    final nameError = validateRuleName(name);
    if (nameError != null) {
      setState(() => _nameError = nameError);
      return;
    }

    final viewmodel = RulesService.instance.notifier;
    final initial = widget.initial;
    final error = initial == null
        ? viewmodel.createRule(name: name, content: _contentController.text)
        : viewmodel.updateRule(
            initial.id,
            name: name,
            content: _contentController.text,
          );

    if (error != null) {
      setState(() => _formError = error);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isEditing = widget.initial != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? t.formEditEntity(t.labelRules) : t.buttonRegister,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: FilledButton(
              onPressed: _submit,
              child: Text(isEditing ? t.buttonSave : t.buttonRegister),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  onChanged: _onNameChanged,
                  decoration: InputDecoration(
                    labelText: t.formName,
                    errorText: _nameError,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      labelText: 'Contenido (instrucciones a inyectar)',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                  ),
                ),
                if (_formError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _formError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
