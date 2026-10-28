import 'package:flutter_test/flutter_test.dart';

import 'package:keel_core/integrations/plan_usage/plan_usage.dart';
import 'package:keel_ui/src/modules/machine/model/plan_accounts_state.dart';

/// En el riel todos los proveedores se pliegan igual: contraído queda solo
/// el nombre, expandido se ven todas sus cuentas con la en uso primero. Tenga
/// una cuenta o varias.
void main() {
  PlanUsage usage(PlanProvider provider, String name) => PlanUsage(
    account: PlanAccount(provider: provider, name: name),
    meters: const [PlanMeter(kind: PlanMeterKind.weekly, percent: 10)],
  );

  final state = PlanAccountsState(
    usage: [
      usage(PlanProvider.claude, 'trabajo'),
      usage(PlanProvider.claude, PlanAccount.defaultName),
      usage(PlanProvider.openRouter, PlanAccount.defaultName),
      // Configurada pero sin sesión: no tiene consumo que mostrar.
      const PlanUsage(
        account: PlanAccount(provider: PlanProvider.claude, name: 'sin-sesion'),
        error: 'not signed in',
        problem: PlanUsageProblem.notSignedIn,
      ),
      // Codex con su única cuenta sin sesión: el proveedor no aparece.
      const PlanUsage(
        account: PlanAccount(provider: PlanProvider.codex, name: 'personal'),
        error: 'not signed in',
        problem: PlanUsageProblem.notSignedIn,
      ),
    ],
  );

  List<String> accountsOf(PlanAccountsState state, PlanProvider provider) => [
    for (final group in state.rail)
      if (group.provider == provider)
        for (final account in group.accounts) account.account.name,
  ];

  test('a collapsed provider shows only its name, whatever it has', () {
    final collapsed = state.copyWith(collapsed: PlanProvider.values.toSet());

    expect(collapsed.rail.map((group) => group.expanded), everyElement(false));
    for (final provider in PlanProvider.values) {
      expect(accountsOf(collapsed, provider), isEmpty, reason: '$provider');
    }
  });

  test('an expanded provider shows every account, the one in use first', () {
    expect(state.rail.map((group) => group.expanded), everyElement(true));
    expect(accountsOf(state, PlanProvider.claude), [
      PlanAccount.defaultName,
      'trabajo',
    ]);
    expect(accountsOf(state, PlanProvider.openRouter), [
      PlanAccount.defaultName,
    ]);
  });

  test('the rail leaves out accounts with nothing to show', () {
    expect(
      accountsOf(state, PlanProvider.claude),
      isNot(contains('sin-sesion')),
    );
    expect(
      state.rail.map((group) => group.provider),
      isNot(contains(PlanProvider.codex)),
    );
  });
}
