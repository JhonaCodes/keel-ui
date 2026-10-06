import 'package:keel_core/shared/validation_l10n.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';

/// Adapts the generated [AppLocalizations] to the `ValidationL10n` surface
/// `keel_core`'s validators and default-capability builders accept —
/// `AppLocalizations` is Flutter-generated and can't be a `keel_core`
/// dependency directly.
class AppLocalizationsValidation implements ValidationL10n {
  const AppLocalizationsValidation(this._l10n);

  final AppLocalizations _l10n;

  @override
  String get validationNameRequired => _l10n.validationNameRequired;

  @override
  String validationMaxCharacters(int max) => _l10n.validationMaxCharacters(max);

  @override
  String get validationNoSpaces => _l10n.validationNoSpaces;

  @override
  String get validationLowercaseOnly => _l10n.validationLowercaseOnly;

  @override
  String get validationBoardKey => _l10n.validationBoardKey;

  @override
  String get workflowTitleTaskFormat => _l10n.workflowTitleTaskFormat;

  @override
  String get workflowTitleVerifyFormat => _l10n.workflowTitleVerifyFormat;

  @override
  String get workflowTitlePlanAndScope => _l10n.workflowTitlePlanAndScope;

  @override
  String get workflowTitleImplement => _l10n.workflowTitleImplement;

  @override
  String get workflowTitleSingleEntryPoint =>
      _l10n.workflowTitleSingleEntryPoint;

  @override
  String get workflowTitleTests => _l10n.workflowTitleTests;

  @override
  String get workflowTitleTestAudit => _l10n.workflowTitleTestAudit;

  @override
  String get workflowTitleCodeAudit => _l10n.workflowTitleCodeAudit;

  @override
  String get workflowTitleVerification => _l10n.workflowTitleVerification;

  @override
  String get workflowTitleDeviceE2e => _l10n.workflowTitleDeviceE2e;
}
