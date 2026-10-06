import 'package:keel_core/core/host/keel_host.dart';
import 'package:keel_core/modules/projects/model/project.dart';
import 'package:keel_core/modules/workflows/model/workflow_capability.dart';
import 'package:keel_e2e_panel/keel_e2e_panel.dart' show KeelE2eHostService;

import 'package:keel_core/integrations/decisions_mcp/decisions_mcp_server.dart';
import 'package:keel_ui/src/integrations/keel_e2e/keel_e2e.dart';
import 'package:keel_ui/src/modules/projects/service/step_mcp_surface.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';

/// keel-ui's implementation of the engine's host seam: everything here is
/// genuinely desktop/process machinery (a supervised keel-e2e subprocess),
/// which is exactly why it lives here and not in `keel_core`.
class KeelHostImpl extends KeelHost {
  const KeelHostImpl();

  @override
  Future<StepMcpSurfaceResult> keelE2eStepSurface({
    required Project project,
    required String sessionId,
    required WorkflowCapability? capability,
    required bool isConsult,
    required String projectId,
    required String workNodeId,
    required String cwd,
  }) async {
    if (isConsult || capability == null || !capability.usesKeelE2e) {
      return const StepMcpSurfaceReady(StepMcpSurface());
    }
    final attach = await ensureKeelE2eAttached(
      project: project,
      sessionId: sessionId,
    );
    final failureMessage = attach.when(ok: (_) => null, err: (f) => f.message);
    if (failureMessage != null) return StepMcpSurfaceFailed(failureMessage);

    return StepMcpSurfaceReady(
      resolveStepMcpSurface(
        capability: capability,
        isConsult: isConsult,
        connection: attach.data,
        projectId: projectId,
        sessionId: sessionId,
        workNodeId: workNodeId,
        cwd: cwd,
      ),
    );
  }

  @override
  Future<void> releaseKeelE2eSession(String sessionId) =>
      KeelE2eHostService.instance.notifier.releaseSession(sessionId);

  @override
  Future<void> ensureDecisionGateStarted() {
    DecisionGateServer.agentGate ??=
        ({required agentId, required toolName, required toolInput}) =>
            AgentsService.instance.notifier.decideToolUse(
              agentId: agentId,
              toolName: toolName,
              toolInput: toolInput,
            );
    return super.ensureDecisionGateStarted();
  }
}
