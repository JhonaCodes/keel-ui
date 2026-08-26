import 'package:keel_ui/src/integrations/system_prompt/system_prompt.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

/// El texto del formato vive con el resto de los prompts, en
/// `integrations/system_prompt/`. Se re-exporta porque esta era su
/// dirección conocida.
export 'package:keel_ui/src/integrations/system_prompt/system_prompt.dart'
    show kRoadmapFormatSkillContent;

/// El nombre del skill que describe el formato de la carpeta de tareas.
///
/// Reservado: se re-sincroniza en cada arranque, igual que el mapa del
/// sistema de Keel AI. Si alguien lo edita a mano, la próxima vez que abra
/// la app vuelve a lo que dice el código — que es lo correcto, porque el
/// lector y el chequeo están escritos contra esto.
const kRoadmapFormatSkillName = 'keel-formato-de-tareas';

/// Cómo se llama la sesión que arma el formato. Fija a propósito: es la que
/// el chequeo obligatorio busca al cerrar.
const kRoadmapFormatSessionTitle = 'Definir el formato';

/// El workflow con el que corre esa sesión.
///
/// Reservado y re-sembrado en cada arranque, igual que el skill. Es de la
/// app y no de un proyecto: cualquiera puede armar su carpeta de tareas sin
/// tener que acordarse de engancharlo.
const kRoadmapFormatWorkflowName = 'keel-formato-de-tareas';

/// Deja el skill del formato al día en cada arranque.
Future<void> seedRoadmapFormatSkill() async {
  final skills = SkillsService.instance.notifier;
  await skills.ready;

  if (!skills.data.skills.any(
    (skill) => skill.name == kRoadmapFormatSkillName,
  )) {
    skills.createSkill(
      name: kRoadmapFormatSkillName,
      content: kRoadmapFormatSkillContent,
    );
  } else {
    await skills.syncReservedSkillContent(
      kRoadmapFormatSkillName,
      kRoadmapFormatSkillContent,
    );
  }
}

/// Deja el workflow de formato registrado y al día.
///
/// Se re-sincroniza en cada arranque como el skill: el chequeo del cierre y
/// el lector de la carpeta están escritos contra esto, así que una edición a
/// mano vuelve a lo que dice el código.
Future<void> seedRoadmapFormatWorkflow() async {
  final workflows = WorkflowsService.instance.notifier;
  await workflows.ready;

  const whenToApply =
      'Cuando un proyecto todavía no tiene su carpeta TASKS/, o la tiene con '
      'un formato que Keel no puede leer.';

  final existing = workflows.data.workflows
      .where((workflow) => workflow.name == kRoadmapFormatWorkflowName)
      .firstOrNull;

  if (existing == null) {
    workflows.createWorkflow(
      name: kRoadmapFormatWorkflowName,
      whenToApply: whenToApply,
      skillNames: const [kRoadmapFormatSkillName],
      buildsRoadmap: true,
      kind: WorkflowKind.roadmap,
    );
    return;
  }

  workflows.updateWorkflow(
    existing.id,
    name: kRoadmapFormatWorkflowName,
    whenToApply: whenToApply,
    skillNames: const [kRoadmapFormatSkillName],
    buildsRoadmap: true,
    kind: WorkflowKind.roadmap,
  );
}

/// El id del workflow de formato, o vacío si todavía no se sembró.
String roadmapFormatWorkflowId() =>
    WorkflowsService.instance.notifier.data.workflows
        .where((workflow) => workflow.name == kRoadmapFormatWorkflowName)
        .firstOrNull
        ?.id ??
    '';
