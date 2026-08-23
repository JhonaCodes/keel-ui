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
