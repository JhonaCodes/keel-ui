import 'package:flutter/material.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/integrations/llm/openai_compatible/remote_model_catalog.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/model/effort_level.dart';
import 'package:keel_ui/src/modules/projects/model/member_tuning.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/secrets/ui/widget/provider_credential_card.dart';

/// Abre el panel para elegir con qué motor corre [member] en [project].
Future<void> openMemberEnginePanel(
  BuildContext context, {
  required Project project,
  required AgentProfile member,
}) {
  return showFormPanel<void>(
    context,
    width: 460,
    child: MemberEnginePanel(project: project, member: member),
  );
}

/// Proveedor, modelo y esfuerzo de un miembro **en este proyecto**.
///
/// El agente está registrado una sola vez y se reusa en todos lados, así que
/// cambiarle el modelo en su ficha lo cambia en todas partes. Casi nunca es
/// lo que uno quiere: lo que cambia entre proyectos es cuánto vale un turno
/// ahí. Por eso esto no toca el perfil — escribe un ajuste que vive en la
/// proyecto y desaparece con ella.
class MemberEnginePanel extends StatefulWidget {
  const MemberEnginePanel({
    super.key,
    required this.project,
    required this.member,
    this.catalog,
  });

  final Project project;
  final AgentProfile member;
  final RemoteModelCatalog? catalog;

  @override
  State<MemberEnginePanel> createState() => _MemberEnginePanelState();
}

class _MemberEnginePanelState extends State<MemberEnginePanel> {
  late final RemoteModelCatalog _catalog =
      widget.catalog ?? RemoteModelCatalog();
  late MemberTuning _tuning =
      widget.project.memberTuning[widget.member.id] ?? const MemberTuning();
  late final TextEditingController _manualModel = TextEditingController(
    text: _tuning.model ?? '',
  );
  late Future<List<AgentModelOption>> _models = _catalog.load(_provider);

  /// El proveedor que va a correr con lo elegido hasta ahora — de él dependen
  /// los modelos que se ofrecen y si el esfuerzo aplica.
  AgentProvider get _provider => _tuning.provider ?? widget.member.provider;

  /// Cómo queda el turno con lo elegido: la única línea que importa leer.
  AgentProfile get _preview => _tuning.applyTo(widget.member);

  @override
  void dispose() {
    _manualModel.dispose();
    super.dispose();
  }

  void _changeProvider(AgentProvider? value) {
    setState(() {
      _tuning = MemberTuning(provider: value, effort: _tuning.effort);
      _manualModel.clear();
      _models = _catalog.load(_provider);
    });
  }

  void _refreshModels() {
    _catalog.clear(_provider);
    setState(() => _models = _catalog.load(_provider));
  }

  void _setModel(String? value) {
    _manualModel.text = value ?? '';
    _storeModel(value);
  }

  void _storeModel(String? value) {
    setState(() {
      _tuning = MemberTuning(
        provider: _tuning.provider,
        model: value,
        effort: _tuning.effort,
      );
    });
  }

  void _save() {
    ProjectsService.instance.notifier.setMemberTuning(
      widget.project.id,
      widget.member.id,
      provider: _tuning.provider,
      model: _tuning.model,
      effort: _tuning.effort,
    );
    Navigator.of(context).pop();
  }

  void _reset() {
    ProjectsService.instance.notifier.clearMemberTuning(
      widget.project.id,
      widget.member.id,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final member = widget.member;
    final preview = _preview;
    final isCodex = _provider == AgentProvider.codex;

    return Scaffold(
      appBar: AppBar(title: Text('Motor de @${member.name}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            'Vale solo en #${widget.project.name}. En su ficha, @${member.name} '
            'sigue siendo ${modelLabelFor(member.provider, member.model)} · '
            '${effortLabel(member.effort)}, y así corre en las demás '
            'proyectos y en los chats 1:1.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<AgentProvider?>(
            initialValue: _tuning.provider,
            decoration: const InputDecoration(
              labelText: 'Proveedor',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text('El del agente (${member.provider.label})'),
              ),
              for (final provider in AgentProvider.values)
                DropdownMenuItem(value: provider, child: Text(provider.label)),
            ],
            // Las dos CLIs no comparten un solo nombre de modelo, así que al
            // cambiar de proveedor el modelo elegido deja de existir: se
            // suelta y vuelve a resolverse por defecto.
            onChanged: _changeProvider,
          ),
          const SizedBox(height: 16),
          _RemoteModelField(
            provider: _provider,
            member: member,
            selected: _tuning.model,
            models: _models,
            onChanged: _setModel,
            onRefresh: _refreshModels,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _manualModel,
            onChanged: (value) =>
                _storeModel(value.trim().isEmpty ? null : value.trim()),
            decoration: const InputDecoration(
              labelText: 'ID exacto del modelo',
              helperText:
                  'Úsalo si tu cuenta ve un modelo que todavía no aparece en el catálogo.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ),
          if (_provider.requiresApiKey) ...[
            const SizedBox(height: 10),
            ProviderCredentialCard(provider: _provider, compact: true),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: isCodex ? null : _tuning.effort,
            decoration: InputDecoration(
              labelText: 'Esfuerzo',
              helperText: isCodex
                  ? 'Codex no recibe niveles de esfuerzo: los resuelve su '
                        'propia config.'
                  : 'Cuánto piensa antes de responder. Sube el costo del '
                        'turno, no solo su calidad.',
              helperMaxLines: 3,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text('El del agente (${effortLabel(member.effort)})'),
              ),
              for (final level in kEffortLevels)
                DropdownMenuItem(value: level.alias, child: Text(level.label)),
            ],
            onChanged: isCodex
                ? null
                : (value) => setState(() {
                    _tuning = MemberTuning(
                      provider: _tuning.provider,
                      model: _tuning.model,
                      effort: value,
                    );
                  }),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.play_arrow, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Acá corre en '
                    '${modelLabelFor(preview.provider, preview.model)}'
                    '${preview.provider == AgentProvider.codex ? '' : ' · ${effortLabel(preview.effort)}'}'
                    ' (${preview.provider.label}).',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Guardar'),
                ),
              ),
              if (widget.project.memberTuning.containsKey(member.id)) ...[
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _reset,
                  child: const Text('Volver al del agente'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'El cambio entra en el próximo turno: el que ya está corriendo '
            'termina con el motor que arrancó.',
            style: TextStyle(fontSize: 11, color: scheme.outline),
          ),
        ],
      ),
    );
  }
}

class _RemoteModelField extends StatelessWidget {
  const _RemoteModelField({
    required this.provider,
    required this.member,
    required this.selected,
    required this.models,
    required this.onChanged,
    required this.onRefresh,
  });

  final AgentProvider provider;
  final AgentProfile member;
  final String? selected;
  final Future<List<AgentModelOption>> models;
  final ValueChanged<String?> onChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return FutureBuilder<List<AgentModelOption>>(
      future: models,
      builder: (context, snapshot) {
        final options = <String, AgentModelOption>{
          for (final option in modelOptionsFor(provider)) option.alias: option,
          for (final option in snapshot.data ?? const <AgentModelOption>[])
            option.alias: option,
          // ignore: use_null_aware_elements
          if (selected != null)
            selected!: AgentModelOption(alias: selected!, label: selected!),
        }.values.toList();
        return DropdownButtonFormField<String?>(
          key: ValueKey((provider, selected, snapshot.connectionState)),
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: t.labelModelWithProvider(provider.label),
            suffixIcon: IconButton(
              tooltip: t.tooltipRefreshCatalog,
              onPressed: onRefresh,
              icon: snapshot.connectionState == ConnectionState.waiting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 18),
            ),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(
                provider == member.provider
                    ? 'El del agente '
                          '(${modelLabelFor(member.provider, member.model)})'
                    : 'Default de ${provider.label} '
                          '(${modelLabelFor(provider, defaultModelFor(provider))})',
              ),
            ),
            for (final option in options)
              DropdownMenuItem(
                value: option.alias,
                child: Text(option.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}
