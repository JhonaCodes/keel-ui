import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/model/effort_level.dart';
import 'package:keel_ui/src/modules/stations/model/member_tuning.dart';
import 'package:keel_ui/src/modules/stations/model/station.dart';
import 'package:keel_ui/src/modules/stations/viewmodel/stations_viewmodel.dart';

/// Abre el panel para elegir con qué motor corre [member] en [station].
Future<void> openMemberEnginePanel(
  BuildContext context, {
  required Station station,
  required AgentProfile member,
}) {
  return showFormPanel<void>(
    context,
    width: 460,
    child: MemberEnginePanel(station: station, member: member),
  );
}

/// Proveedor, modelo y esfuerzo de un miembro **en esta estación**.
///
/// El agente está registrado una sola vez y se reusa en todos lados, así que
/// cambiarle el modelo en su ficha lo cambia en todas partes. Casi nunca es
/// lo que uno quiere: lo que cambia entre estaciones es cuánto vale un turno
/// ahí. Por eso esto no toca el perfil — escribe un ajuste que vive en la
/// estación y desaparece con ella.
class MemberEnginePanel extends StatefulWidget {
  const MemberEnginePanel({
    super.key,
    required this.station,
    required this.member,
  });

  final Station station;
  final AgentProfile member;

  @override
  State<MemberEnginePanel> createState() => _MemberEnginePanelState();
}

class _MemberEnginePanelState extends State<MemberEnginePanel> {
  late MemberTuning _tuning =
      widget.station.memberTuning[widget.member.id] ?? const MemberTuning();

  /// El proveedor que va a correr con lo elegido hasta ahora — de él dependen
  /// los modelos que se ofrecen y si el esfuerzo aplica.
  AgentProvider get _provider => _tuning.provider ?? widget.member.provider;

  /// Cómo queda el turno con lo elegido: la única línea que importa leer.
  AgentProfile get _preview => _tuning.applyTo(widget.member);

  void _save() {
    StationsService.instance.notifier.setMemberTuning(
      widget.station.id,
      widget.member.id,
      provider: _tuning.provider,
      model: _tuning.model,
      effort: _tuning.effort,
    );
    Navigator.of(context).pop();
  }

  void _reset() {
    StationsService.instance.notifier.clearMemberTuning(
      widget.station.id,
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
            'Vale solo en #${widget.station.name}. En su ficha, @${member.name} '
            'sigue siendo ${modelLabelFor(member.provider, member.model)} · '
            '${effortLabel(member.effort)}, y así corre en las demás '
            'estaciones y en los chats 1:1.',
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
            onChanged: (value) => setState(() {
              _tuning = MemberTuning(provider: value, effort: _tuning.effort);
            }),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            key: ValueKey(_provider),
            initialValue: _tuning.model,
            decoration: InputDecoration(
              labelText: 'Modelo (${_provider.label})',
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(
                  _provider == member.provider
                      ? 'El del agente '
                            '(${modelLabelFor(member.provider, member.model)})'
                      : 'El de siempre de ${_provider.label} '
                            '(${modelLabelFor(_provider, defaultModelFor(_provider))})',
                ),
              ),
              for (final option in modelOptionsFor(_provider))
                DropdownMenuItem(
                  value: option.alias,
                  child: Text(option.label),
                ),
            ],
            onChanged: (value) => setState(() {
              _tuning = MemberTuning(
                provider: _tuning.provider,
                model: value,
                effort: _tuning.effort,
              );
            }),
          ),
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
              if (widget.station.memberTuning.containsKey(member.id)) ...[
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
