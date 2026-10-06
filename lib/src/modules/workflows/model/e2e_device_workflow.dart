import 'package:keel_core/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

/// El nombre reservado del workflow sembrado de keel-e2e — el mismo texto
/// que la ficha del workflow muestra en la cabecera del canal (mockup
/// `06-cabecera-condicional`).
///
/// Igual que `keel-formato-de-tareas`: se resiembra en cada arranque, así
/// que una edición a mano vuelve a lo que dice el código la próxima vez que
/// alguien abre la app.
const kE2eDeviceWorkflowName = 'E2E → diagnóstico → arreglo → re-verificación';

/// Cuándo Keel AI ofrece este workflow.
const kE2eDeviceWorkflowWhenToApply =
    'Cuando hay que verificar un comportamiento en un dispositivo o '
    'navegador real: correr escenarios de e2e/, diagnosticar lo que falló, '
    'corregirlo y volver a verificar.';

/// `e2e-run` → `diagnosis` → `fix` → `e2e-verify`.
///
/// `e2e-run` no tiene dependencias (es el primer paso) y por eso nunca lleva
/// `outputContract: 'audit-feedback'`: un NO-GO sobre un nodo sin
/// dependencias se devuelve a sí mismo, y ese paso no es una auditoría de
/// otro nodo. `diagnosis` lee el `e2e-report` de `e2e-run` por dependencia
/// directa (`dependencyOutputs`) y es de solo lectura (no escribe código ni
/// corrige nada todavía) — `lintWorkflowCapabilities` no lo confunde con una
/// auditoría porque `writes()` no cuenta un nodo que cierra con
/// `outputContract: 'e2e-report'` como escritor (architecture §14): investigar
/// la causa no es auditar el reporte que la originó. `e2e-verify` sí es una
/// auditoría real
/// (`audit-feedback`, dueño independiente de `fix`): su trabajo es
/// exactamente decidir si la corrección funcionó.
///
/// Los cuatro roles son `*` (cualquier miembro), como el mockup
/// `07-editor-workflow` y el resto de las plantillas default: un rol
/// literal (`'verifier'`) rompería el workflow apenas arranca en cualquier
/// proyecto sin un agente con ESE rol exacto — `requiresIndependentOwner`
/// ya fuerza que `e2e-verify` tenga un dueño distinto de `fix`, sin
/// necesitar un rol propio para eso.
List<WorkflowCapability> e2eDeviceWorkflowCapabilities() => const [
  WorkflowCapability(
    id: 'e2e-run',
    title: 'Probar en el dispositivo',
    instruction:
        'Correr los escenarios de e2e/ del proyecto contra el dispositivo o '
        'navegador real, con las tools de keel-e2e: `list_targets` y elige '
        'el dispositivo del tipo que pide el `destino` del escenario '
        '(`tablet` o `teléfono`, campo `form_factor`); si el destino no lo '
        'dice, el único conectado. Cada app va solo en su tipo de '
        'dispositivo: nunca la instales ni la abras en otro, y ante '
        '`target_mismatch` elige el del tipo correcto. `list_scenarios` y '
        'corre los que correspondan (todos, por defecto). Por cada '
        'escenario: `start_run` con el escenario y el target_id, `app` con '
        'op `launch` (nunca `clear_data` sobre otra app que no sea la del '
        'escenario), y avanza hito por hito con una sola llamada por paso: '
        '`act` ya devuelve la pantalla nueva, así que no vuelvas a observar '
        'después de actuar. Toca por `ref`, luego por texto visible, y por '
        'coordenadas solo si el árbol no muestra nada; encadena en un '
        '`click_sequence` los pasos de los que estés seguro. Pide captura '
        'solo cuando una comprobación sea visual. Cierra cada hito con '
        '`complete_milestone`, registra los asserts con `record_check` y '
        'termina con `finish_report`. Cierra el paso con el e2e-report '
        'resumiendo los veredictos y las rutas de los reportes, sin '
        'interpretarlo todavía.',
    role: '*',
    mcpServers: [kKeelE2eMcpServerName],
    outputContract: 'e2e-report',
  ),
  WorkflowCapability(
    id: 'diagnosis',
    title: 'Diagnosticar la causa',
    instruction:
        'Con el e2e-report de e2e-run: investigar la causa raíz en el '
        'código del proyecto. No corregir todavía, no escribir código.',
    role: '*',
    dependencyIds: ['e2e-run'],
    readOnly: true,
  ),
  WorkflowCapability(
    id: 'fix',
    title: 'Arreglar',
    instruction:
        'Aplicar la corrección mínima para el diagnóstico de diagnosis, con '
        'su propio test de núcleo si aplica.',
    role: '*',
    dependencyIds: ['diagnosis'],
  ),
  WorkflowCapability(
    id: 'e2e-verify',
    title: 'Re-verificar',
    instruction:
        'Volver a correr los mismos escenarios E2E sobre la corrección de '
        'fix, a través de keel-e2e, en el mismo tipo de dispositivo que '
        'pide su `destino`. Cerrar con verdict GO o NO-GO.',
    role: '*',
    dependencyIds: ['fix'],
    mcpServers: [kKeelE2eMcpServerName],
    outputContract: 'audit-feedback',
    requiresIndependentOwner: true,
  ),
];

/// Deja el workflow sembrado de keel-e2e registrado y al día, igual que
/// `seedRoadmapFormatWorkflow`: se llama en cada arranque desde `main.dart`.
Future<void> seedE2eDeviceWorkflow() async {
  final workflows = WorkflowsService.instance.notifier;
  await workflows.ready;

  final capabilities = e2eDeviceWorkflowCapabilities();
  final existing = workflows.data.workflows
      .where((workflow) => workflow.name == kE2eDeviceWorkflowName)
      .firstOrNull;

  if (existing == null) {
    workflows.createWorkflow(
      name: kE2eDeviceWorkflowName,
      whenToApply: kE2eDeviceWorkflowWhenToApply,
      kind: WorkflowKind.general,
      capabilities: capabilities,
    );
    return;
  }

  workflows.updateWorkflow(
    existing.id,
    name: kE2eDeviceWorkflowName,
    whenToApply: kE2eDeviceWorkflowWhenToApply,
    kind: WorkflowKind.general,
    capabilities: capabilities,
  );
}
