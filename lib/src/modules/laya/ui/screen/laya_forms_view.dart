import 'package:flutter/material.dart';

import 'package:keel_core/modules/laya_forms/model/laya_form.dart';
import 'package:keel_ui/src/modules/laya/model/laya_labels.dart';

/// Los formularios guardados: los que armaste, los que armó Keel AI o el
/// celular. Tocar uno lo abre para completarlo y preguntar.
class LayaFormsList extends StatelessWidget {
  const LayaFormsList({
    super.key,
    required this.forms,
    required this.runs,
    required this.onOpen,
  });

  final List<LayaForm> forms;
  final Map<String, LayaFormRun> runs;
  final ValueChanged<LayaForm> onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (forms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Todavía no hay formularios. Guarda una pregunta desde «Preguntar», '
          'o pídele a Keel AI que te arme uno: «quiero consultar si un log '
          'es un fallo de autenticación».',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final form in forms)
          ListTile(
            onTap: () => onOpen(form),
            leading: Icon(Icons.fact_check_outlined, color: scheme.primary),
            title: Text(form.name),
            subtitle: Text(
              [
                if (form.description.isNotEmpty) form.description,
                '${form.questions.length} '
                    '${form.questions.length == 1 ? 'pregunta' : 'preguntas'}'
                    ' · ${LayaLabels.creator(form.createdBy)}',
                if (runs[form.id] case final run?)
                  'última: ${LayaLabels.when(run.at)}',
              ].join('\n'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
      ],
    );
  }
}

/// Un formulario abierto: sus campos para completar, «Preguntar» y lo que
/// contestó Laya a cada pregunta.
class LayaFormFill extends StatefulWidget {
  const LayaFormFill({
    super.key,
    required this.form,
    required this.onAsk,
    required this.onBack,
    required this.onDuplicate,
    required this.onDelete,
    this.lastRun,
  });

  final LayaForm form;
  final LayaFormRun? lastRun;
  final Future<LayaFormRun> Function(Map<String, String> values) onAsk;
  final VoidCallback onBack;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  State<LayaFormFill> createState() => _LayaFormFillState();
}

class _LayaFormFillState extends State<LayaFormFill> {
  late final Map<String, TextEditingController> _values = {
    for (final field in widget.form.fields)
      field.name: TextEditingController(
        text: widget.lastRun?.values[field.name] ?? '',
      ),
  };
  bool _asking = false;
  late LayaFormRun? _run = widget.lastRun;

  @override
  void dispose() {
    for (final controller in _values.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _ask() async {
    setState(() => _asking = true);
    final run = await widget.onAsk({
      for (final MapEntry(:key, :value) in _values.entries) key: value.text,
    });
    if (!mounted) return;
    setState(() {
      _asking = false;
      _run = run;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final form = widget.form;
    final run = _run;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Volver a la lista',
              icon: const Icon(Icons.arrow_back, size: 18),
              onPressed: widget.onBack,
            ),
            Expanded(child: Text(form.name, style: text.titleMedium)),
            IconButton(
              tooltip: 'Duplicar',
              icon: const Icon(Icons.copy_outlined, size: 17),
              onPressed: widget.onDuplicate,
            ),
            IconButton(
              tooltip: 'Borrar',
              icon: Icon(Icons.delete_outline, size: 18, color: scheme.error),
              onPressed: widget.onDelete,
            ),
          ],
        ),
        if (form.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Text(
              form.description,
              style: text.bodySmall?.copyWith(color: scheme.outline),
            ),
          ),
        Text('Evidencia', style: text.labelLarge),
        const SizedBox(height: 6),
        if (form.fields.isEmpty)
          Text(
            'Este formulario no pide datos: pregunta sobre su nombre.',
            style: text.bodySmall?.copyWith(color: scheme.outline),
          ),
        for (final field in form.fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _values[field.name],
              minLines: 1,
              maxLines: 6,
              decoration: InputDecoration(
                isDense: true,
                labelText: field.name,
                hintText: field.hint.isEmpty ? null : field.hint,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _asking ? null : _ask,
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Preguntar'),
          ),
        ),
        if (_asking)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(minHeight: 1.5),
          ),
        const SizedBox(height: 12),
        Text('Preguntas', style: text.labelLarge),
        const SizedBox(height: 6),
        if (run != null && run.error.isNotEmpty)
          Text(run.error, style: text.bodySmall?.copyWith(color: scheme.error)),
        for (final question in form.questions)
          LayaFormQuestionResult(
            question: question,
            answer: run?.answers
                .where((answer) => answer.questionId == question.id)
                .firstOrNull,
          ),
        if (run != null)
          Text(
            'Respondido ${LayaLabels.when(run.at)}',
            style: text.bodySmall?.copyWith(color: scheme.outline),
          ),
      ],
    );
  }
}

/// Una pregunta del formulario y, si ya se preguntó, lo que dijo Laya.
class LayaFormQuestionResult extends StatelessWidget {
  const LayaFormQuestionResult({
    super.key,
    required this.question,
    this.answer,
  });

  final LayaFormQuestion question;
  final LayaFormAnswer? answer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final result = answer;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(question.text, style: text.bodyMedium),
          if (result == null)
            Text(
              'Sin preguntar todavía',
              style: text.bodySmall?.copyWith(color: scheme.outline),
            )
          else ...[
            const SizedBox(height: 4),
            Text(
              LayaLabels.answerHeadline(result),
              style: text.titleSmall?.copyWith(
                color: result.unsure ? scheme.outline : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            for (final MapEntry(:key, :value) in result.probabilities.entries)
              Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      LayaLabels.answerName(key),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: value.clamp(0, 1).toDouble(),
                      minHeight: 3,
                      backgroundColor: scheme.outlineVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      LayaLabels.percent(value),
                      textAlign: TextAlign.right,
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ),
            Text(
              'Laya: ${LayaLabels.confidence(result.confidence)}',
              style: text.bodySmall?.copyWith(
                color: result.unsure ? scheme.error : scheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
