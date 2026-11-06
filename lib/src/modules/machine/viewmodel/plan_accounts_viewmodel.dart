import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/integrations/plan_usage/plan_usage.dart';
import 'package:keel_core/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/core/services/terminal_launcher.dart';
import 'package:keel_ui/src/integrations/llm/llm_keel_ui_wiring.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/model_catalog_viewmodel.dart';
import 'package:keel_ui/src/modules/machine/model/plan_accounts_state.dart';

/// Las cuentas de Claude, Codex y OpenRouter: cuánto gastó cada una, con
/// cuál corre los turnos cada proveedor, y el alta, el inicio y el cierre
/// de sesión de cada una.
///
/// Corre siempre, no solo con Máquina abierta: el riel muestra el consumo
/// de las cuentas en uso todo el tiempo.
class PlanAccountsViewModel extends ViewModel<PlanAccountsState> {
  PlanAccountsViewModel() : super(const PlanAccountsState());

  /// Cada lectura arranca un CLI por cuenta (un segundo, sin gastar turno)
  /// y dos pedidos a OpenRouter. El porcentaje no se mueve más rápido.
  static const _tick = Duration(minutes: 2);

  /// Mientras una cuenta inicia sesión en la Terminal se mira seguido, y se
  /// deja de mirar a los cinco minutos: un login que tarda más quedó
  /// abandonado.
  static const _loginPoll = Duration(seconds: 5);
  static const _loginWindow = Duration(minutes: 5);

  Timer? _timer;
  Timer? _loginTimer;
  bool _reading = false;

  @override
  void init() {
    updateSilently(const PlanAccountsState());
    unawaited(refresh());
    _timer = Timer.periodic(_tick, (_) => unawaited(refresh()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _loginTimer?.cancel();
    super.dispose();
  }

  /// Relee todas las cuentas, en paralelo, y cuál está en uso.
  Future<void> refresh() async {
    if (_reading) return;
    _reading = true;
    try {
      final (usage, active) = await (
        readAllPlanUsage(resolveSecret: resolveLlmSecret),
        readActivePlanAccounts(),
      ).wait;
      updateState(data.copyWith(usage: usage, active: active, loaded: true));
    } catch (error) {
      Log.w('No pude leer el consumo de las cuentas: $error');
    } finally {
      _reading = false;
    }
  }

  /// Pliega o despliega [provider] en el riel.
  void toggleRail(PlanProvider provider) {
    final collapsed = {...data.collapsed};
    if (!collapsed.remove(provider)) collapsed.add(provider);
    updateState(data.copyWith(collapsed: collapsed));
  }

  /// Los turnos de su proveedor pasan a correr con [account]. La lista de
  /// modelos de Codex depende de la cuenta, así que se vuelve a pedir.
  Future<void> use(PlanAccount account) async {
    await _busy(account, () => setActivePlanAccount(account));
    if (account.provider == PlanProvider.codex) {
      unawaited(
        ModelCatalogService.instance.notifier.load(
          AgentProvider.codex,
          force: true,
        ),
      );
    }
    updateState(
      data.copyWith(
        notice:
            '${account.provider.label} corre ahora con «${account.name}». '
            'Aplica desde el próximo turno.',
      ),
    );
  }

  /// Crea `~/.<cli>-<nombre>` con la configuración compartida y abre la
  /// Terminal para iniciarle sesión. Devuelve el motivo si no se pudo.
  Future<String?> addAccount(PlanProvider provider, String rawName) async {
    final name = rawName.trim().toLowerCase();
    if (!isValidPlanAccountName(name)) {
      return 'Usa minúsculas, números y guiones (máximo 24), sin «default».';
    }
    if (data.accountsOf(provider).any((u) => u.account.name == name)) {
      return 'Ya hay una cuenta «$name» de ${provider.label}.';
    }
    try {
      final account = await createPlanAccount(provider, name);
      await refresh();
      await signIn(account);
      return null;
    } catch (error) {
      Log.e('No pude crear la cuenta $name de ${provider.label}', error: error);
      return 'No se pudo crear la carpeta de la cuenta: $error';
    }
  }

  /// Abre la Terminal con el login oficial del CLI para [account]: abre el
  /// navegador y espera. Al terminar, la cuenta se actualiza sola.
  Future<void> signIn(PlanAccount account) async {
    final command = planLoginCommand(account);
    final opened = await openInTerminal(command);
    updateState(
      data.copyWith(
        notice: opened
            ? 'Inicia sesión de «${account.name}» en la Terminal y el navegador.'
            : 'No se pudo abrir la Terminal. Corre: $command',
      ),
    );
    if (opened) _watchLogin(account);
  }

  Future<void> signOut(PlanAccount account) async {
    await _busy(account, () => signOutPlanAccount(account));
  }

  /// Cierra la sesión y borra la carpeta de la cuenta. La de por defecto no
  /// se quita; si era la cuenta en uso, el proveedor vuelve a la suya.
  Future<void> remove(PlanAccount account) async {
    if (account.isDefault) return;
    await _busy(account, () => removePlanAccount(account));
  }

  Future<void> _busy(
    PlanAccount account,
    Future<void> Function() action,
  ) async {
    updateState(
      data.copyWith(busyAccount: '${account.provider.name}/${account.name}'),
    );
    try {
      await action();
    } catch (error) {
      Log.e('Falló la acción sobre la cuenta ${account.name}', error: error);
      updateState(data.copyWith(notice: 'No se pudo: $error'));
    } finally {
      updateState(data.copyWith(clearBusy: true));
      await refresh();
    }
  }

  void _watchLogin(PlanAccount account) {
    _loginTimer?.cancel();
    final until = DateTime.now().add(_loginWindow);
    _loginTimer = Timer.periodic(_loginPoll, (timer) async {
      await refresh();
      final signedIn = data.usage.any((u) => u.account == account && u.ok);
      if (signedIn || DateTime.now().isAfter(until)) {
        timer.cancel();
        if (signedIn) {
          updateState(
            data.copyWith(notice: '«${account.name}» quedó con sesión.'),
          );
        }
      }
    });
  }
}

mixin PlanAccountsService {
  static final ReactiveNotifier<PlanAccountsViewModel> instance =
      ReactiveNotifier<PlanAccountsViewModel>(() => PlanAccountsViewModel());
}
