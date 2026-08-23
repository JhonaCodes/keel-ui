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
}
