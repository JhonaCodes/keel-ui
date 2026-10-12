import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/modules/laya_forms/model/laya_form.dart';
import 'package:keel_ui/src/core/ui/confirm_card.dart';
import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/laya/model/laya_labels.dart';
import 'package:keel_ui/src/modules/laya/model/laya_state.dart';
import 'package:keel_ui/src/modules/laya/model/laya_templates.dart';
import 'package:keel_ui/src/modules/laya/ui/screen/laya_forms_view.dart';
import 'package:keel_ui/src/modules/laya/viewmodel/laya_forms_viewmodel.dart';
import 'package:keel_ui/src/modules/laya/viewmodel/laya_viewmodel.dart';

/// Abre el mini chat con Laya en el panel lateral.
Future<void> openLayaChatPanel(BuildContext context) =>
    showFormPanel<void>(context, child: const LayaChatPanel(), width: 560);

/// Lo que dispara una pregunta: devuelve por qué no se envió, o null.
typedef LayaAskCallback = Future<String?> Function(LayaQuestionDraft draft);

/// Guarda la pregunta como formulario: devuelve por qué no, o null.
typedef LayaSaveCallback = String? Function(LayaQuestionDraft draft);

/// El panel de Laya: «Preguntar» —una pregunta armada por partes— y
/// «Formularios» —los guardados, para completar y preguntar cuando sea—.
/// Laya no conversa: cada pregunta se ARMA y la respuesta son
/// probabilidades y cuánta seguridad tiene.
class LayaChatPanel extends StatelessWidget {
  const LayaChatPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<LayaViewModel, LayaState>(
      viewmodel: LayaService.instance.notifier,
      build: (state, laya, keep) =>
          ReactiveViewModelBuilder<LayaFormsViewModel, LayaFormsState>(
            viewmodel: LayaFormsService.instance.notifier,
            build: (formsState, forms, keepForms) => LayaPanelView(
              chat: state.chat,
              asking: state.asking,
              forms: formsState.forms,
              runs: formsState.runs,
              focusFormId: state.focusFormId,
              onAsk: laya.ask,
              onSaveForm: laya.saveDraftAsForm,
              onClear: laya.clearChat,
              onFocusHandled: laya.clearFocus,
              onAskForm: forms.ask,
              onDuplicateForm: forms.duplicate,
              onDeleteForm: (form) => _confirmDelete(context, forms, form),
            ),
          ),
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    LayaFormsViewModel forms,
    LayaForm form,
  ) async {
    final confirmed = await confirmWithCard(
      context,
      title: 'Borrar el formulario «${form.name}»',
      body: 'Se borran sus preguntas y su última respuesta.',
      confirmLabel: 'Borrar',
      destructive: true,
    );
    if (confirmed) forms.delete(form.id);
  }
}

/// Lo que se ve del panel, sin los ViewModels.
class LayaPanelView extends StatefulWidget {
  const LayaPanelView({
    super.key,
    required this.chat,
    required this.asking,
    required this.forms,
    required this.runs,
    required this.onAsk,
    required this.onSaveForm,
    required this.onClear,
    required this.onAskForm,
    required this.onDuplicateForm,
    required this.onDeleteForm,
    this.onFocusHandled,
    this.focusFormId,
    this.initialDraft,
    this.initialTab = 0,
  });

  final List<LayaExchange> chat;
  final bool asking;
  final List<LayaForm> forms;
  final Map<String, LayaFormRun> runs;
  final LayaAskCallback onAsk;
  final LayaSaveCallback onSaveForm;
  final VoidCallback onClear;
  final Future<LayaFormRun> Function(LayaForm form, Map<String, String> values)
  onAskForm;
  final ValueChanged<String> onDuplicateForm;
  final ValueChanged<LayaForm> onDeleteForm;

  /// El formulario a abrir de una (lo acaba de crear Keel AI); se avisa
  /// con [onFocusHandled] cuando ya se abrió.
  final String? focusFormId;
  final VoidCallback? onFocusHandled;

  final LayaQuestionDraft? initialDraft;
  final int initialTab;

  @override
  State<LayaPanelView> createState() => _LayaPanelViewState();
}

class _LayaPanelViewState extends State<LayaPanelView>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab,
  );
  String? _openFormId;

  /// Lo que «Repetir» manda al formulario, y un contador para que cargue
  /// aunque sea la misma pregunta dos veces.
  LayaQuestionDraft? _reload;
  int _reloadCount = 0;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
    _takeFocus();
  }

  @override
  void didUpdateWidget(LayaPanelView old) {
    super.didUpdateWidget(old);
    if (widget.focusFormId != old.focusFormId) _takeFocus();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _takeFocus() {
    final focus = widget.focusFormId;
    if (focus == null) return;
    _openFormId = focus;
    _tabs.index = 1;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.onFocusHandled?.call(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.forms.where((f) => f.id == _openFormId).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laya'),
        actions: [
          if (_tabs.index == 0 && widget.chat.isNotEmpty)
            TextButton(onPressed: widget.onClear, child: const Text('Limpiar')),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            const Tab(text: 'Preguntar'),
            Tab(text: 'Formularios (${widget.forms.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _askTab(context),
          if (open == null)
            LayaFormsList(
              forms: widget.forms,
              runs: widget.runs,
              onOpen: (form) => setState(() => _openFormId = form.id),
            )
          else
            LayaFormFill(
              key: ValueKey(open.id),
              form: open,
              lastRun: widget.runs[open.id],
              onAsk: (values) => widget.onAskForm(open, values),
              onBack: () => setState(() => _openFormId = null),
              onDuplicate: () => widget.onDuplicateForm(open.id),
              onDelete: () => widget.onDeleteForm(open),
            ),
        ],
      ),
    );
  }

  Widget _askTab(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: widget.chat.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Arma la pregunta abajo: qué tipo de respuesta quieres, '
                    'qué quieres saber, las opciones si es una entre varias, '
                    'y la evidencia con nombre. Laya contesta con '
                    'probabilidades y te dice cuándo duda. O elige una '
                    'plantilla. En inglés funciona mejor.',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  children: [
                    for (final exchange in widget.chat)
                      LayaExchangeTile(
                        exchange: exchange,
                        onRepeat: () => setState(() {
                          _reload = exchange.draft;
                          _reloadCount++;
                        }),
                      ),
                  ],
                ),
        ),
        const Divider(height: 1),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.58,
          ),
          child: SingleChildScrollView(
            child: LayaQuestionForm(
              asking: widget.asking,
              onAsk: widget.onAsk,
              onSaveForm: widget.onSaveForm,
              initialDraft: widget.initialDraft,
              reload: _reload,
              reloadCount: _reloadCount,
            ),
          ),
        ),
      ],
    );
  }
}

/// Una pregunta y su respuesta, con «Repetir» para volver a cargarla.
class LayaExchangeTile extends StatelessWidget {
  const LayaExchangeTile({super.key, required this.exchange, this.onRepeat});

  final LayaExchange exchange;
  final VoidCallback? onRepeat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final draft = exchange.draft;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(draft.question, style: text.bodyMedium)),
              Text(
                draft.kind.label,
                style: text.bodySmall?.copyWith(color: scheme.outline),
              ),
              if (onRepeat case final repeat?)
                IconButton(
                  tooltip: 'Repetir: cargarla en el formulario',
                  icon: const Icon(Icons.replay, size: 15),
                  constraints: const BoxConstraints.tightFor(
                    width: 26,
                    height: 22,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: repeat,
                ),
            ],
          ),
          for (final item in draft.evidence)
            if (item.value.trim().isNotEmpty)
              Text(
                '${item.name}: ${item.value}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: scheme.outline),
              ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: switch (exchange) {
              LayaExchange(pending: true) => const LinearProgressIndicator(
                minHeight: 1.5,
              ),
              LayaExchange(:final error) when error.isNotEmpty => Text(
                error,
                style: text.bodySmall?.copyWith(color: scheme.error),
              ),
              _ => _Answer(
                headline: exchange.headline,
                rows: exchange.probabilities,
                confidence: exchange.confidence,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({
    required this.headline,
    required this.rows,
    required this.confidence,
  });

  final String headline;
  final Map<String, double> rows;
  final double? confidence;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final unsure = (confidence ?? 0) < 0.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          headline,
          style: text.titleSmall?.copyWith(
            color: unsure ? scheme.outline : scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        for (final MapEntry(:key, :value) in rows.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    key,
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
          ),
        Text(
          'Laya: ${LayaLabels.confidence(confidence)}',
          style: text.bodySmall?.copyWith(
            color: unsure ? scheme.error : scheme.outline,
          ),
        ),
      ],
    );
  }
}

/// El formulario que arma la pregunta. El tipo de respuesta decide qué
/// campos hay: sí/no pide solo la pregunta; una entre opciones, las
/// opciones con su descripción; una escala, los niveles de menor a mayor.
/// La evidencia va en filas de nombre y valor.
class LayaQuestionForm extends StatefulWidget {
  const LayaQuestionForm({
    super.key,
    required this.asking,
    required this.onAsk,
    this.onSaveForm,
    this.initialDraft,
    this.reload,
    this.reloadCount = 0,
  });

  final bool asking;
  final LayaAskCallback onAsk;

  /// Null: sin «Guardar como formulario».
  final LayaSaveCallback? onSaveForm;
  final LayaQuestionDraft? initialDraft;

  /// Una pregunta para volver a cargar; carga cuando [reloadCount] cambia.
  final LayaQuestionDraft? reload;
  final int reloadCount;

  @override
  State<LayaQuestionForm> createState() => _LayaQuestionFormState();
}

class _Pair {
  _Pair(String first, String second)
    : first = TextEditingController(text: first),
      second = TextEditingController(text: second);

  final TextEditingController first;
  final TextEditingController second;

  void dispose() {
    first.dispose();
    second.dispose();
  }
}

class _LayaQuestionFormState extends State<LayaQuestionForm> {
  LayaQuestionKind _kind = LayaQuestionKind.yesNo;
  final _question = TextEditingController();
  List<_Pair> _options = [];
  List<TextEditingController> _levels = [];
  List<_Pair> _evidence = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(
      widget.initialDraft ??
          const LayaQuestionDraft(
            evidence: [LayaEvidence(name: 'text', value: '')],
          ),
    );
  }

  @override
  void didUpdateWidget(LayaQuestionForm old) {
    super.didUpdateWidget(old);
    final reload = widget.reload;
    if (reload != null && widget.reloadCount != old.reloadCount) {
      setState(() => _load(reload));
    }
  }

  @override
  void dispose() {
    _question.dispose();
    _disposeRows();
    super.dispose();
  }

  void _disposeRows() {
    for (final row in [..._options, ..._evidence]) {
      row.dispose();
    }
    for (final level in _levels) {
      level.dispose();
    }
  }

  /// Pone [draft] en los campos. Lo usan el arranque, las plantillas y
  /// «Repetir».
  void _load(LayaQuestionDraft draft) {
    _disposeRows();
    _kind = draft.kind;
    _question.text = draft.question;
    _options = [
      for (final option in draft.options)
        _Pair(option.name, option.description),
    ];
    _levels = [
      for (final level in draft.levels) TextEditingController(text: level),
    ];
    _evidence = [
      for (final item in draft.evidence) _Pair(item.name, item.value),
    ];
    _ensureRows();
    _error = null;
  }

  /// Que cada lista tenga al menos lo que su tipo necesita para empezar.
  void _ensureRows() {
    while (_kind == LayaQuestionKind.choice && _options.length < 2) {
      _options.add(_Pair('', ''));
    }
    while (_kind == LayaQuestionKind.score && _levels.length < 2) {
      _levels.add(TextEditingController());
    }
    if (_evidence.isEmpty) _evidence.add(_Pair('text', ''));
  }

  LayaQuestionDraft get _draft => LayaQuestionDraft(
    kind: _kind,
    question: _question.text,
    options: [
      for (final row in _options)
        LayaOption(name: row.first.text, description: row.second.text),
    ],
    levels: [for (final level in _levels) level.text],
    evidence: [
      for (final row in _evidence)
        LayaEvidence(name: row.first.text, value: row.second.text),
    ],
  );

  Future<void> _send() async {
    if (widget.asking) return;
    final problem = await widget.onAsk(_draft);
    if (!mounted) return;
    setState(() => _error = problem);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<LayaQuestionKind>(
                  initialValue: _kind,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de respuesta',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final kind in LayaQuestionKind.values)
                      DropdownMenuItem(value: kind, child: Text(kind.label)),
                  ],
                  onChanged: (kind) => setState(() {
                    _kind = kind ?? _kind;
                    _ensureRows();
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<LayaTemplate>(
                  isDense: true,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Plantilla',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final template in LayaTemplates.all)
                      DropdownMenuItem(
                        value: template,
                        child: Text(
                          template.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (template) {
                    if (template != null) {
                      setState(() => _load(template.draft));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _question,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Qué quieres saber',
              hintText: 'Is this task blocked by something external?',
              border: OutlineInputBorder(),
            ),
          ),
          if (_kind == LayaQuestionKind.choice) ...[
            _FormHead(
              'Opciones',
              hint: 'Laya compara la evidencia contra la descripción',
            ),
            for (final (index, row) in _options.indexed)
              _PairRow(
                first: row.first,
                second: row.second,
                firstLabel: 'option',
                secondLabel: 'description',
                onRemove: _options.length > 2
                    ? () => setState(() => _options.removeAt(index).dispose())
                    : null,
              ),
            _AddButton(
              label: 'Agregar opción',
              onPressed: () => setState(() => _options.add(_Pair('', ''))),
            ),
          ],
          if (_kind == LayaQuestionKind.score) ...[
            _FormHead(
              'Niveles, de menor a mayor',
              hint: 'Las escalas fueron poco fiables en las pruebas',
              warn: true,
            ),
            for (final (index, level) in _levels.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text('${index + 1}', style: text.bodySmall),
                    ),
                    Expanded(
                      child: TextField(
                        controller: level,
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'level description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    _RemoveButton(
                      onPressed: _levels.length > 2
                          ? () => setState(
                              () => _levels.removeAt(index).dispose(),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            _AddButton(
              label: 'Agregar nivel',
              onPressed: () =>
                  setState(() => _levels.add(TextEditingController())),
            ),
          ],
          _FormHead(
            'Evidencia',
            hint: 'Lo que Laya mira, con nombre: un log, un diff, fechas…',
          ),
          for (final (index, row) in _evidence.indexed)
            _PairRow(
              first: row.first,
              second: row.second,
              firstLabel: 'name',
              secondLabel: 'value',
              multiline: true,
              onRemove: _evidence.length > 1
                  ? () => setState(() => _evidence.removeAt(index).dispose())
                  : null,
            ),
          _AddButton(
            label: 'Agregar dato',
            onPressed: () => setState(() => _evidence.add(_Pair('', ''))),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _error ?? '',
                  style: text.bodySmall?.copyWith(color: scheme.error),
                ),
              ),
              if (widget.onSaveForm case final save?)
                TextButton.icon(
                  onPressed: () => setState(() => _error = save(_draft)),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                  label: const Text('Guardar como formulario'),
                ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: widget.asking ? null : _send,
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Preguntar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormHead extends StatelessWidget {
  const _FormHead(this.label, {required this.hint, this.warn = false});

  final String label;
  final String hint;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: label, style: text.labelLarge),
            TextSpan(
              text: '  $hint',
              style: text.bodySmall?.copyWith(
                color: warn ? scheme.error : scheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una fila de nombre y valor (una opción o un dato de la evidencia).
class _PairRow extends StatelessWidget {
  const _PairRow({
    required this.first,
    required this.second,
    required this.firstLabel,
    required this.secondLabel,
    this.multiline = false,
    this.onRemove,
  });

  final TextEditingController first;
  final TextEditingController second;
  final String firstLabel;
  final String secondLabel;
  final bool multiline;

  /// Null cuando no se puede quitar: es la mínima que hace falta.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: TextField(
              controller: first,
              decoration: InputDecoration(
                isDense: true,
                hintText: firstLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: second,
              minLines: 1,
              maxLines: multiline ? 5 : 2,
              decoration: InputDecoration(
                isDense: true,
                hintText: secondLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          _RemoveButton(onPressed: onRemove),
        ],
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Quitar',
      icon: const Icon(Icons.remove_circle_outline, size: 16),
      constraints: const BoxConstraints.tightFor(width: 30, height: 36),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add, size: 15),
        label: Text(label),
      ),
    );
  }
}
