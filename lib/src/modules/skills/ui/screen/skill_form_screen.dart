import 'package:flutter/material.dart';
import 'package:keel_ui/l10n/generated/app_localizations.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/skills/model/skill.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';

Future<void> openSkillFormScreen(
  BuildContext context, {
  Skill? initial,
  String? draftContent,
  bool draftGlobal = false,
}) {
  return showFormPanel<void>(
    context,
    child: SkillFormScreen(
      initial: initial,
      draftContent: draftContent,
      draftGlobal: draftGlobal,
    ),
  );
}

class SkillFormScreen extends StatefulWidget {
  const SkillFormScreen({
    super.key,
    this.initial,
    this.draftContent,
    this.draftGlobal = false,
  });

  final Skill? initial;

  /// Prefill for a NEW skill (e.g. from a recurrence suggestion). Ignored
  /// when editing.
  final String? draftContent;
  final bool draftGlobal;

  @override
  State<SkillFormScreen> createState() => _SkillFormScreenState();
}

class _SkillFormScreenState extends State<SkillFormScreen> {
  late final _nameController = TextEditingController(
    text: widget.initial?.name,
  );
  late final _contentController = TextEditingController(
    text: widget.initial?.content ?? widget.draftContent,
  );
  late bool _isGlobal = widget.initial?.isGlobal ?? widget.draftGlobal;
  String? _nameError;
  String? _formError;

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    final t = AppLocalizations.of(context)!;
    setState(() {
      _nameError = validateSkillName(value.trim(), t);
      _formError = null;
    });
  }

  void _submit() {
    final t = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final nameError = validateSkillName(name, t);
    if (nameError != null) {
      setState(() => _nameError = nameError);
      return;
    }

    final viewmodel = SkillsService.instance.notifier;
    final initial = widget.initial;
    final error = initial == null
        ? viewmodel.createSkill(
            name: name,
            content: _contentController.text,
            isGlobal: _isGlobal,
          )
        : viewmodel.updateSkill(
            initial.id,
            name: name,
            content: _contentController.text,
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? t.formEditEntity('skill') : t.formRegisterEntity('skill'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: FilledButton(
              onPressed: _submit,
              child: Text(isEditing ? t.formSave : t.buttonRegister),
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
                    labelText: '${t.formName} (skill)',
                    errorText: _nameError,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(t.formGlobalSkill),
                  subtitle: Text(t.formGlobalSkillDescription),
                  contentPadding: EdgeInsets.zero,
                  value: _isGlobal,
                  onChanged: (value) => setState(() => _isGlobal = value),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      labelText: t.formSkillContent,
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
