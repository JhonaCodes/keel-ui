import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('es', 'CO'),
  ];

  /// No description provided for @buttonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get buttonApply;

  /// No description provided for @buttonApplySelection.
  ///
  /// In en, this message translates to:
  /// **'Apply selection'**
  String get buttonApplySelection;

  /// No description provided for @buttonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get buttonCancel;

  /// No description provided for @buttonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get buttonCreate;

  /// No description provided for @buttonCreateEntity.
  ///
  /// In en, this message translates to:
  /// **'Create {entity}'**
  String buttonCreateEntity(String entity);

  /// No description provided for @buttonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get buttonDelete;

  /// No description provided for @buttonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get buttonEdit;

  /// No description provided for @buttonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get buttonSave;

  /// No description provided for @buttonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get buttonSearch;

  /// No description provided for @actionCloneVault.
  ///
  /// In en, this message translates to:
  /// **'Clone vault'**
  String get actionCloneVault;

  /// No description provided for @actionCloneAndRead.
  ///
  /// In en, this message translates to:
  /// **'Clone and read'**
  String get actionCloneAndRead;

  /// No description provided for @actionChooseDestinationAndExport.
  ///
  /// In en, this message translates to:
  /// **'Choose destination and export'**
  String get actionChooseDestinationAndExport;

  /// No description provided for @actionExportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get actionExportBackup;

  /// No description provided for @actionExportPackage.
  ///
  /// In en, this message translates to:
  /// **'Export a package'**
  String get actionExportPackage;

  /// No description provided for @actionSaveZip.
  ///
  /// In en, this message translates to:
  /// **'Save the zip…'**
  String get actionSaveZip;

  /// No description provided for @actionImportBackup.
  ///
  /// In en, this message translates to:
  /// **'Import backup'**
  String get actionImportBackup;

  /// No description provided for @actionIncludeSecrets.
  ///
  /// In en, this message translates to:
  /// **'Include secrets (with their VALUES)'**
  String get actionIncludeSecrets;

  /// No description provided for @actionReadBackup.
  ///
  /// In en, this message translates to:
  /// **'Read the backup'**
  String get actionReadBackup;

  /// No description provided for @actionRestoreFromVault.
  ///
  /// In en, this message translates to:
  /// **'Restore from the vault'**
  String get actionRestoreFromVault;

  /// No description provided for @actionRestoreSelection.
  ///
  /// In en, this message translates to:
  /// **'Restore selection'**
  String get actionRestoreSelection;

  /// No description provided for @actionBringEverythingAndStart.
  ///
  /// In en, this message translates to:
  /// **'Bring everything and start'**
  String get actionBringEverythingAndStart;

  /// No description provided for @actionUnifyInMain.
  ///
  /// In en, this message translates to:
  /// **'Unify in main'**
  String get actionUnifyInMain;

  /// No description provided for @actionReviewAgain.
  ///
  /// In en, this message translates to:
  /// **'Review again'**
  String get actionReviewAgain;

  /// No description provided for @actionStartFromScratch.
  ///
  /// In en, this message translates to:
  /// **'Start from scratch'**
  String get actionStartFromScratch;

  /// No description provided for @actionReadyEnter.
  ///
  /// In en, this message translates to:
  /// **'All set — continue'**
  String get actionReadyEnter;

  /// No description provided for @labelAgents.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get labelAgents;

  /// No description provided for @labelWorkflows.
  ///
  /// In en, this message translates to:
  /// **'Workflows'**
  String get labelWorkflows;

  /// No description provided for @labelSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get labelSkills;

  /// No description provided for @labelProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get labelProject;

  /// No description provided for @labelSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get labelSession;

  /// No description provided for @labelRules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get labelRules;

  /// No description provided for @labelHooks.
  ///
  /// In en, this message translates to:
  /// **'Hooks'**
  String get labelHooks;

  /// No description provided for @labelTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get labelTools;

  /// No description provided for @labelIntegrations.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get labelIntegrations;

  /// No description provided for @labelKnowledgeBases.
  ///
  /// In en, this message translates to:
  /// **'Knowledge Bases'**
  String get labelKnowledgeBases;

  /// No description provided for @labelSecrets.
  ///
  /// In en, this message translates to:
  /// **'Secrets'**
  String get labelSecrets;

  /// No description provided for @labelSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get labelSettings;

  /// No description provided for @messageErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get messageErrorGeneric;

  /// No description provided for @messageErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not connect. Check your network.'**
  String get messageErrorNetwork;

  /// No description provided for @messageErrorFileContainsNothing.
  ///
  /// In en, this message translates to:
  /// **'The file contains nothing applicable.'**
  String get messageErrorFileContainsNothing;

  /// No description provided for @messageErrorBackupContainsNothing.
  ///
  /// In en, this message translates to:
  /// **'The backup contains nothing applicable.'**
  String get messageErrorBackupContainsNothing;

  /// No description provided for @messageSuccessCreated.
  ///
  /// In en, this message translates to:
  /// **'{entity} created successfully.'**
  String messageSuccessCreated(String entity);

  /// No description provided for @messageSuccessSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get messageSuccessSaved;

  /// No description provided for @messageSuccessDeleted.
  ///
  /// In en, this message translates to:
  /// **'{entity} deleted.'**
  String messageSuccessDeleted(String entity);

  /// No description provided for @confirmationDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {entity}?'**
  String confirmationDeleteTitle(String entity);

  /// No description provided for @confirmationDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure? This cannot be undone.'**
  String get confirmationDeleteMessage;

  /// No description provided for @confirmationProceed.
  ///
  /// In en, this message translates to:
  /// **'Proceed'**
  String get confirmationProceed;

  /// No description provided for @placeholderSearchByName.
  ///
  /// In en, this message translates to:
  /// **'Search by name…'**
  String get placeholderSearchByName;

  /// No description provided for @placeholderFilterResults.
  ///
  /// In en, this message translates to:
  /// **'Filter results…'**
  String get placeholderFilterResults;

  /// No description provided for @placeholderAskAboutLine.
  ///
  /// In en, this message translates to:
  /// **'Ask about this line…'**
  String get placeholderAskAboutLine;

  /// No description provided for @hintFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Field required.'**
  String get hintFieldRequired;

  /// No description provided for @hintEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email.'**
  String get hintEmailInvalid;

  /// No description provided for @hintPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get hintPasswordTooShort;

  /// No description provided for @tooltipWorktreeSeparate.
  ///
  /// In en, this message translates to:
  /// **'Separate worktree'**
  String get tooltipWorktreeSeparate;

  /// No description provided for @tooltipOpenInFinder.
  ///
  /// In en, this message translates to:
  /// **'Open in Finder'**
  String get tooltipOpenInFinder;

  /// No description provided for @tooltipCopyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get tooltipCopyToClipboard;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Español (Colombia)'**
  String get languageSpanish;

  /// No description provided for @settingLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingLanguage;

  /// No description provided for @settingTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingTheme;

  /// No description provided for @settingThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingThemeDark;

  /// No description provided for @settingThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingThemeLight;

  /// No description provided for @countAgent.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 agent} other {{count} agents}}'**
  String countAgent(int count);

  /// No description provided for @countSession.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 session} other {{count} sessions}}'**
  String countSession(int count);

  /// No description provided for @countWorkflow.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 workflow} other {{count} workflows}}'**
  String countWorkflow(int count);

  /// No description provided for @countFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {No results found} =1 {1 result found} other {{count} results found}}'**
  String countFound(int count);

  /// No description provided for @pageTitleSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get pageTitleSettings;

  /// No description provided for @pageTitleSkillsRegistered.
  ///
  /// In en, this message translates to:
  /// **'Registered Skills'**
  String get pageTitleSkillsRegistered;

  /// No description provided for @pageTitleSecrets.
  ///
  /// In en, this message translates to:
  /// **'Secrets'**
  String get pageTitleSecrets;

  /// No description provided for @pageTitleHooksRegistered.
  ///
  /// In en, this message translates to:
  /// **'Registered Hooks'**
  String get pageTitleHooksRegistered;

  /// No description provided for @pageTitleRulesRegistered.
  ///
  /// In en, this message translates to:
  /// **'Registered Rules'**
  String get pageTitleRulesRegistered;

  /// No description provided for @pageTitleTestBoard.
  ///
  /// In en, this message translates to:
  /// **'Test Board'**
  String get pageTitleTestBoard;

  /// No description provided for @pageTitleTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get pageTitleTools;

  /// No description provided for @pageTitleIntegrations.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get pageTitleIntegrations;

  /// No description provided for @pageTitleMachine.
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get pageTitleMachine;

  /// No description provided for @pageTitleAgentsRegistered.
  ///
  /// In en, this message translates to:
  /// **'Registered Agents'**
  String get pageTitleAgentsRegistered;

  /// No description provided for @pageTitleKnowledge.
  ///
  /// In en, this message translates to:
  /// **'Knowledge'**
  String get pageTitleKnowledge;

  /// No description provided for @pageTitleInternalRequirements.
  ///
  /// In en, this message translates to:
  /// **'Internal Requirements'**
  String get pageTitleInternalRequirements;

  /// No description provided for @pageTitleProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get pageTitleProjects;

  /// No description provided for @pageTitleSessionAgents.
  ///
  /// In en, this message translates to:
  /// **'Session Agents'**
  String get pageTitleSessionAgents;

  /// No description provided for @pageTitleImportHooks.
  ///
  /// In en, this message translates to:
  /// **'Import Hooks from Claude Code'**
  String get pageTitleImportHooks;

  /// No description provided for @pageTitleTermsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get pageTitleTermsOfUse;

  /// No description provided for @pageTitleLockedElements.
  ///
  /// In en, this message translates to:
  /// **'Locked Elements'**
  String get pageTitleLockedElements;

  /// No description provided for @pageTitleOpenRequirement.
  ///
  /// In en, this message translates to:
  /// **'Open a Requirement'**
  String get pageTitleOpenRequirement;

  /// No description provided for @pageTitleModifySharedDefault.
  ///
  /// In en, this message translates to:
  /// **'Modify Shared Default'**
  String get pageTitleModifySharedDefault;

  /// No description provided for @pageTitlePasteMCPConfig.
  ///
  /// In en, this message translates to:
  /// **'Paste an MCP Configuration'**
  String get pageTitlePasteMCPConfig;

  /// No description provided for @pageTitleImportBackup.
  ///
  /// In en, this message translates to:
  /// **'Import Backup'**
  String get pageTitleImportBackup;

  /// No description provided for @pageTitleExportPackage.
  ///
  /// In en, this message translates to:
  /// **'Export a Package'**
  String get pageTitleExportPackage;

  /// No description provided for @pageTitleBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get pageTitleBackup;

  /// No description provided for @pageTitleImportPackage.
  ///
  /// In en, this message translates to:
  /// **'Import a Package'**
  String get pageTitleImportPackage;

  /// No description provided for @pageTitleFaults.
  ///
  /// In en, this message translates to:
  /// **'Faults'**
  String get pageTitleFaults;

  /// No description provided for @pageTitleEditQueuedMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit Queued Message'**
  String get pageTitleEditQueuedMessage;

  /// No description provided for @pageTitleRegisteredWorkflows.
  ///
  /// In en, this message translates to:
  /// **'Registered Workflows'**
  String get pageTitleRegisteredWorkflows;

  /// No description provided for @pageTitleUseAgent.
  ///
  /// In en, this message translates to:
  /// **'Use an Agent'**
  String get pageTitleUseAgent;

  /// No description provided for @pageTitleEngineOf.
  ///
  /// In en, this message translates to:
  /// **'Engine for @{member}'**
  String pageTitleEngineOf(String member);

  /// No description provided for @pageTitleRejectClosure.
  ///
  /// In en, this message translates to:
  /// **'Reject Closure'**
  String get pageTitleRejectClosure;

  /// No description provided for @settingTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text Size'**
  String get settingTextSize;

  /// No description provided for @settingWritePermissions.
  ///
  /// In en, this message translates to:
  /// **'Write Permissions'**
  String get settingWritePermissions;

  /// No description provided for @settingScheduledJobsApi.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Jobs API'**
  String get settingScheduledJobsApi;

  /// No description provided for @settingApplyToAllAgents.
  ///
  /// In en, this message translates to:
  /// **'Apply to all agents'**
  String get settingApplyToAllAgents;

  /// No description provided for @settingCanAdministrateSystem.
  ///
  /// In en, this message translates to:
  /// **'Can administer the system'**
  String get settingCanAdministrateSystem;

  /// No description provided for @settingBlocksRequester.
  ///
  /// In en, this message translates to:
  /// **'Blocks the requester'**
  String get settingBlocksRequester;

  /// No description provided for @settingAccessEntireFilesystem.
  ///
  /// In en, this message translates to:
  /// **'Access to entire file system'**
  String get settingAccessEntireFilesystem;

  /// No description provided for @descriptionWritePermissions.
  ///
  /// In en, this message translates to:
  /// **'Reading files, searching, and consulting the web is always allowed. Here you decide what agents can modify. Applies to all.'**
  String get descriptionWritePermissions;

  /// No description provided for @descriptionScheduledJobsApi.
  ///
  /// In en, this message translates to:
  /// **'For external schedulers (cron, keel): POST /projects/<name>/tasks with Bearer token. Loopback only.'**
  String get descriptionScheduledJobsApi;

  /// No description provided for @descriptionLockedElements.
  ///
  /// In en, this message translates to:
  /// **'What an agent cannot change or delete without asking your permission first. The lock is set from each item; here you see them all together.'**
  String get descriptionLockedElements;

  /// No description provided for @labelLockedElements.
  ///
  /// In en, this message translates to:
  /// **'Locked Elements'**
  String get labelLockedElements;

  /// No description provided for @labelAboutKeel.
  ///
  /// In en, this message translates to:
  /// **'About Keel'**
  String get labelAboutKeel;

  /// No description provided for @labelGlobal.
  ///
  /// In en, this message translates to:
  /// **'global'**
  String get labelGlobal;

  /// No description provided for @labelWhatExecutes.
  ///
  /// In en, this message translates to:
  /// **'What executes'**
  String get labelWhatExecutes;

  /// No description provided for @labelChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get labelChat;

  /// No description provided for @labelMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get labelMap;

  /// No description provided for @labelEngine.
  ///
  /// In en, this message translates to:
  /// **'ENGINE'**
  String get labelEngine;

  /// No description provided for @labelTurns.
  ///
  /// In en, this message translates to:
  /// **'TURNS'**
  String get labelTurns;

  /// No description provided for @labelInput.
  ///
  /// In en, this message translates to:
  /// **'INPUT'**
  String get labelInput;

  /// No description provided for @labelOutput.
  ///
  /// In en, this message translates to:
  /// **'OUTPUT'**
  String get labelOutput;

  /// No description provided for @labelCacheRead.
  ///
  /// In en, this message translates to:
  /// **'CACHE READ'**
  String get labelCacheRead;

  /// No description provided for @labelSecretsEnv.
  ///
  /// In en, this message translates to:
  /// **'Secrets (env)'**
  String get labelSecretsEnv;

  /// No description provided for @labelSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get labelSource;

  /// No description provided for @labelAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get labelAssistant;

  /// No description provided for @labelCompactContext.
  ///
  /// In en, this message translates to:
  /// **'Compact context ({percent}%)'**
  String labelCompactContext(int percent);

  /// No description provided for @labelRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get labelRequired;

  /// No description provided for @labelOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get labelOptional;

  /// No description provided for @labelDiff.
  ///
  /// In en, this message translates to:
  /// **'Diff'**
  String get labelDiff;

  /// No description provided for @labelEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get labelEdit;

  /// No description provided for @labelView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get labelView;

  /// No description provided for @labelAdaptiveCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Adaptive Capabilities'**
  String get labelAdaptiveCapabilities;

  /// No description provided for @labelMandatoryContext.
  ///
  /// In en, this message translates to:
  /// **'Mandatory Context'**
  String get labelMandatoryContext;

  /// No description provided for @labelReplansLimit.
  ///
  /// In en, this message translates to:
  /// **'Replans limit: {count}'**
  String labelReplansLimit(int count);

  /// No description provided for @labelReadVerifySubagents.
  ///
  /// In en, this message translates to:
  /// **'Read/verify subagents: {count}'**
  String labelReadVerifySubagents(int count);

  /// No description provided for @labelSharedAuditCycles.
  ///
  /// In en, this message translates to:
  /// **'Shared audit cycles: {count}'**
  String labelSharedAuditCycles(int count);

  /// No description provided for @labelAgentFor.
  ///
  /// In en, this message translates to:
  /// **'Agent for \"{capability}\"'**
  String labelAgentFor(String capability);

  /// No description provided for @buttonNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get buttonNew;

  /// No description provided for @buttonRegisterSkill.
  ///
  /// In en, this message translates to:
  /// **'Register skill'**
  String get buttonRegisterSkill;

  /// No description provided for @buttonCreateSkill.
  ///
  /// In en, this message translates to:
  /// **'Create skill'**
  String get buttonCreateSkill;

  /// No description provided for @buttonReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get buttonReplace;

  /// No description provided for @buttonImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get buttonImport;

  /// No description provided for @buttonRegenerateToken.
  ///
  /// In en, this message translates to:
  /// **'Regenerate token'**
  String get buttonRegenerateToken;

  /// No description provided for @buttonViewLocked.
  ///
  /// In en, this message translates to:
  /// **'View locked…'**
  String get buttonViewLocked;

  /// No description provided for @buttonAskKeelAI.
  ///
  /// In en, this message translates to:
  /// **'Ask Keel AI'**
  String get buttonAskKeelAI;

  /// No description provided for @buttonCreateManually.
  ///
  /// In en, this message translates to:
  /// **'Create manually'**
  String get buttonCreateManually;

  /// No description provided for @buttonRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get buttonRename;

  /// No description provided for @buttonUngroupGroup.
  ///
  /// In en, this message translates to:
  /// **'Ungroup'**
  String get buttonUngroupGroup;

  /// No description provided for @buttonRegisterSecret.
  ///
  /// In en, this message translates to:
  /// **'Register secret'**
  String get buttonRegisterSecret;

  /// No description provided for @buttonLoadValue.
  ///
  /// In en, this message translates to:
  /// **'Load value'**
  String get buttonLoadValue;

  /// No description provided for @buttonNewSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get buttonNewSession;

  /// No description provided for @buttonChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get buttonChooseFolder;

  /// No description provided for @buttonReviewAgain.
  ///
  /// In en, this message translates to:
  /// **'Review again'**
  String get buttonReviewAgain;

  /// No description provided for @buttonDefineFormat.
  ///
  /// In en, this message translates to:
  /// **'Define the format'**
  String get buttonDefineFormat;

  /// No description provided for @buttonDocumentation.
  ///
  /// In en, this message translates to:
  /// **'Documentation'**
  String get buttonDocumentation;

  /// No description provided for @buttonTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test the connection'**
  String get buttonTestConnection;

  /// No description provided for @buttonRegisterMCP.
  ///
  /// In en, this message translates to:
  /// **'Register MCP'**
  String get buttonRegisterMCP;

  /// No description provided for @buttonChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose…'**
  String get buttonChoose;

  /// No description provided for @buttonRegisterAgent.
  ///
  /// In en, this message translates to:
  /// **'Register agent'**
  String get buttonRegisterAgent;

  /// No description provided for @buttonTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get buttonTest;

  /// No description provided for @buttonOpenWithSystemApp.
  ///
  /// In en, this message translates to:
  /// **'Open with system app'**
  String get buttonOpenWithSystemApp;

  /// No description provided for @buttonReturnToAgentDefault.
  ///
  /// In en, this message translates to:
  /// **'Return to agent default'**
  String get buttonReturnToAgentDefault;

  /// No description provided for @buttonReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get buttonReview;

  /// No description provided for @buttonRebuildAndReopen.
  ///
  /// In en, this message translates to:
  /// **'Rebuild and reopen'**
  String get buttonRebuildAndReopen;

  /// No description provided for @buttonExport.
  ///
  /// In en, this message translates to:
  /// **'Export…'**
  String get buttonExport;

  /// No description provided for @buttonImportDots.
  ///
  /// In en, this message translates to:
  /// **'Import…'**
  String get buttonImportDots;

  /// No description provided for @buttonBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get buttonBackup;

  /// No description provided for @buttonBackupAndUpload.
  ///
  /// In en, this message translates to:
  /// **'Backup and upload'**
  String get buttonBackupAndUpload;

  /// No description provided for @buttonRestoreDots.
  ///
  /// In en, this message translates to:
  /// **'Restore…'**
  String get buttonRestoreDots;

  /// No description provided for @buttonBring.
  ///
  /// In en, this message translates to:
  /// **'Bring'**
  String get buttonBring;

  /// No description provided for @buttonInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get buttonInstall;

  /// No description provided for @buttonAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask…'**
  String get buttonAsk;

  /// No description provided for @buttonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get buttonClear;

  /// No description provided for @buttonView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get buttonView;

  /// No description provided for @buttonApproveChange.
  ///
  /// In en, this message translates to:
  /// **'Approve change'**
  String get buttonApproveChange;

  /// No description provided for @buttonAddRule.
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get buttonAddRule;

  /// No description provided for @buttonAddKnowledge.
  ///
  /// In en, this message translates to:
  /// **'Add knowledge'**
  String get buttonAddKnowledge;

  /// No description provided for @buttonApproveAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Approve and continue'**
  String get buttonApproveAndContinue;

  /// No description provided for @buttonOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get buttonOpen;

  /// No description provided for @buttonNewKnowledgeBase.
  ///
  /// In en, this message translates to:
  /// **'New knowledge base'**
  String get buttonNewKnowledgeBase;

  /// No description provided for @buttonContinuePlanning.
  ///
  /// In en, this message translates to:
  /// **'Continue planning'**
  String get buttonContinuePlanning;

  /// No description provided for @buttonImplement.
  ///
  /// In en, this message translates to:
  /// **'Implement'**
  String get buttonImplement;

  /// No description provided for @buttonRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get buttonRegister;

  /// No description provided for @buttonReloadFromDisk.
  ///
  /// In en, this message translates to:
  /// **'Reload from disk'**
  String get buttonReloadFromDisk;

  /// No description provided for @buttonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get buttonClose;

  /// No description provided for @buttonReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get buttonReject;

  /// No description provided for @buttonAssignAndEvaluate.
  ///
  /// In en, this message translates to:
  /// **'Take and evaluate'**
  String get buttonAssignAndEvaluate;

  /// No description provided for @buttonGoToSession.
  ///
  /// In en, this message translates to:
  /// **'Go to session'**
  String get buttonGoToSession;

  /// No description provided for @buttonRejectAndExplain.
  ///
  /// In en, this message translates to:
  /// **'Reject and explain'**
  String get buttonRejectAndExplain;

  /// No description provided for @messageNoSkillsRegistered.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t registered any skills yet.'**
  String get messageNoSkillsRegistered;

  /// No description provided for @messageNoToolsRegistered.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t registered any tools yet.'**
  String get messageNoToolsRegistered;

  /// No description provided for @messageNoRulesRegistered.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t registered any rules yet.'**
  String get messageNoRulesRegistered;

  /// No description provided for @messageApiNotRunning.
  ///
  /// In en, this message translates to:
  /// **'The API is not running in this window.'**
  String get messageApiNotRunning;

  /// No description provided for @messageApiUrl.
  ///
  /// In en, this message translates to:
  /// **'URL: http://127.0.0.1:{port}'**
  String messageApiUrl(int port);

  /// No description provided for @messageApiToken.
  ///
  /// In en, this message translates to:
  /// **'Token: {token}'**
  String messageApiToken(String token);

  /// No description provided for @messageBoardNotFound.
  ///
  /// In en, this message translates to:
  /// **'That board no longer exists.'**
  String get messageBoardNotFound;

  /// No description provided for @messageNoBoardsYet.
  ///
  /// In en, this message translates to:
  /// **'No boards yet'**
  String get messageNoBoardsYet;

  /// No description provided for @messageNoHooksRegistered.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t registered any hooks yet.'**
  String get messageNoHooksRegistered;

  /// No description provided for @messageNoExternalMCPs.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t registered any external MCPs yet.'**
  String get messageNoExternalMCPs;

  /// No description provided for @messageNoProjectsRegistered.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t registered any projects yet.'**
  String get messageNoProjectsRegistered;

  /// No description provided for @messageNoAgentsRegistered.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t registered any agents yet.'**
  String get messageNoAgentsRegistered;

  /// No description provided for @messageNoWorkflowsRegistered.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t registered any workflows yet.'**
  String get messageNoWorkflowsRegistered;

  /// No description provided for @messageNoneYet.
  ///
  /// In en, this message translates to:
  /// **'None yet.'**
  String get messageNoneYet;

  /// No description provided for @messageNoMoreAgentsToAdd.
  ///
  /// In en, this message translates to:
  /// **'No more agents to add.'**
  String get messageNoMoreAgentsToAdd;

  /// No description provided for @messageCouldNotOpenImage.
  ///
  /// In en, this message translates to:
  /// **'Could not open the image: {error}'**
  String messageCouldNotOpenImage(String error);

  /// No description provided for @messageSessionNotFound.
  ///
  /// In en, this message translates to:
  /// **'The session no longer exists.'**
  String get messageSessionNotFound;

  /// No description provided for @messageDrop.
  ///
  /// In en, this message translates to:
  /// **'Drop {name}'**
  String messageDrop(String name);

  /// No description provided for @messageFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File is too large to show a diff.'**
  String get messageFileTooLarge;

  /// No description provided for @messageAskYourAgent.
  ///
  /// In en, this message translates to:
  /// **'Ask your agent something'**
  String get messageAskYourAgent;

  /// No description provided for @messageNoKnowledgeBases.
  ///
  /// In en, this message translates to:
  /// **'There are no knowledge bases yet.'**
  String get messageNoKnowledgeBases;

  /// No description provided for @messageBackupEmpty.
  ///
  /// In en, this message translates to:
  /// **'The backup brings nothing applicable.'**
  String get messageBackupEmpty;

  /// No description provided for @optionCommand.
  ///
  /// In en, this message translates to:
  /// **'A command'**
  String get optionCommand;

  /// No description provided for @optionRegisteredTool.
  ///
  /// In en, this message translates to:
  /// **'A registered tool'**
  String get optionRegisteredTool;

  /// No description provided for @optionGiveToKeelAI.
  ///
  /// In en, this message translates to:
  /// **'Give it to Keel AI (the assistant)'**
  String get optionGiveToKeelAI;

  /// No description provided for @optionIMaintainIt.
  ///
  /// In en, this message translates to:
  /// **'I maintain it'**
  String get optionIMaintainIt;

  /// No description provided for @optionUseDefault.
  ///
  /// In en, this message translates to:
  /// **'Use default ({role})'**
  String optionUseDefault(String role);

  /// No description provided for @optionAnyMember.
  ///
  /// In en, this message translates to:
  /// **'Any member'**
  String get optionAnyMember;

  /// No description provided for @optionNewSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get optionNewSession;

  /// No description provided for @optionResumeParentSession.
  ///
  /// In en, this message translates to:
  /// **'Resume parent session'**
  String get optionResumeParentSession;

  /// No description provided for @optionProviderSubagent.
  ///
  /// In en, this message translates to:
  /// **'Provider subagent'**
  String get optionProviderSubagent;

  /// No description provided for @optionManualApproval.
  ///
  /// In en, this message translates to:
  /// **'Manual approval'**
  String get optionManualApproval;

  /// No description provided for @optionAgentProvider.
  ///
  /// In en, this message translates to:
  /// **'Agent\'s ({provider})'**
  String optionAgentProvider(String provider);

  /// No description provided for @optionAgentEffort.
  ///
  /// In en, this message translates to:
  /// **'Agent\'s ({effort})'**
  String optionAgentEffort(String effort);

  /// No description provided for @titleReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get titleReadOnly;

  /// No description provided for @titleRequiresIndependentAgent.
  ///
  /// In en, this message translates to:
  /// **'Requires independent agent'**
  String get titleRequiresIndependentAgent;

  /// No description provided for @subtitleReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Planners and auditors do not write.'**
  String get subtitleReadOnly;

  /// No description provided for @linkWebsite.
  ///
  /// In en, this message translates to:
  /// **'jhonacode.com'**
  String get linkWebsite;

  /// No description provided for @linkCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community on Discord'**
  String get linkCommunity;

  /// No description provided for @tooltipRegisterNew.
  ///
  /// In en, this message translates to:
  /// **'Register new'**
  String get tooltipRegisterNew;

  /// No description provided for @tooltipImportPackage.
  ///
  /// In en, this message translates to:
  /// **'Import a package'**
  String get tooltipImportPackage;

  /// No description provided for @tooltipDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get tooltipDismiss;

  /// No description provided for @messageNoHooksDescription.
  ///
  /// In en, this message translates to:
  /// **'A hook is a command that runs at a point in a turn and that an agent cannot skip: it can stop a tool before use or react afterward. A rule asks; a hook guarantees.'**
  String get messageNoHooksDescription;

  /// No description provided for @labelLlmProviders.
  ///
  /// In en, this message translates to:
  /// **'LLM PROVIDERS'**
  String get labelLlmProviders;

  /// No description provided for @labelOtherSecrets.
  ///
  /// In en, this message translates to:
  /// **'OTHER SECRETS'**
  String get labelOtherSecrets;

  /// No description provided for @suggestionIntro.
  ///
  /// In en, this message translates to:
  /// **'I noticed things you ask for repeatedly — shall we turn them into global skills?'**
  String get suggestionIntro;

  /// No description provided for @suggestionDraftHeader.
  ///
  /// In en, this message translates to:
  /// **'Recurring instruction detected ({count} times). Examples of what you asked for:\\n'**
  String suggestionDraftHeader(int count);

  /// No description provided for @suggestionDraftFooter.
  ///
  /// In en, this message translates to:
  /// **'Write the final instruction here:'**
  String get suggestionDraftFooter;

  /// No description provided for @formTitleRegisterAgent.
  ///
  /// In en, this message translates to:
  /// **'Register agent'**
  String get formTitleRegisterAgent;

  /// No description provided for @formTitleEditAgent.
  ///
  /// In en, this message translates to:
  /// **'Edit registered agent'**
  String get formTitleEditAgent;

  /// No description provided for @formLabelAgentName.
  ///
  /// In en, this message translates to:
  /// **'Name (lowercase, no spaces, max 16)'**
  String get formLabelAgentName;

  /// No description provided for @formLabelAgentRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get formLabelAgentRole;

  /// No description provided for @formLabelAgentRoleHint.
  ///
  /// In en, this message translates to:
  /// **'What this agent does'**
  String get formLabelAgentRoleHint;

  /// No description provided for @formLabelSystemPrompt.
  ///
  /// In en, this message translates to:
  /// **'System prompt'**
  String get formLabelSystemPrompt;

  /// No description provided for @formLabelProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider (codex: no tools/MCPs/effort, and its own models)'**
  String get formLabelProvider;

  /// No description provided for @formLabelModel.
  ///
  /// In en, this message translates to:
  /// **'Default model ({provider})'**
  String formLabelModel(String provider);

  /// No description provided for @formLabelEffort.
  ///
  /// In en, this message translates to:
  /// **'Default effort'**
  String get formLabelEffort;

  /// No description provided for @formMessageCanManageSystem.
  ///
  /// In en, this message translates to:
  /// **'Can manage the system'**
  String get formMessageCanManageSystem;

  /// No description provided for @formDescriptionManageSystem.
  ///
  /// In en, this message translates to:
  /// **'Builder agent: receives the same creation tools as Keel AI (skills, rules, tools, agents, workflows, projects) in its 1:1 chats.'**
  String get formDescriptionManageSystem;

  /// No description provided for @formDescriptionKeelAiHooks.
  ///
  /// In en, this message translates to:
  /// **'Keel AI runs without hooks on purpose: it\'s who you ask to disable one that\'s stuck. What you assign here won\'t apply.'**
  String get formDescriptionKeelAiHooks;

  /// No description provided for @formDescriptionHooks.
  ///
  /// In en, this message translates to:
  /// **'They run outside the model, so it can\'t skip them. The rules above are requested; these are enforced.'**
  String get formDescriptionHooks;

  /// No description provided for @formDescriptionRoles.
  ///
  /// In en, this message translates to:
  /// **'Roles your workflows ask for — pick one so this agent covers them:'**
  String get formDescriptionRoles;

  /// No description provided for @formDescriptionRolesHelp.
  ///
  /// In en, this message translates to:
  /// **'Workflow preflight looks for responsibles by this role.'**
  String get formDescriptionRolesHelp;

  /// No description provided for @formConfirmDeleteAgent.
  ///
  /// In en, this message translates to:
  /// **'The \"{name}\" registration will be deleted. This doesn\'t affect chats you already had with this setup.'**
  String formConfirmDeleteAgent(Object name);

  /// No description provided for @formTitleDeleteAgent.
  ///
  /// In en, this message translates to:
  /// **'Delete registered agent'**
  String get formTitleDeleteAgent;

  /// No description provided for @tooltipEditAgent.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get tooltipEditAgent;

  /// No description provided for @tooltipExportAsPackage.
  ///
  /// In en, this message translates to:
  /// **'Export as package'**
  String get tooltipExportAsPackage;

  /// No description provided for @tooltipDeleteAgent.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get tooltipDeleteAgent;

  /// No description provided for @mapStateWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for you'**
  String get mapStateWaiting;

  /// No description provided for @mapStateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get mapStateFailed;

  /// No description provided for @labelAskedFor.
  ///
  /// In en, this message translates to:
  /// **'Asked for'**
  String get labelAskedFor;

  /// No description provided for @labelHowReasons.
  ///
  /// In en, this message translates to:
  /// **'How it reasons'**
  String get labelHowReasons;

  /// No description provided for @statusLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get statusLive;

  /// No description provided for @labelWhatDid.
  ///
  /// In en, this message translates to:
  /// **'What it did'**
  String get labelWhatDid;

  /// No description provided for @labelWhatReturned.
  ///
  /// In en, this message translates to:
  /// **'What it returned'**
  String get labelWhatReturned;

  /// No description provided for @labelTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get labelTask;

  /// No description provided for @labelWhatResolved.
  ///
  /// In en, this message translates to:
  /// **'What it resolved'**
  String get labelWhatResolved;

  /// No description provided for @labelAskedAbout.
  ///
  /// In en, this message translates to:
  /// **'Asked about'**
  String get labelAskedAbout;

  /// No description provided for @labelNumbers.
  ///
  /// In en, this message translates to:
  /// **'Numbers'**
  String get labelNumbers;

  /// No description provided for @labelMemberOpened.
  ///
  /// In en, this message translates to:
  /// **'Member who opened it'**
  String get labelMemberOpened;

  /// No description provided for @placeholderWriteTo.
  ///
  /// In en, this message translates to:
  /// **'Write to @{name}…'**
  String placeholderWriteTo(String name);

  /// No description provided for @messageNoReasoningVisible.
  ///
  /// In en, this message translates to:
  /// **'Did not leave visible reasoning. With models that don\'t emit it, there\'s nothing to show here.'**
  String get messageNoReasoningVisible;

  /// No description provided for @messageNodeNotResolution.
  ///
  /// In en, this message translates to:
  /// **'This node is not part of a resolution case: it only speaks when consulted.'**
  String get messageNodeNotResolution;

  /// No description provided for @messageNoReasoningYet.
  ///
  /// In en, this message translates to:
  /// **'No reasoning shown yet at this step.'**
  String get messageNoReasoningYet;

  /// No description provided for @messageNodeNotMember.
  ///
  /// In en, this message translates to:
  /// **'This node is no longer a project member, so there\'s no one to write to.'**
  String get messageNodeNotMember;

  /// No description provided for @messageNoConsultRecord.
  ///
  /// In en, this message translates to:
  /// **'Not recorded which phrase was used to call it.'**
  String get messageNoConsultRecord;

  /// No description provided for @messageNoToolsOpened.
  ///
  /// In en, this message translates to:
  /// **'No tools have been opened yet.'**
  String get messageNoToolsOpened;

  /// No description provided for @messageSubagentWriteLocked.
  ///
  /// In en, this message translates to:
  /// **'While running, you cannot write to a subagent: the CLI doesn\'t open that channel. What you write below goes to {parent}, who opened it.'**
  String messageSubagentWriteLocked(String parent);

  /// No description provided for @formLabelHookName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get formLabelHookName;

  /// No description provided for @formHintHookScript.
  ///
  /// In en, this message translates to:
  /// **'Also the name of the script that will be generated.'**
  String get formHintHookScript;

  /// No description provided for @formLabelWhatHookDoes.
  ///
  /// In en, this message translates to:
  /// **'What it does'**
  String get formLabelWhatHookDoes;

  /// No description provided for @formMessageNoEventFilter.
  ///
  /// In en, this message translates to:
  /// **'This event doesn\'t filter: leave it empty.'**
  String get formMessageNoEventFilter;

  /// No description provided for @formHintEventFilter.
  ///
  /// In en, this message translates to:
  /// **'Empty = all. Examples: {matcherHint}'**
  String formHintEventFilter(String matcherHint);

  /// No description provided for @formDescriptionHookScope.
  ///
  /// In en, this message translates to:
  /// **'Brief on purpose: a \"before tool use\" hook: if you reject it, it won\'t be called. A \"after\" one is rarer.'**
  String get formDescriptionHookScope;

  /// No description provided for @formLabelHookRules.
  ///
  /// In en, this message translates to:
  /// **'Which rules does this hook enforce'**
  String get formLabelHookRules;

  /// No description provided for @formDescriptionHookRules.
  ///
  /// In en, this message translates to:
  /// **'Changes nothing about what runs: just marks which of your rules are guaranteed and which are just asked.'**
  String get formDescriptionHookRules;

  /// No description provided for @formLabelWhenHookRuns.
  ///
  /// In en, this message translates to:
  /// **'When it runs'**
  String get formLabelWhenHookRuns;

  /// No description provided for @formLabelWhatHookExecutes.
  ///
  /// In en, this message translates to:
  /// **'What it executes'**
  String get formLabelWhatHookExecutes;

  /// No description provided for @messageNoToolsRegisteredShort.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t registered any tools yet.'**
  String get messageNoToolsRegisteredShort;

  /// No description provided for @formDescriptionHookCode.
  ///
  /// In en, this message translates to:
  /// **'Code travels in backups and can use the secrets you set up. If the admin doesn\'t allow write, a hook from disk won\'t restore on another machine.'**
  String get formDescriptionHookCode;

  /// No description provided for @formLabelHookTimeout.
  ///
  /// In en, this message translates to:
  /// **'Timeout (seconds)'**
  String get formLabelHookTimeout;

  /// No description provided for @formDescriptionHookTimeout.
  ///
  /// In en, this message translates to:
  /// **'Receives the event as JSON on stdin. Exiting with code 2 blocks.'**
  String get formDescriptionHookTimeout;

  /// No description provided for @pageTitleMachineTitle.
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get pageTitleMachineTitle;

  /// No description provided for @messageDetectionNotIntegration.
  ///
  /// In en, this message translates to:
  /// **'Detecting is not integrating: those that say \"no adapter\" are on your machine but Keel still doesn\'t know how to talk to them, and can\'t be asked to do it alone.'**
  String get messageDetectionNotIntegration;

  /// No description provided for @labelConsumption.
  ///
  /// In en, this message translates to:
  /// **'Consumption · last 14 days'**
  String get labelConsumption;

  /// No description provided for @messageNoConsumptionYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing measured yet. History starts today: until now, the counters for each turn were read for the context percentage and thrown away, so there\'s no way to know what was spent where. History starts on the day this screen was installed.'**
  String get messageNoConsumptionYet;

  /// No description provided for @labelCacheReadShort.
  ///
  /// In en, this message translates to:
  /// **'CACHE READ'**
  String get labelCacheReadShort;

  /// No description provided for @messageNoTokenCount.
  ///
  /// In en, this message translates to:
  /// **'No measurement — its CLI doesn\'t report tokens'**
  String get messageNoTokenCount;

  /// No description provided for @labelCoresShort.
  ///
  /// In en, this message translates to:
  /// **'{cores} cores'**
  String labelCoresShort(int cores);

  /// No description provided for @messageNotInPath.
  ///
  /// In en, this message translates to:
  /// **'Not in the PATH'**
  String get messageNotInPath;

  /// No description provided for @formLabelWorkflowIntent.
  ///
  /// In en, this message translates to:
  /// **'Intent and when it applies'**
  String get formLabelWorkflowIntent;

  /// No description provided for @formDescriptionWorkflowEngine.
  ///
  /// In en, this message translates to:
  /// **'The engine decides the minimum nodes; you don\'t configure a chain of agents.'**
  String get formDescriptionWorkflowEngine;

  /// No description provided for @labelMaxReplans.
  ///
  /// In en, this message translates to:
  /// **'Replan limit: {count}'**
  String labelMaxReplans(int count);

  /// No description provided for @labelMaxSubagents.
  ///
  /// In en, this message translates to:
  /// **'Read/verify subagents: {count}'**
  String labelMaxSubagents(int count);

  /// No description provided for @labelMaxReviewCycles.
  ///
  /// In en, this message translates to:
  /// **'Shared audit cycles: {count}'**
  String labelMaxReviewCycles(int count);

  /// No description provided for @formLabelWorkflowTitle.
  ///
  /// In en, this message translates to:
  /// **'Visible title'**
  String get formLabelWorkflowTitle;

  /// No description provided for @formLabelWorkflowInstruction.
  ///
  /// In en, this message translates to:
  /// **'Instruction'**
  String get formLabelWorkflowInstruction;

  /// No description provided for @formLabelWorkflowActivation.
  ///
  /// In en, this message translates to:
  /// **'Activation'**
  String get formLabelWorkflowActivation;

  /// No description provided for @formLabelWorkflowExecution.
  ///
  /// In en, this message translates to:
  /// **'Execution'**
  String get formLabelWorkflowExecution;

  /// No description provided for @formDescriptionParentSessionKept.
  ///
  /// In en, this message translates to:
  /// **'The parent session is kept and resumed.'**
  String get formDescriptionParentSessionKept;

  /// No description provided for @formLabelMaxAgenticTurns.
  ///
  /// In en, this message translates to:
  /// **'Maximum agentic turns'**
  String get formLabelMaxAgenticTurns;

  /// No description provided for @formDescriptionMaxAgenticTurns.
  ///
  /// In en, this message translates to:
  /// **'Empty or 0 uses the provider limit.'**
  String get formDescriptionMaxAgenticTurns;

  /// No description provided for @formLabelWorkflowOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get formLabelWorkflowOwner;

  /// No description provided for @formDescriptionWorkflowOwner.
  ///
  /// In en, this message translates to:
  /// **'The owner must be different from those who produced its dependencies.'**
  String get formDescriptionWorkflowOwner;

  /// No description provided for @formLabelWorkflowResponsible.
  ///
  /// In en, this message translates to:
  /// **'Responsible for resolution'**
  String get formLabelWorkflowResponsible;

  /// No description provided for @formDescriptionResponsible.
  ///
  /// In en, this message translates to:
  /// **'A responsible integrates evidence and is the only writer.'**
  String get formDescriptionResponsible;

  /// No description provided for @workflowKindMigration.
  ///
  /// In en, this message translates to:
  /// **'Migration'**
  String get workflowKindMigration;

  /// No description provided for @labelAge.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1 {1 day} other {{days} days}}'**
  String labelAge(int days);

  /// No description provided for @labelWeekdayShort.
  ///
  /// In en, this message translates to:
  /// **'Mon, Tue, Wed, Thu, Fri, Sat, Sun'**
  String get labelWeekdayShort;

  /// No description provided for @messageRequirementTaken.
  ///
  /// In en, this message translates to:
  /// **'Taken by @{handle}'**
  String messageRequirementTaken(String handle);

  /// No description provided for @messageRequirementTask.
  ///
  /// In en, this message translates to:
  /// **'Became a task: {taskPath}'**
  String messageRequirementTask(String taskPath);

  /// No description provided for @messagePlanMode.
  ///
  /// In en, this message translates to:
  /// **'Plan mode: propose how they would do it. To actually implement it, \"Take and evaluate\" opens a session.'**
  String get messagePlanMode;

  /// No description provided for @messageRequirementAnswering.
  ///
  /// In en, this message translates to:
  /// **'Answering…'**
  String get messageRequirementAnswering;

  /// No description provided for @messagePlanRequest.
  ///
  /// In en, this message translates to:
  /// **'Ask for a plan — @ to call an agent'**
  String get messagePlanRequest;

  /// No description provided for @messageWriteHere.
  ///
  /// In en, this message translates to:
  /// **'Write here — @ to ask an agent'**
  String get messageWriteHere;

  /// No description provided for @messageRequirementClosed.
  ///
  /// In en, this message translates to:
  /// **'The recipient asked for closure.'**
  String get messageRequirementClosed;

  /// No description provided for @messageOnlyOriginCanClose.
  ///
  /// In en, this message translates to:
  /// **'Only the side that opened it can close — they know if what they needed is there.'**
  String get messageOnlyOriginCanClose;

  /// No description provided for @labelWithWorkflow.
  ///
  /// In en, this message translates to:
  /// **'With which workflow to evaluate'**
  String get labelWithWorkflow;

  /// No description provided for @messageNewSessionOpenedWorkflow.
  ///
  /// In en, this message translates to:
  /// **'Will open a new session in #{workflowName}. Choose the row below for each role.'**
  String messageNewSessionOpenedWorkflow(String workflowName);

  /// No description provided for @formLabelWhatMissing.
  ///
  /// In en, this message translates to:
  /// **'What\'s missing'**
  String get formLabelWhatMissing;

  /// No description provided for @bundleExportNothingYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing to export yet.'**
  String get bundleExportNothingYet;

  /// No description provided for @bundleSectionWhatItTakes.
  ///
  /// In en, this message translates to:
  /// **'What it takes'**
  String get bundleSectionWhatItTakes;

  /// No description provided for @bundleSectionWhatItBrings.
  ///
  /// In en, this message translates to:
  /// **'What it brings'**
  String get bundleSectionWhatItBrings;

  /// No description provided for @bundleSectionWhatRecipientSees.
  ///
  /// In en, this message translates to:
  /// **'What the recipient will see'**
  String get bundleSectionWhatRecipientSees;

  /// No description provided for @bundleSectionSecurityReview.
  ///
  /// In en, this message translates to:
  /// **'Security review'**
  String get bundleSectionSecurityReview;

  /// No description provided for @bundleNoFindings.
  ///
  /// In en, this message translates to:
  /// **'no findings'**
  String get bundleNoFindings;

  /// No description provided for @bundleFindingsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 finding} other {{count} findings}}'**
  String bundleFindingsCount(int count);

  /// No description provided for @bundleMissingNote.
  ///
  /// In en, this message translates to:
  /// **'This is named but doesn\'t exist on this side, so it won\'t travel:\n{list}'**
  String bundleMissingNote(String list);

  /// No description provided for @bundleSecretsToCreateNote.
  ///
  /// In en, this message translates to:
  /// **'Whoever installs it will need to create these secrets with these names: {names}. The values don\'t travel.'**
  String bundleSecretsToCreateNote(String names);

  /// No description provided for @actionImportPackage.
  ///
  /// In en, this message translates to:
  /// **'Import a package'**
  String get actionImportPackage;

  /// No description provided for @bundleImportIntro.
  ///
  /// In en, this message translates to:
  /// **'A package brings an agent, a workflow or a skill with everything it needs to work: its skills, its rules, its tools, its hooks, its MCP servers and its documentation.'**
  String get bundleImportIntro;

  /// No description provided for @bundleImportSafetyNote.
  ///
  /// In en, this message translates to:
  /// **'Nothing is installed before you see what it brings and what the review found.'**
  String get bundleImportSafetyNote;

  /// No description provided for @actionChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get actionChooseFile;

  /// No description provided for @bundleOrFromLink.
  ///
  /// In en, this message translates to:
  /// **'or from a link'**
  String get bundleOrFromLink;

  /// No description provided for @bundleLinkHint.
  ///
  /// In en, this message translates to:
  /// **'https://…/keel-agent-flutter-expert.zip'**
  String get bundleLinkHint;

  /// No description provided for @actionBring.
  ///
  /// In en, this message translates to:
  /// **'Bring'**
  String get actionBring;

  /// No description provided for @bundleDocumentsLabel.
  ///
  /// In en, this message translates to:
  /// **'documents'**
  String get bundleDocumentsLabel;

  /// No description provided for @bundleSecretsRequiredNote.
  ///
  /// In en, this message translates to:
  /// **'It needs these secrets, which you have to create yourself with these names: {names}. A package never brings values.'**
  String bundleSecretsRequiredNote(String names);

  /// No description provided for @actionInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get actionInstall;

  /// No description provided for @bundleHighRiskAck.
  ///
  /// In en, this message translates to:
  /// **'I read the {count} high-severity findings and want to install it anyway.'**
  String bundleHighRiskAck(int count);

  /// No description provided for @bundleAuditCleanNote.
  ///
  /// In en, this message translates to:
  /// **'I reviewed {count} pieces of text and found nothing known. This isn\'t a guarantee: it only searches for what it knows to search for.'**
  String bundleAuditCleanNote(int count);

  /// No description provided for @bundleRiskLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'SEVERITY {level}'**
  String bundleRiskLevelLabel(String level);

  /// No description provided for @actionSaveAsPng.
  ///
  /// In en, this message translates to:
  /// **'Save as PNG'**
  String get actionSaveAsPng;

  /// No description provided for @codeBlockLineCount.
  ///
  /// In en, this message translates to:
  /// **'{title} · {count, plural, =1 {1 line} other {{count} lines}}'**
  String codeBlockLineCount(String title, int count);

  /// No description provided for @semanticsOpenImageFullSize.
  ///
  /// In en, this message translates to:
  /// **'Attached image, open at full size'**
  String get semanticsOpenImageFullSize;

  /// No description provided for @tooltipOpenFullSize.
  ///
  /// In en, this message translates to:
  /// **'Open at full size'**
  String get tooltipOpenFullSize;

  /// No description provided for @messageImageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Image unavailable'**
  String get messageImageUnavailable;

  /// No description provided for @labelDeletedProject.
  ///
  /// In en, this message translates to:
  /// **'deleted project'**
  String get labelDeletedProject;

  /// No description provided for @labelOpenSince.
  ///
  /// In en, this message translates to:
  /// **'open for {age}'**
  String labelOpenSince(String age);

  /// No description provided for @labelBlockingRequester.
  ///
  /// In en, this message translates to:
  /// **'blocks whoever asks'**
  String get labelBlockingRequester;

  /// No description provided for @durationMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String durationMinutesShort(int count);

  /// No description provided for @durationHoursShort.
  ///
  /// In en, this message translates to:
  /// **'{count} h'**
  String durationHoursShort(int count);

  /// No description provided for @durationDaysShort.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 day} other {{count} days}}'**
  String durationDaysShort(int count);

  /// No description provided for @messageTakenByYou.
  ///
  /// In en, this message translates to:
  /// **'You took it'**
  String get messageTakenByYou;

  /// No description provided for @labelVerdict.
  ///
  /// In en, this message translates to:
  /// **'VERDICT'**
  String get labelVerdict;

  /// No description provided for @tooltipPlanModeActive.
  ///
  /// In en, this message translates to:
  /// **'Plan mode active: proposes instead of asserting'**
  String get tooltipPlanModeActive;

  /// No description provided for @messageNewRequirementSessionNote.
  ///
  /// In en, this message translates to:
  /// **'It\'s going to open a new session in #{workflowName}. Choose the row of agents that matches this request — evaluating a requirement is rarely the same as resolving a ticket.'**
  String messageNewRequirementSessionNote(String workflowName);

  /// No description provided for @labelProjectNoLongerExists.
  ///
  /// In en, this message translates to:
  /// **'a project that no longer exists'**
  String get labelProjectNoLongerExists;

  /// No description provided for @assistantWindowTitle.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get assistantWindowTitle;

  /// No description provided for @buttonAskKeelAi.
  ///
  /// In en, this message translates to:
  /// **'Ask Keel AI'**
  String get buttonAskKeelAi;

  /// No description provided for @buttonCreateByHand.
  ///
  /// In en, this message translates to:
  /// **'Create by hand'**
  String get buttonCreateByHand;

  /// No description provided for @buttonOverwriteAnyway.
  ///
  /// In en, this message translates to:
  /// **'Overwrite anyway'**
  String get buttonOverwriteAnyway;

  /// No description provided for @hintAskAboutThisLine.
  ///
  /// In en, this message translates to:
  /// **'Ask about this line…'**
  String get hintAskAboutThisLine;

  /// No description provided for @hintQueuedMessage.
  ///
  /// In en, this message translates to:
  /// **'Message that will be sent on the next turn'**
  String get hintQueuedMessage;

  /// No description provided for @hintSessionName.
  ///
  /// In en, this message translates to:
  /// **'Session name'**
  String get hintSessionName;

  /// No description provided for @labelCloseSession.
  ///
  /// In en, this message translates to:
  /// **'Close session'**
  String get labelCloseSession;

  /// No description provided for @labelDeleteIntegration.
  ///
  /// In en, this message translates to:
  /// **'Delete integration'**
  String get labelDeleteIntegration;

  /// No description provided for @labelFileChanged.
  ///
  /// In en, this message translates to:
  /// **'The file changed'**
  String get labelFileChanged;

  /// No description provided for @labelGiveToKeelAi.
  ///
  /// In en, this message translates to:
  /// **'Give it to Keel AI (the assistant)'**
  String get labelGiveToKeelAi;

  /// No description provided for @labelHeadersKeyValue.
  ///
  /// In en, this message translates to:
  /// **'Headers (KEY=value, one per line)'**
  String get labelHeadersKeyValue;

  /// No description provided for @labelKnowledgeBaseAnswers.
  ///
  /// In en, this message translates to:
  /// **'What this base answers'**
  String get labelKnowledgeBaseAnswers;

  /// No description provided for @labelModelWithProvider.
  ///
  /// In en, this message translates to:
  /// **'Model ({provider})'**
  String labelModelWithProvider(String provider);

  /// No description provided for @labelMaxReplansLimit.
  ///
  /// In en, this message translates to:
  /// **'Replan limit: {count}'**
  String labelMaxReplansLimit(int count);

  /// No description provided for @labelMaxReviewCyclesLimit.
  ///
  /// In en, this message translates to:
  /// **'Shared audit cycles: {count}'**
  String labelMaxReviewCyclesLimit(int count);

  /// No description provided for @labelMaxSubagentsLimit.
  ///
  /// In en, this message translates to:
  /// **'Read/verification subagents: {count}'**
  String labelMaxSubagentsLimit(int count);

  /// No description provided for @labelIdleTimeoutLimit.
  ///
  /// In en, this message translates to:
  /// **'Minutes without provider activity before a step is cut: {count}'**
  String labelIdleTimeoutLimit(int count);

  /// No description provided for @labelNodeTimeoutLimit.
  ///
  /// In en, this message translates to:
  /// **'Maximum minutes per step: {count}'**
  String labelNodeTimeoutLimit(int count);

  /// No description provided for @labelSessionCostLimit.
  ///
  /// In en, this message translates to:
  /// **'Session cost ceiling in USD (0 = no ceiling): {amount}'**
  String labelSessionCostLimit(int amount);

  /// No description provided for @labelNoBoardsYet.
  ///
  /// In en, this message translates to:
  /// **'No boards yet'**
  String get labelNoBoardsYet;

  /// No description provided for @labelNoSessionOpen.
  ///
  /// In en, this message translates to:
  /// **'No session open'**
  String get labelNoSessionOpen;

  /// No description provided for @labelPasteBlockAsInDocs.
  ///
  /// In en, this message translates to:
  /// **'Paste the block exactly as shown in the docs'**
  String get labelPasteBlockAsInDocs;

  /// No description provided for @labelPasteMcpConfig.
  ///
  /// In en, this message translates to:
  /// **'Paste an MCP configuration'**
  String get labelPasteMcpConfig;

  /// No description provided for @labelProjectPurpose.
  ///
  /// In en, this message translates to:
  /// **'Purpose'**
  String get labelProjectPurpose;

  /// No description provided for @labelRequirementContext.
  ///
  /// In en, this message translates to:
  /// **'Context: what they did and why they need it'**
  String get labelRequirementContext;

  /// No description provided for @labelRequirementNeed.
  ///
  /// In en, this message translates to:
  /// **'What is needed'**
  String get labelRequirementNeed;

  /// No description provided for @labelRequirementTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get labelRequirementTitle;

  /// No description provided for @labelSessionAgents.
  ///
  /// In en, this message translates to:
  /// **'Agents for this session'**
  String get labelSessionAgents;

  /// No description provided for @labelSpecification.
  ///
  /// In en, this message translates to:
  /// **'Specification'**
  String get labelSpecification;

  /// No description provided for @labelTermsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get labelTermsOfUse;

  /// No description provided for @labelWhichWorkflowRuns.
  ///
  /// In en, this message translates to:
  /// **'Which workflow runs'**
  String get labelWhichWorkflowRuns;

  /// No description provided for @messageCloseSessionBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes the thread of \"{title}\" and the context the agents built up in it. The project stays the same, with its agents, rules, and documents.'**
  String messageCloseSessionBody(String title);

  /// No description provided for @messageDeleteIntegrationBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" gets deleted. Agents that had it assigned stop receiving its tools.'**
  String messageDeleteIntegrationBody(String name);

  /// No description provided for @messageFileChangedBody.
  ///
  /// In en, this message translates to:
  /// **'This file was modified (for example, the agent edited it) since you opened this window. If you save now, you will overwrite that change with what you have here.'**
  String get messageFileChangedBody;

  /// No description provided for @messageNoAgentsToAdd.
  ///
  /// In en, this message translates to:
  /// **'No more registered agents to add'**
  String get messageNoAgentsToAdd;

  /// No description provided for @messageNoBoardsExplainer.
  ///
  /// In en, this message translates to:
  /// **'A board is a small screen for triggering something against your own app: launch an offer, send yourself a push, hit an endpoint you\'re writing.\n\nThe fastest way is to ask a project agent for it: it reads your code and builds it on its own. It shows up in that project\'s Boards section.'**
  String get messageNoBoardsExplainer;

  /// No description provided for @messageNoExtraAgentsYet.
  ///
  /// In en, this message translates to:
  /// **'None yet.'**
  String get messageNoExtraAgentsYet;

  /// No description provided for @messageNoKnowledgeBasesYet.
  ///
  /// In en, this message translates to:
  /// **'No knowledge base yet.'**
  String get messageNoKnowledgeBasesYet;

  /// No description provided for @messageNoMcpServersRegistered.
  ///
  /// In en, this message translates to:
  /// **'No external MCP registered yet.'**
  String get messageNoMcpServersRegistered;

  /// No description provided for @messageSessionGone.
  ///
  /// In en, this message translates to:
  /// **'The session no longer exists.'**
  String get messageSessionGone;

  /// No description provided for @messageWhichWorkflowRunsNote.
  ///
  /// In en, this message translates to:
  /// **'This session, and no other. A project does jobs of different kinds — building the task folder, resolving a ticket, evaluating a requirement — and each one wants a different row of agents.'**
  String get messageWhichWorkflowRunsNote;

  /// No description provided for @sectionAddToSession.
  ///
  /// In en, this message translates to:
  /// **'Add to this session'**
  String get sectionAddToSession;

  /// No description provided for @sectionProjectMembers.
  ///
  /// In en, this message translates to:
  /// **'Project members (in every session)'**
  String get sectionProjectMembers;

  /// No description provided for @sectionSessionOnly.
  ///
  /// In en, this message translates to:
  /// **'Only in THIS session'**
  String get sectionSessionOnly;

  /// No description provided for @tooltipAgentAnsweringThread.
  ///
  /// In en, this message translates to:
  /// **'An agent is answering in the thread'**
  String get tooltipAgentAnsweringThread;

  /// No description provided for @tooltipGoToLatestMessage.
  ///
  /// In en, this message translates to:
  /// **'Go to the most recent message'**
  String get tooltipGoToLatestMessage;

  /// No description provided for @tooltipGuardrailsAutorun.
  ///
  /// In en, this message translates to:
  /// **'Guardrails that run on their own'**
  String get tooltipGuardrailsAutorun;

  /// No description provided for @tooltipLegendMeaning.
  ///
  /// In en, this message translates to:
  /// **'What each line means'**
  String get tooltipLegendMeaning;

  /// No description provided for @tooltipNewConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get tooltipNewConversation;

  /// No description provided for @tooltipRefreshCatalog.
  ///
  /// In en, this message translates to:
  /// **'Refresh catalog'**
  String get tooltipRefreshCatalog;

  /// No description provided for @tooltipRemoveFromSession.
  ///
  /// In en, this message translates to:
  /// **'Remove from this session'**
  String get tooltipRemoveFromSession;

  /// No description provided for @tooltipRunsCommandsOnYourMachine.
  ///
  /// In en, this message translates to:
  /// **'Runs commands on your machine'**
  String get tooltipRunsCommandsOnYourMachine;

  /// No description provided for @tooltipWorkingNow.
  ///
  /// In en, this message translates to:
  /// **'Working now'**
  String get tooltipWorkingNow;

  /// No description provided for @workflowTitleTaskFormat.
  ///
  /// In en, this message translates to:
  /// **'Build the task format'**
  String get workflowTitleTaskFormat;

  /// No description provided for @workflowTitleVerifyFormat.
  ///
  /// In en, this message translates to:
  /// **'Verify format'**
  String get workflowTitleVerifyFormat;

  /// No description provided for @workflowTitlePlanAndScope.
  ///
  /// In en, this message translates to:
  /// **'Plan and scope'**
  String get workflowTitlePlanAndScope;

  /// No description provided for @workflowTitleSingleEntryPoint.
  ///
  /// In en, this message translates to:
  /// **'Design the single entry point'**
  String get workflowTitleSingleEntryPoint;

  /// No description provided for @workflowTitleImplement.
  ///
  /// In en, this message translates to:
  /// **'Implement with evidence'**
  String get workflowTitleImplement;

  /// No description provided for @workflowTitleCodeAudit.
  ///
  /// In en, this message translates to:
  /// **'Audit code'**
  String get workflowTitleCodeAudit;

  /// No description provided for @workflowTitleCodeCorrection.
  ///
  /// In en, this message translates to:
  /// **'Fix code findings'**
  String get workflowTitleCodeCorrection;

  /// No description provided for @workflowTitleTests.
  ///
  /// In en, this message translates to:
  /// **'Create and adjust tests'**
  String get workflowTitleTests;

  /// No description provided for @workflowTitleTestAudit.
  ///
  /// In en, this message translates to:
  /// **'Audit tests'**
  String get workflowTitleTestAudit;

  /// No description provided for @workflowTitleTestCorrection.
  ///
  /// In en, this message translates to:
  /// **'Fix test findings'**
  String get workflowTitleTestCorrection;

  /// No description provided for @workflowTitleDeviceE2e.
  ///
  /// In en, this message translates to:
  /// **'End-to-end verification on device'**
  String get workflowTitleDeviceE2e;

  /// No description provided for @workflowTitleVerification.
  ///
  /// In en, this message translates to:
  /// **'Closing verification'**
  String get workflowTitleVerification;

  /// No description provided for @workflowTitlePublishApproval.
  ///
  /// In en, this message translates to:
  /// **'Approve publication'**
  String get workflowTitlePublishApproval;

  /// No description provided for @termsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version 1 — August 2026'**
  String get termsVersion;

  /// No description provided for @termsSection1Title.
  ///
  /// In en, this message translates to:
  /// **'1. What Keel is'**
  String get termsSection1Title;

  /// No description provided for @termsSection1Body.
  ///
  /// In en, this message translates to:
  /// **'Keel is a desktop tool that works on top of the agent CLIs you already have installed on your machine. It isn\'t a service: there\'s no Keel server you connect to, no account to create, and no registration. If you turn off the internet, Keel still opens.\n\nUsing Keel means accepting these terms. If you disagree with any of them, don\'t use it.'**
  String get termsSection1Body;

  /// No description provided for @termsSection2Title.
  ///
  /// In en, this message translates to:
  /// **'2. Who owns it'**
  String get termsSection2Title;

  /// No description provided for @termsSection2Body.
  ///
  /// In en, this message translates to:
  /// **'Keel — its code, its design, its name, its documentation and everything that comes with it — is the intellectual property of Jhonatan Ortiz (JhonaCode), software engineer. All rights reserved.\n\nIt is not free or open-source software. It isn\'t distributed under MIT, Apache, BSD, GPL, or any other permissive license. Having a copy doesn\'t give you the right to use it: you need the author\'s written permission. The full text is in the LICENSE file.'**
  String get termsSection2Body;

  /// No description provided for @termsSection3Title.
  ///
  /// In en, this message translates to:
  /// **'3. Only downloadable from jhonacode.com'**
  String get termsSection3Title;

  /// No description provided for @termsSection3Body.
  ///
  /// In en, this message translates to:
  /// **'The author exclusively reserves the right to distribute Keel. The ONLY authorized channel is jhonacode.com.\n\nRepublishing, mirroring, uploading to another site, including it in a package repository, an app store, a container image, or any other distribution channel — free or paid — is prohibited. Keel also can\'t be resold, rented, sublicensed, or offered as a service to third parties.'**
  String get termsSection3Body;

  /// No description provided for @termsSection4Title.
  ///
  /// In en, this message translates to:
  /// **'4. Copies that didn\'t come from there'**
  String get termsSection4Title;

  /// No description provided for @termsSection4Body.
  ///
  /// In en, this message translates to:
  /// **'Any copy of Keel obtained outside jhonacode.com is unauthorized, and the author has no way of knowing what was done to it: it may have been modified, bundled with something else, or altered to do something Keel doesn\'t do.\n\nThe author isn\'t responsible for those copies or what they cause, and nothing they do can be attributed to the author. A build modified by a third party isn\'t Keel, even if it\'s called that. If what runs on your machine matters to you, download it from the official site.'**
  String get termsSection4Body;

  /// No description provided for @termsSection5Title.
  ///
  /// In en, this message translates to:
  /// **'5. Keel doesn\'t ask for your data'**
  String get termsSection5Title;

  /// No description provided for @termsSection5Body.
  ///
  /// In en, this message translates to:
  /// **'It doesn\'t ask for your name, email, passwords, or any keys. There\'s no login. Everything you set up — projects, agents, skills, tools, knowledge bases, chat threads, and settings — is stored on your own machine.\n\nYour secret values never leave in a backup: the backup only carries the names, so you know which ones to fill in on the other end. The scheduled-jobs API only listens on loopback, meaning it can\'t be reached from outside your machine.'**
  String get termsSection5Body;

  /// No description provided for @termsSection6Title.
  ///
  /// In en, this message translates to:
  /// **'6. The only thing that does leave your machine'**
  String get termsSection6Title;

  /// No description provided for @termsSection6Body.
  ///
  /// In en, this message translates to:
  /// **'If this build ships with a reporting channel configured, when something breaks it\'s sent to that channel: the error message, its trace, the Keel file where it happened, your team\'s name, and whether the build is development or production.\n\nNothing else is sent. Not your chat content, not your files, not your secrets, not what projects you have. It serves one purpose: letting whoever maintains Keel know something failed.'**
  String get termsSection6Body;

  /// No description provided for @termsSection7Title.
  ///
  /// In en, this message translates to:
  /// **'7. Keel is a tool, and you\'re the one steering it'**
  String get termsSection7Title;

  /// No description provided for @termsSection7Body.
  ///
  /// In en, this message translates to:
  /// **'Keel launches agents with the permissions you give them, and those permissions can include full access to your disk. An agent can create, modify, and delete files, run commands, and make commits to your repositories.\n\nYou decide which permissions to grant, over which folders, and what you ask each agent to do. Keel executes those decisions; it doesn\'t make them for you and doesn\'t supervise them. The author isn\'t responsible for how you use the tool or for the consequences of what agents do following your instructions.'**
  String get termsSection7Body;

  /// No description provided for @termsSection8Title.
  ///
  /// In en, this message translates to:
  /// **'8. Your files are yours, and so are your backups'**
  String get termsSection8Title;

  /// No description provided for @termsSection8Body.
  ///
  /// In en, this message translates to:
  /// **'A tool that gives an agent access to your disk can end up with files lost, overwritten, or changed in a way you didn\'t want. That can happen through a Keel bug, an agent error, or an instruction of yours that turned out differently than you intended.\n\nKeeping backups of what matters to you is your responsibility. The author isn\'t liable for data loss or corruption.'**
  String get termsSection8Body;

  /// No description provided for @termsSection9Title.
  ///
  /// In en, this message translates to:
  /// **'9. Not for critical uses'**
  String get termsSection9Title;

  /// No description provided for @termsSection9Body.
  ///
  /// In en, this message translates to:
  /// **'Keel isn\'t designed or tested for environments where a failure would put life, health, safety, or essential infrastructure at risk: medicine, aviation, transportation, energy, industrial control, or similar. Don\'t use it there.'**
  String get termsSection9Body;

  /// No description provided for @termsSection10Title.
  ///
  /// In en, this message translates to:
  /// **'10. What doesn\'t depend on Keel'**
  String get termsSection10Title;

  /// No description provided for @termsSection10Body.
  ///
  /// In en, this message translates to:
  /// **'The agent CLIs and MCP servers you use are third-party. Each has its own terms, its own prices, and its own way of handling what you send it. Keel isn\'t responsible for them, for what they charge, for what they do with the information they receive, or for what they decide to change or discontinue.\n\nComplying with those services\' terms is on you.'**
  String get termsSection10Body;

  /// No description provided for @termsSection11Title.
  ///
  /// In en, this message translates to:
  /// **'11. What you agree not to do'**
  String get termsSection11Title;

  /// No description provided for @termsSection11Body.
  ///
  /// In en, this message translates to:
  /// **'Not copy, modify, translate, or create derivative works of Keel.\nNot reverse-engineer, decompile, or disassemble it, except where the law imperatively allows it.\nNot circumvent or disable any technical protection measure.\nNot remove or hide authorship, copyright, or license notices.\nNot use Keel\'s or JhonaCode\'s name, logo, or image without written permission.\nNot use Keel or any part of it to train machine-learning models or artificial-intelligence systems.\nNot use Keel for anything illegal, or to infringe on third-party rights.'**
  String get termsSection11Body;

  /// No description provided for @termsSection12Title.
  ///
  /// In en, this message translates to:
  /// **'12. If your use causes a problem for the author'**
  String get termsSection12Title;

  /// No description provided for @termsSection12Body.
  ///
  /// In en, this message translates to:
  /// **'If a third party makes a claim over how you used Keel, or over what you did with what it produced, that claim is yours. You agree to keep the author free from any harm, expense, or liability arising from your use of the tool or from breaching these terms.'**
  String get termsSection12Body;

  /// No description provided for @termsSection13Title.
  ///
  /// In en, this message translates to:
  /// **'13. No warranty'**
  String get termsSection13Title;

  /// No description provided for @termsSection13Body.
  ///
  /// In en, this message translates to:
  /// **'Keel is provided AS IS and AS AVAILABLE, without warranty of any kind, express or implied. There\'s no guarantee it will run without errors or interruptions, that it will be available, that it will be compatible with your equipment or tools, or that it will serve any particular purpose.'**
  String get termsSection13Body;

  /// No description provided for @termsSection14Title.
  ///
  /// In en, this message translates to:
  /// **'14. How far liability goes'**
  String get termsSection14Title;

  /// No description provided for @termsSection14Body.
  ///
  /// In en, this message translates to:
  /// **'To the extent the law allows, the author isn\'t liable for indirect, incidental, special, or consequential damages, nor for lost profits, data loss, lost work time, or business interruption, even if advised of that possibility.\n\nIf liability is nonetheless found, its total limit will be what you paid for Keel in the twelve months prior to the event, which in practice is zero: Keel isn\'t sold, and donations aren\'t payment for the software.'**
  String get termsSection14Body;

  /// No description provided for @termsSection15Title.
  ///
  /// In en, this message translates to:
  /// **'15. Donations'**
  String get termsSection15Title;

  /// No description provided for @termsSection15Body.
  ///
  /// In en, this message translates to:
  /// **'If Keel is useful to you and you want to support the work, it\'s appreciated. It\'s entirely voluntary.\n\nA donation is exactly that and nothing more: it isn\'t a purchase, it isn\'t a license, it doesn\'t grant the right to use the software without permission, it doesn\'t include support, it doesn\'t give priority on anything, it doesn\'t create any obligation from the author to the donor, and it isn\'t refunded.'**
  String get termsSection15Body;

  /// No description provided for @termsSection16Title.
  ///
  /// In en, this message translates to:
  /// **'16. When permission ends'**
  String get termsSection16Title;

  /// No description provided for @termsSection16Body.
  ///
  /// In en, this message translates to:
  /// **'Any use outside what\'s authorized immediately and without notice ends all permission granted. A previously granted permission may also be revoked. Upon termination, you must stop using Keel and delete any copies you have.\n\nThe sections on ownership, liability, warranty, and indemnity remain in effect after that.'**
  String get termsSection16Body;

  /// No description provided for @termsSection17Title.
  ///
  /// In en, this message translates to:
  /// **'17. If any clause doesn\'t hold'**
  String get termsSection17Title;

  /// No description provided for @termsSection17Body.
  ///
  /// In en, this message translates to:
  /// **'If a court declares any part of these terms invalid or unenforceable, the rest remains in force, and that part is interpreted as closely as possible to its original intent.\n\nThe author not exercising a right at some point doesn\'t mean giving it up. There\'s no partnership, employment, franchise, or representation of any kind between Keel and you.'**
  String get termsSection17Body;

  /// No description provided for @termsSection18Title.
  ///
  /// In en, this message translates to:
  /// **'18. Governing law'**
  String get termsSection18Title;

  /// No description provided for @termsSection18Body.
  ///
  /// In en, this message translates to:
  /// **'These terms are governed by the laws of the author\'s country of residence, and any dispute is submitted to the competent courts of that place.'**
  String get termsSection18Body;

  /// No description provided for @termsSection19Title.
  ///
  /// In en, this message translates to:
  /// **'19. These terms can change'**
  String get termsSection19Title;

  /// No description provided for @termsSection19Body.
  ///
  /// In en, this message translates to:
  /// **'If they change, the version that applies is the one this screen shows. Continuing to use Keel after a change means you accept it.'**
  String get termsSection19Body;

  /// No description provided for @termsSection20Title.
  ///
  /// In en, this message translates to:
  /// **'20. Contact'**
  String get termsSection20Title;

  /// No description provided for @termsSection20Body.
  ///
  /// In en, this message translates to:
  /// **'To request permission for a use, donate, report something, or any other inquiry: jhonacode.com'**
  String get termsSection20Body;

  /// No description provided for @messageWriteToAgent.
  ///
  /// In en, this message translates to:
  /// **'Write something to your agent'**
  String get messageWriteToAgent;

  /// No description provided for @skillAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'The skill \"{name}\" already existed, I reused it.'**
  String skillAlreadyExists(String name);

  /// No description provided for @ruleAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'The rule \"{name}\" already existed, I reused it.'**
  String ruleAlreadyExists(String name);

  /// No description provided for @toolAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'The tool \"{name}\" already existed, I reused it.'**
  String toolAlreadyExists(String name);

  /// No description provided for @skillCreated.
  ///
  /// In en, this message translates to:
  /// **'I created the skill \"{name}\".'**
  String skillCreated(String name);

  /// No description provided for @ruleCreated.
  ///
  /// In en, this message translates to:
  /// **'I created the rule \"{name}\".'**
  String ruleCreated(String name);

  /// No description provided for @handleReserved.
  ///
  /// In en, this message translates to:
  /// **'The handle \"{handle}\" is reserved.'**
  String handleReserved(String handle);

  /// No description provided for @keelAiModifyBlocked.
  ///
  /// In en, this message translates to:
  /// **'Keel AI requested to modify a locked element.'**
  String get keelAiModifyBlocked;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'es':
      {
        switch (locale.countryCode) {
          case 'CO':
            return AppLocalizationsEsCo();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
