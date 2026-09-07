import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/integrations/project_radar/project_radar.dart';
import 'package:keel_ui/src/integrations/roadmap_mcp/roadmap_mcp.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/model/member_color.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/member_avatar.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/requirements/model/internal_requirement.dart';
import 'package:keel_ui/src/modules/requirements/viewmodel/requirements_viewmodel.dart';
import 'package:keel_ui/src/modules/roadmap/model/task_claim.dart';
import 'package:keel_ui/src/modules/roadmap/viewmodel/task_claims_viewmodel.dart';
import 'package:keel_ui/src/modules/workspace/viewmodel/workspace_viewmodel.dart';

/// Cada cuánto se vuelve a leer la carpeta como piso.
///
/// Los momentos en que los números se mueven de verdad —una toma nueva, un
/// turno que cierra— ya disparan un redibujo. Este intervalo existe para lo
/// que pasa AFUERA de la app: un `git pull`, otro agente marcando
/// `estado: hecho` desde otra máquina. Recorrer un directorio es barato;
/// mostrar una foto vieja no.
const _kRadarFloor = Duration(seconds: 15);

/// La sección fija de un proyecto: cómo va.
///
/// **Mira, no toca.** No hay un solo control acá adentro, y es una decisión:
/// para abrir una sesión está su fila en el sidebar, a diez píxeles. Una
/// pantalla que informa y además actúa termina siendo dos pantallas malas.
class ProjectStateView extends StatefulWidget {
  const ProjectStateView({super.key, required this.project});

  final Project project;

  @override
  State<ProjectStateView> createState() => _ProjectStateViewState();
}

class _ProjectStateViewState extends State<ProjectStateView> {
  List<RoadmapTask> _roadmap = const [];
  RoadmapFormatCheck? _check;
  DateTime _readAt = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _reload();
    _timer = Timer.periodic(_kRadarFloor, (_) => _reload());
  }

  @override
  void didUpdateWidget(ProjectStateView old) {
    super.didUpdateWidget(old);
    if (old.project.workingDirectory != widget.project.workingDirectory) {
      _reload();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reload() {
    final path = widget.project.workingDirectory;
    final check = checkRoadmapFormat(path);
    final roadmap = check.ok ? readRoadmap(path) : const <RoadmapTask>[];
    if (!mounted) return;
    setState(() {
      _check = check;
      _roadmap = roadmap;
      _readAt = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final check = _check;
    return ReactiveViewModelBuilder<TaskClaimsViewModel, RoadmapClaimsState>(
      viewmodel: TaskClaimsService.instance.notifier,
      build: (claimsState, viewmodel, keep) {
        final now = DateTime.now();
        final radar = buildProjectRadar(
          project: widget.project,
          roadmap: _roadmap,
          claims: claimsState.claims
              .where(
                (claim) =>
                    claim.projectPath.trim() ==
                    widget.project.workingDirectory.trim(),
              )
              .toList(),
          totalSteps: ProjectsService.instance.notifier.nodeCountFor(
            widget.project,
          ),
          now: now,
          hasRoadmap: check?.ok ?? false,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(project: widget.project, readAt: _readAt, radar: radar),
            const Divider(height: 1),
            Expanded(
              child: radar.hasRoadmap
                  ? _Radar(radar: radar, project: widget.project, now: now)
                  : _SinFormato(check: check, project: widget.project),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.project,
    required this.readAt,
    required this.radar,
  });

  final Project project;
  final DateTime readAt;
  final ProjectRadar radar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final leido = DateTime.now().difference(readAt).inSeconds;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '#',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(project.name, style: text.titleMedium),
                    if (!project.maintained) ...[
                      const SizedBox(width: 8),
                      _Chip(
                        label: 'no lo mantengo',
                        icon: Icons.lock_outline,
                        muted: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (project.workingDirectory.isNotEmpty)
                      project.workingDirectory,
                    '${project.profileIds.length} agentes',
                    if (radar.hasRoadmap)
                      leido < 2
                          ? 'TASKS/ recién leído'
                          : 'TASKS/ leído hace $leido s',
                  ].join(' · '),
                  style: text.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _Facepile(project: project),
        ],
      ),
    );
  }
}

class _Facepile extends StatelessWidget {
  const _Facepile({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final profiles = AgentProfilesService.instance.notifier.data.profiles;
    final members = [
      for (final id in project.profileIds)
        profiles.where((profile) => profile.id == id).firstOrNull,
    ].nonNulls.toList();
    if (members.isEmpty) return const SizedBox.shrink();

    // Cinco caras y el resto contado, igual que la cabecera del canal: con
    // ocho miembros la pila se comía el ancho del encabezado.
    final shown = members.take(5).toList();
    final rest = members.length - shown.length;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown.length; i++)
          Transform.translate(
            offset: Offset(-7.0 * i, 0),
            child: Tooltip(
              message: '@${shown[i].name} · ${shown[i].role}',
              child: MemberAvatar(color: memberColorFor(i), size: 24),
            ),
          ),
        Transform.translate(
          offset: Offset(-7.0 * (shown.length - 1), 0),
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              rest > 0 ? '+$rest  ${members.length}' : '${members.length}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: scheme.outline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Un rótulo chico. Los estados del radar se leen de un vistazo o no se leen.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    this.icon,
    this.muted = false,
    this.good = false,
  });

  final String label;
  final IconData? icon;
  final bool muted;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch ((muted, good)) {
      (true, _) => (scheme.surfaceContainerLow, scheme.outline),
      (_, true) => (scheme.tertiary.withValues(alpha: 0.16), scheme.tertiary),
      _ => (scheme.secondaryContainer, scheme.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: muted ? Border.all(color: scheme.outlineVariant) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: fg),
          ),
        ],
      ),
    );
  }
}

/// El encabezado de un bloque del radar: rótulo y una línea que lo separa.
class _SectionHead extends StatelessWidget {
  const _SectionHead(this.label, {this.first = false});

  final String label;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 22, bottom: 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              letterSpacing: 1.2,
              color: scheme.outline,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(height: 1, color: scheme.outlineVariant)),
        ],
      ),
    );
  }
}

/// El radar propiamente dicho: cinco bloques, ninguno interactivo.
class _Radar extends StatelessWidget {
  const _Radar({required this.radar, required this.project, required this.now});

  final ProjectRadar radar;
  final Project project;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHead('Cumplimiento', first: true),
          _Cumplimiento(radar: radar),
          if (radar.inProgress.isNotEmpty) ...[
            const _SectionHead('En curso ahora'),
            _EnCurso(radar: radar, project: project, now: now),
          ],
          if (radar.sessions.isNotEmpty) ...[
            const _SectionHead('Sesiones en el radar'),
            _Sesiones(radar: radar),
          ],
          if (radar.stuck.isNotEmpty) ...[
            const _SectionHead('Trabado'),
            _Trabado(radar: radar),
          ],
          const _SectionHead('Requerimientos'),
          _Requerimientos(project: project),
        ],
      ),
    );
  }
}

class _Cumplimiento extends StatelessWidget {
  const _Cumplimiento({required this.radar});

  final ProjectRadar radar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = radar.total;
    double share(int n) => total == 0 ? 0 : n / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${radar.done} de $total',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 26,
                letterSpacing: -0.5,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${radar.completionPercent}%',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 26,
                color: scheme.primary,
              ),
            ),
            if (radar.drafts > 0) ...[
              const SizedBox(width: 10),
              Text(
                '· ${radar.drafts} ${radar.drafts == 1 ? 'borrador' : 'borradores'} aparte, no cuentan',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        // La vía va de fondo y los tramos encima: un `Expanded` de flex 0 no
        // dibuja nada, así que con cero hechas y cero en curso la barra se
        // armaba con dos huecos y quedaba a merced de cómo se repartiera el
        // resto. Los tramos vacíos directamente no se ponen.
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Container(
            height: 4,
            color: scheme.outlineVariant,
            child: Row(
              children: [
                for (final tramo in <({int count, Color color})>[
                  (count: radar.done, color: scheme.tertiary),
                  (count: radar.running, color: scheme.primary),
                  (count: radar.blocked, color: scheme.error),
                ])
                  if (tramo.count > 0)
                    Expanded(
                      // Un solo ítem sobre quinientos igual tiene que dejar
                      // una marca: redondear a cero lo haría desaparecer.
                      flex: (share(tramo.count) * 1000).round().clamp(1, 1000),
                      child: ColoredBox(color: tramo.color),
                    ),
                if (radar.free > 0)
                  Expanded(
                    flex: (share(radar.free) * 1000).round().clamp(1, 1000),
                    child: const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _Legend(color: scheme.tertiary, label: '${radar.done} hechas'),
            _Legend(color: scheme.primary, label: '${radar.running} en curso'),
            _Legend(color: scheme.error, label: '${radar.blocked} bloqueadas'),
            _Legend(
              color: scheme.outlineVariant,
              label: '${radar.free} libres',
            ),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Una grilla de hairlines, no una tabla con bordes: es el idioma del resto
/// de la app y deja que los números manden.
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.rows});

  final List<({String label, int flex})> columns;
  final List<List<Widget>> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            children: [
              for (final column in columns)
                Expanded(
                  flex: column.flex,
                  child: Text(
                    column.label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9.5,
                      letterSpacing: 0.9,
                      color: scheme.outline,
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (final row in rows)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: scheme.outlineVariant, width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < row.length; i++)
                  Expanded(flex: columns[i].flex, child: row[i]),
              ],
            ),
          ),
      ],
    );
  }
}

class _EnCurso extends StatelessWidget {
  const _EnCurso({
    required this.radar,
    required this.project,
    required this.now,
  });

  final ProjectRadar radar;
  final Project project;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profiles = AgentProfilesService.instance.notifier.data.profiles;

    Color colorOf(String handle) {
      final id = profiles
          .where((profile) => profile.name == handle)
          .firstOrNull
          ?.id;
      final index = id == null ? -1 : project.profileIds.indexOf(id);
      return memberColorFor(index);
    }

    return _Grid(
      columns: const [
        (label: 'Tarea del roadmap', flex: 29),
        (label: 'Agente', flex: 20),
        (label: 'Sesión', flex: 22),
        (label: 'Hace', flex: 13),
        (label: 'Toma', flex: 16),
      ],
      rows: [
        for (final item in radar.inProgress)
          [
            _Mono(item.taskPath),
            Row(
              children: [
                MemberAvatar(color: colorOf(item.profileHandle), size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '@${item.profileHandle}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorOf(item.profileHandle),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Flexible(
                  child: Text(
                    item.sessionTitle.isEmpty ? '—' : item.sessionTitle,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (item.live) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            Text(
              _hace(item.heldFor(now)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'vence en ${item.expiresIn(now).inMinutes}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                // A menos de cinco minutos la toma se cae sola y alguien más
                // la va a agarrar: eso hay que verlo antes de que pase.
                color: item.expiresIn(now).inMinutes <= 5
                    ? scheme.onErrorContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
      ],
    );
  }

  static String _hace(Duration held) {
    if (held.inMinutes < 1) return 'recién';
    if (held.inMinutes < 60) return '${held.inMinutes} min';
    return '${held.inHours} h';
  }
}

class _Sesiones extends StatelessWidget {
  const _Sesiones({required this.radar});

  final ProjectRadar radar;

  @override
  Widget build(BuildContext context) {
    return _Grid(
      columns: const [
        (label: 'Sesión', flex: 29),
        (label: 'Estado', flex: 20),
        (label: 'Paso', flex: 11),
        (label: 'Plan', flex: 12),
        (label: 'Contexto', flex: 12),
        (label: 'Trabaja en', flex: 16),
      ],
      rows: [
        for (final session in radar.sessions)
          [
            Text(
              session.title,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: session.status == SessionStatus.running
                    ? null
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: switch (session.status) {
                SessionStatus.running => const _Chip(label: 'corriendo'),
                SessionStatus.finished => const _Chip(
                  label: 'terminada',
                  good: true,
                ),
                SessionStatus.failed => const _Chip(
                  label: 'falló',
                  muted: true,
                ),
              },
            ),
            _Mono(
              session.totalNodes == 0
                  ? '—'
                  : '${(session.nodeIndex + 1).clamp(1, session.totalNodes)}/${session.totalNodes}',
            ),
            _Mono(
              session.planTotal == 0
                  ? '—'
                  : '${session.planDone} de ${session.planTotal}',
            ),
            _Mono(
              session.contextRatio == null
                  ? '—'
                  : '${(session.contextRatio! * 100).round()}%',
            ),
            _Mono(
              session.claimedTaskPath == null
                  ? '—'
                  : session.claimedTaskPath!.split('/').last,
            ),
          ],
      ],
    );
  }
}

/// Cuántas tareas trabadas se listan antes de pasar a contarlas.
///
/// Con treinta y una, la lista entera convierte la pantalla en una pared y
/// empuja todo lo demás fuera de la vista. El tope no es silencioso: abajo
/// dice cuántas quedaron, que es el número que importa.
const _kStuckShown = 6;

class _Trabado extends StatelessWidget {
  const _Trabado({required this.radar});

  final ProjectRadar radar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = radar.stuck.take(_kStuckShown).toList();
    final rest = radar.stuck.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in shown)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  width: 2,
                  color: item.worst == StuckKind.blocker
                      ? scheme.primary
                      : scheme.error,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.taskPath,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: scheme.onSurface,
                  ),
                ),
                for (final issue in item.issues)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'bloqueante '),
                          TextSpan(
                            text: issue.reference,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                          const TextSpan(text: ' → '),
                          TextSpan(
                            text: issue.detail,
                            style: TextStyle(
                              color: issue.kind == StuckKind.blocker
                                  ? scheme.onSurfaceVariant
                                  : scheme.onErrorContainer,
                              fontWeight: issue.kind == StuckKind.blocker
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (rest > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 14),
            child: Text(
              'y $rest ${rest == 1 ? 'tarea trabada más' : 'tareas trabadas más'} '
              '— están todas en TASKS/',
              style: TextStyle(fontSize: 11.5, color: scheme.outline),
            ),
          ),
      ],
    );
  }
}

class _Mono extends StatelessWidget {
  const _Mono(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Lo que se ve cuando la carpeta de tareas no cierra.
///
/// No muestra ceros: un cero no distingue "todavía no arrancó" de "está mal
/// escrito", y son dos problemas con dos salidas distintas. Muestra qué
/// falta, línea por línea, y ofrece una sola cosa: abrir la sesión que lo
/// arregla.
class _SinFormato extends StatelessWidget {
  const _SinFormato({required this.check, required this.project});

  final RoadmapFormatCheck? check;
  final Project project;

  /// Abre la sesión de formato y VA a ella.
  ///
  /// Las dos cosas, siempre: el botón dejaba la sesión creada en el sidebar y
  /// a vos mirando la misma pantalla de error, sin ninguna señal de que algo
  /// había pasado. Crear no es ir —esa regla vale para lo que arranca solo—,
  /// así que el que apreta es el que navega.
  void _abrir(BuildContext context) {
    final sessionId = ProjectsService.instance.notifier
        .startRoadmapFormatSession(project.id);
    if (sessionId == null) return;
    WorkspaceService.instance.notifier.openSession(project.id, sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final findings = check?.findings ?? const <FormatFinding>[];
    final passed = check?.passed ?? const <String>[];
    final sinCarpeta = project.workingDirectory.trim().isEmpty;
    final pendiente = ProjectsViewModel.openFormatSessionOf(project);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                sinCarpeta ? Icons.folder_off_outlined : Icons.checklist_rtl,
                size: 36,
                color: scheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                sinCarpeta
                    ? 'Este proyecto todavía no tiene carpeta de trabajo'
                    : 'El formato de tareas de este proyecto no cierra',
                textAlign: TextAlign.center,
                style: text.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(
                sinCarpeta
                    ? 'Elegila en la ficha del proyecto y esto empieza a '
                          'funcionar solo.'
                    : 'Sin él no hay nada que medir, y los agentes no reciben '
                          'las tools del roadmap.',
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
              if (!sinCarpeta) ...[
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final done in passed)
                        _CheckLine(ok: true, text: done),
                      for (final finding in findings)
                        _CheckLine(
                          ok: false,
                          text: finding.where == null
                              ? finding.message
                              : '${finding.where} — ${finding.message}',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Con una sesión de formato ya abierta el botón NO ofrece
                // abrir otra: te lleva a la que hay. Dos sesiones arreglando
                // la misma carpeta se pisan los archivos, y la única salida
                // sensata desde acá es ir a mirar la que está trabajando.
                if (pendiente == null)
                  FilledButton.icon(
                    onPressed: () => _abrir(context),
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Definir el formato'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => _abrir(context),
                    icon: Icon(
                      pendiente.isRunning
                          ? Icons.hourglass_top
                          : Icons.forum_outlined,
                      size: 16,
                    ),
                    label: Text(
                      pendiente.isRunning
                          ? 'Está trabajando — ir a la sesión'
                          : 'Ir a la sesión abierta',
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  pendiente == null
                      ? 'Abre una sesión con el formato y las plantillas '
                            'adentro, y no la deja cerrar hasta que estos '
                            'chequeos pasen.'
                      : 'Ya hay una sesión abierta para esto. Cuando cierre, '
                            'el chequeo vuelve a correr solo y esta pantalla '
                            'pasa a mostrar el roadmap.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(
                    fontSize: 11,
                    color: scheme.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ok ? '✓' : '✗',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: ok ? scheme.tertiary : scheme.error,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dos contadores y nada más. El detalle vive en su propio grupo del sidebar;
/// acá lo único que importa es si hay algo esperándote.
class _Requerimientos extends StatelessWidget {
  const _Requerimientos({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ReactiveViewModelBuilder<RequirementsViewModel, RequirementsState>(
      viewmodel: RequirementsService.instance.notifier,
      build: (state, viewmodel, keep) {
        final salientes = state.requirements
            .where(
              (requirement) =>
                  requirement.fromProjectId == project.id &&
                  requirement.status.isOpen,
            )
            .length;
        final entrantes = state.requirements
            .where(
              (requirement) =>
                  requirement.toProjectId == project.id &&
                  requirement.status == RequirementStatus.abierto,
            )
            .length;

        if (salientes == 0 && entrantes == 0) {
          return Text(
            AppLocalizations.of(context).noOpenRequirements,
            style: Theme.of(context).textTheme.bodySmall,
          );
        }

        return Wrap(
          spacing: 26,
          runSpacing: 6,
          children: [
            _Counter(
              value: salientes,
              label: 'abiertos hacia afuera',
              color: scheme.onSurface,
            ),
            _Counter(
              value: entrantes,
              label: 'entrantes sin tomar',
              color: scheme.primary,
            ),
          ],
        );
      },
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
