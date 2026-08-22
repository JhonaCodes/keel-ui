import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/assistant/service/assistant_window_bridge.dart';
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
/// Conversaciones NO — ni las estaciones ni los agentes sueltos. Esa lista
/// vive en el sidebar, y estuvo un tiempo también acá: dos columnas pegadas
/// mostrando los mismos agentes, con dos formas distintas de seleccionarlos.
/// Acá quedó lo que se abre como panel y vuelve a cerrarse.
class AgentRail extends StatelessWidget {
  const AgentRail({
    super.key,
    required this.onOpenProfiles,
    required this.onOpenSkills,
    required this.onOpenRules,
    required this.onOpenTools,
    required this.onOpenSecrets,
    required this.onOpenMcpServers,
    required this.onOpenKnowledge,
    required this.onOpenWorkflows,
  });

  final VoidCallback onOpenProfiles;
  final VoidCallback onOpenSkills;
  final VoidCallback onOpenRules;
  final VoidCallback onOpenTools;
  final VoidCallback onOpenSecrets;
  final VoidCallback onOpenMcpServers;
  final VoidCallback onOpenKnowledge;
  final VoidCallback onOpenWorkflows;

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
                      label: 'Tools',
                      icon: Icons.terminal_outlined,
                      onPressed: onOpenTools,
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
            _RailButton(
              label: 'Ajustes',
              icon: Icons.settings_outlined,
              tooltip: 'Configuración',
              onPressed: () => openSettingsPanel(context),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
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
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurfaceVariant;

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
              const SizedBox(height: 3),
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
