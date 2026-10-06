import 'package:keel_core/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_core/modules/agents/model/agent_provider.dart';
import 'package:keel_core/modules/projects/model/project.dart';
import 'package:keel_core/modules/projects/model/session.dart';
import 'package:keel_core/modules/projects/model/session_plan_item.dart';
import 'package:keel_core/modules/projects/model/session_queued_message.dart';
import 'package:keel_core/modules/projects/model/session_tab.dart';
import 'package:keel_core/modules/projects/service/projects_store.dart';
import 'package:keel_core/modules/requirements/model/internal_requirement.dart';
import 'package:keel_core/modules/workflows/model/workflow.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';

/// El título con el que nace una sesión. Vale como marca de "todavía no
/// tiene nombre propio": mientras siga siendo este, el primer pedido la
/// renombra sola.
const kDefaultSessionTitle = 'Sesión nueva';

/// Mirror delgado de [ProjectsStore] (keel_core): toda la lógica real
/// vive ahí.
class ProjectsViewModel extends StoreMirrorViewModel<ProjectsState> {
  ProjectsViewModel() : super(ProjectsStore.instance);

  Future<void> get ready => ProjectsStore.instance.ready;

  // ── estáticas puras, llamadas directo desde afuera ───────────────────

  static Session? openFormatSessionOf(Project project) =>
      ProjectsStore.openFormatSessionOf(project);

  static List<Project> repairWorkflowReferences(
    List<Project> projects,
    Set<String> existingWorkflowIds,
  ) => ProjectsStore.repairWorkflowReferences(projects, existingWorkflowIds);

  static Session revivedSession(
    Session session,
    Project project,
    String formatWorkflowId,
  ) => ProjectsStore.revivedSession(session, project, formatWorkflowId);

  // ── el resto, forward 1:1 a ProjectsStore ────────────────────────────

  Future<String?> activateWorkflowCapability(
    String projectId,
    String sessionId,
    String capabilityId,
  ) => ProjectsStore.instance.activateWorkflowCapability(
    projectId,
    sessionId,
    capabilityId,
  );

  void addAgentToSession(
    String projectId,
    String sessionId,
    String profileId,
  ) =>
      ProjectsStore.instance.addAgentToSession(projectId, sessionId, profileId);

  void addKnowledgeBase(String projectId, String baseName) =>
      ProjectsStore.instance.addKnowledgeBase(projectId, baseName);

  void addRule(String projectId, String ruleName) =>
      ProjectsStore.instance.addRule(projectId, ruleName);

  Future<void> answerInRequirementThread({
    required InternalRequirement requirement,
    required AgentProfile member,
    required Project memberProject,
    required bool asTarget,
    required String question,
    bool planMode = false,
  }) => ProjectsStore.instance.answerInRequirementThread(
    requirement: requirement,
    member: member,
    memberProject: memberProject,
    asTarget: asTarget,
    question: question,
    planMode: planMode,
  );

  Future<String?> answerSessionDecision(
    String projectId,
    String sessionId,
    String decisionId, {
    String answer = '',
    bool? approve,
    String scope = 'once',
  }) => ProjectsStore.instance.answerSessionDecision(
    projectId,
    sessionId,
    decisionId,
    answer: answer,
    approve: approve,
    scope: scope,
  );

  Future<String?> approveWorkflowCapability(
    String projectId,
    String sessionId,
    String capabilityId,
  ) => ProjectsStore.instance.approveWorkflowCapability(
    projectId,
    sessionId,
    capabilityId,
  );

  Future<void> askAboutLine(
    String projectId, {
    required String profileId,
    required String filePath,
    required int lineNumber,
    required String lineContent,
    required String question,
  }) => ProjectsStore.instance.askAboutLine(
    projectId,
    profileId: profileId,
    filePath: filePath,
    lineNumber: lineNumber,
    lineContent: lineContent,
    question: question,
  );

  Future<String> askProject({
    required String toProjectName,
    required String question,
  }) => ProjectsStore.instance.askProject(
    toProjectName: toProjectName,
    question: question,
  );

  Future<String> askUser({
    required String projectId,
    required String sessionId,
    required String profileId,
    required String question,
    List<String> options = const [],
  }) => ProjectsStore.instance.askUser(
    projectId: projectId,
    sessionId: sessionId,
    profileId: profileId,
    question: question,
    options: options,
  );

  bool canSteerSession(String sessionId) =>
      ProjectsStore.instance.canSteerSession(sessionId);

  List<Workflow> choosableWorkflowsOf(Project project) =>
      ProjectsStore.instance.choosableWorkflowsOf(project);

  void clearMemberTuning(String projectId, String profileId) =>
      ProjectsStore.instance.clearMemberTuning(projectId, profileId);

  void closeSession(String projectId, String sessionId) =>
      ProjectsStore.instance.closeSession(projectId, sessionId);

  List<String> completePlanItems(
    String projectId,
    String sessionId, {
    required List<String> items,
    String? byProfileId,
  }) => ProjectsStore.instance.completePlanItems(
    projectId,
    sessionId,
    items: items,
    byProfileId: byProfileId,
  );

  String? createProject({
    required String name,
    required String purpose,
    required String workingDirectory,
    required List<String> profileIds,
    required List<String> workflowIds,
    required List<String> ruleNames,
    List<String> hookNames = const [],
    required List<String> knowledgeBaseNames,
    bool maintained = true,
  }) => ProjectsStore.instance.createProject(
    name: name,
    purpose: purpose,
    workingDirectory: workingDirectory,
    profileIds: profileIds,
    workflowIds: workflowIds,
    ruleNames: ruleNames,
    hookNames: hookNames,
    knowledgeBaseNames: knowledgeBaseNames,
    maintained: maintained,
  );

  void createSession(String projectId, {String? workflowId}) =>
      ProjectsStore.instance.createSession(projectId, workflowId: workflowId);

  Future<({bool allow, String reason})> decideToolUse({
    required String projectId,
    required String sessionId,
    required String profileId,
    required String toolName,
    required String toolInput,
  }) => ProjectsStore.instance.decideToolUse(
    projectId: projectId,
    sessionId: sessionId,
    profileId: profileId,
    toolName: toolName,
    toolInput: toolInput,
  );

  Workflow? defaultWorkflowOf(Project project) =>
      ProjectsStore.instance.defaultWorkflowOf(project);

  void deleteProject(String id) => ProjectsStore.instance.deleteProject(id);

  int detachHook(String hookName) =>
      ProjectsStore.instance.detachHook(hookName);

  int detachWorkflow(String workflowId) =>
      ProjectsStore.instance.detachWorkflow(workflowId);

  void discardPlanItem(String projectId, String sessionId, String itemId) =>
      ProjectsStore.instance.discardPlanItem(projectId, sessionId, itemId);

  void dismissSessionPermission(String projectId, String sessionId) =>
      ProjectsStore.instance.dismissSessionPermission(projectId, sessionId);

  Future<void> editQueuedSessionMessage(
    String projectId,
    String sessionId,
    String messageId,
    String text,
  ) => ProjectsStore.instance.editQueuedSessionMessage(
    projectId,
    sessionId,
    messageId,
    text,
  );

  Future<void> holdQueuedSessionMessage(
    String projectId,
    String sessionId,
    String messageId,
  ) => ProjectsStore.instance.holdQueuedSessionMessage(
    projectId,
    sessionId,
    messageId,
  );

  Future<void> implementSessionPlan(String projectId, String sessionId) =>
      ProjectsStore.instance.implementSessionPlan(projectId, sessionId);

  bool isSessionStopped(String sessionId) =>
      ProjectsStore.instance.isSessionStopped(sessionId);

  void keepPlanningSession(String projectId, String sessionId) =>
      ProjectsStore.instance.keepPlanningSession(projectId, sessionId);

  List<AgentProfile> membersOf(Project project, {Session? session}) =>
      ProjectsStore.instance.membersOf(project, session: session);

  int nodeCountFor(Project project) =>
      ProjectsStore.instance.nodeCountFor(project);

  int nodeCountOf(Session session) =>
      ProjectsStore.instance.nodeCountOf(session);

  List<SessionPlanItem> planOf(String projectId, String sessionId) =>
      ProjectsStore.instance.planOf(projectId, sessionId);

  Future<String?> queueSessionMessage(
    String projectId,
    String sessionId,
    String text, {
    List<String> imagePaths = const [],
    bool viaKeelAi = false,
    SessionQueuedDelivery delivery = SessionQueuedDelivery.standby,
  }) => ProjectsStore.instance.queueSessionMessage(
    projectId,
    sessionId,
    text,
    imagePaths: imagePaths,
    viaKeelAi: viaKeelAi,
    delivery: delivery,
  );

  ({int percent, bool ok}) radarBadgeFor(Project project) =>
      ProjectsStore.instance.radarBadgeFor(project);

  Future<void> recordManualEdit(
    String projectId, {
    required String profileId,
    required String filePath,
  }) => ProjectsStore.instance.recordManualEdit(
    projectId,
    profileId: profileId,
    filePath: filePath,
  );

  void removeAgentFromSession(
    String projectId,
    String sessionId,
    String profileId,
  ) => ProjectsStore.instance.removeAgentFromSession(
    projectId,
    sessionId,
    profileId,
  );

  void removeKnowledgeBase(String projectId, String baseName) =>
      ProjectsStore.instance.removeKnowledgeBase(projectId, baseName);

  void removePlanItem(String projectId, String sessionId, String itemId) =>
      ProjectsStore.instance.removePlanItem(projectId, sessionId, itemId);

  Future<void> removeQueuedSessionMessage(
    String projectId,
    String sessionId,
    String messageId,
  ) => ProjectsStore.instance.removeQueuedSessionMessage(
    projectId,
    sessionId,
    messageId,
  );

  void removeRule(String projectId, String ruleName) =>
      ProjectsStore.instance.removeRule(projectId, ruleName);

  void renameHook(String from, String to) =>
      ProjectsStore.instance.renameHook(from, to);

  String? renameProject(String id, String name) =>
      ProjectsStore.instance.renameProject(id, name);

  void renameSession(String projectId, String sessionId, String title) =>
      ProjectsStore.instance.renameSession(projectId, sessionId, title);

  Future<void> replyInSession(
    String projectId,
    String sessionId,
    String text,
  ) => ProjectsStore.instance.replyInSession(projectId, sessionId, text);

  Future<void> respondToSessionPermission(
    String projectId,
    String sessionId, {
    required bool grant,
  }) => ProjectsStore.instance.respondToSessionPermission(
    projectId,
    sessionId,
    grant: grant,
  );

  Future<void> resumeWorkflow(String projectId, String sessionId) =>
      ProjectsStore.instance.resumeWorkflow(projectId, sessionId);

  Future<String?> retryWorkNode(
    String projectId,
    String sessionId,
    String nodeId,
  ) => ProjectsStore.instance.retryWorkNode(projectId, sessionId, nodeId);

  void selectProject(String id) => ProjectsStore.instance.selectProject(id);

  void selectSession(String projectId, String sessionId) =>
      ProjectsStore.instance.selectSession(projectId, sessionId);

  Future<void> sendQueuedSessionMessageAfterTurn(
    String projectId,
    String sessionId,
    String messageId,
  ) => ProjectsStore.instance.sendQueuedSessionMessageAfterTurn(
    projectId,
    sessionId,
    messageId,
  );

  Future<void> sendQueuedSessionMessageNow(
    String projectId,
    String sessionId,
    String messageId,
  ) => ProjectsStore.instance.sendQueuedSessionMessageNow(
    projectId,
    sessionId,
    messageId,
  );

  Future<void> sendToChannel(
    String projectId,
    String text, {
    List<String> imagePaths = const [],
  }) => ProjectsStore.instance.sendToChannel(
    projectId,
    text,
    imagePaths: imagePaths,
  );

  bool sessionUsesE2e(Session session) =>
      ProjectsStore.instance.sessionUsesE2e(session);

  void setActiveWorkflow(String projectId, String workflowId) =>
      ProjectsStore.instance.setActiveWorkflow(projectId, workflowId);

  void setMemberTuning(
    String projectId,
    String profileId, {
    AgentProvider? provider,
    String? model,
    String? effort,
  }) => ProjectsStore.instance.setMemberTuning(
    projectId,
    profileId,
    provider: provider,
    model: model,
    effort: effort,
  );

  void setProjectWorkingDirectory(String id, String path) =>
      ProjectsStore.instance.setProjectWorkingDirectory(id, path);

  void setSessionPlan(
    String projectId,
    String sessionId,
    List<PlanEntry> entries, {
    String logicMermaid = '',
  }) => ProjectsStore.instance.setSessionPlan(
    projectId,
    sessionId,
    entries,
    logicMermaid: logicMermaid,
  );

  void setSessionPlanMode(String projectId, String sessionId, bool enabled) =>
      ProjectsStore.instance.setSessionPlanMode(projectId, sessionId, enabled);

  bool setSessionWorkflow(String projectId, String sessionId, String id) =>
      ProjectsStore.instance.setSessionWorkflow(projectId, sessionId, id);

  void setTab(String projectId, SessionTab tab) =>
      ProjectsStore.instance.setTab(projectId, tab);

  bool setWorkflowNodeAssignment(
    String projectId,
    String workflowId,
    String nodeId,
    String? profileId,
  ) => ProjectsStore.instance.setWorkflowNodeAssignment(
    projectId,
    workflowId,
    nodeId,
    profileId,
  );

  void showProjectState(String projectId) =>
      ProjectsStore.instance.showProjectState(projectId);

  String? startRequirementSession({
    required String projectId,
    required String sessionTitle,
    required String request,
    String? workflowId,
  }) => ProjectsStore.instance.startRequirementSession(
    projectId: projectId,
    sessionTitle: sessionTitle,
    request: request,
    workflowId: workflowId,
  );

  String? startRoadmapFormatSession(String projectId) =>
      ProjectsStore.instance.startRoadmapFormatSession(projectId);

  void stopSession(
    String projectId,
    String sessionId, {
    bool interrupting = false,
  }) => ProjectsStore.instance.stopSession(
    projectId,
    sessionId,
    interrupting: interrupting,
  );

  SessionTab tabOf(String projectId) => ProjectsStore.instance.tabOf(projectId);

  void togglePlanItem(String projectId, String sessionId, String itemId) =>
      ProjectsStore.instance.togglePlanItem(projectId, sessionId, itemId);

  String? updateProject(
    String id, {
    required String name,
    required String purpose,
    required String workingDirectory,
    required List<String> profileIds,
    required List<String> workflowIds,
    required List<String> ruleNames,
    List<String> hookNames = const [],
    required List<String> knowledgeBaseNames,
    bool maintained = true,
  }) => ProjectsStore.instance.updateProject(
    id,
    name: name,
    purpose: purpose,
    workingDirectory: workingDirectory,
    profileIds: profileIds,
    workflowIds: workflowIds,
    ruleNames: ruleNames,
    hookNames: hookNames,
    knowledgeBaseNames: knowledgeBaseNames,
    maintained: maintained,
  );

  Workflow? workflowOf(Session session) =>
      ProjectsStore.instance.workflowOf(session);

  String? workingDirectoryOf(String projectId) =>
      ProjectsStore.instance.workingDirectoryOf(projectId);
}

mixin ProjectsService {
  static final ReactiveNotifier<ProjectsViewModel> instance =
      ReactiveNotifier<ProjectsViewModel>(() => ProjectsViewModel());
}
