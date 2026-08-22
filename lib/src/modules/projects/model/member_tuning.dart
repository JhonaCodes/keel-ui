import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';

/// Con qué motor corre un miembro **en este proyecto**: proveedor, modelo y
/// esfuerzo.
///
/// El agente es global —una identidad registrada una vez y reusada en todos
/// lados— pero el costo de un turno es local: el mismo `@flutter-expert` puede
/// ir en Sonnet en un proyecto de mantenimiento y en Opus en la que está
/// rediseñando algo. Por eso esto vive en el proyecto y no en el perfil.
///
/// Cada campo en null significa "lo que diga el agente". Un ajuste con los
/// tres en null es lo mismo que no tener ajuste, y se borra al guardarlo.
class MemberTuning {
  final AgentProvider? provider;
  final String? model;
  final String? effort;

  const MemberTuning({this.provider, this.model, this.effort});

  bool get isEmpty => provider == null && model == null && effort == null;

  /// El perfil con el que se corre el turno acá.
  ///
  /// Cambiar de proveedor sin elegir modelo no puede arrastrar el alias del
  /// anterior: las dos CLIs no comparten un solo nombre de modelo, así que
  /// `sonnet` en codex es un fallo de arranque. En ese caso cae al modelo por
  /// defecto del proveedor nuevo.
  AgentProfile applyTo(AgentProfile member) {
    final resolvedProvider = provider ?? member.provider;
    final resolvedModel =
        model ??
        (resolvedProvider == member.provider
            ? member.model
            : defaultModelFor(resolvedProvider));

    return member.copyWith(
      provider: resolvedProvider,
      model: resolvedModel,
      effort: effort ?? member.effort,
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider?.alias,
    'model': model,
    'effort': effort,
  };

  factory MemberTuning.fromJson(Map<String, dynamic> json) {
    final providerAlias = json['provider'] as String?;
    return MemberTuning(
      provider: providerAlias == null
          ? null
          : AgentProvider.tryFromAlias(providerAlias),
      model: json['model'] as String?,
      effort: json['effort'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberTuning &&
          runtimeType == other.runtimeType &&
          provider == other.provider &&
          model == other.model &&
          effort == other.effort;

  @override
  int get hashCode => Object.hash(provider, model, effort);

  @override
  String toString() =>
      'MemberTuning(provider: ${provider?.alias}, model: $model, '
      'effort: $effort)';
}
