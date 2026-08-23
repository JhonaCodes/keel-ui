// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get buttonApply => 'Aplicar';

  @override
  String get buttonApplySelection => 'Aplicar lo seleccionado';

  @override
  String get buttonCancel => 'Cancelar';

  @override
  String get buttonCreate => 'Crear';

  @override
  String buttonCreateEntity(String entity) {
    return 'Crear $entity';
  }

  @override
  String get buttonDelete => 'Eliminar';

  @override
  String get buttonEdit => 'Editar';

  @override
  String get buttonSave => 'Guardar';

  @override
  String get buttonSearch => 'Buscar';

  @override
  String get actionCloneVault => 'Clonar vault';

  @override
  String get actionCloneAndRead => 'Clonar y leer';

  @override
  String get actionChooseDestinationAndExport => 'Elegir destino y exportar';

  @override
  String get actionExportBackup => 'Exportar respaldo';

  @override
  String get actionExportPackage => 'Exportar un paquete';

  @override
  String get actionSaveZip => 'Guardar el zip…';

  @override
  String get actionImportBackup => 'Importar respaldo';

  @override
  String get actionIncludeSecrets => 'Incluir secrets (con sus VALORES)';

  @override
  String get actionReadBackup => 'Leer el respaldo';

  @override
  String get actionRestoreFromVault => 'Restaurar desde el vault';

  @override
  String get actionRestoreSelection => 'Restaurar lo seleccionado';

  @override
  String get actionBringEverythingAndStart => 'Traer todo e iniciar';

  @override
  String get actionUnifyInMain => 'Unificar en el principal';

  @override
  String get actionReviewAgain => 'Volver a revisar';

  @override
  String get actionStartFromScratch => 'Empezar de cero';

  @override
  String get actionReadyEnter => 'Listo — entrar';

  @override
  String get labelAgents => 'Agentes';

  @override
  String get labelWorkflows => 'Workflows';

  @override
  String get labelSkills => 'Skills';

  @override
  String get labelProject => 'Proyecto';

  @override
  String get labelSession => 'Sesión';

  @override
  String get labelRules => 'Reglas';

  @override
  String get labelHooks => 'Hooks';

  @override
  String get labelTools => 'Herramientas';

  @override
  String get labelIntegrations => 'Integraciones';

  @override
  String get labelKnowledgeBases => 'Bases de saber';

  @override
  String get labelSecrets => 'Secretos';

  @override
  String get labelSettings => 'Ajustes';

  @override
  String get messageErrorGeneric => 'Algo salió mal. Intenta de nuevo.';

  @override
  String get messageErrorNetwork => 'No se pudo conectar. Verifica tu red.';

  @override
  String get messageErrorFileContainsNothing =>
      'El archivo no contiene nada aplicable.';

  @override
  String get messageErrorBackupContainsNothing =>
      'El respaldo no contiene nada aplicable.';

  @override
  String messageSuccessCreated(String entity) {
    return '$entity creado exitosamente.';
  }

  @override
  String get messageSuccessSaved => 'Guardado.';

  @override
  String messageSuccessDeleted(String entity) {
    return '$entity eliminado.';
  }

  @override
  String confirmationDeleteTitle(String entity) {
    return '¿Eliminar $entity?';
  }

  @override
  String get confirmationDeleteMessage =>
      '¿Estás seguro? Esto no se puede deshacer.';

  @override
  String get confirmationProceed => 'Continuar';

  @override
  String get placeholderSearchByName => 'Busca por nombre…';

  @override
  String get placeholderFilterResults => 'Filtra los resultados…';

  @override
  String get placeholderAskAboutLine => 'Pregunta sobre esta línea…';

  @override
  String get hintFieldRequired => 'Campo requerido.';

  @override
  String get hintEmailInvalid => 'Email inválido.';

  @override
  String get hintPasswordTooShort =>
      'La contraseña debe tener al menos 8 caracteres.';

  @override
  String get tooltipWorktreeSeparate => 'Worktree aparte';

  @override
  String get tooltipOpenInFinder => 'Abrir en Finder';

  @override
  String get tooltipCopyToClipboard => 'Copiar al portapapeles';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español (Colombia)';

  @override
  String get settingLanguage => 'Idioma';

  @override
  String get settingTheme => 'Tema';

  @override
  String get settingThemeDark => 'Oscuro';

  @override
  String get settingThemeLight => 'Claro';

  @override
  String countAgent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count agentes',
      one: '1 agente',
    );
    return '$_temp0';
  }

  @override
  String countSession(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sesiones',
      one: '1 sesión',
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
      other: '$count resultados encontrados',
      one: '1 resultado encontrado',
      zero: 'No se encontraron resultados',
    );
    return '$_temp0';
  }
}

/// The translations for Spanish Castilian, as used in Colombia (`es_CO`).
class AppLocalizationsEsCo extends AppLocalizationsEs {
  AppLocalizationsEsCo() : super('es_CO');

  @override
  String get buttonApply => 'Aplicar';

  @override
  String get buttonApplySelection => 'Aplicar lo seleccionado';

  @override
  String get buttonCancel => 'Cancelar';

  @override
  String get buttonCreate => 'Crear';

  @override
  String buttonCreateEntity(String entity) {
    return 'Crear $entity';
  }

  @override
  String get buttonDelete => 'Eliminar';

  @override
  String get buttonEdit => 'Editar';

  @override
  String get buttonSave => 'Guardar';

  @override
  String get buttonSearch => 'Buscar';

  @override
  String get actionCloneVault => 'Clonar vault';

  @override
  String get actionCloneAndRead => 'Clonar y leer';

  @override
  String get actionChooseDestinationAndExport => 'Elegir destino y exportar';

  @override
  String get actionExportBackup => 'Exportar respaldo';

  @override
  String get actionExportPackage => 'Exportar un paquete';

  @override
  String get actionSaveZip => 'Guardar el zip…';

  @override
  String get actionImportBackup => 'Importar respaldo';

  @override
  String get actionIncludeSecrets => 'Incluir secrets (con sus VALORES)';

  @override
  String get actionReadBackup => 'Leer el respaldo';

  @override
  String get actionRestoreFromVault => 'Restaurar desde el vault';

  @override
  String get actionRestoreSelection => 'Restaurar lo seleccionado';

  @override
  String get actionBringEverythingAndStart => 'Traer todo e iniciar';

  @override
  String get actionUnifyInMain => 'Unificar en el principal';

  @override
  String get actionReviewAgain => 'Volver a revisar';

  @override
  String get actionStartFromScratch => 'Empezar de cero';

  @override
  String get actionReadyEnter => 'Listo — entrar';

  @override
  String get labelAgents => 'Agentes';

  @override
  String get labelWorkflows => 'Workflows';

  @override
  String get labelSkills => 'Skills';

  @override
  String get labelProject => 'Proyecto';

  @override
  String get labelSession => 'Sesión';

  @override
  String get labelRules => 'Reglas';

  @override
  String get labelHooks => 'Hooks';

  @override
  String get labelTools => 'Herramientas';

  @override
  String get labelIntegrations => 'Integraciones';

  @override
  String get labelKnowledgeBases => 'Bases de saber';

  @override
  String get labelSecrets => 'Secretos';

  @override
  String get labelSettings => 'Ajustes';

  @override
  String get messageErrorGeneric => 'Algo salió mal. Intenta de nuevo.';

  @override
  String get messageErrorNetwork => 'No se pudo conectar. Verifica tu red.';

  @override
  String get messageErrorFileContainsNothing =>
      'El archivo no contiene nada aplicable.';

  @override
  String get messageErrorBackupContainsNothing =>
      'El respaldo no contiene nada aplicable.';

  @override
  String messageSuccessCreated(String entity) {
    return '$entity creado exitosamente.';
  }

  @override
  String get messageSuccessSaved => 'Guardado.';

  @override
  String messageSuccessDeleted(String entity) {
    return '$entity eliminado.';
  }

  @override
  String confirmationDeleteTitle(String entity) {
    return '¿Eliminar $entity?';
  }

  @override
  String get confirmationDeleteMessage =>
      '¿Estás seguro? Esto no se puede deshacer.';

  @override
  String get confirmationProceed => 'Continuar';

  @override
  String get placeholderSearchByName => 'Busca por nombre…';

  @override
  String get placeholderFilterResults => 'Filtra los resultados…';

  @override
  String get placeholderAskAboutLine => 'Pregunta sobre esta línea…';

  @override
  String get hintFieldRequired => 'Campo requerido.';

  @override
  String get hintEmailInvalid => 'Email inválido.';

  @override
  String get hintPasswordTooShort =>
      'La contraseña debe tener al menos 8 caracteres.';

  @override
  String get tooltipWorktreeSeparate => 'Worktree aparte';

  @override
  String get tooltipOpenInFinder => 'Abrir en Finder';

  @override
  String get tooltipCopyToClipboard => 'Copiar al portapapeles';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español (Colombia)';

  @override
  String get settingLanguage => 'Idioma';

  @override
  String get settingTheme => 'Tema';

  @override
  String get settingThemeDark => 'Oscuro';

  @override
  String get settingThemeLight => 'Claro';

  @override
  String countAgent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count agentes',
      one: '1 agente',
    );
    return '$_temp0';
  }

  @override
  String countSession(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sesiones',
      one: '1 sesión',
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
      other: '$count resultados encontrados',
      one: '1 resultado encontrado',
      zero: 'No se encontraron resultados',
    );
    return '$_temp0';
  }
}
