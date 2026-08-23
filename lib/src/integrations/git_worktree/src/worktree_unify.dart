part of '../git_worktree.dart';

enum WorktreeStepResult { ok, skipped, failed }

/// Un paso de la unificación, con lo que git contestó.
///
/// La operación se cuenta paso por paso porque puede quedar a la mitad y eso
/// no es lo mismo que no haber empezado: si la carpeta ya se fue, hay que
/// decir dónde quedaron los commits.
class WorktreeStep {
  const WorktreeStep(this.label, this.result, [this.detail = '']);

  final String label;
  final WorktreeStepResult result;
  final String detail;

  bool get failed => result == WorktreeStepResult.failed;
}

class WorktreeUnifyReport {
  const WorktreeUnifyReport({
    required this.steps,
    required this.moved,
    required this.path,
    required this.branch,
    this.behind = 0,
  });

  final List<WorktreeStep> steps;

  /// El worktree de al lado ya no existe. Cuando esto es cierto el proyecto
  /// TIENE que cambiar de carpeta, haya salido bien el resto o no: la vieja
  /// no está más.
  final bool moved;

  /// El worktree principal: dónde se sigue trabajando.
  final String path;
  final String branch;

  /// Commits de la rama base que le faltan a [branch], ya con el pull hecho.
  final int behind;

  bool get ok => moved && !steps.any((step) => step.failed);
}

/// Trae la rama al worktree principal y saca la carpeta de al lado.
///
/// El orden no es casual: primero lo que se puede deshacer, después lo que
/// no. Traer la base no destruye nada; sacar el worktree sí, y para entonces
/// ya se sabe que el resto del camino está despejado.
///
/// No revisa [WorktreeUnifyPlan.blockers]: eso lo decide quien llama, que es
/// el que puede mostrarlos.
Future<WorktreeUnifyReport> unifyWorktree(WorktreeUnifyPlan plan) async {
  final steps = <WorktreeStep>[];
  final root = plan.mainTree.path;
  final base = plan.base;

  // ── 1. la base, al día ──────────────────────────────────────────────
  //
  // Falla y sigue a propósito. Traer `main` depende de que haya red y de
  // que el remoto conteste, y ninguna de las dos cosas tiene que ver con
  // consolidar dos carpetas locales. Que se vea en el informe, no que
  // trabe.
  final pullLabel = base.isEmpty
      ? 'Actualizar la rama base'
      : 'Actualizar `$base` en el principal';

  if (base.isEmpty) {
    steps.add(
      WorktreeStep(
        pullLabel,
        WorktreeStepResult.skipped,
        'No encontré ni main ni master en este repo.',
      ),
    );
  } else if (!plan.hasRemote) {
    steps.add(
      WorktreeStep(
        pullLabel,
        WorktreeStepResult.skipped,
        'El repo no tiene origin: no hay de dónde traer.',
      ),
    );
  } else {
    // Si el principal ya está parado en la base, es un pull de verdad. Si
    // está en otra rama, se adelanta la referencia sin tocarle la copia de
    // trabajo — que es lo mismo, sin el checkout de más.
    final onBase = plan.mainTree.branch == base;
    final pull = onBase
        ? await _git(['pull', '--ff-only', 'origin', base], cwd: root)
        : await _git(['fetch', 'origin', '$base:$base'], cwd: root);
    steps.add(
      WorktreeStep(
        pullLabel,
        pull.ok ? WorktreeStepResult.ok : WorktreeStepResult.failed,
        pull.output.isEmpty ? 'Ya estaba al día.' : pull.output,
      ),
    );
  }

  // ── 2. sacar el worktree ────────────────────────────────────────────
  //
  // Acá se borra la carpeta. Hasta este punto todo era reversible.
  final removed = await _git(['worktree', 'remove', plan.from.path], cwd: root);
  steps.add(
    WorktreeStep(
      'Sacar `${plan.from.name}`',
      removed.ok ? WorktreeStepResult.ok : WorktreeStepResult.failed,
      removed.ok ? 'La carpeta ya no está.' : removed.output,
    ),
  );
  if (!removed.ok) {
    return WorktreeUnifyReport(
      steps: steps,
      moved: false,
      path: plan.from.path,
      branch: plan.branch,
    );
  }

  // ── 3. la rama, en el principal ─────────────────────────────────────
  //
  // Recién ahora es posible: git no deja tomar una rama que otro worktree
  // tiene checkeada, y hasta el paso anterior la tenía.
  final switched = await _git(['switch', plan.branch], cwd: root);
  steps.add(
    WorktreeStep(
      'Poner `${plan.branch}` en el principal',
      switched.ok ? WorktreeStepResult.ok : WorktreeStepResult.failed,
      switched.ok
          ? switched.output
          : '${switched.output}\nLos commits están: la rama sigue existiendo. '
                'Tomala a mano con: git switch ${plan.branch}',
    ),
  );

  await _git(['worktree', 'prune'], cwd: root);

  return WorktreeUnifyReport(
    steps: steps,
    moved: true,
    path: root,
    branch: plan.branch,
    behind: await _behind(root, plan.branch, base),
  );
}
