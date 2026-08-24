import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/assistant/service/assistant_window_bridge.dart';
import 'package:keel_ui/src/integrations/app_update/app_update.dart';
import 'package:keel_ui/src/integrations/fault_journal/fault_journal.dart';
import 'package:keel_ui/src/integrations/system_vault/system_vault.dart';
import 'package:keel_ui/src/modules/settings/ui/widget/settings_panel.dart';

/// Ancho de la columna. Sale del texto más largo que tiene que entrar con
/// [_railLabelStyle], no al revés: el rail es lo más angosto que puede ser sin
/// cortar un nombre.
const _railWidth = 70.0;

/// La letra del rail es chica a propósito. Es lo que permite que el nombre
/// entre entero en 70 puntos: con la fuente por defecto haría falta casi el
/// doble de ancho para lo mismo, y el rail se comería el chat.
const _railLabelStyle = TextStyle(
  fontSize: 9,
  height: 1.2,
  fontWeight: FontWeight.w500,
);

/// La columna de la izquierda: el asistente y los registros de la app.
///
/// Conversaciones NO — ni los proyectos ni los agentes sueltos. Esa lista
/// vive en el sidebar, y estuvo un tiempo también acá: dos columnas pegadas
/// mostrando los mismos agentes, con dos formas distintas de seleccionarlos.
/// Acá quedó lo que se abre como panel y vuelve a cerrarse.
class AgentRail extends StatelessWidget {
  const AgentRail({
    super.key,
    required this.onOpenProfiles,
    required this.onOpenSkills,
    required this.onOpenRules,
    required this.onOpenHooks,
    required this.onOpenTools,
    required this.onOpenSecrets,
    required this.onOpenMcpServers,
    required this.onOpenKnowledge,
    required this.onOpenWorkflows,
    required this.onOpenBoards,
    required this.onOpenMachine,
  });

  final VoidCallback onOpenProfiles;
  final VoidCallback onOpenSkills;
  final VoidCallback onOpenRules;
  final VoidCallback onOpenHooks;
  final VoidCallback onOpenTools;
  final VoidCallback onOpenSecrets;
  final VoidCallback onOpenMcpServers;
  final VoidCallback onOpenKnowledge;
  final VoidCallback onOpenWorkflows;
  final VoidCallback onOpenBoards;
  final VoidCallback onOpenMachine;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: _railWidth,
        // Alto completo, o el Row de afuera centra la columna entera y los
        // botones flotan en el medio de la ventana en vez de arrancar arriba.
        height: double.infinity,
        child: Column(
          children: [
            // Lo que scrollea cuando la ventana es baja. Ajustes queda fuera,
            // anclado abajo: es lo único que uno busca por su posición y no
            // por su nombre.
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    // Keel AI arriba de todo: es lo primero que se abre en una
                    // sesión y lo que se usa para arreglar todo lo demás.
                    _RailButton(
                      label: 'Keel AI',
                      icon: Icons.auto_awesome,
                      tooltip: 'Asistente Keel AI',
                      onPressed: () => AssistantWindowBridge.instance.open(),
                    ),
                    const SizedBox(height: 12),
                    // Orden por uso real, no por jerarquía del modelo. Arriba lo que
                    // se abre todos los días; abajo lo que se configura una vez y se
                    // deja quieto. El hueco del medio marca el corte entre los dos
                    // grupos sin gastar una línea más.
                    _RailButton(
                      label: 'Agentes',
                      icon: Icons.badge_outlined,
                      tooltip: 'Agentes registrados',
                      onPressed: onOpenProfiles,
                    ),
                    _RailButton(
                      label: 'Skills',
                      icon: Icons.extension_outlined,
                      onPressed: onOpenSkills,
                    ),
                    _RailButton(
                      label: 'Workflows',
                      icon: Icons.account_tree_outlined,
                      onPressed: onOpenWorkflows,
                    ),
                    _RailButton(
                      label: 'Reglas',
                      icon: Icons.rule_outlined,
                      onPressed: onOpenRules,
                    ),
                    const SizedBox(height: 12),
                    _RailButton(
                      label: 'Hooks',
                      icon: Icons.gpp_maybe_outlined,
                      tooltip: 'Guardarraíles que corren solos',
                      onPressed: onOpenHooks,
                    ),
                    _RailButton(
                      label: 'Tools',
                      icon: Icons.terminal_outlined,
                      onPressed: onOpenTools,
                    ),
                    _RailButton(
                      label: 'Banco',
                      icon: Icons.tune,
                      tooltip: 'Tableros de prueba',
                      onPressed: onOpenBoards,
                    ),
                    _RailButton(
                      label: 'MCP',
                      icon: Icons.hub_outlined,
                      tooltip: 'Integraciones MCP',
                      onPressed: onOpenMcpServers,
                    ),
                    _RailButton(
                      label: 'Saber',
                      icon: Icons.menu_book_outlined,
                      tooltip: 'Conocimiento',
                      onPressed: onOpenKnowledge,
                    ),
                    _RailButton(
                      label: 'Secrets',
                      icon: Icons.key_outlined,
                      onPressed: onOpenSecrets,
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 4),
            // Con Respaldo y Ajustes: son las que hablan de la app y no del
            // trabajo. Fallas arriba de todas ellas porque es la única que
            // se mira porque se prendió, no porque la fuiste a buscar.
            //
            // Solo en debug: en una compilación instalada, un stack de Dart no
            // le dice nada a quien la usa y un punto rojo permanente solo
            // asusta. Ahí las fallas se siguen anotando igual y salen por el
            // canal de reportes, que es donde alguien puede hacer algo con
            // ellas. Ver `reportToDiscord`.
            if (kDebugMode) const _FaultsRailButton(),
            _MachineRailButton(onPressed: onOpenMachine),
            _VaultRailButton(onPressed: () => openSettingsPanel(context)),
            _RailButton(
              label: 'Ajustes',
              icon: Icons.settings_outlined,
              tooltip: 'Configuración',
              onPressed: () => openSettingsPanel(context),
            ),
            const _InstalledVersionRailButton(),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

/// Versión del bundle abierto y punto de descarga cuando hay una posterior.
///
/// Vive debajo de Ajustes porque describe esta copia de la app, no la máquina
/// ni el proyecto seleccionado.
class _InstalledVersionRailButton extends StatelessWidget {
  const _InstalledVersionRailButton();

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<AppUpdateViewModel, AppUpdateState>(
      viewmodel: AppUpdateService.instance.notifier,
      build: (state, viewmodel, keep) {
        final release = state.release;
        final available = release.updateAvailable;
        final scheme = Theme.of(context).colorScheme;
        final current = release.current;
        final latest = release.latest;
        final tooltip = available && latest != null
            ? 'Nueva versión ${latest.release.buildName} disponible. '
                  'Clic para descargar.'
            : release.error ??
                  (current == null
                      ? 'Leyendo la versión instalada'
                      : 'Keel ${current.pubspecValue}. Clic para revisar.');

        return Tooltip(
          message: tooltip,
          waitDuration: const Duration(milliseconds: 500),
          child: InkWell(
            onTap: state.checking
                ? null
                : available
                ? viewmodel.downloadLatest
                : () => viewmodel.check(force: true),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              child: SizedBox(
                width: _railWidth - 12,
                child: Row(
                  children: [
                    if (available) ...[
                      Icon(
                        Icons.download_outlined,
                        size: 9,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 2),
                    ],
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'v${release.displayVersion}',
                          key: const Key('keel-app-version'),
                          maxLines: 1,
                          style: _railLabelStyle.copyWith(
                            fontFamily: 'monospace',
                            color: available ? scheme.primary : scheme.outline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Un registro del rail: icono con su nombre debajo.
///
/// Con tooltip solo, saber a dónde lleva cada uno de los diez iconos obliga
/// a pasar el mouse por todos. El nombre escrito lo resuelve de una mirada;
/// el tooltip queda para el nombre largo cuando [tooltip] difiere del
/// [label] corto que entra en el ancho del rail.
class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  /// Que ESTE botón esté haciendo algo. Se dice acá y no atenuando la app:
  /// el aviso vive donde vive la cosa que está trabajando.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = busy ? scheme.primary : scheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip ?? label,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            children: [
              Icon(icon, size: 20, color: foreground),
              // La barrita ocupa el hueco que ya había entre el icono y la
              // etiqueta: aparece y desaparece sin mover un píxel del riel.
              SizedBox(
                height: 3,
                width: 26,
                child: busy
                    ? const LinearProgressIndicator(minHeight: 2)
                    : null,
              ),
              Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: _railLabelStyle.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lo que se rompió, con cuántas no miraste.
///
/// Es el único registro del rail que se abre porque se prendió y no porque
/// lo fuiste a buscar: sin el número, una falla de las tres de la mañana se
/// entera el que tenga la consola abierta, o sea nadie.
class _FaultsRailButton extends StatelessWidget {
  const _FaultsRailButton();

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<FaultJournalViewModel, FaultJournalState>(
      viewmodel: FaultJournalService.instance.notifier,
      build: (state, viewmodel, keep) {
        final scheme = Theme.of(context).colorScheme;
        return Stack(
          alignment: Alignment.topRight,
          children: [
            _RailButton(
              label: 'Fallas',
              icon: Icons.report_gmailerrorred_outlined,
              tooltip: switch (state.unseen) {
                0 => 'Lo que se rompió — nada sin ver',
                1 => 'Una falla sin ver',
                final count => '$count fallas sin ver',
              },
              onPressed: () => openFaultsPanel(context),
            ),
            if (state.unseen > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.error,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    state.unseen > 9 ? '9+' : '${state.unseen}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: scheme.onError,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// La máquina, con un punto cuando hay una versión nueva de Keel.
///
/// El aviso vive acá y no en un cartel aparte porque la respuesta también:
/// la sección Keel de esa pantalla es la que trae los commits y la que
/// reconstruye.
class _MachineRailButton extends StatelessWidget {
  const _MachineRailButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<AppUpdateViewModel, AppUpdateState>(
      viewmodel: AppUpdateService.instance.notifier,
      build: (state, viewmodel, keep) {
        return Stack(
          alignment: Alignment.topRight,
          children: [
            _RailButton(
              label: 'Máquina',
              icon: Icons.memory_outlined,
              tooltip: state.pending
                  ? 'Hay una versión nueva de Keel'
                  : 'Servicios, consumo y estado de la máquina',
              onPressed: onPressed,
            ),
            if (state.pending)
              Positioned(
                right: 6,
                top: 4,
                child: _Dot(color: Theme.of(context).colorScheme.primary),
              ),
          ],
        );
      },
    );
  }
}

/// El punto de aviso de un registro del rail.
class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// El estado del respaldo, siempre a la vista.
///
/// El respaldo automático commitea local pero NO sube: sin este punto, "ya
/// está guardado" y "está guardado en un lugar que sobrevive a esta
/// máquina" se ven exactamente igual. El punto naranja es la diferencia.
class _VaultRailButton extends StatelessWidget {
  const _VaultRailButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<SystemVaultViewModel, SystemVaultState>(
      viewmodel: SystemVaultService.instance.notifier,
      build: (vault, viewmodel, keep) {
        final warning = vault.warning;
        return Stack(
          alignment: Alignment.topRight,
          children: [
            _RailButton(
              label: vault.busy ? 'Respaldando' : 'Respaldo',
              icon: Icons.backup_outlined,
              busy: vault.busy,
              tooltip: vault.busy
                  ? 'Escribiendo el respaldo, sin frenarte'
                  : (warning ?? 'Respaldo al día y subido al remoto'),
              onPressed: onPressed,
            ),
            // Mientras corre no se muestra: el aviso habla del estado
            // ANTERIOR y todavía no se recalculó.
            if (warning != null && !vault.busy)
              Positioned(
                right: 6,
                top: 4,
                child: _Dot(color: Theme.of(context).colorScheme.error),
              ),
          ],
        );
      },
    );
  }
}
