import 'package:keel_core/integrations/plan_usage/plan_usage.dart';

/// Las cuentas de Claude, Codex y OpenRouter de esta máquina, cuánto lleva
/// gastado cada una y con cuál corre los turnos cada proveedor.
class PlanAccountsState {
  const PlanAccountsState({
    this.usage = const [],
    this.active = const {},
    this.loaded = false,
    this.busyAccount,
    this.notice = '',
    this.collapsed = const {},
  });

  /// Una entrada por cuenta, agrupadas por proveedor en el orden de
  /// [PlanProvider]. Una cuenta que falla trae su motivo adentro.
  final List<PlanUsage> usage;

  /// La cuenta con la que corre los turnos cada proveedor, por nombre. Un
  /// proveedor que no figura usa la suya por defecto.
  final Map<PlanProvider, String> active;

  /// Si ya hubo una primera lectura.
  final bool loaded;

  /// `proveedor/nombre` de la cuenta con una acción en curso.
  final String? busyAccount;

  /// El resultado de la última acción, para quien la pidió.
  final String notice;

  /// Los proveedores plegados en el riel: ahí muestran solo la cuenta en
  /// uso. Desplegado, que es lo normal, se ven todas.
  final Set<PlanProvider> collapsed;

  bool isActive(PlanAccount account) =>
      account.provider.hasAccounts &&
      (active[account.provider] ?? PlanAccount.defaultName) == account.name;

  bool isBusy(PlanAccount account) =>
      busyAccount == '${account.provider.name}/${account.name}';

  /// Las cuentas de [provider], o vacío si su CLI no está instalado.
  List<PlanUsage> accountsOf(PlanProvider provider) {
    final accounts = [
      for (final u in usage)
        if (u.account.provider == provider) u,
    ];
    final installed = accounts.any(
      (u) => u.problem != PlanUsageProblem.notInstalled,
    );
    return installed ? accounts : const [];
  }

  /// Lo que muestra el riel, por proveedor: todas sus cuentas, o solo la
  /// que está en uso si el proveedor está plegado. La en uso va primero.
  List<({PlanProvider provider, bool expanded, List<PlanUsage> accounts})>
  get rail => [
    for (final provider in PlanProvider.values)
      if (accountsOf(provider) case final accounts when accounts.isNotEmpty)
        (
          provider: provider,
          expanded: !collapsed.contains(provider),
          accounts: [
            ...accounts.where((u) => isActive(u.account)),
            if (!collapsed.contains(provider) || !provider.hasAccounts)
              ...accounts.where((u) => !isActive(u.account)),
          ],
        ),
  ];

  /// Si [provider] tiene más de una cuenta: solo entonces tiene algo que
  /// plegar en el riel.
  bool hasSeveral(PlanProvider provider) => accountsOf(provider).length > 1;

  PlanAccountsState copyWith({
    List<PlanUsage>? usage,
    Map<PlanProvider, String>? active,
    bool? loaded,
    String? busyAccount,
    bool clearBusy = false,
    String? notice,
    Set<PlanProvider>? collapsed,
  }) => PlanAccountsState(
    usage: usage ?? this.usage,
    active: active ?? this.active,
    loaded: loaded ?? this.loaded,
    busyAccount: clearBusy ? null : busyAccount ?? this.busyAccount,
    notice: notice ?? this.notice,
    collapsed: collapsed ?? this.collapsed,
  );

  Map<String, Object?> toJson() => {
    'usage': [for (final u in usage) u.toJson()],
    'active': {for (final e in active.entries) e.key.name: e.value},
    'loaded': loaded,
    'busyAccount': busyAccount,
    'notice': notice,
    'collapsed': [for (final provider in collapsed) provider.name],
  };

  factory PlanAccountsState.fromJson(Map<String, Object?> json) =>
      PlanAccountsState(
        usage: [
          for (final u in json['usage'] as List? ?? const [])
            PlanUsage.fromJson((u as Map).cast<String, Object?>()),
        ],
        active: {
          for (final MapEntry(:key, :value)
              in ((json['active'] as Map?) ?? const {}).entries)
            ?PlanProvider.values.asNameMap()[key]: '$value',
        },
        loaded: json['loaded'] as bool? ?? false,
        busyAccount: json['busyAccount'] as String?,
        notice: json['notice'] as String? ?? '',
        collapsed: {
          for (final name in json['collapsed'] as List? ?? const [])
            ?PlanProvider.values.asNameMap()['$name'],
        },
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlanAccountsState &&
          identical(usage, other.usage) &&
          identical(active, other.active) &&
          loaded == other.loaded &&
          busyAccount == other.busyAccount &&
          notice == other.notice &&
          identical(collapsed, other.collapsed);

  @override
  int get hashCode => Object.hash(
    usage.length,
    active.length,
    loaded,
    busyAccount,
    notice,
    collapsed.length,
  );

  @override
  String toString() =>
      'PlanAccountsState(${usage.length} accounts, loaded: $loaded)';
}
