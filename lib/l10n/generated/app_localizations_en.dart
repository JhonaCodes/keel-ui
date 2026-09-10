// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get buttonApply => 'Apply';

  @override
  String get buttonApplySelection => 'Apply selection';

  @override
  String get buttonCancel => 'Cancel';

  @override
  String get buttonCreate => 'Create';

  @override
  String buttonCreateEntity(String entity) {
    return 'Create $entity';
  }

  @override
  String get buttonDelete => 'Delete';

  @override
  String get buttonEdit => 'Edit';

  @override
  String get buttonSave => 'Save';

  @override
  String get buttonSearch => 'Search';

  @override
  String get actionCloneVault => 'Clone vault';

  @override
  String get actionCloneAndRead => 'Clone and read';

  @override
  String get actionChooseDestinationAndExport =>
      'Choose destination and export';

  @override
  String get actionExportBackup => 'Export backup';

  @override
  String get actionExportPackage => 'Export a package';

  @override
  String get actionSaveZip => 'Save the zip…';

  @override
  String get actionImportBackup => 'Import backup';

  @override
  String get actionIncludeSecrets => 'Include secrets (with their VALUES)';

  @override
  String get actionReadBackup => 'Read the backup';

  @override
  String get actionRestoreFromVault => 'Restore from the vault';

  @override
  String get actionRestoreSelection => 'Restore selection';

  @override
  String get actionBringEverythingAndStart => 'Bring everything and start';

  @override
  String get actionUnifyInMain => 'Unify in main';

  @override
  String get actionReviewAgain => 'Review again';

  @override
  String get actionStartFromScratch => 'Start from scratch';

  @override
  String get actionReadyEnter => 'All set — continue';

  @override
  String get labelAgents => 'Agents';

  @override
  String get labelWorkflows => 'Workflows';

  @override
  String get labelSkills => 'Skills';

  @override
  String get labelProject => 'Project';

  @override
  String get labelSession => 'Session';

  @override
  String get labelRules => 'Rules';

  @override
  String get labelHooks => 'Hooks';

  @override
  String get labelTools => 'Tools';

  @override
  String get labelIntegrations => 'Integrations';

  @override
  String get labelKnowledgeBases => 'Knowledge Bases';

  @override
  String get labelSecrets => 'Secrets';

  @override
  String get labelSettings => 'Settings';

  @override
  String get messageErrorGeneric => 'Something went wrong. Try again.';

  @override
  String get messageErrorNetwork => 'Could not connect. Check your network.';

  @override
  String get messageErrorFileContainsNothing =>
      'The file contains nothing applicable.';

  @override
  String get messageErrorBackupContainsNothing =>
      'The backup contains nothing applicable.';

  @override
  String messageSuccessCreated(String entity) {
    return '$entity created successfully.';
  }

  @override
  String get messageSuccessSaved => 'Saved.';

  @override
  String messageSuccessDeleted(String entity) {
    return '$entity deleted.';
  }

  @override
  String confirmationDeleteTitle(String entity) {
    return 'Delete $entity?';
  }

  @override
  String get confirmationDeleteMessage =>
      'Are you sure? This cannot be undone.';

  @override
  String get confirmationProceed => 'Proceed';

  @override
  String get placeholderSearchByName => 'Search by name…';

  @override
  String get placeholderFilterResults => 'Filter results…';

  @override
  String get placeholderAskAboutLine => 'Ask about this line…';

  @override
  String get hintFieldRequired => 'Field required.';

  @override
  String get hintEmailInvalid => 'Invalid email.';

  @override
  String get hintPasswordTooShort => 'Password must be at least 8 characters.';

  @override
  String get tooltipWorktreeSeparate => 'Separate worktree';

  @override
  String get tooltipOpenInFinder => 'Open in Finder';

  @override
  String get tooltipCopyToClipboard => 'Copy to clipboard';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español (Colombia)';

  @override
  String get settingLanguage => 'Language';

  @override
  String get settingTheme => 'Theme';

  @override
  String get settingThemeDark => 'Dark';

  @override
  String get settingThemeLight => 'Light';

  @override
  String countAgent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count agents',
      one: '1 agent',
    );
    return '$_temp0';
  }

  @override
  String countSession(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0';
  }

  @override
  String countWorkflow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count workflows',
      one: '1 workflow',
    );
    return '$_temp0';
  }

  @override
  String countFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results found',
      one: '1 result found',
      zero: 'No results found',
    );
    return '$_temp0';
  }

  @override
  String get pageTitleSettings => 'Settings';

  @override
  String get pageTitleSkillsRegistered => 'Registered Skills';

  @override
  String get pageTitleSecrets => 'Secrets';

  @override
  String get pageTitleHooksRegistered => 'Registered Hooks';

  @override
  String get pageTitleRulesRegistered => 'Registered Rules';

  @override
  String get pageTitleTestBoard => 'Test Board';

  @override
  String get pageTitleTools => 'Tools';

  @override
  String get pageTitleIntegrations => 'Integrations';

  @override
  String get pageTitleMachine => 'Machine';

  @override
  String get pageTitleAgentsRegistered => 'Registered Agents';

  @override
  String get pageTitleKnowledge => 'Knowledge';

  @override
  String get pageTitleInternalRequirements => 'Internal Requirements';

  @override
  String get pageTitleProjects => 'Projects';

  @override
  String get pageTitleSessionAgents => 'Session Agents';

  @override
  String get pageTitleImportHooks => 'Import Hooks from Claude Code';

  @override
  String get pageTitleTermsOfUse => 'Terms of Use';

  @override
  String get pageTitleLockedElements => 'Locked Elements';

  @override
  String get pageTitleOpenRequirement => 'Open a Requirement';

  @override
  String get pageTitleModifySharedDefault => 'Modify Shared Default';

  @override
  String get pageTitlePasteMCPConfig => 'Paste an MCP Configuration';

  @override
  String get pageTitleImportBackup => 'Import Backup';

  @override
  String get pageTitleExportPackage => 'Export a Package';

  @override
  String get pageTitleBackup => 'Backup';

  @override
  String get pageTitleImportPackage => 'Import a Package';

  @override
  String get pageTitleFaults => 'Faults';

  @override
  String get pageTitleEditQueuedMessage => 'Edit Queued Message';

  @override
  String get pageTitleRegisteredWorkflows => 'Registered Workflows';

  @override
  String get pageTitleUseAgent => 'Use an Agent';

  @override
  String pageTitleEngineOf(String member) {
    return 'Engine for @$member';
  }

  @override
  String get pageTitleRejectClosure => 'Reject Closure';

  @override
  String get settingTextSize => 'Text Size';

  @override
  String get settingWritePermissions => 'Write Permissions';

  @override
  String get settingScheduledJobsApi => 'Scheduled Jobs API';

  @override
  String get settingApplyToAllAgents => 'Apply to all agents';

  @override
  String get settingCanAdministrateSystem => 'Can administer the system';

  @override
  String get settingBlocksRequester => 'Blocks the requester';

  @override
  String get settingAccessEntireFilesystem => 'Access to entire file system';

  @override
  String get descriptionWritePermissions =>
      'Reading files, searching, and consulting the web is always allowed. Here you decide what agents can modify. Applies to all.';

  @override
  String get descriptionScheduledJobsApi =>
      'For external schedulers (cron, keel): POST /projects/<name>/tasks with Bearer token. Loopback only.';

  @override
  String get descriptionLockedElements =>
      'What an agent cannot change or delete without asking your permission first. The lock is set from each item; here you see them all together.';

  @override
  String get labelLockedElements => 'Locked Elements';

  @override
  String get labelAboutKeel => 'About Keel';

  @override
  String get labelGlobal => 'global';

  @override
  String get labelWhatExecutes => 'What executes';

  @override
  String get labelChat => 'Chat';

  @override
  String get labelMap => 'Map';

  @override
  String get labelEngine => 'ENGINE';

  @override
  String get labelTurns => 'TURNS';

  @override
  String get labelInput => 'INPUT';

  @override
  String get labelOutput => 'OUTPUT';

  @override
  String get labelCacheRead => 'CACHE READ';

  @override
  String get labelSecretsEnv => 'Secrets (env)';

  @override
  String get labelSource => 'Source';

  @override
  String get labelAssistant => 'Assistant';

  @override
  String labelCompactContext(int percent) {
    return 'Compact context ($percent%)';
  }

  @override
  String get labelRequired => 'Required';

  @override
  String get labelOptional => 'Optional';

  @override
  String get labelDiff => 'Diff';

  @override
  String get labelEdit => 'Edit';

  @override
  String get labelView => 'View';

  @override
  String get labelAdaptiveCapabilities => 'Adaptive Capabilities';

  @override
  String get labelMandatoryContext => 'Mandatory Context';

  @override
  String labelReplansLimit(int count) {
    return 'Replans limit: $count';
  }

  @override
  String labelReadVerifySubagents(int count) {
    return 'Read/verify subagents: $count';
  }

  @override
  String labelSharedAuditCycles(int count) {
    return 'Shared audit cycles: $count';
  }

  @override
  String labelAgentFor(String capability) {
    return 'Agent for \"$capability\"';
  }

  @override
  String get buttonNew => 'New';

  @override
  String get buttonRegisterSkill => 'Register skill';

  @override
  String get buttonCreateSkill => 'Create skill';

  @override
  String get buttonReplace => 'Replace';

  @override
  String get buttonImport => 'Import';

  @override
  String get buttonRegenerateToken => 'Regenerate token';

  @override
  String get buttonViewLocked => 'View locked…';

  @override
  String get buttonAskKeelAI => 'Ask Keel AI';

  @override
  String get buttonCreateManually => 'Create manually';

  @override
  String get buttonRename => 'Rename';

  @override
  String get buttonUngroupGroup => 'Ungroup';

  @override
  String get buttonRegisterSecret => 'Register secret';

  @override
  String get buttonLoadValue => 'Load value';

  @override
  String get buttonNewSession => 'New session';

  @override
  String get buttonChooseFolder => 'Choose folder';

  @override
  String get buttonReviewAgain => 'Review again';

  @override
  String get buttonDefineFormat => 'Define the format';

  @override
  String get buttonDocumentation => 'Documentation';

  @override
  String get buttonTestConnection => 'Test the connection';

  @override
  String get buttonRegisterMCP => 'Register MCP';

  @override
  String get buttonChoose => 'Choose…';

  @override
  String get buttonRegisterAgent => 'Register agent';

  @override
  String get buttonTest => 'Test';

  @override
  String get buttonOpenWithSystemApp => 'Open with system app';

  @override
  String get buttonReturnToAgentDefault => 'Return to agent default';

  @override
  String get buttonReview => 'Review';

  @override
  String get buttonRebuildAndReopen => 'Rebuild and reopen';

  @override
  String get buttonExport => 'Export…';

  @override
  String get buttonImportDots => 'Import…';

  @override
  String get buttonBackup => 'Backup';

  @override
  String get buttonBackupAndUpload => 'Backup and upload';

  @override
  String get buttonRestoreDots => 'Restore…';

  @override
  String get buttonBring => 'Bring';

  @override
  String get buttonInstall => 'Install';

  @override
  String get buttonAsk => 'Ask…';

  @override
  String get buttonClear => 'Clear';

  @override
  String get buttonView => 'View';

  @override
  String get buttonApproveChange => 'Approve change';

  @override
  String get buttonAddRule => 'Add rule';

  @override
  String get buttonAddKnowledge => 'Add knowledge';

  @override
  String get buttonApproveAndContinue => 'Approve and continue';

  @override
  String get buttonOpen => 'Open';

  @override
  String get buttonNewKnowledgeBase => 'New knowledge base';

  @override
  String get buttonContinuePlanning => 'Continue planning';

  @override
  String get buttonImplement => 'Implement';

  @override
  String get buttonRegister => 'Register';

  @override
  String get buttonReloadFromDisk => 'Reload from disk';

  @override
  String get buttonClose => 'Close';

  @override
  String get buttonReject => 'Reject';

  @override
  String get buttonAssignAndEvaluate => 'Take and evaluate';

  @override
  String get buttonGoToSession => 'Go to session';

  @override
  String get buttonRejectAndExplain => 'Reject and explain';

  @override
  String get messageNoSkillsRegistered =>
      'You haven\'t registered any skills yet.';

  @override
  String get messageNoToolsRegistered =>
      'You haven\'t registered any tools yet.';

  @override
  String get messageNoRulesRegistered =>
      'You haven\'t registered any rules yet.';

  @override
  String get messageApiNotRunning => 'The API is not running in this window.';

  @override
  String messageApiUrl(int port) {
    return 'URL: http://127.0.0.1:$port';
  }

  @override
  String messageApiToken(String token) {
    return 'Token: $token';
  }

  @override
  String get messageBoardNotFound => 'That board no longer exists.';

  @override
  String get messageNoBoardsYet => 'No boards yet';

  @override
  String get messageNoHooksRegistered =>
      'You haven\'t registered any hooks yet.';

  @override
  String get messageNoExternalMCPs =>
      'You haven\'t registered any external MCPs yet.';

  @override
  String get messageNoProjectsRegistered =>
      'You haven\'t registered any projects yet.';

  @override
  String get messageNoAgentsRegistered =>
      'You haven\'t registered any agents yet.';

  @override
  String get messageNoWorkflowsRegistered =>
      'You haven\'t registered any workflows yet.';

  @override
  String get messageNoneYet => 'None yet.';

  @override
  String get messageNoMoreAgentsToAdd => 'No more agents to add.';

  @override
  String messageCouldNotOpenImage(String error) {
    return 'Could not open the image: $error';
  }

  @override
  String get messageSessionNotFound => 'The session no longer exists.';

  @override
  String messageDrop(String name) {
    return 'Drop $name';
  }

  @override
  String get messageFileTooLarge => 'File is too large to show a diff.';

  @override
  String get messageAskYourAgent => 'Ask your agent something';

  @override
  String get messageNoKnowledgeBases => 'There are no knowledge bases yet.';

  @override
  String get messageBackupEmpty => 'The backup brings nothing applicable.';

  @override
  String get optionCommand => 'A command';

  @override
  String get optionRegisteredTool => 'A registered tool';

  @override
  String get optionGiveToKeelAI => 'Give it to Keel AI (the assistant)';

  @override
  String get optionIMaintainIt => 'I maintain it';

  @override
  String optionUseDefault(String role) {
    return 'Use default ($role)';
  }

  @override
  String get optionAnyMember => 'Any member';

  @override
  String get optionNewSession => 'New session';

  @override
  String get optionResumeParentSession => 'Resume parent session';

  @override
  String get optionProviderSubagent => 'Provider subagent';

  @override
  String get optionManualApproval => 'Manual approval';

  @override
  String optionAgentProvider(String provider) {
    return 'Agent\'s ($provider)';
  }

  @override
  String optionAgentEffort(String effort) {
    return 'Agent\'s ($effort)';
  }

  @override
  String get titleReadOnly => 'Read-only';

  @override
  String get titleRequiresIndependentAgent => 'Requires independent agent';

  @override
  String get subtitleReadOnly => 'Planners and auditors do not write.';

  @override
  String get linkWebsite => 'jhonacode.com';

  @override
  String get linkCommunity => 'Community on Discord';

  @override
  String get tooltipRegisterNew => 'Register new';

  @override
  String get tooltipImportPackage => 'Import a package';

  @override
  String get tooltipDismiss => 'Dismiss';

  @override
  String get messageNoHooksDescription =>
      'A hook is a command that runs at a point in a turn and that an agent cannot skip: it can stop a tool before use or react afterward. A rule asks; a hook guarantees.';

  @override
  String get labelLlmProviders => 'LLM PROVIDERS';

  @override
  String get labelOtherSecrets => 'OTHER SECRETS';

  @override
  String get suggestionIntro =>
      'I noticed things you ask for repeatedly — shall we turn them into global skills?';

  @override
  String suggestionDraftHeader(int count) {
    return 'Recurring instruction detected ($count times). Examples of what you asked for:\\n';
  }

  @override
  String get suggestionDraftFooter => 'Write the final instruction here:';

  @override
  String get formTitleRegisterAgent => 'Register agent';

  @override
  String get formTitleEditAgent => 'Edit registered agent';

  @override
  String get formLabelAgentName => 'Name (lowercase, no spaces, max 16)';

  @override
  String get formLabelAgentRole => 'Role';

  @override
  String get formLabelAgentRoleHint => 'What this agent does';

  @override
  String get formLabelSystemPrompt => 'System prompt';

  @override
  String get formLabelProvider =>
      'Provider (codex: no tools/MCPs/effort, and its own models)';

  @override
  String formLabelModel(String provider) {
    return 'Default model ($provider)';
  }

  @override
  String get formLabelEffort => 'Default effort';

  @override
  String get formMessageCanManageSystem => 'Can manage the system';

  @override
  String get formDescriptionManageSystem =>
      'Builder agent: receives the same creation tools as Keel AI (skills, rules, tools, agents, workflows, projects) in its 1:1 chats.';

  @override
  String get formDescriptionKeelAiHooks =>
      'Keel AI runs without hooks on purpose: it\'s who you ask to disable one that\'s stuck. What you assign here won\'t apply.';

  @override
  String get formDescriptionHooks =>
      'They run outside the model, so it can\'t skip them. The rules above are requested; these are enforced.';

  @override
  String get formDescriptionRoles =>
      'Roles your workflows ask for — pick one so this agent covers them:';

  @override
  String get formDescriptionRolesHelp =>
      'Workflow preflight looks for responsibles by this role.';

  @override
  String formConfirmDeleteAgent(Object name) {
    return 'The \"$name\" registration will be deleted. This doesn\'t affect chats you already had with this setup.';
  }

  @override
  String get formTitleDeleteAgent => 'Delete registered agent';

  @override
  String get tooltipEditAgent => 'Edit';

  @override
  String get tooltipExportAsPackage => 'Export as package';

  @override
  String get tooltipDeleteAgent => 'Delete';

  @override
  String get mapStateWaiting => 'Waiting for you';

  @override
  String get mapStateFailed => 'Failed';

  @override
  String get labelAskedFor => 'Asked for';

  @override
  String get labelHowReasons => 'How it reasons';

  @override
  String get statusLive => 'Live';

  @override
  String get labelWhatDid => 'What it did';

  @override
  String get labelWhatReturned => 'What it returned';

  @override
  String get labelTask => 'Task';

  @override
  String get labelWhatResolved => 'What it resolved';

  @override
  String get labelAskedAbout => 'Asked about';

  @override
  String get labelNumbers => 'Numbers';

  @override
  String get labelMemberOpened => 'Member who opened it';

  @override
  String placeholderWriteTo(String name) {
    return 'Write to @$name…';
  }

  @override
  String get messageNoReasoningVisible =>
      'Did not leave visible reasoning. With models that don\'t emit it, there\'s nothing to show here.';

  @override
  String get messageNodeNotResolution =>
      'This node is not part of a resolution case: it only speaks when consulted.';

  @override
  String get messageNoReasoningYet => 'No reasoning shown yet at this step.';

  @override
  String get messageNodeNotMember =>
      'This node is no longer a project member, so there\'s no one to write to.';

  @override
  String get messageNoConsultRecord =>
      'Not recorded which phrase was used to call it.';

  @override
  String get messageNoToolsOpened => 'No tools have been opened yet.';

  @override
  String messageSubagentWriteLocked(String parent) {
    return 'While running, you cannot write to a subagent: the CLI doesn\'t open that channel. What you write below goes to $parent, who opened it.';
  }

  @override
  String get formLabelHookName => 'Name';

  @override
  String get formHintHookScript =>
      'Also the name of the script that will be generated.';

  @override
  String get formLabelWhatHookDoes => 'What it does';

  @override
  String get formMessageNoEventFilter =>
      'This event doesn\'t filter: leave it empty.';

  @override
  String formHintEventFilter(String matcherHint) {
    return 'Empty = all. Examples: $matcherHint';
  }

  @override
  String get formDescriptionHookScope =>
      'Brief on purpose: a \"before tool use\" hook: if you reject it, it won\'t be called. A \"after\" one is rarer.';

  @override
  String get formLabelHookRules => 'Which rules does this hook enforce';

  @override
  String get formDescriptionHookRules =>
      'Changes nothing about what runs: just marks which of your rules are guaranteed and which are just asked.';

  @override
  String get formLabelWhenHookRuns => 'When it runs';

  @override
  String get formLabelWhatHookExecutes => 'What it executes';

  @override
  String get messageNoToolsRegisteredShort =>
      'You haven\'t registered any tools yet.';

  @override
  String get formDescriptionHookCode =>
      'Code travels in backups and can use the secrets you set up. If the admin doesn\'t allow write, a hook from disk won\'t restore on another machine.';

  @override
  String get formLabelHookTimeout => 'Timeout (seconds)';

  @override
  String get formDescriptionHookTimeout =>
      'Receives the event as JSON on stdin. Exiting with code 2 blocks.';

  @override
  String get pageTitleMachineTitle => 'Machine';

  @override
  String get messageDetectionNotIntegration =>
      'Detecting is not integrating: those that say \"no adapter\" are on your machine but Keel still doesn\'t know how to talk to them, and can\'t be asked to do it alone.';

  @override
  String get labelConsumption => 'Consumption · last 14 days';

  @override
  String get messageNoConsumptionYet =>
      'Nothing measured yet. History starts today: until now, the counters for each turn were read for the context percentage and thrown away, so there\'s no way to know what was spent where. History starts on the day this screen was installed.';

  @override
  String get labelCacheReadShort => 'CACHE READ';

  @override
  String get messageNoTokenCount =>
      'No measurement — its CLI doesn\'t report tokens';

  @override
  String labelCoresShort(int cores) {
    return '$cores cores';
  }

  @override
  String get messageNotInPath => 'Not in the PATH';

  @override
  String get formLabelWorkflowIntent => 'Intent and when it applies';

  @override
  String get formDescriptionWorkflowEngine =>
      'The engine decides the minimum nodes; you don\'t configure a chain of agents.';

  @override
  String labelMaxReplans(int count) {
    return 'Replan limit: $count';
  }

  @override
  String labelMaxSubagents(int count) {
    return 'Read/verify subagents: $count';
  }

  @override
  String labelMaxReviewCycles(int count) {
    return 'Shared audit cycles: $count';
  }

  @override
  String get formLabelWorkflowTitle => 'Visible title';

  @override
  String get formLabelWorkflowInstruction => 'Instruction';

  @override
  String get formLabelWorkflowActivation => 'Activation';

  @override
  String get formLabelWorkflowExecution => 'Execution';

  @override
  String get formDescriptionParentSessionKept =>
      'The parent session is kept and resumed.';

  @override
  String get formLabelMaxAgenticTurns => 'Maximum agentic turns';

  @override
  String get formDescriptionMaxAgenticTurns =>
      'Empty or 0 uses the provider limit.';

  @override
  String get formLabelWorkflowOwner => 'Owner';

  @override
  String get formDescriptionWorkflowOwner =>
      'The owner must be different from those who produced its dependencies.';

  @override
  String get formLabelWorkflowResponsible => 'Responsible for resolution';

  @override
  String get formDescriptionResponsible =>
      'A responsible integrates evidence and is the only writer.';

  @override
  String get workflowKindMigration => 'Migration';

  @override
  String labelAge(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get labelWeekdayShort => 'Mon, Tue, Wed, Thu, Fri, Sat, Sun';

  @override
  String messageRequirementTaken(String handle) {
    return 'Taken by @$handle';
  }

  @override
  String messageRequirementTask(String taskPath) {
    return 'Became a task: $taskPath';
  }

  @override
  String get messagePlanMode =>
      'Plan mode: propose how they would do it. To actually implement it, \"Take and evaluate\" opens a session.';

  @override
  String get messageRequirementAnswering => 'Answering…';

  @override
  String get messagePlanRequest => 'Ask for a plan — @ to call an agent';

  @override
  String get messageWriteHere => 'Write here — @ to ask an agent';

  @override
  String get messageRequirementClosed => 'The recipient asked for closure.';

  @override
  String get messageOnlyOriginCanClose =>
      'Only the side that opened it can close — they know if what they needed is there.';

  @override
  String get labelWithWorkflow => 'With which workflow to evaluate';

  @override
  String messageNewSessionOpenedWorkflow(String workflowName) {
    return 'Will open a new session in #$workflowName. Choose the row below for each role.';
  }

  @override
  String get formLabelWhatMissing => 'What\'s missing';

  @override
  String get bundleExportNothingYet => 'Nothing to export yet.';

  @override
  String get bundleSectionWhatItTakes => 'What it takes';

  @override
  String get bundleSectionWhatItBrings => 'What it brings';

  @override
  String get bundleSectionWhatRecipientSees => 'What the recipient will see';

  @override
  String get bundleSectionSecurityReview => 'Security review';

  @override
  String get bundleNoFindings => 'no findings';

  @override
  String bundleFindingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count findings',
      one: '1 finding',
    );
    return '$_temp0';
  }

  @override
  String bundleMissingNote(String list) {
    return 'This is named but doesn\'t exist on this side, so it won\'t travel:\n$list';
  }

  @override
  String bundleSecretsToCreateNote(String names) {
    return 'Whoever installs it will need to create these secrets with these names: $names. The values don\'t travel.';
  }

  @override
  String get actionImportPackage => 'Import a package';

  @override
  String get bundleImportIntro =>
      'A package brings an agent, a workflow or a skill with everything it needs to work: its skills, its rules, its tools, its hooks, its MCP servers and its documentation.';

  @override
  String get bundleImportSafetyNote =>
      'Nothing is installed before you see what it brings and what the review found.';

  @override
  String get actionChooseFile => 'Choose a file';

  @override
  String get bundleOrFromLink => 'or from a link';

  @override
  String get bundleLinkHint => 'https://…/keel-agent-flutter-expert.zip';

  @override
  String get actionBring => 'Bring';

  @override
  String get bundleDocumentsLabel => 'documents';

  @override
  String bundleSecretsRequiredNote(String names) {
    return 'It needs these secrets, which you have to create yourself with these names: $names. A package never brings values.';
  }

  @override
  String get actionInstall => 'Install';

  @override
  String bundleHighRiskAck(int count) {
    return 'I read the $count high-severity findings and want to install it anyway.';
  }

  @override
  String bundleAuditCleanNote(int count) {
    return 'I reviewed $count pieces of text and found nothing known. This isn\'t a guarantee: it only searches for what it knows to search for.';
  }

  @override
  String bundleRiskLevelLabel(String level) {
    return 'SEVERITY $level';
  }

  @override
  String get actionSaveAsPng => 'Save as PNG';

  @override
  String codeBlockLineCount(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
    );
    return '$title · $_temp0';
  }

  @override
  String get semanticsOpenImageFullSize => 'Attached image, open at full size';

  @override
  String get tooltipOpenFullSize => 'Open at full size';

  @override
  String get messageImageUnavailable => 'Image unavailable';

  @override
  String get labelDeletedProject => 'deleted project';

  @override
  String labelOpenSince(String age) {
    return 'open for $age';
  }

  @override
  String get labelBlockingRequester => 'blocks whoever asks';

  @override
  String durationMinutesShort(int count) {
    return '$count min';
  }

  @override
  String durationHoursShort(int count) {
    return '$count h';
  }

  @override
  String durationDaysShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get messageTakenByYou => 'You took it';

  @override
  String get labelVerdict => 'VERDICT';

  @override
  String get tooltipPlanModeActive =>
      'Plan mode active: proposes instead of asserting';

  @override
  String messageNewRequirementSessionNote(String workflowName) {
    return 'It\'s going to open a new session in #$workflowName. Choose the row of agents that matches this request — evaluating a requirement is rarely the same as resolving a ticket.';
  }

  @override
  String get labelProjectNoLongerExists => 'a project that no longer exists';

  @override
  String get assistantWindowTitle => 'Assistant';

  @override
  String get buttonAskKeelAi => 'Ask Keel AI';

  @override
  String get buttonCreateByHand => 'Create by hand';

  @override
  String get buttonOverwriteAnyway => 'Overwrite anyway';

  @override
  String get hintAskAboutThisLine => 'Ask about this line…';

  @override
  String get hintQueuedMessage => 'Message that will be sent on the next turn';

  @override
  String get hintSessionName => 'Session name';

  @override
  String get labelCloseSession => 'Close session';

  @override
  String get labelDeleteIntegration => 'Delete integration';

  @override
  String get labelFileChanged => 'The file changed';

  @override
  String get labelGiveToKeelAi => 'Give it to Keel AI (the assistant)';

  @override
  String get labelHeadersKeyValue => 'Headers (KEY=value, one per line)';

  @override
  String get labelKnowledgeBaseAnswers => 'What this base answers';

  @override
  String labelModelWithProvider(String provider) {
    return 'Model ($provider)';
  }

  @override
  String labelMaxReplansLimit(int count) {
    return 'Replan limit: $count';
  }

  @override
  String labelMaxReviewCyclesLimit(int count) {
    return 'Shared audit cycles: $count';
  }

  @override
  String labelMaxSubagentsLimit(int count) {
    return 'Read/verification subagents: $count';
  }

  @override
  String labelIdleTimeoutLimit(int count) {
    return 'Minutes without provider activity before a step is cut: $count';
  }

  @override
  String labelNodeTimeoutLimit(int count) {
    return 'Maximum minutes per step: $count';
  }

  @override
  String labelSessionCostLimit(int amount) {
    return 'Session cost ceiling in USD (0 = no ceiling): $amount';
  }

  @override
  String get labelNoBoardsYet => 'No boards yet';

  @override
  String get labelNoSessionOpen => 'No session open';

  @override
  String get labelPasteBlockAsInDocs =>
      'Paste the block exactly as shown in the docs';

  @override
  String get labelPasteMcpConfig => 'Paste an MCP configuration';

  @override
  String get labelProjectPurpose => 'Purpose';

  @override
  String get labelRequirementContext =>
      'Context: what they did and why they need it';

  @override
  String get labelRequirementNeed => 'What is needed';

  @override
  String get labelRequirementTitle => 'Title';

  @override
  String get labelSessionAgents => 'Agents for this session';

  @override
  String get labelSpecification => 'Specification';

  @override
  String get labelTermsOfUse => 'Terms of use';

  @override
  String get labelWhichWorkflowRuns => 'Which workflow runs';

  @override
  String messageCloseSessionBody(String title) {
    return 'This deletes the thread of \"$title\" and the context the agents built up in it. The project stays the same, with its agents, rules, and documents.';
  }

  @override
  String messageDeleteIntegrationBody(String name) {
    return '\"$name\" gets deleted. Agents that had it assigned stop receiving its tools.';
  }

  @override
  String get messageFileChangedBody =>
      'This file was modified (for example, the agent edited it) since you opened this window. If you save now, you will overwrite that change with what you have here.';

  @override
  String get messageNoAgentsToAdd => 'No more registered agents to add';

  @override
  String get messageNoBoardsExplainer =>
      'A board is a small screen for triggering something against your own app: launch an offer, send yourself a push, hit an endpoint you\'re writing.\n\nThe fastest way is to ask a project agent for it: it reads your code and builds it on its own. It shows up in that project\'s Boards section.';

  @override
  String get messageNoExtraAgentsYet => 'None yet.';

  @override
  String get messageNoKnowledgeBasesYet => 'No knowledge base yet.';

  @override
  String get messageNoMcpServersRegistered => 'No external MCP registered yet.';

  @override
  String get messageSessionGone => 'The session no longer exists.';

  @override
  String get messageWhichWorkflowRunsNote =>
      'This session, and no other. A project does jobs of different kinds — building the task folder, resolving a ticket, evaluating a requirement — and each one wants a different row of agents.';

  @override
  String get sectionAddToSession => 'Add to this session';

  @override
  String get sectionProjectMembers => 'Project members (in every session)';

  @override
  String get sectionSessionOnly => 'Only in THIS session';

  @override
  String get tooltipAgentAnsweringThread =>
      'An agent is answering in the thread';

  @override
  String get tooltipGoToLatestMessage => 'Go to the most recent message';

  @override
  String get tooltipGuardrailsAutorun => 'Guardrails that run on their own';

  @override
  String get tooltipLegendMeaning => 'What each line means';

  @override
  String get tooltipNewConversation => 'New conversation';

  @override
  String get tooltipRefreshCatalog => 'Refresh catalog';

  @override
  String get tooltipRemoveFromSession => 'Remove from this session';

  @override
  String get tooltipRunsCommandsOnYourMachine =>
      'Runs commands on your machine';

  @override
  String get tooltipWorkingNow => 'Working now';

  @override
  String get workflowTitleTaskFormat => 'Build the task format';

  @override
  String get workflowTitleVerifyFormat => 'Verify format';

  @override
  String get workflowTitlePlanAndScope => 'Plan and scope';

  @override
  String get workflowTitleSingleEntryPoint => 'Design the single entry point';

  @override
  String get workflowTitleImplement => 'Implement with evidence';

  @override
  String get workflowTitleCodeAudit => 'Audit code';

  @override
  String get workflowTitleCodeCorrection => 'Fix code findings';

  @override
  String get workflowTitleTests => 'Create and adjust tests';

  @override
  String get workflowTitleTestAudit => 'Audit tests';

  @override
  String get workflowTitleTestCorrection => 'Fix test findings';

  @override
  String get workflowTitleDeviceE2e => 'End-to-end verification on device';

  @override
  String get workflowTitleVerification => 'Closing verification';

  @override
  String get workflowTitlePublishApproval => 'Approve publication';

  @override
  String get termsVersion => 'Version 1 — August 2026';

  @override
  String get termsSection1Title => '1. What Keel is';

  @override
  String get termsSection1Body =>
      'Keel is a desktop tool that works on top of the agent CLIs you already have installed on your machine. It isn\'t a service: there\'s no Keel server you connect to, no account to create, and no registration. If you turn off the internet, Keel still opens.\n\nUsing Keel means accepting these terms. If you disagree with any of them, don\'t use it.';

  @override
  String get termsSection2Title => '2. Who owns it';

  @override
  String get termsSection2Body =>
      'Keel — its code, its design, its name, its documentation and everything that comes with it — is the intellectual property of Jhonatan Ortiz (JhonaCode), software engineer. All rights reserved.\n\nIt is not free or open-source software. It isn\'t distributed under MIT, Apache, BSD, GPL, or any other permissive license. Having a copy doesn\'t give you the right to use it: you need the author\'s written permission. The full text is in the LICENSE file.';

  @override
  String get termsSection3Title => '3. Only downloadable from jhonacode.com';

  @override
  String get termsSection3Body =>
      'The author exclusively reserves the right to distribute Keel. The ONLY authorized channel is jhonacode.com.\n\nRepublishing, mirroring, uploading to another site, including it in a package repository, an app store, a container image, or any other distribution channel — free or paid — is prohibited. Keel also can\'t be resold, rented, sublicensed, or offered as a service to third parties.';

  @override
  String get termsSection4Title => '4. Copies that didn\'t come from there';

  @override
  String get termsSection4Body =>
      'Any copy of Keel obtained outside jhonacode.com is unauthorized, and the author has no way of knowing what was done to it: it may have been modified, bundled with something else, or altered to do something Keel doesn\'t do.\n\nThe author isn\'t responsible for those copies or what they cause, and nothing they do can be attributed to the author. A build modified by a third party isn\'t Keel, even if it\'s called that. If what runs on your machine matters to you, download it from the official site.';

  @override
  String get termsSection5Title => '5. Keel doesn\'t ask for your data';

  @override
  String get termsSection5Body =>
      'It doesn\'t ask for your name, email, passwords, or any keys. There\'s no login. Everything you set up — projects, agents, skills, tools, knowledge bases, chat threads, and settings — is stored on your own machine.\n\nYour secret values never leave in a backup: the backup only carries the names, so you know which ones to fill in on the other end. The scheduled-jobs API only listens on loopback, meaning it can\'t be reached from outside your machine.';

  @override
  String get termsSection6Title =>
      '6. The only thing that does leave your machine';

  @override
  String get termsSection6Body =>
      'If this build ships with a reporting channel configured, when something breaks it\'s sent to that channel: the error message, its trace, the Keel file where it happened, your team\'s name, and whether the build is development or production.\n\nNothing else is sent. Not your chat content, not your files, not your secrets, not what projects you have. It serves one purpose: letting whoever maintains Keel know something failed.';

  @override
  String get termsSection7Title =>
      '7. Keel is a tool, and you\'re the one steering it';

  @override
  String get termsSection7Body =>
      'Keel launches agents with the permissions you give them, and those permissions can include full access to your disk. An agent can create, modify, and delete files, run commands, and make commits to your repositories.\n\nYou decide which permissions to grant, over which folders, and what you ask each agent to do. Keel executes those decisions; it doesn\'t make them for you and doesn\'t supervise them. The author isn\'t responsible for how you use the tool or for the consequences of what agents do following your instructions.';

  @override
  String get termsSection8Title =>
      '8. Your files are yours, and so are your backups';

  @override
  String get termsSection8Body =>
      'A tool that gives an agent access to your disk can end up with files lost, overwritten, or changed in a way you didn\'t want. That can happen through a Keel bug, an agent error, or an instruction of yours that turned out differently than you intended.\n\nKeeping backups of what matters to you is your responsibility. The author isn\'t liable for data loss or corruption.';

  @override
  String get termsSection9Title => '9. Not for critical uses';

  @override
  String get termsSection9Body =>
      'Keel isn\'t designed or tested for environments where a failure would put life, health, safety, or essential infrastructure at risk: medicine, aviation, transportation, energy, industrial control, or similar. Don\'t use it there.';

  @override
  String get termsSection10Title => '10. What doesn\'t depend on Keel';

  @override
  String get termsSection10Body =>
      'The agent CLIs and MCP servers you use are third-party. Each has its own terms, its own prices, and its own way of handling what you send it. Keel isn\'t responsible for them, for what they charge, for what they do with the information they receive, or for what they decide to change or discontinue.\n\nComplying with those services\' terms is on you.';

  @override
  String get termsSection11Title => '11. What you agree not to do';

  @override
  String get termsSection11Body =>
      'Not copy, modify, translate, or create derivative works of Keel.\nNot reverse-engineer, decompile, or disassemble it, except where the law imperatively allows it.\nNot circumvent or disable any technical protection measure.\nNot remove or hide authorship, copyright, or license notices.\nNot use Keel\'s or JhonaCode\'s name, logo, or image without written permission.\nNot use Keel or any part of it to train machine-learning models or artificial-intelligence systems.\nNot use Keel for anything illegal, or to infringe on third-party rights.';

  @override
  String get termsSection12Title =>
      '12. If your use causes a problem for the author';

  @override
  String get termsSection12Body =>
      'If a third party makes a claim over how you used Keel, or over what you did with what it produced, that claim is yours. You agree to keep the author free from any harm, expense, or liability arising from your use of the tool or from breaching these terms.';

  @override
  String get termsSection13Title => '13. No warranty';

  @override
  String get termsSection13Body =>
      'Keel is provided AS IS and AS AVAILABLE, without warranty of any kind, express or implied. There\'s no guarantee it will run without errors or interruptions, that it will be available, that it will be compatible with your equipment or tools, or that it will serve any particular purpose.';

  @override
  String get termsSection14Title => '14. How far liability goes';

  @override
  String get termsSection14Body =>
      'To the extent the law allows, the author isn\'t liable for indirect, incidental, special, or consequential damages, nor for lost profits, data loss, lost work time, or business interruption, even if advised of that possibility.\n\nIf liability is nonetheless found, its total limit will be what you paid for Keel in the twelve months prior to the event, which in practice is zero: Keel isn\'t sold, and donations aren\'t payment for the software.';

  @override
  String get termsSection15Title => '15. Donations';

  @override
  String get termsSection15Body =>
      'If Keel is useful to you and you want to support the work, it\'s appreciated. It\'s entirely voluntary.\n\nA donation is exactly that and nothing more: it isn\'t a purchase, it isn\'t a license, it doesn\'t grant the right to use the software without permission, it doesn\'t include support, it doesn\'t give priority on anything, it doesn\'t create any obligation from the author to the donor, and it isn\'t refunded.';

  @override
  String get termsSection16Title => '16. When permission ends';

  @override
  String get termsSection16Body =>
      'Any use outside what\'s authorized immediately and without notice ends all permission granted. A previously granted permission may also be revoked. Upon termination, you must stop using Keel and delete any copies you have.\n\nThe sections on ownership, liability, warranty, and indemnity remain in effect after that.';

  @override
  String get termsSection17Title => '17. If any clause doesn\'t hold';

  @override
  String get termsSection17Body =>
      'If a court declares any part of these terms invalid or unenforceable, the rest remains in force, and that part is interpreted as closely as possible to its original intent.\n\nThe author not exercising a right at some point doesn\'t mean giving it up. There\'s no partnership, employment, franchise, or representation of any kind between Keel and you.';

  @override
  String get termsSection18Title => '18. Governing law';

  @override
  String get termsSection18Body =>
      'These terms are governed by the laws of the author\'s country of residence, and any dispute is submitted to the competent courts of that place.';

  @override
  String get termsSection19Title => '19. These terms can change';

  @override
  String get termsSection19Body =>
      'If they change, the version that applies is the one this screen shows. Continuing to use Keel after a change means you accept it.';

  @override
  String get termsSection20Title => '20. Contact';

  @override
  String get termsSection20Body =>
      'To request permission for a use, donate, report something, or any other inquiry: jhonacode.com';

  @override
  String get messageWriteToAgent => 'Write something to your agent';

  @override
  String skillAlreadyExists(String name) {
    return 'The skill \"$name\" already existed, I reused it.';
  }

  @override
  String ruleAlreadyExists(String name) {
    return 'The rule \"$name\" already existed, I reused it.';
  }

  @override
  String toolAlreadyExists(String name) {
    return 'The tool \"$name\" already existed, I reused it.';
  }

  @override
  String skillCreated(String name) {
    return 'I created the skill \"$name\".';
  }

  @override
  String ruleCreated(String name) {
    return 'I created the rule \"$name\".';
  }

  @override
  String handleReserved(String handle) {
    return 'The handle \"$handle\" is reserved.';
  }

  @override
  String get keelAiModifyBlocked =>
      'Keel AI requested to modify a locked element.';

  @override
  String formEditEntity(Object entity) {
    return 'Edit $entity';
  }

  @override
  String formRegisterEntity(Object entity) {
    return 'Register $entity';
  }

  @override
  String get formName => 'Name';

  @override
  String get formEnvironmentVariableName => 'Environment variable name';

  @override
  String get formWorkingDirectory => 'Working directory';

  @override
  String get formChoose => 'Choose…';

  @override
  String get formSave => 'Save';

  @override
  String get formCreate => 'Create';

  @override
  String get formGlobalSkill => 'Global skill';

  @override
  String get formGlobalSkillDescription =>
      'All agents receive it on every turn without assigning it.';

  @override
  String get formSkillContent => 'Content (instructions to inject)';

  @override
  String get formToolDescription =>
      'Description for the agent: what it does, when to use it, and what each positional argument means';

  @override
  String get formStoredValue => 'Value loaded  ••••••••';

  @override
  String get formNewValueKeepCurrent => 'New value (empty = keep current)';

  @override
  String get formValue => 'Value';

  @override
  String get formValueDescription =>
      'It never passes through a model. It is injected as a credential only into the provider, tool, or MCP that declares it.';

  @override
  String get formBoardDescription =>
      'The fastest option is to ask a project agent: it reads your code or OpenAPI and builds it. Use this to refine it or write it yourself.';

  @override
  String get formWorkflowName => 'Name';

  @override
  String get formWorkflowCaseType => 'Case type';

  @override
  String get formRequiredRules => 'Required rules';

  @override
  String get formRequiredKnowledgeBases => 'Required knowledge bases';

  @override
  String get formCommaSeparatedNames => 'Names separated by commas.';

  @override
  String get validationNameRequired => 'Name is required.';

  @override
  String validationMaxCharacters(Object count) {
    return 'Maximum $count characters.';
  }

  @override
  String get validationNoSpaces => 'Spaces are not allowed.';

  @override
  String get validationLowercaseOnly => 'Use lowercase letters only.';

  @override
  String get validationBoardKey =>
      'Use lowercase letters, numbers, and \"_\", starting with a letter (max. 32).';

  @override
  String get assistantWelcomeTitle => 'I am Keel AI';

  @override
  String get assistantWelcomeDescription =>
      'I can register any of these for you in the conversation. Tap an example to try it.';

  @override
  String get assistantExampleProject =>
      'Create a project to review PRs with two agents.';

  @override
  String get assistantExampleAgent =>
      'Register a security reviewer agent and assign it the skill you just created.';

  @override
  String get assistantExampleWorkflow =>
      'Create a workflow for bugs with implementation and a review gate.';

  @override
  String get assistantExampleSkill =>
      'Create a skill with this project\'s style rules.';

  @override
  String get assistantExampleRule =>
      'Add a rule that forbids obvious comments in the code.';

  @override
  String get labelEnabled => 'Enabled';

  @override
  String get labelDisabled => 'Disabled';

  @override
  String get navAssistantTooltip => 'Keel AI assistant';

  @override
  String get navRegisteredAgents => 'Registered agents';

  @override
  String get navTestBoards => 'Test boards';

  @override
  String get navMcpIntegrations => 'MCP integrations';

  @override
  String get navKnowledge => 'Knowledge';

  @override
  String get navMachine => 'Machine';

  @override
  String get navBackup => 'Backup';

  @override
  String get navSettings => 'Settings';

  @override
  String get mapLaneBack => 'back';

  @override
  String get mapLaneForward => 'forward';

  @override
  String get mapLaneDelegate => 'delegate';

  @override
  String get mapViewQuery => 'View the full query';

  @override
  String get mapZoomOut => 'Zoom out  ⌘−';

  @override
  String get mapZoomIn => 'Zoom in  ⌘+';

  @override
  String get mapFit => 'Fit everything on screen  ⌘0';

  @override
  String get mapFollow => 'Follow the node taking its turn';

  @override
  String get mapHelp => 'drag = pan · ⌘ + scroll = zoom';

  @override
  String get mapEmptyTitle => 'This project has no nodes to map yet';

  @override
  String get mapEmptyDescription =>
      'Add members and a workflow. The map opens with the roster in place, idle, before anything runs.';

  @override
  String get chatCreateSession => 'Create a session to get started';

  @override
  String get chatAskForPlan => 'Ask for a plan…';

  @override
  String chatSessionPrompt(Object project) {
    return 'What do you need in this #$project session?';
  }

  @override
  String chatMessagePrompt(Object project) {
    return 'Message to #$project';
  }

  @override
  String get chatStop => 'Stop';

  @override
  String get chatQueue => 'Queue for later';

  @override
  String get chatSend => 'Send';

  @override
  String get chatSessionsCreatedByButton =>
      'Sessions are created with the \"New session\" button.';

  @override
  String get chatRunsPreflight =>
      'The workflow preflight runs in this session.';

  @override
  String get chatQueueHelp =>
      'You can queue messages, schedule them for the end of the turn, or interrupt and send them now.';

  @override
  String get chatWorkflowHelp =>
      'The workflow coordinates the graph. Write whenever you want to correct the course; it is recorded on the active node.';

  @override
  String get chatReferencesHelp =>
      'References: / directories · @ agents · \$ skills and rules · # knowledge';

  @override
  String get labelNoOpenSession => 'No session open';

  @override
  String labelSessionTitle(Object title) {
    return 'Session: $title';
  }

  @override
  String labelContextUsage(Object percent) {
    return 'context $percent%';
  }

  @override
  String assistantLegacyBlocked(Object names) {
    return 'The automatic block was not executed: it tried to change locked elements ($names). Use the MCP tools with change_intent and change_reason to request permission.';
  }

  @override
  String assistantSkillExists(Object name) {
    return 'The skill \"$name\" already existed; I reused it.';
  }

  @override
  String assistantSkillCreated(Object name, Object suffix) {
    return 'I created the skill \"$name\"$suffix.';
  }

  @override
  String assistantRuleExists(Object name) {
    return 'The rule \"$name\" already existed; I reused it.';
  }

  @override
  String assistantRuleCreated(Object name) {
    return 'I created the rule \"$name\".';
  }

  @override
  String assistantToolExists(Object name) {
    return 'The tool \"$name\" already existed; I reused it.';
  }

  @override
  String assistantToolCreated(Object name, Object runtime) {
    return 'I created the tool \"$name\" ($runtime).';
  }

  @override
  String assistantAgentCreated(Object details, Object handle) {
    return 'I registered @$handle.$details';
  }

  @override
  String assistantAgentUpdated(Object details, Object handle) {
    return 'I updated @$handle.$details';
  }

  @override
  String assistantWorkflowCreated(Object kind, Object name) {
    return 'I created the workflow \"$name\" ($kind).';
  }

  @override
  String assistantProjectCreated(Object name) {
    return 'I created the project \"$name\".';
  }

  @override
  String updateAvailable(Object version) {
    return 'New version $version available. Click to download.';
  }

  @override
  String get readingInstalledVersion => 'Reading installed version';

  @override
  String reviewVersion(Object version) {
    return 'Keel $version. Click to check.';
  }

  @override
  String get faultsLabel => 'Faults';

  @override
  String get faultsNone => 'Nothing broken — all clear';

  @override
  String get faultsOne => '1 unseen fault';

  @override
  String faultsMany(Object count) {
    return '$count unseen faults';
  }

  @override
  String get machineUpdateAvailable => 'A new Keel version is available';

  @override
  String get machineStatus => 'Services, usage, and machine status';

  @override
  String get machineOneWork => '1 job in progress';

  @override
  String machineManyWork(Object count) {
    return '$count jobs in progress';
  }

  @override
  String get backupBusy => 'Backing up';

  @override
  String get backupLabel => 'Backup';

  @override
  String get backupSaving => 'Writing the backup without interrupting you';

  @override
  String get backupReady => 'Backup is current and uploaded remotely';

  @override
  String get mapLegend => 'Legend';

  @override
  String get fileTypeImages => 'Images';

  @override
  String get chatFilterSystem => 'system';

  @override
  String get chatFilterSubagents => 'subagents';

  @override
  String get chatFilterAll => 'all';

  @override
  String chatStepLabel(Object title) {
    return 'step: $title';
  }

  @override
  String get chatNoticeWarningTitle => 'Warning';

  @override
  String get chatNoticeFailureTitle => 'Failure';

  @override
  String get chatNoticeInfoTitle => 'Note';

  @override
  String chatRetryStep(Object title) {
    return 'Retry «$title»';
  }

  @override
  String get buttonDeleteAgent => 'Delete agent';

  @override
  String deleteAgentConfirmation(Object name) {
    return '\"$name\" and its chat history will be deleted.';
  }

  @override
  String get emptyProjectsHint =>
      'None yet. Create one so multiple agents can work on the same repo.';

  @override
  String get emptyAgentsHint =>
      'None open. Use a registered agent to talk to it directly, without a project.';

  @override
  String get filesystemAccessTitle => 'Give access to the entire file system';

  @override
  String filesystemAccessBody(Object name) {
    return '\"$name\" will be able to read and write in any folder on the computer, not only your user folder.';
  }

  @override
  String get filesystemAccessGrant => 'Give access';

  @override
  String get filesystemAccessEnabledTooltip =>
      'Has access to the entire file system (click to remove it)';

  @override
  String get filesystemAccessGrantTooltip =>
      'Give access to the entire file system';

  @override
  String get noOpenRequirements => 'No open requirements in either direction.';

  @override
  String get labelSubagents => 'subagents';

  @override
  String get useAgentTitle => 'Use an agent';

  @override
  String get filesystemAccessSubtitle =>
      'This is decided here, not when registering the agent: the same agent can have different permissions depending on where you use it.';

  @override
  String get chatHintStreaming => 'It will be sent when the turn ends…';

  @override
  String get chatHintPlan => 'Ask for a plan…';

  @override
  String get chatHintMessage => 'Write a message…';

  @override
  String get noAgentsTitle => 'No agents registered yet';

  @override
  String get noAgentsDescription =>
      'Register one to make it available everywhere: for direct conversations, projects, and workflow steps that find agents by role.';

  @override
  String get sidebarSectionProjects => 'Projects';

  @override
  String get sidebarSectionSessions => 'Sessions';

  @override
  String get sidebarSectionStatus => 'Status';

  @override
  String get sidebarSectionLooseAgents => 'LOOSE AGENTS';

  @override
  String get sidebarTooltipManageAgents => 'Register or edit agents';

  @override
  String get sidebarTooltipUseAgent => 'Use a registered agent';

  @override
  String get sidebarTooltipManageProjects => 'Manage projects';

  @override
  String get sidebarTooltipNewProject => 'New project';

  @override
  String get sidebarHintProjectName => 'Project name';

  @override
  String get sidebarTooltipReadOnlyProject => 'I do not maintain it: read-only';

  @override
  String get sidebarTooltipOneSessionWorking => 'One session working';

  @override
  String sidebarTooltipSessionsWorking(int count) {
    return '$count sessions working';
  }

  @override
  String get sidebarSectionBoards => 'Boards';

  @override
  String get sidebarNewBoard => 'New board';

  @override
  String get sidebarTooltipDeleteBoard => 'Delete board';

  @override
  String get sidebarSectionRequirements => 'REQUIREMENTS';

  @override
  String get sidebarTooltipAllRequirements => 'All requirements';

  @override
  String get sidebarTooltipOpenRequirement => 'Open a requirement';

  @override
  String get sidebarRequirementsEmpty =>
      'None. They show up here when one project needs something from another.';

  @override
  String get panelTitleInProgress => 'WORKFLOW IN PROGRESS';

  @override
  String get panelNoWorkflowSelected =>
      'This project has no workflow selected.';

  @override
  String panelProgressOf(int done, int active) {
    return '$done of $active';
  }

  @override
  String panelReviewCycles(int done, int max) {
    return 'audits $done/$max';
  }

  @override
  String get panelSectionSkills => 'Skills';

  @override
  String get panelSectionRules => 'Rules';

  @override
  String get panelSectionKnowledge => 'Knowledge and documentation';

  @override
  String get panelAddRule => 'Add rule';

  @override
  String get panelAddKnowledge => 'Add knowledge';

  @override
  String get panelAddToProject => 'Add to this project';

  @override
  String get panelRemoveFromProject => 'Remove from this project';

  @override
  String get panelRequiredByWorkflow => 'Required by the workflow';

  @override
  String get panelMissingBlocksPreflight => 'Missing: blocks the preflight';

  @override
  String get panelActivateOptional => 'Activate this optional capability';

  @override
  String get panelChangeDefaultRole => 'Change the workflow default role';

  @override
  String get panelApproveAndContinue => 'Approve and continue';

  @override
  String panelNoAgentForRole(Object role) {
    return 'no agent for $role';
  }

  @override
  String panelConsultedTo(Object names) {
    return 'consulted $names';
  }

  @override
  String panelCoverageMatrix(int resolved, int total) {
    return 'matrix $resolved/$total';
  }

  @override
  String get panelChangeSharedDefault => 'Change the shared default';

  @override
  String panelUseDefaultRole(Object role) {
    return 'Use default ($role)';
  }

  @override
  String get panelStateDone => 'ready';

  @override
  String get panelStateCurrent => 'now';

  @override
  String get panelStatePending => 'pending';

  @override
  String get panelStateBlocked => 'blocked';

  @override
  String get panelStateAvailable => 'available';

  @override
  String get panelStateNotRequired => 'not required';

  @override
  String get panelExecutorNewSession => 'new session';

  @override
  String get panelExecutorResumeParent => 'resumes parent session';

  @override
  String get panelExecutorSubagent => 'subagent / external fallback';

  @override
  String get panelExecutorManualApproval => 'requires manual approval';

  @override
  String get nodeKindTriage => 'Triage and contract';

  @override
  String get nodeKindImpact => 'End-to-end impact';

  @override
  String get nodeKindImplementation => 'Implementation';

  @override
  String get nodeKindVerification => 'Verification';

  @override
  String get mapNodeYou => 'you';

  @override
  String get mapNodeEnd => 'end';

  @override
  String get mapChipConsultation => 'consultation';

  @override
  String get mapChipSubagent => 'subagent';

  @override
  String get mapCountEnter => 'open';

  @override
  String get mapCalloutAsked => 'asked for';

  @override
  String get mapCalloutReturned => 'returned';

  @override
  String get mapCalloutCut => 'cut off';

  @override
  String get mapCalloutAnswered => 'answered';

  @override
  String get mapCalloutResolved => 'resolved';

  @override
  String get mapCalloutThinking => 'thinking';

  @override
  String get mapLegendOpensSubagent => 'opens a subagent';

  @override
  String get mapLegendSubagentReturned => 'the subagent returned';

  @override
  String get subagentPhaseWorking => 'working';

  @override
  String get turnPhaseWorking => 'working…';

  @override
  String get mapLegendForward => 'advances one step';

  @override
  String get mapLegendBack => 'consults another node';

  @override
  String get mapLegendAnswer => 'answers that consultation';

  @override
  String get mapLegendSpawn => 'registered it';

  @override
  String get mapLegendFinish => 'final delivery';

  @override
  String get mapLegendFailed => 'cut off';

  @override
  String get mapLegendUntraveled => 'not travelled';

  @override
  String get subagentPhaseThinking => 'thinking';

  @override
  String get subagentPhaseWriting => 'writing';

  @override
  String get subagentPhaseDone => 'finished';

  @override
  String get subagentPhaseFailed => 'failed';

  @override
  String get turnPhaseThinking => 'thinking…';

  @override
  String get turnPhaseWriting => 'writing…';

  @override
  String threadAdaptiveResolution(Object workflow) {
    return '$workflow · adaptive resolution';
  }

  @override
  String get threadBackToOwner => 'back to the owner';

  @override
  String threadNextNode(Object node) {
    return 'next $node';
  }

  @override
  String threadConsultOf(Object name) {
    return 'consultation from $name';
  }

  @override
  String panelAgentForNode(Object title) {
    return 'Agent for \"$title\"';
  }

  @override
  String panelOverrideScope(Object project) {
    return 'This override only affects #$project. The node stores the concrete agent once the preflight passes.';
  }

  @override
  String panelSharedChangeScope(Object workflow) {
    return 'This changes the workflow \"$workflow\" in every project. Concrete overrides are preserved.';
  }
}
