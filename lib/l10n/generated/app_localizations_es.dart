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

  @override
  String get pageTitleSettings => 'Configuración';

  @override
  String get pageTitleSkillsRegistered => 'Skills registrados';

  @override
  String get pageTitleSecrets => 'Secretos';

  @override
  String get pageTitleHooksRegistered => 'Hooks registrados';

  @override
  String get pageTitleRulesRegistered => 'Reglas registradas';

  @override
  String get pageTitleTestBoard => 'Banco de pruebas';

  @override
  String get pageTitleTools => 'Herramientas registradas';

  @override
  String get pageTitleIntegrations => 'Integraciones';

  @override
  String get pageTitleMachine => 'Máquina';

  @override
  String get pageTitleAgentsRegistered => 'Agentes registrados';

  @override
  String get pageTitleKnowledge => 'Saber';

  @override
  String get pageTitleInternalRequirements => 'Requerimientos internos';

  @override
  String get pageTitleProjects => 'Proyectos';

  @override
  String get pageTitleSessionAgents => 'Agentes de esta sesión';

  @override
  String get pageTitleImportHooks => 'Importar hooks de Claude Code';

  @override
  String get pageTitleTermsOfUse => 'Términos de uso';

  @override
  String get pageTitleLockedElements => 'Elementos bloqueados';

  @override
  String get pageTitleOpenRequirement => 'Abrir un requerimiento';

  @override
  String get pageTitleModifySharedDefault => 'Modificar default compartido';

  @override
  String get pageTitlePasteMCPConfig => 'Pegar una configuración MCP';

  @override
  String get pageTitleImportBackup => 'Importar respaldo';

  @override
  String get pageTitleExportPackage => 'Exportar un paquete';

  @override
  String get pageTitleBackup => 'Respaldo';

  @override
  String get pageTitleImportPackage => 'Importar un paquete';

  @override
  String get pageTitleFaults => 'Fallas';

  @override
  String get pageTitleEditQueuedMessage => 'Editar mensaje en espera';

  @override
  String get pageTitleRegisteredWorkflows => 'Workflows registrados';

  @override
  String get pageTitleUseAgent => 'Usar un agente';

  @override
  String pageTitleEngineOf(String member) {
    return 'Motor de @$member';
  }

  @override
  String get pageTitleRejectClosure => 'Rechazar el cierre';

  @override
  String get settingTextSize => 'Tamaño del texto';

  @override
  String get settingWritePermissions => 'Permisos de escritura';

  @override
  String get settingScheduledJobsApi => 'API de trabajos programados';

  @override
  String get settingApplyToAllAgents => 'Aplicar a todos los agentes';

  @override
  String get settingCanAdministrateSystem => 'Puede administrar el sistema';

  @override
  String get settingBlocksRequester => 'Frena a quien lo pide';

  @override
  String get settingAccessEntireFilesystem =>
      'Acceso a todo el sistema de archivos';

  @override
  String get descriptionWritePermissions =>
      'Leer archivos, buscarlos y consultar la web siempre está permitido. Aquí decides qué pueden modificar los agentes. Aplica a todos.';

  @override
  String get descriptionScheduledJobsApi =>
      'Para schedulers externos (cron, keel): POST /projects/<nombre>/tasks con el token Bearer. Solo loopback.';

  @override
  String get descriptionLockedElements =>
      'Lo que un agente no puede cambiar ni borrar sin pedirte permiso primero. El candado se pone desde cada ítem; aquí se ven todos juntos.';

  @override
  String get labelLockedElements => 'Elementos bloqueados';

  @override
  String get labelAboutKeel => 'Acerca de Keel';

  @override
  String get labelGlobal => 'global';

  @override
  String get labelWhatExecutes => 'Qué ejecuta';

  @override
  String get labelChat => 'Chat';

  @override
  String get labelMap => 'Mapa';

  @override
  String get labelEngine => 'MOTOR';

  @override
  String get labelTurns => 'TURNOS';

  @override
  String get labelInput => 'ENTRADA';

  @override
  String get labelOutput => 'SALIDA';

  @override
  String get labelCacheRead => 'CACHÉ LEÍDA';

  @override
  String get labelSecretsEnv => 'Secretos (env)';

  @override
  String get labelSource => 'Fuente';

  @override
  String get labelAssistant => 'Asistente';

  @override
  String labelCompactContext(int percent) {
    return 'Compactar contexto ($percent%)';
  }

  @override
  String get labelRequired => 'Requerida';

  @override
  String get labelOptional => 'Opcional';

  @override
  String get labelDiff => 'Diff';

  @override
  String get labelEdit => 'Editar';

  @override
  String get labelView => 'Vista';

  @override
  String get labelAdaptiveCapabilities => 'Capacidades adaptativas';

  @override
  String get labelMandatoryContext => 'Contexto obligatorio';

  @override
  String labelReplansLimit(int count) {
    return 'Límite de reformulaciones: $count';
  }

  @override
  String labelReadVerifySubagents(int count) {
    return 'Subagentes de lectura/verificación: $count';
  }

  @override
  String labelSharedAuditCycles(int count) {
    return 'Ciclos compartidos de auditoría: $count';
  }

  @override
  String labelAgentFor(String capability) {
    return 'Agente para \\\"$capability\\\"';
  }

  @override
  String get buttonNew => 'Nuevo';

  @override
  String get buttonRegisterSkill => 'Registrar skill';

  @override
  String get buttonCreateSkill => 'Crear skill';

  @override
  String get buttonReplace => 'Reemplazar';

  @override
  String get buttonImport => 'Importar';

  @override
  String get buttonRegenerateToken => 'Regenerar token';

  @override
  String get buttonViewLocked => 'Ver bloqueados…';

  @override
  String get buttonAskKeelAI => 'Pedírselo a Keel AI';

  @override
  String get buttonCreateManually => 'Crearlo a mano';

  @override
  String get buttonRename => 'Renombrar';

  @override
  String get buttonUngroupGroup => 'Deshacer el grupo';

  @override
  String get buttonRegisterSecret => 'Registrar secret';

  @override
  String get buttonLoadValue => 'Cargar valor';

  @override
  String get buttonNewSession => 'Nueva sesión';

  @override
  String get buttonChooseFolder => 'Elegir carpeta';

  @override
  String get buttonReviewAgain => 'Revisar de nuevo';

  @override
  String get buttonDefineFormat => 'Definir el formato';

  @override
  String get buttonDocumentation => 'Documentación';

  @override
  String get buttonTestConnection => 'Probar la conexión';

  @override
  String get buttonRegisterMCP => 'Registrar MCP';

  @override
  String get buttonChoose => 'Elegir…';

  @override
  String get buttonRegisterAgent => 'Registrar agente';

  @override
  String get buttonTest => 'Probar';

  @override
  String get buttonOpenWithSystemApp => 'Abrir con la app del sistema';

  @override
  String get buttonReturnToAgentDefault => 'Volver al del agente';

  @override
  String get buttonReview => 'Revisar';

  @override
  String get buttonRebuildAndReopen => 'Reconstruir y reabrir';

  @override
  String get buttonExport => 'Exportar…';

  @override
  String get buttonImportDots => 'Importar…';

  @override
  String get buttonBackup => 'Respaldar';

  @override
  String get buttonBackupAndUpload => 'Respaldar y subir';

  @override
  String get buttonRestoreDots => 'Restaurar…';

  @override
  String get buttonBring => 'Traer';

  @override
  String get buttonInstall => 'Instalar';

  @override
  String get buttonAsk => 'Preguntar…';

  @override
  String get buttonClear => 'Vaciar';

  @override
  String get buttonView => 'Ver';

  @override
  String get buttonApproveChange => 'Aprobar cambio';

  @override
  String get buttonAddRule => 'Agregar regla';

  @override
  String get buttonAddKnowledge => 'Agregar conocimiento';

  @override
  String get buttonApproveAndContinue => 'Aprobar y continuar';

  @override
  String get buttonOpen => 'Abrir';

  @override
  String get buttonNewKnowledgeBase => 'Nueva base';

  @override
  String get buttonContinuePlanning => 'Seguir planificando';

  @override
  String get buttonImplement => 'Implementar';

  @override
  String get buttonRegister => 'Registrar';

  @override
  String get buttonReloadFromDisk => 'Recargar del disco';

  @override
  String get buttonClose => 'Cerrar';

  @override
  String get buttonReject => 'Rechazar';

  @override
  String get buttonAssignAndEvaluate => 'Tomar y evaluar';

  @override
  String get buttonGoToSession => 'Ir a la sesión';

  @override
  String get buttonRejectAndExplain => 'Rechazar y explicar';

  @override
  String get messageNoSkillsRegistered =>
      'Todavía no registraste ningún skill.';

  @override
  String get messageNoToolsRegistered =>
      'Todavía no registraste ninguna herramienta.';

  @override
  String get messageNoRulesRegistered =>
      'Todavía no registraste ninguna regla.';

  @override
  String get messageApiNotRunning =>
      'La API no está corriendo en esta ventana.';

  @override
  String messageApiUrl(int port) {
    return 'URL: http://127.0.0.1:$port';
  }

  @override
  String messageApiToken(String token) {
    return 'Token: $token';
  }

  @override
  String get messageBoardNotFound => 'Ese tablero ya no existe.';

  @override
  String get messageNoBoardsYet => 'Todavía no hay tableros';

  @override
  String get messageNoHooksRegistered => 'Todavía no registraste ningún hook.';

  @override
  String get messageNoExternalMCPs =>
      'Todavía no registraste ningún MCP externo.';

  @override
  String get messageNoProjectsRegistered =>
      'Todavía no registraste ningún proyecto.';

  @override
  String get messageNoAgentsRegistered =>
      'Todavía no registraste ningún agente.';

  @override
  String get messageNoWorkflowsRegistered =>
      'Todavía no registraste ningún workflow.';

  @override
  String get messageNoneYet => 'Ninguno todavía.';

  @override
  String get messageNoMoreAgentsToAdd =>
      'No quedan agentes registrados por sumar.';

  @override
  String messageCouldNotOpenImage(String error) {
    return 'No pude abrir la imagen: $error';
  }

  @override
  String get messageSessionNotFound => 'La sesión ya no existe.';

  @override
  String messageDrop(String name) {
    return 'Soltar $name';
  }

  @override
  String get messageFileTooLarge =>
      'El archivo es muy grande para mostrar un diff.';

  @override
  String get messageAskYourAgent => 'Escríbele algo a tu agente';

  @override
  String get messageNoKnowledgeBases => 'Todavía no hay ninguna base de saber.';

  @override
  String get messageBackupEmpty => 'El respaldo no trae nada aplicable.';

  @override
  String get optionCommand => 'Un comando';

  @override
  String get optionRegisteredTool => 'Una tool registrada';

  @override
  String get optionGiveToKeelAI => 'Dárselo a Keel AI (el asistente)';

  @override
  String get optionIMaintainIt => 'Lo mantengo yo';

  @override
  String optionUseDefault(String role) {
    return 'Usar default ($role)';
  }

  @override
  String get optionAnyMember => 'Cualquier miembro';

  @override
  String get optionNewSession => 'Nueva sesión';

  @override
  String get optionResumeParentSession => 'Reanudar sesión padre';

  @override
  String get optionProviderSubagent => 'Subagente del proveedor';

  @override
  String get optionManualApproval => 'Aprobación manual';

  @override
  String optionAgentProvider(String provider) {
    return 'El del agente ($provider)';
  }

  @override
  String optionAgentEffort(String effort) {
    return 'El del agente ($effort)';
  }

  @override
  String get titleReadOnly => 'Solo lectura';

  @override
  String get titleRequiresIndependentAgent => 'Requiere agente independiente';

  @override
  String get subtitleReadOnly => 'Planificadores y auditores no escriben.';

  @override
  String get linkWebsite => 'jhonacode.com';

  @override
  String get linkCommunity => 'Comunidad en Discord';

  @override
  String get tooltipRegisterNew => 'Registrar nuevo';

  @override
  String get tooltipImportPackage => 'Importar un paquete';

  @override
  String get tooltipDismiss => 'Descartar';

  @override
  String get messageNoHooksDescription =>
      'Un hook es un comando que se ejecuta en un momento del turno y que el agente no puede omitir: puede detener una herramienta antes de usarla o reaccionar después. Una regla pide; un hook garantiza.';

  @override
  String get labelLlmProviders => 'PROVEEDORES LLM';

  @override
  String get labelOtherSecrets => 'OTROS SECRETOS';

  @override
  String get suggestionIntro =>
      'Detecté cosas que pides con frecuencia — ¿las convertimos en skills globales?';

  @override
  String suggestionDraftHeader(int count) {
    return 'Se detectó una instrucción recurrente ($count veces). Ejemplos de lo que pediste:\\n';
  }

  @override
  String get suggestionDraftFooter => 'Redacta aquí la instrucción definitiva:';

  @override
  String get formTitleRegisterAgent => 'Registrar agente';

  @override
  String get formTitleEditAgent => 'Editar agente registrado';

  @override
  String get formLabelAgentName => 'Nombre (minúsculas, sin espacios, máx. 16)';

  @override
  String get formLabelAgentRole => 'Rol';

  @override
  String get formLabelAgentRoleHint => 'Qué hace este agente';

  @override
  String get formLabelSystemPrompt => 'System prompt';

  @override
  String get formLabelProvider =>
      'Proveedor (codex: sin tools/MCPs/esfuerzo, y sus propios modelos)';

  @override
  String formLabelModel(String provider) {
    return 'Modelo por defecto ($provider)';
  }

  @override
  String get formLabelEffort => 'Esfuerzo por defecto';

  @override
  String get formMessageCanManageSystem => 'Puede administrar el sistema';

  @override
  String get formDescriptionManageSystem =>
      'Agente constructor: recibe las mismas tools de creación que Keel AI (skills, reglas, tools, agentes, workflows, proyectos) en sus chats 1:1.';

  @override
  String get formDescriptionKeelAiHooks =>
      'Keel AI corre sin hooks a propósito: es a quien le pides apagar uno que te trabó. Lo que asignes aquí no se va a aplicar.';

  @override
  String get formDescriptionHooks =>
      'Corren fuera del modelo, así que no los puede saltear. Las reglas de arriba se piden; estos se cumplen.';

  @override
  String get formDescriptionRoles =>
      'Roles que piden tus workflows — tocá uno para que este agente los cubra:';

  @override
  String get formDescriptionRolesHelp =>
      'El preflight del workflow busca responsables por este rol.';

  @override
  String formConfirmDeleteAgent(Object name) {
    return 'Se eliminará el registro \\\"$name\\\". Esto no afecta a los chats que ya usaste con esta configuración.';
  }

  @override
  String get formTitleDeleteAgent => 'Eliminar agente registrado';

  @override
  String get tooltipEditAgent => 'Editar';

  @override
  String get tooltipExportAsPackage => 'Exportar como paquete';

  @override
  String get tooltipDeleteAgent => 'Eliminar';

  @override
  String get mapStateWaiting => 'Esperándote';

  @override
  String get mapStateFailed => 'Cortó';

  @override
  String get labelAskedFor => 'Le pidió';

  @override
  String get labelHowReasons => 'Cómo razona';

  @override
  String get statusLive => 'En vivo';

  @override
  String get labelWhatDid => 'Qué hizo';

  @override
  String get labelWhatReturned => 'Qué devolvió';

  @override
  String get labelTask => 'El encargo';

  @override
  String get labelWhatResolved => 'Qué resolvió';

  @override
  String get labelAskedAbout => 'Le consultaron';

  @override
  String get labelNumbers => 'Números';

  @override
  String get labelMemberOpened => 'El miembro que lo abrió';

  @override
  String placeholderWriteTo(String name) {
    return 'Escribe a @$name…';
  }

  @override
  String get messageNoReasoningVisible =>
      'No dejó pensamiento visible. Con modelos que no lo emiten, aquí no hay nada que mostrar.';

  @override
  String get messageNodeNotResolution =>
      'Este nodo no pertenece a un caso de resolución: habla cuando lo consultan.';

  @override
  String get messageNoReasoningYet => 'Todavía no razonó nada en este paso.';

  @override
  String get messageNodeNotMember =>
      'Este nodo ya no es miembro del proyecto, así que no hay a quién escribirle.';

  @override
  String get messageNoConsultRecord =>
      'No quedó registrado con qué frase lo llamó.';

  @override
  String get messageNoToolsOpened => 'Todavía no abrió ninguna herramienta.';

  @override
  String messageSubagentWriteLocked(String parent) {
    return 'Mientras corre, no se puede escribirle a un subagente: el CLI no abre ese canal. Lo que escribas aquí le llega a $parent, quien lo abrió.';
  }

  @override
  String get formLabelHookName => 'Nombre';

  @override
  String get formHintHookScript =>
      'Es también el nombre del script que se genera.';

  @override
  String get formLabelWhatHookDoes => 'Qué hace';

  @override
  String get formMessageNoEventFilter => 'Este evento no filtra: dejalo vacío.';

  @override
  String formHintEventFilter(String matcherHint) {
    return 'Vacío = todo. Ejemplos: $matcherHint';
  }

  @override
  String get formDescriptionHookScope =>
      'Corto a propósito: un hook de \"antes de usar una herramienta\": si lo rechazas, no se llama. Uno de \"después\" es más raro.';

  @override
  String get formLabelHookRules => 'Qué reglas hace cumplir este hook';

  @override
  String get formDescriptionHookRules =>
      'No cambia lo que corre: deja anotado cuáles de tus reglas están garantizadas y cuáles se piden.';

  @override
  String get formLabelWhenHookRuns => 'Cuándo corre';

  @override
  String get formLabelWhatHookExecutes => 'Qué ejecuta';

  @override
  String get messageNoToolsRegisteredShort =>
      'Todavía no registraste ninguna tool.';

  @override
  String get formDescriptionHookCode =>
      'El código viaja en el respaldo y puede usar los secrets que configuraste. Si el admin no permite write, un hook del disco no se restaura en otra máquina.';

  @override
  String get formLabelHookTimeout => 'Timeout (segundos)';

  @override
  String get formDescriptionHookTimeout =>
      'Recibe el evento como JSON por entrada estándar. Salir con código 2 bloquea.';

  @override
  String get pageTitleMachineTitle => 'Máquina';

  @override
  String get messageDetectionNotIntegration =>
      'Detectar no es integrar: los que dicen «sin adaptador» están en tu máquina pero Keel todavía no sabe hablarles, y no se le puede pedir que lo hagan solos.';

  @override
  String get labelConsumption => 'Consumo · últimos 14 días';

  @override
  String get messageNoConsumptionYet =>
      'Todavía no hay nada medido. El historial arranca hoy: hasta ahora los contadores de cada turno se leían para el porcentaje de contexto y se tiraban, así que no hay forma de saber qué se gastó dónde. Y el historial empieza el día que se instaló esta pantalla.';

  @override
  String get labelCacheReadShort => 'CACHÉ LEÍDA';

  @override
  String get messageNoTokenCount => 'Sin medición — su CLI no informa tokens';

  @override
  String labelCoresShort(int cores) {
    return '$cores núcleos';
  }

  @override
  String get messageNotInPath => 'No está en el PATH';

  @override
  String get formLabelWorkflowIntent => 'Intención y cuándo se aplica';

  @override
  String get formDescriptionWorkflowEngine =>
      'El motor decide los nodos mínimos; no configuras una cadena de agentes.';

  @override
  String labelMaxReplans(int count) {
    return 'Límite de reformulaciones: $count';
  }

  @override
  String labelMaxSubagents(int count) {
    return 'Subagentes de lectura/verificación: $count';
  }

  @override
  String labelMaxReviewCycles(int count) {
    return 'Ciclos compartidos de auditoría: $count';
  }

  @override
  String get formLabelWorkflowTitle => 'Título visible';

  @override
  String get formLabelWorkflowInstruction => 'Instrucción';

  @override
  String get formLabelWorkflowActivation => 'Activación';

  @override
  String get formLabelWorkflowExecution => 'Ejecución';

  @override
  String get formDescriptionParentSessionKept =>
      'La sesión del padre se conserva y se reanuda.';

  @override
  String get formLabelMaxAgenticTurns => 'Máximo de turnos agentic';

  @override
  String get formDescriptionMaxAgenticTurns =>
      'Vacío o 0 usa el límite del proveedor.';

  @override
  String get formLabelWorkflowOwner => 'Dueño';

  @override
  String get formDescriptionWorkflowOwner =>
      'El dueño debe ser distinto de quienes produjeron sus dependencias.';

  @override
  String get formLabelWorkflowResponsible => 'Responsable de resolución';

  @override
  String get formDescriptionResponsible =>
      'Un responsable integra evidencia y es el único escritor.';

  @override
  String get workflowKindMigration => 'Migración';

  @override
  String labelAge(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String get labelWeekdayShort => 'lun, mar, mié, jue, vie, sáb, dom';

  @override
  String messageRequirementTaken(String handle) {
    return 'Lo tomó @$handle';
  }

  @override
  String messageRequirementTask(String taskPath) {
    return 'Quedó como tarea: $taskPath';
  }

  @override
  String get messagePlanMode =>
      'Modo plan: que proponga cómo lo haría. Para implementarlo de verdad, «Tomar y evaluar» abre una sesión.';

  @override
  String get messageRequirementAnswering => 'Está contestando…';

  @override
  String get messagePlanRequest => 'Pide un plan — @ para llamar a un agente';

  @override
  String get messageWriteHere =>
      'Escribe aquí — @ para preguntarle a un agente';

  @override
  String get messageRequirementClosed => 'El destino pidió el cierre.';

  @override
  String get messageOnlyOriginCanClose =>
      'Solo del lado que lo abrió se puede cerrar — es quien sabe si lo que necesitaba está.';

  @override
  String get labelWithWorkflow => 'Con qué workflow lo evalúa';

  @override
  String messageNewSessionOpenedWorkflow(String workflowName) {
    return 'Va a abrir una sesión nueva en #$workflowName. Elige la fila de abajo para cada rol.';
  }

  @override
  String get formLabelWhatMissing => 'Qué falta';

  @override
  String get bundleExportNothingYet => 'Todavía no hay nada para exportar.';

  @override
  String get bundleSectionWhatItTakes => 'Qué se lleva';

  @override
  String get bundleSectionWhatItBrings => 'Qué trae';

  @override
  String get bundleSectionWhatRecipientSees =>
      'Lo que va a ver quien lo reciba';

  @override
  String get bundleSectionSecurityReview => 'Revisión de seguridad';

  @override
  String get bundleNoFindings => 'sin hallazgos';

  @override
  String bundleFindingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hallazgos',
      one: '1 hallazgo',
    );
    return '$_temp0';
  }

  @override
  String bundleMissingNote(String list) {
    return 'Esto lo nombra pero de este lado no existe, así que no viaja:\n$list';
  }

  @override
  String bundleSecretsToCreateNote(String names) {
    return 'Quien lo instale va a tener que crear estos secrets con estos nombres: $names. Los valores no viajan.';
  }

  @override
  String get actionImportPackage => 'Importar un paquete';

  @override
  String get bundleImportIntro =>
      'Un paquete trae un agente, un workflow o una skill con todo lo que necesita para funcionar: sus skills, sus reglas, sus tools, sus hooks, sus servidores MCP y su documentación.';

  @override
  String get bundleImportSafetyNote =>
      'Nada se instala sin que veas antes qué trae y qué encontró la revisión.';

  @override
  String get actionChooseFile => 'Elegir un archivo';

  @override
  String get bundleOrFromLink => 'o desde un enlace';

  @override
  String get bundleLinkHint => 'https://…/keel-agent-flutter-expert.zip';

  @override
  String get actionBring => 'Traer';

  @override
  String get bundleDocumentsLabel => 'documentos';

  @override
  String bundleSecretsRequiredNote(String names) {
    return 'Necesita estos secrets, que tienes que crear tú con estos nombres: $names. Un paquete nunca trae valores.';
  }

  @override
  String get actionInstall => 'Instalar';

  @override
  String bundleHighRiskAck(int count) {
    return 'Leí los $count hallazgos de gravedad alta y quiero instalarlo igual.';
  }

  @override
  String bundleAuditCleanNote(int count) {
    return 'Revisé $count textos y no encontré nada conocido. No es una garantía: busca lo que sabe buscar.';
  }

  @override
  String bundleRiskLevelLabel(String level) {
    return 'GRAVEDAD $level';
  }

  @override
  String get actionSaveAsPng => 'Guardar como PNG';

  @override
  String codeBlockLineCount(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count líneas',
      one: '1 línea',
    );
    return '$title · $_temp0';
  }

  @override
  String get semanticsOpenImageFullSize =>
      'Imagen adjunta, abrir en tamaño completo';

  @override
  String get tooltipOpenFullSize => 'Abrir en tamaño completo';

  @override
  String get messageImageUnavailable => 'Imagen no disponible';

  @override
  String get labelDeletedProject => 'proyecto eliminado';

  @override
  String labelOpenSince(String age) {
    return 'abierto hace $age';
  }

  @override
  String get labelBlockingRequester => 'bloquea a quien lo pide';

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
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String get messageTakenByYou => 'Lo tomaste tú';

  @override
  String get labelVerdict => 'VEREDICTO';

  @override
  String get tooltipPlanModeActive =>
      'Modo plan activo: propone en vez de afirmar';

  @override
  String messageNewRequirementSessionNote(String workflowName) {
    return 'Va a abrir una sesión nueva en #$workflowName. Elige la fila de agentes que corresponde a este pedido — evaluar un requerimiento rara vez es lo mismo que resolver un ticket.';
  }

  @override
  String get labelProjectNoLongerExists => 'un proyecto que ya no existe';

  @override
  String get assistantWindowTitle => 'Asistente';

  @override
  String get buttonAskKeelAi => 'Pedírselo a Keel AI';

  @override
  String get buttonCreateByHand => 'Crearlo a mano';

  @override
  String get buttonOverwriteAnyway => 'Sobrescribir igual';

  @override
  String get hintAskAboutThisLine => 'Pregunta sobre esta línea…';

  @override
  String get hintQueuedMessage => 'Mensaje que se enviará en el próximo turno';

  @override
  String get hintSessionName => 'Nombre de la sesión';

  @override
  String get labelCloseSession => 'Cerrar sesión';

  @override
  String get labelDeleteIntegration => 'Eliminar integración';

  @override
  String get labelFileChanged => 'El archivo cambió';

  @override
  String get labelGiveToKeelAi => 'Dárselo a Keel AI (el asistente)';

  @override
  String get labelHeadersKeyValue => 'Headers (KEY=valor, una por línea)';

  @override
  String get labelKnowledgeBaseAnswers => 'Qué contesta esta base';

  @override
  String labelModelWithProvider(String provider) {
    return 'Modelo ($provider)';
  }

  @override
  String labelMaxReplansLimit(int count) {
    return 'Límite de reformulaciones: $count';
  }

  @override
  String labelMaxReviewCyclesLimit(int count) {
    return 'Ciclos compartidos de auditoría: $count';
  }

  @override
  String labelMaxSubagentsLimit(int count) {
    return 'Subagentes de lectura/verificación: $count';
  }

  @override
  String labelIdleTimeoutLimit(int count) {
    return 'Minutos sin actividad del proveedor antes de cortar un paso: $count (0 = sin límite)';
  }

  @override
  String labelNodeTimeoutLimit(int count) {
    return 'Minutos máximos por paso: $count (0 = sin límite)';
  }

  @override
  String labelSessionCostLimit(int amount) {
    return 'Techo de costo de la sesión en USD (0 = sin techo): $amount';
  }

  @override
  String get labelNoBoardsYet => 'Todavía no hay tableros';

  @override
  String get labelNoSessionOpen => 'Ninguna sesión abierta';

  @override
  String get labelPasteBlockAsInDocs =>
      'Pega el bloque tal como está en la documentación';

  @override
  String get labelPasteMcpConfig => 'Pegar una configuración MCP';

  @override
  String get labelProjectPurpose => 'Propósito';

  @override
  String get labelRequirementContext =>
      'Contexto: qué hicieron y por qué lo necesitan';

  @override
  String get labelRequirementNeed => 'Qué necesita';

  @override
  String get labelRequirementTitle => 'Título';

  @override
  String get labelSessionAgents => 'Agentes de esta sesión';

  @override
  String get labelSpecification => 'Especificación';

  @override
  String get labelTermsOfUse => 'Términos de uso';

  @override
  String get labelWhichWorkflowRuns => 'Con qué workflow corre';

  @override
  String messageCloseSessionBody(String title) {
    return 'Se borra el hilo de \"$title\" y el contexto que los agentes acumularon en ella. El proyecto queda igual, con sus agentes, reglas y documentos.';
  }

  @override
  String messageDeleteIntegrationBody(String name) {
    return 'Se elimina \"$name\". Los agentes que la tenían asignada dejan de recibir sus tools.';
  }

  @override
  String get messageFileChangedBody =>
      'Este archivo se modificó (por ejemplo el agente lo editó) desde que abriste esta ventana. Si guardas ahora, vas a sobrescribir ese cambio con lo que tienes aquí.';

  @override
  String get messageNoAgentsToAdd => 'No quedan agentes registrados por sumar';

  @override
  String get messageNoBoardsExplainer =>
      'Un tablero es una pantallita para disparar algo contra tu propia app: lanzar una oferta, mandarte un push, pegarle a un endpoint que estás escribiendo.\n\nLo más rápido es pedírselo a un agente del proyecto: lee tu código y lo arma solo. Aparece en la sección Tableros de ese proyecto.';

  @override
  String get messageNoExtraAgentsYet => 'Ninguno todavía.';

  @override
  String get messageNoKnowledgeBasesYet =>
      'Todavía no hay ninguna base de saber.';

  @override
  String get messageNoMcpServersRegistered =>
      'Todavía no registraste ningún MCP externo.';

  @override
  String get messageSessionGone => 'La sesión ya no existe.';

  @override
  String get messageWhichWorkflowRunsNote =>
      'Esta sesión y ninguna otra. Un proyecto hace trabajos de clases distintas —armar la carpeta de tareas, resolver un ticket, evaluar un requerimiento— y cada uno quiere otra fila de agentes.';

  @override
  String get sectionAddToSession => 'Agregar a esta sesión';

  @override
  String get sectionProjectMembers =>
      'Miembros del proyecto (en todas las sesiones)';

  @override
  String get sectionSessionOnly => 'Solo en ESTA sesión';

  @override
  String get tooltipAgentAnsweringThread =>
      'Un agente está contestando en el hilo';

  @override
  String get tooltipGoToLatestMessage => 'Ir al mensaje más reciente';

  @override
  String get tooltipGuardrailsAutorun => 'Guardarraíles que corren solos';

  @override
  String get tooltipLegendMeaning => 'Qué significa cada línea';

  @override
  String get tooltipNewConversation => 'Nueva conversación';

  @override
  String get tooltipRefreshCatalog => 'Refrescar catálogo';

  @override
  String get tooltipRemoveFromSession => 'Quitar de esta sesión';

  @override
  String get tooltipRunsCommandsOnYourMachine => 'Corre comandos en tu máquina';

  @override
  String get tooltipWorkingNow => 'Trabajando ahora';

  @override
  String get workflowTitleTaskFormat => 'Construir formato de tareas';

  @override
  String get workflowTitleVerifyFormat => 'Verificar formato';

  @override
  String get workflowTitlePlanAndScope => 'Planificar y delimitar';

  @override
  String get workflowTitleSingleEntryPoint =>
      'Diseño del punto único de entrada';

  @override
  String get workflowTitleImplement => 'Implementar con evidencia';

  @override
  String get workflowTitleCodeAudit => 'Auditar código';

  @override
  String get workflowTitleCodeCorrection => 'Corregir hallazgos de código';

  @override
  String get workflowTitleTests => 'Crear y ajustar pruebas';

  @override
  String get workflowTitleTestAudit => 'Auditar tests';

  @override
  String get workflowTitleTestCorrection => 'Corregir hallazgos de tests';

  @override
  String get workflowTitleDeviceE2e => 'Verificación end-to-end en dispositivo';

  @override
  String get workflowTitleVerification => 'Verificación de cierre';

  @override
  String get workflowTitlePublishApproval => 'Aprobar publicación';

  @override
  String get termsVersion => 'Versión 1 — agosto de 2026';

  @override
  String get termsSection1Title => '1. Qué es Keel';

  @override
  String get termsSection1Body =>
      'Keel es una herramienta de escritorio que trabaja sobre los CLI de agentes que ya tienes instalados en tu máquina. No es un servicio: no hay un servidor de Keel al que te conectes, no hay cuenta que crear y no hay registro. Si apagas internet, Keel sigue abriéndose.\n\nUsar Keel significa aceptar estos términos. Si no estás de acuerdo con alguno, no lo uses.';

  @override
  String get termsSection2Title => '2. De quién es';

  @override
  String get termsSection2Body =>
      'Keel —su código, su diseño, su nombre, su documentación y todo lo que lo acompaña— es propiedad intelectual de Jhonatan Ortiz (JhonaCode), ingeniero de software. Todos los derechos reservados.\n\nNo es software libre ni de código abierto. No se distribuye bajo MIT, Apache, BSD, GPL ni ninguna otra licencia permisiva. Tener una copia no te da derecho a usarla: hace falta permiso escrito del autor. El texto completo está en el archivo LICENSE.';

  @override
  String get termsSection3Title => '3. Solo se descarga de jhonacode.com';

  @override
  String get termsSection3Body =>
      'El autor se reserva de forma exclusiva el derecho a distribuir Keel. El ÚNICO canal autorizado es jhonacode.com.\n\nQueda prohibido republicar, espejar, subir a otro sitio, incluir en un repositorio de paquetes, en una tienda de aplicaciones, en una imagen de contenedor o en cualquier otro canal de distribución, sea gratis o cobrando. Tampoco se puede revender, alquilar, sublicenciar ni ofrecer Keel como servicio a terceros.';

  @override
  String get termsSection4Title => '4. Copias que no vinieron de ahí';

  @override
  String get termsSection4Body =>
      'Cualquier copia de Keel obtenida fuera de jhonacode.com no está autorizada, y el autor no tiene forma de saber qué le hicieron: pudo ser modificada, empaquetada con otra cosa o alterada para hacer algo que Keel no hace.\n\nEl autor no responde por esas copias ni por lo que provoquen, y nada de lo que hagan puede atribuírsele. Una compilación modificada por un tercero no es Keel, aunque se llame así. Si te importa lo que corre en tu máquina, bájala del sitio oficial.';

  @override
  String get termsSection5Title => '5. Keel no te pide datos';

  @override
  String get termsSection5Body =>
      'No te pide nombre, correo, contraseñas ni claves de nada. No hay inicio de sesión. Todo lo que armas —proyectos, agentes, skills, tools, bases de saber, hilos de chat y ajustes— se guarda en tu propia máquina.\n\nLos valores de tus secrets nunca salen en un respaldo: el respaldo lleva solo los nombres, para que del otro lado sepas cuáles completar. La API de trabajos programados escucha únicamente en loopback, o sea que no es alcanzable desde fuera de tu equipo.';

  @override
  String get termsSection6Title => '6. Lo único que sí sale de tu máquina';

  @override
  String get termsSection6Body =>
      'Si esta compilación trae configurado un canal de reportes, cuando algo se rompe se envía a ese canal: el mensaje del error, su traza, el archivo de Keel donde ocurrió, el nombre de tu equipo y si la compilación es de desarrollo o de producción.\n\nNo se envía nada más. Ni el contenido de tus chats, ni tus archivos, ni tus secrets, ni qué proyectos tienes. Sirve para una sola cosa: que quien mantiene Keel se entere de que algo falló.';

  @override
  String get termsSection7Title =>
      '7. Keel es una herramienta, y tú la manejas';

  @override
  String get termsSection7Body =>
      'Keel lanza agentes con los permisos que tú les das, y esos permisos pueden incluir acceso completo a tu disco. Un agente puede crear, modificar y borrar archivos, ejecutar comandos y hacer commits en tus repositorios.\n\nTú decides qué permisos otorgas, sobre qué carpetas y qué le pides a cada agente. Keel ejecuta esas decisiones; no las toma por ti y no las supervisa. El autor no se hace responsable del uso que le des a la herramienta ni de las consecuencias de lo que los agentes hagan siguiendo tus instrucciones.';

  @override
  String get termsSection8Title =>
      '8. Tus archivos son tuyos, y tus respaldos también';

  @override
  String get termsSection8Body =>
      'Una herramienta que le da acceso a tu disco a un agente puede terminar en archivos perdidos, sobrescritos o cambiados de una forma que no querías. Puede pasar por un error de Keel, por un error del agente o por una instrucción tuya que salió distinta a como la pensaste.\n\nMantener respaldos de lo que te importa es responsabilidad tuya. El autor no responde por pérdida ni por corrupción de datos.';

  @override
  String get termsSection9Title => '9. No es para usos críticos';

  @override
  String get termsSection9Body =>
      'Keel no está diseñado ni probado para entornos donde una falla ponga en riesgo la vida, la salud, la seguridad o infraestructura esencial: medicina, aviación, transporte, energía, control industrial o similares. No lo uses ahí.';

  @override
  String get termsSection10Title => '10. Lo que no depende de Keel';

  @override
  String get termsSection10Body =>
      'Los CLI de agentes y los servidores MCP que uses son de terceros. Cada uno tiene sus propios términos, sus precios y su propia forma de tratar lo que le mandas. Keel no responde por ellos, ni por lo que cobren, ni por lo que hagan con la información que reciben, ni por lo que decidan cambiar o discontinuar.\n\nCumplir los términos de esos servicios es cosa tuya.';

  @override
  String get termsSection11Title => '11. Lo que te comprometes a no hacer';

  @override
  String get termsSection11Body =>
      'No copiar, modificar, traducir ni crear obras derivadas de Keel.\nNo aplicar ingeniería inversa, descompilar ni desensamblar, salvo donde la ley lo permita de forma imperativa.\nNo eludir ni desactivar ninguna medida técnica de protección.\nNo quitar ni tapar los avisos de autoría, copyright o licencia.\nNo usar el nombre, el logo ni la imagen de Keel o de JhonaCode sin permiso escrito.\nNo usar Keel ni ninguna parte de él para entrenar modelos de aprendizaje automático o sistemas de inteligencia artificial.\nNo usar Keel para nada ilegal, ni para vulnerar derechos de terceros.';

  @override
  String get termsSection12Title =>
      '12. Si tu uso le trae un problema al autor';

  @override
  String get termsSection12Body =>
      'Si un tercero reclama algo por la forma en que usaste Keel, o por lo que hiciste con lo que produjo, ese reclamo es tuyo. Te comprometes a mantener al autor libre de todo daño, gasto o responsabilidad que salga de tu uso de la herramienta o del incumplimiento de estos términos.';

  @override
  String get termsSection13Title => '13. Sin garantía';

  @override
  String get termsSection13Body =>
      'Keel se entrega TAL CUAL ESTÁ y SEGÚN DISPONIBILIDAD, sin garantía de ningún tipo, expresa o implícita. No se garantiza que funcione sin errores ni interrupciones, que esté disponible, que sea compatible con tu equipo o con tus herramientas, ni que sirva para un propósito determinado.';

  @override
  String get termsSection14Title => '14. Hasta dónde llega la responsabilidad';

  @override
  String get termsSection14Body =>
      'En la medida en que la ley lo permita, el autor no responde por daños indirectos, incidentales, especiales ni consecuentes, ni por lucro cesante, pérdida de datos, pérdida de tiempo de trabajo o interrupción de actividad, aunque se le hubiera advertido de esa posibilidad.\n\nSi aun así se determinara alguna responsabilidad, su límite total será lo que hayas pagado por Keel en los doce meses previos al hecho, que en la práctica es cero: Keel no se cobra y las donaciones no son un pago por el software.';

  @override
  String get termsSection15Title => '15. Donaciones';

  @override
  String get termsSection15Body =>
      'Si Keel te sirve y quieres apoyar el trabajo, se agradece. Es completamente voluntario.\n\nUna donación es eso y nada más: no es una compra, no es una licencia, no da derecho a usar el software sin permiso, no incluye soporte, no da prioridad en nada, no crea ninguna obligación del autor hacia quien dona y no se devuelve.';

  @override
  String get termsSection16Title => '16. Cuándo se termina el permiso';

  @override
  String get termsSection16Body =>
      'Cualquier uso fuera de lo autorizado extingue de inmediato y sin aviso todo permiso concedido. También puede revocarse un permiso otorgado antes. Al terminar, tienes que dejar de usar Keel y borrar las copias que tengas.\n\nLas secciones sobre propiedad, responsabilidad, garantía e indemnidad siguen vigentes después de eso.';

  @override
  String get termsSection17Title => '17. Si alguna cláusula no vale';

  @override
  String get termsSection17Body =>
      'Si un tribunal declara inválida o inaplicable alguna parte de estos términos, el resto sigue en pie, y esa parte se interpreta de la forma más cercana posible a su intención original.\n\nQue el autor no ejerza un derecho en algún momento no significa que renuncie a él. Entre Keel y tú no hay sociedad, empleo, franquicia ni representación de ningún tipo.';

  @override
  String get termsSection18Title => '18. Ley aplicable';

  @override
  String get termsSection18Body =>
      'Estos términos se rigen por las leyes del país de residencia del autor, y cualquier controversia se somete a los tribunales competentes de ese lugar.';

  @override
  String get termsSection19Title => '19. Estos términos pueden cambiar';

  @override
  String get termsSection19Body =>
      'Si cambian, la versión que vale es la que muestra esta pantalla. Seguir usando Keel después de un cambio significa que lo aceptas.';

  @override
  String get termsSection20Title => '20. Contacto';

  @override
  String get termsSection20Body =>
      'Para pedir permiso de uso, donar, reportar algo o cualquier otra consulta: jhonacode.com';

  @override
  String get messageWriteToAgent => 'Escríbele algo a tu agente';

  @override
  String skillAlreadyExists(String name) {
    return 'La skill \"$name\" ya existía, la reusé.';
  }

  @override
  String ruleAlreadyExists(String name) {
    return 'La regla \"$name\" ya existía, la reusé.';
  }

  @override
  String toolAlreadyExists(String name) {
    return 'La tool \"$name\" ya existía, la reusé.';
  }

  @override
  String skillCreated(String name) {
    return 'Creé la skill \"$name\".';
  }

  @override
  String ruleCreated(String name) {
    return 'Creé la regla \"$name\".';
  }

  @override
  String handleReserved(String handle) {
    return 'El handle \"$handle\" está reservado.';
  }

  @override
  String get keelAiModifyBlocked =>
      'Keel AI pidió modificar un elemento bloqueado.';

  @override
  String formEditEntity(Object entity) {
    return 'Editar $entity';
  }

  @override
  String formRegisterEntity(Object entity) {
    return 'Registrar $entity';
  }

  @override
  String get formName => 'Nombre';

  @override
  String get formEnvironmentVariableName => 'Nombre de la variable de entorno';

  @override
  String get formWorkingDirectory => 'Carpeta de trabajo';

  @override
  String get formChoose => 'Elegir…';

  @override
  String get formSave => 'Guardar';

  @override
  String get formCreate => 'Crear';

  @override
  String get formGlobalSkill => 'Skill global';

  @override
  String get formGlobalSkillDescription =>
      'La reciben todos los agentes en cada turno, sin necesidad de asignarla.';

  @override
  String get formSkillContent => 'Contenido (instrucciones para inyectar)';

  @override
  String get formToolDescription =>
      'Descripción para el agente: qué hace, cuándo usarla y qué significa cada argumento posicional';

  @override
  String get formStoredValue => 'Valor cargado  ••••••••';

  @override
  String get formNewValueKeepCurrent =>
      'Valor nuevo (vacío = conservar el actual)';

  @override
  String get formValue => 'Valor';

  @override
  String get formValueDescription =>
      'Nunca pasa por un modelo. Se inyecta como credencial solo al proveedor, tool o MCP que la declare.';

  @override
  String get formBoardDescription =>
      'La opción más rápida es pedírselo a un agente del proyecto: lee tu código o OpenAPI y lo construye. Usa esto para ajustarlo o escribirlo manualmente.';

  @override
  String get formWorkflowName => 'Nombre';

  @override
  String get formWorkflowCaseType => 'Tipo de caso';

  @override
  String get formRequiredRules => 'Reglas requeridas';

  @override
  String get formRequiredKnowledgeBases => 'Bases de conocimiento requeridas';

  @override
  String get formCommaSeparatedNames => 'Nombres separados por comas.';

  @override
  String get validationNameRequired => 'El nombre es obligatorio.';

  @override
  String validationMaxCharacters(Object count) {
    return 'Máximo $count caracteres.';
  }

  @override
  String get validationNoSpaces => 'No se permiten espacios.';

  @override
  String get validationLowercaseOnly => 'Usa solo minúsculas.';

  @override
  String get validationBoardKey =>
      'Usa minúsculas, números y \"_\", empezando por una letra (máx. 32).';

  @override
  String get assistantWelcomeTitle => 'Soy Keel AI';

  @override
  String get assistantWelcomeDescription =>
      'Puedo registrar cualquiera de estas opciones por ti en la conversación. Toca un ejemplo para probarlo.';

  @override
  String get assistantExampleProject =>
      'Crea un proyecto para revisar PR con dos agentes.';

  @override
  String get assistantExampleAgent =>
      'Registra un agente revisor de seguridad y asígnale la skill que acabas de crear.';

  @override
  String get assistantExampleWorkflow =>
      'Crea un workflow para bugs con implementación y una etapa de revisión.';

  @override
  String get assistantExampleSkill =>
      'Crea una skill con las reglas de estilo de este proyecto.';

  @override
  String get assistantExampleRule =>
      'Agrega una regla que prohíba comentarios obvios en el código.';

  @override
  String get labelEnabled => 'Activo';

  @override
  String get labelDisabled => 'Apagado';

  @override
  String get navAssistantTooltip => 'Asistente Keel AI';

  @override
  String get navRegisteredAgents => 'Agentes registrados';

  @override
  String get navTestBoards => 'Tableros de prueba';

  @override
  String get navMcpIntegrations => 'Integraciones MCP';

  @override
  String get navKnowledge => 'Conocimiento';

  @override
  String get navMachine => 'Máquina';

  @override
  String get navBackup => 'Respaldo';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get mapLaneBack => 'regresa';

  @override
  String get mapLaneForward => 'avanza';

  @override
  String get mapLaneDelegate => 'delega';

  @override
  String get mapViewQuery => 'Ver la consulta completa';

  @override
  String get mapZoomOut => 'Alejar  ⌘−';

  @override
  String get mapZoomIn => 'Acercar  ⌘+';

  @override
  String get mapFit => 'Mostrar todo en pantalla  ⌘0';

  @override
  String get mapFollow => 'Seguir el nodo que tiene el turno';

  @override
  String get mapHelp => 'arrastrar = mover · ⌘ + rueda = zoom';

  @override
  String get mapEmptyTitle =>
      'Este proyecto todavía no tiene nodos para mapear';

  @override
  String get mapEmptyDescription =>
      'Agrega miembros y un workflow. El mapa se abre con el elenco en su lugar, en reposo, antes de que corra algo.';

  @override
  String get chatCreateSession => 'Crea una sesión para empezar';

  @override
  String get chatAskForPlan => 'Pide un plan…';

  @override
  String chatSessionPrompt(Object project) {
    return 'Qué necesitas en esta sesión de #$project';
  }

  @override
  String chatMessagePrompt(Object project) {
    return 'Mensaje para #$project';
  }

  @override
  String get chatStop => 'Detener';

  @override
  String get chatQueue => 'Guardar en espera';

  @override
  String get chatSend => 'Enviar';

  @override
  String get chatSessionsCreatedByButton =>
      'Las sesiones se crean con el botón \"Nueva sesión\".';

  @override
  String get chatRunsPreflight =>
      'El preflight del workflow se ejecuta en esta sesión.';

  @override
  String get chatQueueHelp =>
      'Puedes guardar mensajes en espera, programarlos para el final del turno o interrumpir y enviarlos ahora.';

  @override
  String get chatWorkflowHelp =>
      'El workflow coordina el grafo. Escribe cuando quieras corregir el rumbo; queda registrado en el nodo activo.';

  @override
  String get chatReferencesHelp =>
      'Referencias: / directorios · @ agentes · \$ skills y reglas · # conocimiento';

  @override
  String get labelNoOpenSession => 'Sin sesión abierta';

  @override
  String labelSessionTitle(Object title) {
    return 'Sesión: $title';
  }

  @override
  String labelContextUsage(Object percent) {
    return 'contexto $percent%';
  }

  @override
  String assistantLegacyBlocked(Object names) {
    return 'No ejecuté el bloque automático: intentaba cambiar elementos bloqueados ($names). Usa las tools MCP con change_intent y change_reason para pedir permiso.';
  }

  @override
  String assistantSkillExists(Object name) {
    return 'La skill \"$name\" ya existía; la reutilicé.';
  }

  @override
  String assistantSkillCreated(Object name, Object suffix) {
    return 'Creé la skill \"$name\"$suffix.';
  }

  @override
  String assistantRuleExists(Object name) {
    return 'La regla \"$name\" ya existía; la reutilicé.';
  }

  @override
  String assistantRuleCreated(Object name) {
    return 'Creé la regla \"$name\".';
  }

  @override
  String assistantToolExists(Object name) {
    return 'La tool \"$name\" ya existía; la reutilicé.';
  }

  @override
  String assistantToolCreated(Object name, Object runtime) {
    return 'Creé la tool \"$name\" ($runtime).';
  }

  @override
  String assistantAgentCreated(Object details, Object handle) {
    return 'Registré a @$handle.$details';
  }

  @override
  String assistantAgentUpdated(Object details, Object handle) {
    return 'Actualicé a @$handle.$details';
  }

  @override
  String assistantWorkflowCreated(Object kind, Object name) {
    return 'Creé el workflow \"$name\" ($kind).';
  }

  @override
  String assistantProjectCreated(Object name) {
    return 'Creé el proyecto \"$name\".';
  }

  @override
  String updateAvailable(Object version) {
    return 'Nueva versión $version disponible. Haz clic para descargarla.';
  }

  @override
  String get readingInstalledVersion => 'Leyendo la versión instalada';

  @override
  String reviewVersion(Object version) {
    return 'Keel $version. Haz clic para revisar.';
  }

  @override
  String get faultsLabel => 'Fallas';

  @override
  String get faultsNone => 'No hay fallas sin revisar';

  @override
  String get faultsOne => '1 falla sin revisar';

  @override
  String faultsMany(Object count) {
    return '$count fallas sin revisar';
  }

  @override
  String get machineUpdateAvailable => 'Hay una versión nueva de Keel';

  @override
  String get machineStatus => 'Servicios, consumo y estado de la máquina';

  @override
  String get machineOneWork => 'Hay 1 trabajo en curso';

  @override
  String machineManyWork(Object count) {
    return 'Hay $count trabajos en curso';
  }

  @override
  String get backupBusy => 'Respaldando';

  @override
  String get backupLabel => 'Respaldo';

  @override
  String get backupSaving => 'Escribiendo el respaldo sin interrumpirte';

  @override
  String get backupReady => 'Respaldo al día y subido al remoto';

  @override
  String get mapLegend => 'Leyenda';

  @override
  String get fileTypeImages => 'Imágenes';

  @override
  String get chatFilterSystem => 'sistema';

  @override
  String get chatFilterSubagents => 'subagentes';

  @override
  String get chatFilterAll => 'todo';

  @override
  String chatStepLabel(Object title) {
    return 'paso: $title';
  }

  @override
  String get chatNoticeWarningTitle => 'Advertencia';

  @override
  String get chatNoticeFailureTitle => 'Falla';

  @override
  String get chatNoticeInfoTitle => 'Nota';

  @override
  String chatRetryStep(Object title) {
    return 'Reintentar «$title»';
  }

  @override
  String get buttonDeleteAgent => 'Eliminar agente';

  @override
  String deleteAgentConfirmation(Object name) {
    return 'Se eliminarán \"$name\" y su historial de chat.';
  }

  @override
  String get emptyProjectsHint =>
      'Todavía no hay proyectos. Crea uno para que varios agentes trabajen en el mismo repositorio.';

  @override
  String get emptyAgentsHint =>
      'No hay agentes abiertos. Usa un agente registrado para hablarle directamente, sin proyecto.';

  @override
  String get filesystemAccessTitle =>
      'Dar acceso a todo el sistema de archivos';

  @override
  String filesystemAccessBody(Object name) {
    return '\"$name\" podrá leer y escribir en cualquier carpeta del computador, no solo en tu carpeta de usuario.';
  }

  @override
  String get filesystemAccessGrant => 'Dar acceso';

  @override
  String get filesystemAccessEnabledTooltip =>
      'Tiene acceso a todo el sistema de archivos (haz clic para quitarlo)';

  @override
  String get filesystemAccessGrantTooltip =>
      'Dar acceso a todo el sistema de archivos';

  @override
  String get noOpenRequirements =>
      'No hay requisitos abiertos en ninguna dirección.';

  @override
  String get labelSubagents => 'subagentes';

  @override
  String get useAgentTitle => 'Usar un agente';

  @override
  String get filesystemAccessSubtitle =>
      'Esto se decide aquí, no al registrar el agente: el mismo agente puede tener permisos diferentes según dónde lo uses.';

  @override
  String get chatHintStreaming => 'Se enviará cuando termine el turno…';

  @override
  String get chatHintPlan => 'Pide un plan…';

  @override
  String get chatHintMessage => 'Escribe un mensaje…';

  @override
  String get noAgentsTitle => 'Todavía no hay agentes registrados';

  @override
  String get noAgentsDescription =>
      'Registra uno para tenerlo disponible en todas partes: para hablarle directamente, agregarlo a un proyecto y usarlo en pasos de workflow por rol.';

  @override
  String get sidebarSectionProjects => 'Proyectos';

  @override
  String get sidebarSectionSessions => 'Sesiones';

  @override
  String get sidebarSectionStatus => 'Estado';

  @override
  String get sidebarSectionLooseAgents => 'AGENTES SUELTOS';

  @override
  String get sidebarTooltipManageAgents => 'Registrar o editar agentes';

  @override
  String get sidebarTooltipUseAgent => 'Usar un agente registrado';

  @override
  String get sidebarTooltipManageProjects => 'Administrar proyectos';

  @override
  String get sidebarTooltipNewProject => 'Nuevo proyecto';

  @override
  String get sidebarHintProjectName => 'Nombre del proyecto';

  @override
  String get sidebarTooltipReadOnlyProject => 'No lo mantengo: solo lectura';

  @override
  String get sidebarTooltipOneSessionWorking => 'Una sesión trabajando';

  @override
  String sidebarTooltipSessionsWorking(int count) {
    return '$count sesiones trabajando';
  }

  @override
  String get sidebarSectionBoards => 'Tableros';

  @override
  String get sidebarNewBoard => 'Nuevo tablero';

  @override
  String get sidebarTooltipDeleteBoard => 'Eliminar tablero';

  @override
  String get sidebarSectionRequirements => 'REQUERIMIENTOS';

  @override
  String get sidebarTooltipAllRequirements => 'Todos los requerimientos';

  @override
  String get sidebarTooltipOpenRequirement => 'Abrir un requerimiento';

  @override
  String get sidebarRequirementsEmpty =>
      'Ninguno. Aparecen acá cuando un proyecto necesita algo de otro.';

  @override
  String get panelTitleInProgress => 'WORKFLOW EN CURSO';

  @override
  String get panelNoWorkflowSelected =>
      'Este proyecto no tiene un workflow seleccionado.';

  @override
  String panelProgressOf(int done, int active) {
    return '$done de $active';
  }

  @override
  String panelReviewCycles(int done, int max) {
    return 'auditorías $done/$max';
  }

  @override
  String get panelSectionSkills => 'Skills';

  @override
  String get panelSectionRules => 'Reglas';

  @override
  String get panelSectionKnowledge => 'Conocimiento y documentación';

  @override
  String get panelAddRule => 'Agregar regla';

  @override
  String get panelAddKnowledge => 'Agregar conocimiento';

  @override
  String get panelAddToProject => 'Agregar a este proyecto';

  @override
  String get panelRemoveFromProject => 'Quitar de este proyecto';

  @override
  String get panelRequiredByWorkflow => 'Requerido por el workflow';

  @override
  String get panelMissingBlocksPreflight => 'Faltante: bloquea el preflight';

  @override
  String get panelActivateOptional => 'Activar esta capacidad opcional';

  @override
  String get panelChangeDefaultRole => 'Modificar rol default del workflow';

  @override
  String get panelApproveAndContinue => 'Aprobar y continuar';

  @override
  String panelNoAgentForRole(Object role) {
    return 'sin agente para $role';
  }

  @override
  String panelConsultedTo(Object names) {
    return 'consultó a $names';
  }

  @override
  String panelCoverageMatrix(int resolved, int total) {
    return 'matriz $resolved/$total';
  }

  @override
  String get panelChangeSharedDefault => 'Modificar default compartido';

  @override
  String panelUseDefaultRole(Object role) {
    return 'Usar default ($role)';
  }

  @override
  String get panelStateDone => 'listo';

  @override
  String get panelStateCurrent => 'ahora';

  @override
  String get panelStatePending => 'pendiente';

  @override
  String get panelStateBlocked => 'bloqueado';

  @override
  String get panelStateAvailable => 'disponible';

  @override
  String get panelStateNotRequired => 'no requerido';

  @override
  String get panelExecutorNewSession => 'sesión nueva';

  @override
  String get panelExecutorResumeParent => 'reanuda sesión padre';

  @override
  String get panelExecutorSubagent => 'subagente / fallback externo';

  @override
  String get panelExecutorManualApproval => 'requiere aprobación manual';

  @override
  String get nodeKindTriage => 'Triage y contrato';

  @override
  String get nodeKindImpact => 'Impacto end-to-end';

  @override
  String get nodeKindImplementation => 'Implementación';

  @override
  String get nodeKindVerification => 'Verificación';

  @override
  String get mapNodeYou => 'vos';

  @override
  String get mapNodeEnd => 'fin';

  @override
  String get mapChipConsultation => 'consulta';

  @override
  String get mapChipSubagent => 'subagente';

  @override
  String get mapCountEnter => 'entrar';

  @override
  String get mapCalloutAsked => 'le pidió';

  @override
  String get mapCalloutReturned => 'devolvió';

  @override
  String get mapCalloutCut => 'cortó';

  @override
  String get mapCalloutAnswered => 'contestó';

  @override
  String get mapCalloutResolved => 'resolvió';

  @override
  String get mapCalloutThinking => 'pensando';

  @override
  String get mapLegendOpensSubagent => 'abre un subagente';

  @override
  String get mapLegendSubagentReturned => 'el subagente devolvió';

  @override
  String get subagentPhaseWorking => 'trabajando';

  @override
  String get turnPhaseWorking => 'trabajando…';

  @override
  String get mapLegendForward => 'avanza un paso';

  @override
  String get mapLegendBack => 'consulta a otro nodo';

  @override
  String get mapLegendAnswer => 'contesta esa consulta';

  @override
  String get mapLegendSpawn => 'lo registró';

  @override
  String get mapLegendFinish => 'entrega final';

  @override
  String get mapLegendFailed => 'cortó';

  @override
  String get mapLegendUntraveled => 'sin recorrer';

  @override
  String get subagentPhaseThinking => 'pensando';

  @override
  String get subagentPhaseWriting => 'escribiendo';

  @override
  String get subagentPhaseDone => 'terminó';

  @override
  String get subagentPhaseFailed => 'falló';

  @override
  String get turnPhaseThinking => 'pensando…';

  @override
  String get turnPhaseWriting => 'escribiendo…';

  @override
  String threadAdaptiveResolution(Object workflow) {
    return '$workflow · resolución adaptativa';
  }

  @override
  String get threadBackToOwner => 'vuelve al responsable';

  @override
  String threadNextNode(Object node) {
    return 'sigue $node';
  }

  @override
  String threadConsultOf(Object name) {
    return 'consulta de $name';
  }

  @override
  String panelAgentForNode(Object title) {
    return 'Agente para \"$title\"';
  }

  @override
  String panelOverrideScope(Object project) {
    return 'Este override solo afecta #$project. El nodo guardará el agente concreto cuando pase el preflight.';
  }

  @override
  String panelSharedChangeScope(Object workflow) {
    return 'Este cambio modifica el workflow \"$workflow\" en todos los proyectos. Los overrides concretos se conservan.';
  }

  @override
  String get subagentPhaseUnconfirmed => 'resultado sin confirmar';

  @override
  String get sessionAwaitingOutput => 'Esperando salida del proveedor…';

  @override
  String get sessionTurnOpen => 'Turno abierto';
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

  @override
  String get pageTitleSettings => 'Configuración';

  @override
  String get pageTitleSkillsRegistered => 'Skills registrados';

  @override
  String get pageTitleSecrets => 'Secretos';

  @override
  String get pageTitleHooksRegistered => 'Hooks registrados';

  @override
  String get pageTitleRulesRegistered => 'Reglas registradas';

  @override
  String get pageTitleTestBoard => 'Banco de pruebas';

  @override
  String get pageTitleTools => 'Herramientas registradas';

  @override
  String get pageTitleIntegrations => 'Integraciones';

  @override
  String get pageTitleMachine => 'Máquina';

  @override
  String get pageTitleAgentsRegistered => 'Agentes registrados';

  @override
  String get pageTitleKnowledge => 'Saber';

  @override
  String get pageTitleInternalRequirements => 'Requerimientos internos';

  @override
  String get pageTitleProjects => 'Proyectos';

  @override
  String get pageTitleSessionAgents => 'Agentes de esta sesión';

  @override
  String get pageTitleImportHooks => 'Importar hooks de Claude Code';

  @override
  String get pageTitleTermsOfUse => 'Términos de uso';

  @override
  String get pageTitleLockedElements => 'Elementos bloqueados';

  @override
  String get pageTitleOpenRequirement => 'Abrir un requerimiento';

  @override
  String get pageTitleModifySharedDefault => 'Modificar default compartido';

  @override
  String get pageTitlePasteMCPConfig => 'Pegar una configuración MCP';

  @override
  String get pageTitleImportBackup => 'Importar respaldo';

  @override
  String get pageTitleExportPackage => 'Exportar un paquete';

  @override
  String get pageTitleBackup => 'Respaldo';

  @override
  String get pageTitleImportPackage => 'Importar un paquete';

  @override
  String get pageTitleFaults => 'Fallas';

  @override
  String get pageTitleEditQueuedMessage => 'Editar mensaje en espera';

  @override
  String get pageTitleRegisteredWorkflows => 'Workflows registrados';

  @override
  String get pageTitleUseAgent => 'Usar un agente';

  @override
  String pageTitleEngineOf(String member) {
    return 'Motor de @$member';
  }

  @override
  String get pageTitleRejectClosure => 'Rechazar el cierre';

  @override
  String get settingTextSize => 'Tamaño del texto';

  @override
  String get settingWritePermissions => 'Permisos de escritura';

  @override
  String get settingScheduledJobsApi => 'API de trabajos programados';

  @override
  String get settingApplyToAllAgents => 'Aplicar a todos los agentes';

  @override
  String get settingCanAdministrateSystem => 'Puede administrar el sistema';

  @override
  String get settingBlocksRequester => 'Frena a quien lo pide';

  @override
  String get settingAccessEntireFilesystem =>
      'Acceso a todo el sistema de archivos';

  @override
  String get descriptionWritePermissions =>
      'Leer archivos, buscarlos y consultar la web siempre está permitido. Aquí decides qué pueden modificar los agentes. Aplica a todos.';

  @override
  String get descriptionScheduledJobsApi =>
      'Para schedulers externos (cron, keel): POST /projects/<nombre>/tasks con el token Bearer. Solo loopback.';

  @override
  String get descriptionLockedElements =>
      'Lo que un agente no puede cambiar ni borrar sin pedirte permiso primero. El candado se pone desde cada ítem; aquí se ven todos juntos.';

  @override
  String get labelLockedElements => 'Elementos bloqueados';

  @override
  String get labelAboutKeel => 'Acerca de Keel';

  @override
  String get labelGlobal => 'global';

  @override
  String get labelWhatExecutes => 'Qué ejecuta';

  @override
  String get labelChat => 'Chat';

  @override
  String get labelMap => 'Mapa';

  @override
  String get labelEngine => 'MOTOR';

  @override
  String get labelTurns => 'TURNOS';

  @override
  String get labelInput => 'ENTRADA';

  @override
  String get labelOutput => 'SALIDA';

  @override
  String get labelCacheRead => 'CACHÉ LEÍDA';

  @override
  String get labelSecretsEnv => 'Secretos (env)';

  @override
  String get labelSource => 'Fuente';

  @override
  String get labelAssistant => 'Asistente';

  @override
  String labelCompactContext(int percent) {
    return 'Compactar contexto ($percent%)';
  }

  @override
  String get labelRequired => 'Requerida';

  @override
  String get labelOptional => 'Opcional';

  @override
  String get labelDiff => 'Diff';

  @override
  String get labelEdit => 'Editar';

  @override
  String get labelView => 'Vista';

  @override
  String get labelAdaptiveCapabilities => 'Capacidades adaptativas';

  @override
  String get labelMandatoryContext => 'Contexto obligatorio';

  @override
  String labelReplansLimit(int count) {
    return 'Límite de reformulaciones: $count';
  }

  @override
  String labelReadVerifySubagents(int count) {
    return 'Subagentes de lectura/verificación: $count';
  }

  @override
  String labelSharedAuditCycles(int count) {
    return 'Ciclos compartidos de auditoría: $count';
  }

  @override
  String labelAgentFor(String capability) {
    return 'Agente para \\\"$capability\\\"';
  }

  @override
  String get buttonNew => 'Nuevo';

  @override
  String get buttonRegisterSkill => 'Registrar skill';

  @override
  String get buttonCreateSkill => 'Crear skill';

  @override
  String get buttonReplace => 'Reemplazar';

  @override
  String get buttonImport => 'Importar';

  @override
  String get buttonRegenerateToken => 'Regenerar token';

  @override
  String get buttonViewLocked => 'Ver bloqueados…';

  @override
  String get buttonAskKeelAI => 'Pedírselo a Keel AI';

  @override
  String get buttonCreateManually => 'Crearlo a mano';

  @override
  String get buttonRename => 'Renombrar';

  @override
  String get buttonUngroupGroup => 'Deshacer el grupo';

  @override
  String get buttonRegisterSecret => 'Registrar secret';

  @override
  String get buttonLoadValue => 'Cargar valor';

  @override
  String get buttonNewSession => 'Nueva sesión';

  @override
  String get buttonChooseFolder => 'Elegir carpeta';

  @override
  String get buttonReviewAgain => 'Revisar de nuevo';

  @override
  String get buttonDefineFormat => 'Definir el formato';

  @override
  String get buttonDocumentation => 'Documentación';

  @override
  String get buttonTestConnection => 'Probar la conexión';

  @override
  String get buttonRegisterMCP => 'Registrar MCP';

  @override
  String get buttonChoose => 'Elegir…';

  @override
  String get buttonRegisterAgent => 'Registrar agente';

  @override
  String get buttonTest => 'Probar';

  @override
  String get buttonOpenWithSystemApp => 'Abrir con la app del sistema';

  @override
  String get buttonReturnToAgentDefault => 'Volver al del agente';

  @override
  String get buttonReview => 'Revisar';

  @override
  String get buttonRebuildAndReopen => 'Reconstruir y reabrir';

  @override
  String get buttonExport => 'Exportar…';

  @override
  String get buttonImportDots => 'Importar…';

  @override
  String get buttonBackup => 'Respaldar';

  @override
  String get buttonBackupAndUpload => 'Respaldar y subir';

  @override
  String get buttonRestoreDots => 'Restaurar…';

  @override
  String get buttonBring => 'Traer';

  @override
  String get buttonInstall => 'Instalar';

  @override
  String get buttonAsk => 'Preguntar…';

  @override
  String get buttonClear => 'Vaciar';

  @override
  String get buttonView => 'Ver';

  @override
  String get buttonApproveChange => 'Aprobar cambio';

  @override
  String get buttonAddRule => 'Agregar regla';

  @override
  String get buttonAddKnowledge => 'Agregar conocimiento';

  @override
  String get buttonApproveAndContinue => 'Aprobar y continuar';

  @override
  String get buttonOpen => 'Abrir';

  @override
  String get buttonNewKnowledgeBase => 'Nueva base';

  @override
  String get buttonContinuePlanning => 'Seguir planificando';

  @override
  String get buttonImplement => 'Implementar';

  @override
  String get buttonRegister => 'Registrar';

  @override
  String get buttonReloadFromDisk => 'Recargar del disco';

  @override
  String get buttonClose => 'Cerrar';

  @override
  String get buttonReject => 'Rechazar';

  @override
  String get buttonAssignAndEvaluate => 'Tomar y evaluar';

  @override
  String get buttonGoToSession => 'Ir a la sesión';

  @override
  String get buttonRejectAndExplain => 'Rechazar y explicar';

  @override
  String get messageNoSkillsRegistered =>
      'Todavía no registraste ningún skill.';

  @override
  String get messageNoToolsRegistered =>
      'Todavía no registraste ninguna herramienta.';

  @override
  String get messageNoRulesRegistered =>
      'Todavía no registraste ninguna regla.';

  @override
  String get messageApiNotRunning =>
      'La API no está corriendo en esta ventana.';

  @override
  String messageApiUrl(int port) {
    return 'URL: http://127.0.0.1:$port';
  }

  @override
  String messageApiToken(String token) {
    return 'Token: $token';
  }

  @override
  String get messageBoardNotFound => 'Ese tablero ya no existe.';

  @override
  String get messageNoBoardsYet => 'Todavía no hay tableros';

  @override
  String get messageNoHooksRegistered => 'Todavía no registraste ningún hook.';

  @override
  String get messageNoExternalMCPs =>
      'Todavía no registraste ningún MCP externo.';

  @override
  String get messageNoProjectsRegistered =>
      'Todavía no registraste ningún proyecto.';

  @override
  String get messageNoAgentsRegistered =>
      'Todavía no registraste ningún agente.';

  @override
  String get messageNoWorkflowsRegistered =>
      'Todavía no registraste ningún workflow.';

  @override
  String get messageNoneYet => 'Ninguno todavía.';

  @override
  String get messageNoMoreAgentsToAdd =>
      'No quedan agentes registrados por sumar.';

  @override
  String messageCouldNotOpenImage(String error) {
    return 'No pude abrir la imagen: $error';
  }

  @override
  String get messageSessionNotFound => 'La sesión ya no existe.';

  @override
  String messageDrop(String name) {
    return 'Soltar $name';
  }

  @override
  String get messageFileTooLarge =>
      'El archivo es muy grande para mostrar un diff.';

  @override
  String get messageAskYourAgent => 'Escríbele algo a tu agente';

  @override
  String get messageNoKnowledgeBases => 'Todavía no hay ninguna base de saber.';

  @override
  String get messageBackupEmpty => 'El respaldo no trae nada aplicable.';

  @override
  String get optionCommand => 'Un comando';

  @override
  String get optionRegisteredTool => 'Una tool registrada';

  @override
  String get optionGiveToKeelAI => 'Dárselo a Keel AI (el asistente)';

  @override
  String get optionIMaintainIt => 'Lo mantengo yo';

  @override
  String optionUseDefault(String role) {
    return 'Usar default ($role)';
  }

  @override
  String get optionAnyMember => 'Cualquier miembro';

  @override
  String get optionNewSession => 'Nueva sesión';

  @override
  String get optionResumeParentSession => 'Reanudar sesión padre';

  @override
  String get optionProviderSubagent => 'Subagente del proveedor';

  @override
  String get optionManualApproval => 'Aprobación manual';

  @override
  String optionAgentProvider(String provider) {
    return 'El del agente ($provider)';
  }

  @override
  String optionAgentEffort(String effort) {
    return 'El del agente ($effort)';
  }

  @override
  String get titleReadOnly => 'Solo lectura';

  @override
  String get titleRequiresIndependentAgent => 'Requiere agente independiente';

  @override
  String get subtitleReadOnly => 'Planificadores y auditores no escriben.';

  @override
  String get linkWebsite => 'jhonacode.com';

  @override
  String get linkCommunity => 'Comunidad en Discord';

  @override
  String get tooltipRegisterNew => 'Registrar nuevo';

  @override
  String get tooltipImportPackage => 'Importar un paquete';

  @override
  String get tooltipDismiss => 'Descartar';

  @override
  String get messageNoHooksDescription =>
      'Un hook es un comando que se ejecuta en un momento del turno y que el agente no puede omitir: puede detener una herramienta antes de usarla o reaccionar después. Una regla pide; un hook garantiza.';

  @override
  String get labelLlmProviders => 'PROVEEDORES LLM';

  @override
  String get labelOtherSecrets => 'OTROS SECRETOS';

  @override
  String get suggestionIntro =>
      'Detecté cosas que pides con frecuencia — ¿las convertimos en skills globales?';

  @override
  String suggestionDraftHeader(int count) {
    return 'Se detectó una instrucción recurrente ($count veces). Ejemplos de lo que pediste:\\n';
  }

  @override
  String get suggestionDraftFooter => 'Redacta aquí la instrucción definitiva:';

  @override
  String get formTitleRegisterAgent => 'Registrar agente';

  @override
  String get formTitleEditAgent => 'Editar agente registrado';

  @override
  String get formLabelAgentName => 'Nombre (minúsculas, sin espacios, máx. 16)';

  @override
  String get formLabelAgentRole => 'Rol';

  @override
  String get formLabelAgentRoleHint => 'Qué hace este agente';

  @override
  String get formLabelSystemPrompt => 'System prompt';

  @override
  String get formLabelProvider =>
      'Proveedor (codex: sin tools/MCPs/esfuerzo, y sus propios modelos)';

  @override
  String formLabelModel(String provider) {
    return 'Modelo por defecto ($provider)';
  }

  @override
  String get formLabelEffort => 'Esfuerzo por defecto';

  @override
  String get formMessageCanManageSystem => 'Puede administrar el sistema';

  @override
  String get formDescriptionManageSystem =>
      'Agente constructor: recibe las mismas tools de creación que Keel AI (skills, reglas, tools, agentes, workflows, proyectos) en sus chats 1:1.';

  @override
  String get formDescriptionKeelAiHooks =>
      'Keel AI corre sin hooks a propósito: es a quien le pides apagar uno que te trabó. Lo que asignes aquí no se va a aplicar.';

  @override
  String get formDescriptionHooks =>
      'Corren fuera del modelo, así que no los puede saltear. Las reglas de arriba se piden; estos se cumplen.';

  @override
  String get formDescriptionRoles =>
      'Roles que piden tus workflows — tocá uno para que este agente los cubra:';

  @override
  String get formDescriptionRolesHelp =>
      'El preflight del workflow busca responsables por este rol.';

  @override
  String formConfirmDeleteAgent(Object name) {
    return 'Se eliminará el registro \\\"$name\\\". Esto no afecta a los chats que ya usaste con esta configuración.';
  }

  @override
  String get formTitleDeleteAgent => 'Eliminar agente registrado';

  @override
  String get tooltipEditAgent => 'Editar';

  @override
  String get tooltipExportAsPackage => 'Exportar como paquete';

  @override
  String get tooltipDeleteAgent => 'Eliminar';

  @override
  String get mapStateWaiting => 'Esperándote';

  @override
  String get mapStateFailed => 'Cortó';

  @override
  String get labelAskedFor => 'Le pidió';

  @override
  String get labelHowReasons => 'Cómo razona';

  @override
  String get statusLive => 'En vivo';

  @override
  String get labelWhatDid => 'Qué hizo';

  @override
  String get labelWhatReturned => 'Qué devolvió';

  @override
  String get labelTask => 'El encargo';

  @override
  String get labelWhatResolved => 'Qué resolvió';

  @override
  String get labelAskedAbout => 'Le consultaron';

  @override
  String get labelNumbers => 'Números';

  @override
  String get labelMemberOpened => 'El miembro que lo abrió';

  @override
  String placeholderWriteTo(String name) {
    return 'Escribe a @$name…';
  }

  @override
  String get messageNoReasoningVisible =>
      'No dejó pensamiento visible. Con modelos que no lo emiten, aquí no hay nada que mostrar.';

  @override
  String get messageNodeNotResolution =>
      'Este nodo no pertenece a un caso de resolución: habla cuando lo consultan.';

  @override
  String get messageNoReasoningYet => 'Todavía no razonó nada en este paso.';

  @override
  String get messageNodeNotMember =>
      'Este nodo ya no es miembro del proyecto, así que no hay a quién escribirle.';

  @override
  String get messageNoConsultRecord =>
      'No quedó registrado con qué frase lo llamó.';

  @override
  String get messageNoToolsOpened => 'Todavía no abrió ninguna herramienta.';

  @override
  String messageSubagentWriteLocked(String parent) {
    return 'Mientras corre, no se puede escribirle a un subagente: el CLI no abre ese canal. Lo que escribas aquí le llega a $parent, quien lo abrió.';
  }

  @override
  String get formLabelHookName => 'Nombre';

  @override
  String get formHintHookScript =>
      'Es también el nombre del script que se genera.';

  @override
  String get formLabelWhatHookDoes => 'Qué hace';

  @override
  String get formMessageNoEventFilter => 'Este evento no filtra: dejalo vacío.';

  @override
  String formHintEventFilter(String matcherHint) {
    return 'Vacío = todo. Ejemplos: $matcherHint';
  }

  @override
  String get formDescriptionHookScope =>
      'Corto a propósito: un hook de \"antes de usar una herramienta\": si lo rechazas, no se llama. Uno de \"después\" es más raro.';

  @override
  String get formLabelHookRules => 'Qué reglas hace cumplir este hook';

  @override
  String get formDescriptionHookRules =>
      'No cambia lo que corre: deja anotado cuáles de tus reglas están garantizadas y cuáles se piden.';

  @override
  String get formLabelWhenHookRuns => 'Cuándo corre';

  @override
  String get formLabelWhatHookExecutes => 'Qué ejecuta';

  @override
  String get messageNoToolsRegisteredShort =>
      'Todavía no registraste ninguna tool.';

  @override
  String get formDescriptionHookCode =>
      'El código viaja en el respaldo y puede usar los secrets que configuraste. Si el admin no permite write, un hook del disco no se restaura en otra máquina.';

  @override
  String get formLabelHookTimeout => 'Timeout (segundos)';

  @override
  String get formDescriptionHookTimeout =>
      'Recibe el evento como JSON por entrada estándar. Salir con código 2 bloquea.';

  @override
  String get pageTitleMachineTitle => 'Máquina';

  @override
  String get messageDetectionNotIntegration =>
      'Detectar no es integrar: los que dicen «sin adaptador» están en tu máquina pero Keel todavía no sabe hablarles, y no se le puede pedir que lo hagan solos.';

  @override
  String get labelConsumption => 'Consumo · últimos 14 días';

  @override
  String get messageNoConsumptionYet =>
      'Todavía no hay nada medido. El historial arranca hoy: hasta ahora los contadores de cada turno se leían para el porcentaje de contexto y se tiraban, así que no hay forma de saber qué se gastó dónde. Y el historial empieza el día que se instaló esta pantalla.';

  @override
  String get labelCacheReadShort => 'CACHÉ LEÍDA';

  @override
  String get messageNoTokenCount => 'Sin medición — su CLI no informa tokens';

  @override
  String labelCoresShort(int cores) {
    return '$cores núcleos';
  }

  @override
  String get messageNotInPath => 'No está en el PATH';

  @override
  String get formLabelWorkflowIntent => 'Intención y cuándo se aplica';

  @override
  String get formDescriptionWorkflowEngine =>
      'El motor decide los nodos mínimos; no configuras una cadena de agentes.';

  @override
  String labelMaxReplans(int count) {
    return 'Límite de reformulaciones: $count';
  }

  @override
  String labelMaxSubagents(int count) {
    return 'Subagentes de lectura/verificación: $count';
  }

  @override
  String labelMaxReviewCycles(int count) {
    return 'Ciclos compartidos de auditoría: $count';
  }

  @override
  String get formLabelWorkflowTitle => 'Título visible';

  @override
  String get formLabelWorkflowInstruction => 'Instrucción';

  @override
  String get formLabelWorkflowActivation => 'Activación';

  @override
  String get formLabelWorkflowExecution => 'Ejecución';

  @override
  String get formDescriptionParentSessionKept =>
      'La sesión del padre se conserva y se reanuda.';

  @override
  String get formLabelMaxAgenticTurns => 'Máximo de turnos agentic';

  @override
  String get formDescriptionMaxAgenticTurns =>
      'Vacío o 0 usa el límite del proveedor.';

  @override
  String get formLabelWorkflowOwner => 'Dueño';

  @override
  String get formDescriptionWorkflowOwner =>
      'El dueño debe ser distinto de quienes produjeron sus dependencias.';

  @override
  String get formLabelWorkflowResponsible => 'Responsable de resolución';

  @override
  String get formDescriptionResponsible =>
      'Un responsable integra evidencia y es el único escritor.';

  @override
  String get workflowKindMigration => 'Migración';

  @override
  String labelAge(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String get labelWeekdayShort => 'lun, mar, mié, jue, vie, sáb, dom';

  @override
  String messageRequirementTaken(String handle) {
    return 'Lo tomó @$handle';
  }

  @override
  String messageRequirementTask(String taskPath) {
    return 'Quedó como tarea: $taskPath';
  }

  @override
  String get messagePlanMode =>
      'Modo plan: que proponga cómo lo haría. Para implementarlo de verdad, «Tomar y evaluar» abre una sesión.';

  @override
  String get messageRequirementAnswering => 'Está contestando…';

  @override
  String get messagePlanRequest => 'Pide un plan — @ para llamar a un agente';

  @override
  String get messageWriteHere =>
      'Escribe aquí — @ para preguntarle a un agente';

  @override
  String get messageRequirementClosed => 'El destino pidió el cierre.';

  @override
  String get messageOnlyOriginCanClose =>
      'Solo del lado que lo abrió se puede cerrar — es quien sabe si lo que necesitaba está.';

  @override
  String get labelWithWorkflow => 'Con qué workflow lo evalúa';

  @override
  String messageNewSessionOpenedWorkflow(String workflowName) {
    return 'Va a abrir una sesión nueva en #$workflowName. Elige la fila de abajo para cada rol.';
  }

  @override
  String get formLabelWhatMissing => 'Qué falta';

  @override
  String get bundleExportNothingYet => 'Todavía no hay nada para exportar.';

  @override
  String get bundleSectionWhatItTakes => 'Qué se lleva';

  @override
  String get bundleSectionWhatItBrings => 'Qué trae';

  @override
  String get bundleSectionWhatRecipientSees =>
      'Lo que va a ver quien lo reciba';

  @override
  String get bundleSectionSecurityReview => 'Revisión de seguridad';

  @override
  String get bundleNoFindings => 'sin hallazgos';

  @override
  String bundleFindingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hallazgos',
      one: '1 hallazgo',
    );
    return '$_temp0';
  }

  @override
  String bundleMissingNote(String list) {
    return 'Esto lo nombra pero de este lado no existe, así que no viaja:\n$list';
  }

  @override
  String bundleSecretsToCreateNote(String names) {
    return 'Quien lo instale va a tener que crear estos secrets con estos nombres: $names. Los valores no viajan.';
  }

  @override
  String get actionImportPackage => 'Importar un paquete';

  @override
  String get bundleImportIntro =>
      'Un paquete trae un agente, un workflow o una skill con todo lo que necesita para funcionar: sus skills, sus reglas, sus tools, sus hooks, sus servidores MCP y su documentación.';

  @override
  String get bundleImportSafetyNote =>
      'Nada se instala sin que veas antes qué trae y qué encontró la revisión.';

  @override
  String get actionChooseFile => 'Elegir un archivo';

  @override
  String get bundleOrFromLink => 'o desde un enlace';

  @override
  String get bundleLinkHint => 'https://…/keel-agent-flutter-expert.zip';

  @override
  String get actionBring => 'Traer';

  @override
  String get bundleDocumentsLabel => 'documentos';

  @override
  String bundleSecretsRequiredNote(String names) {
    return 'Necesita estos secrets, que tienes que crear tú con estos nombres: $names. Un paquete nunca trae valores.';
  }

  @override
  String get actionInstall => 'Instalar';

  @override
  String bundleHighRiskAck(int count) {
    return 'Leí los $count hallazgos de gravedad alta y quiero instalarlo igual.';
  }

  @override
  String bundleAuditCleanNote(int count) {
    return 'Revisé $count textos y no encontré nada conocido. No es una garantía: busca lo que sabe buscar.';
  }

  @override
  String bundleRiskLevelLabel(String level) {
    return 'GRAVEDAD $level';
  }

  @override
  String get actionSaveAsPng => 'Guardar como PNG';

  @override
  String codeBlockLineCount(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count líneas',
      one: '1 línea',
    );
    return '$title · $_temp0';
  }

  @override
  String get semanticsOpenImageFullSize =>
      'Imagen adjunta, abrir en tamaño completo';

  @override
  String get tooltipOpenFullSize => 'Abrir en tamaño completo';

  @override
  String get messageImageUnavailable => 'Imagen no disponible';

  @override
  String get labelDeletedProject => 'proyecto eliminado';

  @override
  String labelOpenSince(String age) {
    return 'abierto hace $age';
  }

  @override
  String get labelBlockingRequester => 'bloquea a quien lo pide';

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
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String get messageTakenByYou => 'Lo tomaste tú';

  @override
  String get labelVerdict => 'VEREDICTO';

  @override
  String get tooltipPlanModeActive =>
      'Modo plan activo: propone en vez de afirmar';

  @override
  String messageNewRequirementSessionNote(String workflowName) {
    return 'Va a abrir una sesión nueva en #$workflowName. Elige la fila de agentes que corresponde a este pedido — evaluar un requerimiento rara vez es lo mismo que resolver un ticket.';
  }

  @override
  String get labelProjectNoLongerExists => 'un proyecto que ya no existe';

  @override
  String get assistantWindowTitle => 'Asistente';

  @override
  String get buttonAskKeelAi => 'Pedírselo a Keel AI';

  @override
  String get buttonCreateByHand => 'Crearlo a mano';

  @override
  String get buttonOverwriteAnyway => 'Sobrescribir igual';

  @override
  String get hintAskAboutThisLine => 'Pregunta sobre esta línea…';

  @override
  String get hintQueuedMessage => 'Mensaje que se enviará en el próximo turno';

  @override
  String get hintSessionName => 'Nombre de la sesión';

  @override
  String get labelCloseSession => 'Cerrar sesión';

  @override
  String get labelDeleteIntegration => 'Eliminar integración';

  @override
  String get labelFileChanged => 'El archivo cambió';

  @override
  String get labelGiveToKeelAi => 'Dárselo a Keel AI (el asistente)';

  @override
  String get labelHeadersKeyValue => 'Headers (KEY=valor, una por línea)';

  @override
  String get labelKnowledgeBaseAnswers => 'Qué contesta esta base';

  @override
  String labelModelWithProvider(String provider) {
    return 'Modelo ($provider)';
  }

  @override
  String labelMaxReplansLimit(int count) {
    return 'Límite de reformulaciones: $count';
  }

  @override
  String labelMaxReviewCyclesLimit(int count) {
    return 'Ciclos compartidos de auditoría: $count';
  }

  @override
  String labelMaxSubagentsLimit(int count) {
    return 'Subagentes de lectura/verificación: $count';
  }

  @override
  String labelIdleTimeoutLimit(int count) {
    return 'Minutos sin actividad del proveedor antes de cortar un paso: $count (0 = sin límite)';
  }

  @override
  String labelNodeTimeoutLimit(int count) {
    return 'Minutos máximos por paso: $count (0 = sin límite)';
  }

  @override
  String labelSessionCostLimit(int amount) {
    return 'Techo de costo de la sesión en USD (0 = sin techo): $amount';
  }

  @override
  String get labelNoBoardsYet => 'Todavía no hay tableros';

  @override
  String get labelNoSessionOpen => 'Ninguna sesión abierta';

  @override
  String get labelPasteBlockAsInDocs =>
      'Pega el bloque tal como está en la documentación';

  @override
  String get labelPasteMcpConfig => 'Pegar una configuración MCP';

  @override
  String get labelProjectPurpose => 'Propósito';

  @override
  String get labelRequirementContext =>
      'Contexto: qué hicieron y por qué lo necesitan';

  @override
  String get labelRequirementNeed => 'Qué necesita';

  @override
  String get labelRequirementTitle => 'Título';

  @override
  String get labelSessionAgents => 'Agentes de esta sesión';

  @override
  String get labelSpecification => 'Especificación';

  @override
  String get labelTermsOfUse => 'Términos de uso';

  @override
  String get labelWhichWorkflowRuns => 'Con qué workflow corre';

  @override
  String messageCloseSessionBody(String title) {
    return 'Se borra el hilo de \"$title\" y el contexto que los agentes acumularon en ella. El proyecto queda igual, con sus agentes, reglas y documentos.';
  }

  @override
  String messageDeleteIntegrationBody(String name) {
    return 'Se elimina \"$name\". Los agentes que la tenían asignada dejan de recibir sus tools.';
  }

  @override
  String get messageFileChangedBody =>
      'Este archivo se modificó (por ejemplo el agente lo editó) desde que abriste esta ventana. Si guardas ahora, vas a sobrescribir ese cambio con lo que tienes aquí.';

  @override
  String get messageNoAgentsToAdd => 'No quedan agentes registrados por sumar';

  @override
  String get messageNoBoardsExplainer =>
      'Un tablero es una pantallita para disparar algo contra tu propia app: lanzar una oferta, mandarte un push, pegarle a un endpoint que estás escribiendo.\n\nLo más rápido es pedírselo a un agente del proyecto: lee tu código y lo arma solo. Aparece en la sección Tableros de ese proyecto.';

  @override
  String get messageNoExtraAgentsYet => 'Ninguno todavía.';

  @override
  String get messageNoKnowledgeBasesYet =>
      'Todavía no hay ninguna base de saber.';

  @override
  String get messageNoMcpServersRegistered =>
      'Todavía no registraste ningún MCP externo.';

  @override
  String get messageSessionGone => 'La sesión ya no existe.';

  @override
  String get messageWhichWorkflowRunsNote =>
      'Esta sesión y ninguna otra. Un proyecto hace trabajos de clases distintas —armar la carpeta de tareas, resolver un ticket, evaluar un requerimiento— y cada uno quiere otra fila de agentes.';

  @override
  String get sectionAddToSession => 'Agregar a esta sesión';

  @override
  String get sectionProjectMembers =>
      'Miembros del proyecto (en todas las sesiones)';

  @override
  String get sectionSessionOnly => 'Solo en ESTA sesión';

  @override
  String get tooltipAgentAnsweringThread =>
      'Un agente está contestando en el hilo';

  @override
  String get tooltipGoToLatestMessage => 'Ir al mensaje más reciente';

  @override
  String get tooltipGuardrailsAutorun => 'Guardarraíles que corren solos';

  @override
  String get tooltipLegendMeaning => 'Qué significa cada línea';

  @override
  String get tooltipNewConversation => 'Nueva conversación';

  @override
  String get tooltipRefreshCatalog => 'Refrescar catálogo';

  @override
  String get tooltipRemoveFromSession => 'Quitar de esta sesión';

  @override
  String get tooltipRunsCommandsOnYourMachine => 'Corre comandos en tu máquina';

  @override
  String get tooltipWorkingNow => 'Trabajando ahora';

  @override
  String get workflowTitleTaskFormat => 'Construir formato de tareas';

  @override
  String get workflowTitleVerifyFormat => 'Verificar formato';

  @override
  String get workflowTitlePlanAndScope => 'Planificar y delimitar';

  @override
  String get workflowTitleSingleEntryPoint =>
      'Diseño del punto único de entrada';

  @override
  String get workflowTitleImplement => 'Implementar con evidencia';

  @override
  String get workflowTitleCodeAudit => 'Auditar código';

  @override
  String get workflowTitleCodeCorrection => 'Corregir hallazgos de código';

  @override
  String get workflowTitleTests => 'Crear y ajustar pruebas';

  @override
  String get workflowTitleTestAudit => 'Auditar tests';

  @override
  String get workflowTitleTestCorrection => 'Corregir hallazgos de tests';

  @override
  String get workflowTitleDeviceE2e => 'Verificación end-to-end en dispositivo';

  @override
  String get workflowTitleVerification => 'Verificación de cierre';

  @override
  String get workflowTitlePublishApproval => 'Aprobar publicación';

  @override
  String get termsVersion => 'Versión 1 — agosto de 2026';

  @override
  String get termsSection1Title => '1. Qué es Keel';

  @override
  String get termsSection1Body =>
      'Keel es una herramienta de escritorio que trabaja sobre los CLI de agentes que ya tienes instalados en tu máquina. No es un servicio: no hay un servidor de Keel al que te conectes, no hay cuenta que crear y no hay registro. Si apagas internet, Keel sigue abriéndose.\n\nUsar Keel significa aceptar estos términos. Si no estás de acuerdo con alguno, no lo uses.';

  @override
  String get termsSection2Title => '2. De quién es';

  @override
  String get termsSection2Body =>
      'Keel —su código, su diseño, su nombre, su documentación y todo lo que lo acompaña— es propiedad intelectual de Jhonatan Ortiz (JhonaCode), ingeniero de software. Todos los derechos reservados.\n\nNo es software libre ni de código abierto. No se distribuye bajo MIT, Apache, BSD, GPL ni ninguna otra licencia permisiva. Tener una copia no te da derecho a usarla: hace falta permiso escrito del autor. El texto completo está en el archivo LICENSE.';

  @override
  String get termsSection3Title => '3. Solo se descarga de jhonacode.com';

  @override
  String get termsSection3Body =>
      'El autor se reserva de forma exclusiva el derecho a distribuir Keel. El ÚNICO canal autorizado es jhonacode.com.\n\nQueda prohibido republicar, espejar, subir a otro sitio, incluir en un repositorio de paquetes, en una tienda de aplicaciones, en una imagen de contenedor o en cualquier otro canal de distribución, sea gratis o cobrando. Tampoco se puede revender, alquilar, sublicenciar ni ofrecer Keel como servicio a terceros.';

  @override
  String get termsSection4Title => '4. Copias que no vinieron de ahí';

  @override
  String get termsSection4Body =>
      'Cualquier copia de Keel obtenida fuera de jhonacode.com no está autorizada, y el autor no tiene forma de saber qué le hicieron: pudo ser modificada, empaquetada con otra cosa o alterada para hacer algo que Keel no hace.\n\nEl autor no responde por esas copias ni por lo que provoquen, y nada de lo que hagan puede atribuírsele. Una compilación modificada por un tercero no es Keel, aunque se llame así. Si te importa lo que corre en tu máquina, bájala del sitio oficial.';

  @override
  String get termsSection5Title => '5. Keel no te pide datos';

  @override
  String get termsSection5Body =>
      'No te pide nombre, correo, contraseñas ni claves de nada. No hay inicio de sesión. Todo lo que armas —proyectos, agentes, skills, tools, bases de saber, hilos de chat y ajustes— se guarda en tu propia máquina.\n\nLos valores de tus secrets nunca salen en un respaldo: el respaldo lleva solo los nombres, para que del otro lado sepas cuáles completar. La API de trabajos programados escucha únicamente en loopback, o sea que no es alcanzable desde fuera de tu equipo.';

  @override
  String get termsSection6Title => '6. Lo único que sí sale de tu máquina';

  @override
  String get termsSection6Body =>
      'Si esta compilación trae configurado un canal de reportes, cuando algo se rompe se envía a ese canal: el mensaje del error, su traza, el archivo de Keel donde ocurrió, el nombre de tu equipo y si la compilación es de desarrollo o de producción.\n\nNo se envía nada más. Ni el contenido de tus chats, ni tus archivos, ni tus secrets, ni qué proyectos tienes. Sirve para una sola cosa: que quien mantiene Keel se entere de que algo falló.';

  @override
  String get termsSection7Title =>
      '7. Keel es una herramienta, y tú la manejas';

  @override
  String get termsSection7Body =>
      'Keel lanza agentes con los permisos que tú les das, y esos permisos pueden incluir acceso completo a tu disco. Un agente puede crear, modificar y borrar archivos, ejecutar comandos y hacer commits en tus repositorios.\n\nTú decides qué permisos otorgas, sobre qué carpetas y qué le pides a cada agente. Keel ejecuta esas decisiones; no las toma por ti y no las supervisa. El autor no se hace responsable del uso que le des a la herramienta ni de las consecuencias de lo que los agentes hagan siguiendo tus instrucciones.';

  @override
  String get termsSection8Title =>
      '8. Tus archivos son tuyos, y tus respaldos también';

  @override
  String get termsSection8Body =>
      'Una herramienta que le da acceso a tu disco a un agente puede terminar en archivos perdidos, sobrescritos o cambiados de una forma que no querías. Puede pasar por un error de Keel, por un error del agente o por una instrucción tuya que salió distinta a como la pensaste.\n\nMantener respaldos de lo que te importa es responsabilidad tuya. El autor no responde por pérdida ni por corrupción de datos.';

  @override
  String get termsSection9Title => '9. No es para usos críticos';

  @override
  String get termsSection9Body =>
      'Keel no está diseñado ni probado para entornos donde una falla ponga en riesgo la vida, la salud, la seguridad o infraestructura esencial: medicina, aviación, transporte, energía, control industrial o similares. No lo uses ahí.';

  @override
  String get termsSection10Title => '10. Lo que no depende de Keel';

  @override
  String get termsSection10Body =>
      'Los CLI de agentes y los servidores MCP que uses son de terceros. Cada uno tiene sus propios términos, sus precios y su propia forma de tratar lo que le mandas. Keel no responde por ellos, ni por lo que cobren, ni por lo que hagan con la información que reciben, ni por lo que decidan cambiar o discontinuar.\n\nCumplir los términos de esos servicios es cosa tuya.';

  @override
  String get termsSection11Title => '11. Lo que te comprometes a no hacer';

  @override
  String get termsSection11Body =>
      'No copiar, modificar, traducir ni crear obras derivadas de Keel.\nNo aplicar ingeniería inversa, descompilar ni desensamblar, salvo donde la ley lo permita de forma imperativa.\nNo eludir ni desactivar ninguna medida técnica de protección.\nNo quitar ni tapar los avisos de autoría, copyright o licencia.\nNo usar el nombre, el logo ni la imagen de Keel o de JhonaCode sin permiso escrito.\nNo usar Keel ni ninguna parte de él para entrenar modelos de aprendizaje automático o sistemas de inteligencia artificial.\nNo usar Keel para nada ilegal, ni para vulnerar derechos de terceros.';

  @override
  String get termsSection12Title =>
      '12. Si tu uso le trae un problema al autor';

  @override
  String get termsSection12Body =>
      'Si un tercero reclama algo por la forma en que usaste Keel, o por lo que hiciste con lo que produjo, ese reclamo es tuyo. Te comprometes a mantener al autor libre de todo daño, gasto o responsabilidad que salga de tu uso de la herramienta o del incumplimiento de estos términos.';

  @override
  String get termsSection13Title => '13. Sin garantía';

  @override
  String get termsSection13Body =>
      'Keel se entrega TAL CUAL ESTÁ y SEGÚN DISPONIBILIDAD, sin garantía de ningún tipo, expresa o implícita. No se garantiza que funcione sin errores ni interrupciones, que esté disponible, que sea compatible con tu equipo o con tus herramientas, ni que sirva para un propósito determinado.';

  @override
  String get termsSection14Title => '14. Hasta dónde llega la responsabilidad';

  @override
  String get termsSection14Body =>
      'En la medida en que la ley lo permita, el autor no responde por daños indirectos, incidentales, especiales ni consecuentes, ni por lucro cesante, pérdida de datos, pérdida de tiempo de trabajo o interrupción de actividad, aunque se le hubiera advertido de esa posibilidad.\n\nSi aun así se determinara alguna responsabilidad, su límite total será lo que hayas pagado por Keel en los doce meses previos al hecho, que en la práctica es cero: Keel no se cobra y las donaciones no son un pago por el software.';

  @override
  String get termsSection15Title => '15. Donaciones';

  @override
  String get termsSection15Body =>
      'Si Keel te sirve y quieres apoyar el trabajo, se agradece. Es completamente voluntario.\n\nUna donación es eso y nada más: no es una compra, no es una licencia, no da derecho a usar el software sin permiso, no incluye soporte, no da prioridad en nada, no crea ninguna obligación del autor hacia quien dona y no se devuelve.';

  @override
  String get termsSection16Title => '16. Cuándo se termina el permiso';

  @override
  String get termsSection16Body =>
      'Cualquier uso fuera de lo autorizado extingue de inmediato y sin aviso todo permiso concedido. También puede revocarse un permiso otorgado antes. Al terminar, tienes que dejar de usar Keel y borrar las copias que tengas.\n\nLas secciones sobre propiedad, responsabilidad, garantía e indemnidad siguen vigentes después de eso.';

  @override
  String get termsSection17Title => '17. Si alguna cláusula no vale';

  @override
  String get termsSection17Body =>
      'Si un tribunal declara inválida o inaplicable alguna parte de estos términos, el resto sigue en pie, y esa parte se interpreta de la forma más cercana posible a su intención original.\n\nQue el autor no ejerza un derecho en algún momento no significa que renuncie a él. Entre Keel y tú no hay sociedad, empleo, franquicia ni representación de ningún tipo.';

  @override
  String get termsSection18Title => '18. Ley aplicable';

  @override
  String get termsSection18Body =>
      'Estos términos se rigen por las leyes del país de residencia del autor, y cualquier controversia se somete a los tribunales competentes de ese lugar.';

  @override
  String get termsSection19Title => '19. Estos términos pueden cambiar';

  @override
  String get termsSection19Body =>
      'Si cambian, la versión que vale es la que muestra esta pantalla. Seguir usando Keel después de un cambio significa que lo aceptas.';

  @override
  String get termsSection20Title => '20. Contacto';

  @override
  String get termsSection20Body =>
      'Para pedir permiso de uso, donar, reportar algo o cualquier otra consulta: jhonacode.com';

  @override
  String get messageWriteToAgent => 'Escríbele algo a tu agente';

  @override
  String skillAlreadyExists(String name) {
    return 'La skill \"$name\" ya existía, la reusé.';
  }

  @override
  String ruleAlreadyExists(String name) {
    return 'La regla \"$name\" ya existía, la reusé.';
  }

  @override
  String toolAlreadyExists(String name) {
    return 'La tool \"$name\" ya existía, la reusé.';
  }

  @override
  String skillCreated(String name) {
    return 'Creé la skill \"$name\".';
  }

  @override
  String ruleCreated(String name) {
    return 'Creé la regla \"$name\".';
  }

  @override
  String handleReserved(String handle) {
    return 'El handle \"$handle\" está reservado.';
  }

  @override
  String get keelAiModifyBlocked =>
      'Keel AI pidió modificar un elemento bloqueado.';

  @override
  String formEditEntity(Object entity) {
    return 'Editar $entity';
  }

  @override
  String formRegisterEntity(Object entity) {
    return 'Registrar $entity';
  }

  @override
  String get formName => 'Nombre';

  @override
  String get formEnvironmentVariableName => 'Nombre de la variable de entorno';

  @override
  String get formWorkingDirectory => 'Carpeta de trabajo';

  @override
  String get formChoose => 'Elegir…';

  @override
  String get formSave => 'Guardar';

  @override
  String get formCreate => 'Crear';

  @override
  String get formGlobalSkill => 'Skill global';

  @override
  String get formGlobalSkillDescription =>
      'La reciben todos los agentes en cada turno, sin necesidad de asignarla.';

  @override
  String get formSkillContent => 'Contenido (instrucciones para inyectar)';

  @override
  String get formToolDescription =>
      'Descripción para el agente: qué hace, cuándo usarla y qué significa cada argumento posicional';

  @override
  String get formStoredValue => 'Valor cargado  ••••••••';

  @override
  String get formNewValueKeepCurrent =>
      'Valor nuevo (vacío = conservar el actual)';

  @override
  String get formValue => 'Valor';

  @override
  String get formValueDescription =>
      'Nunca pasa por un modelo. Se inyecta como credencial solo al proveedor, tool o MCP que la declare.';

  @override
  String get formBoardDescription =>
      'La opción más rápida es pedírselo a un agente del proyecto: lee tu código o OpenAPI y lo construye. Usa esto para ajustarlo o escribirlo manualmente.';

  @override
  String get formWorkflowName => 'Nombre';

  @override
  String get formWorkflowCaseType => 'Tipo de caso';

  @override
  String get formRequiredRules => 'Reglas requeridas';

  @override
  String get formRequiredKnowledgeBases => 'Bases de conocimiento requeridas';

  @override
  String get formCommaSeparatedNames => 'Nombres separados por comas.';

  @override
  String get validationNameRequired => 'El nombre es obligatorio.';

  @override
  String validationMaxCharacters(Object count) {
    return 'Máximo $count caracteres.';
  }

  @override
  String get validationNoSpaces => 'No se permiten espacios.';

  @override
  String get validationLowercaseOnly => 'Usa solo minúsculas.';

  @override
  String get validationBoardKey =>
      'Usa minúsculas, números y \"_\", empezando por una letra (máx. 32).';

  @override
  String get assistantWelcomeTitle => 'Soy Keel AI';

  @override
  String get assistantWelcomeDescription =>
      'Puedo registrar cualquiera de estas opciones por ti en la conversación. Toca un ejemplo para probarlo.';

  @override
  String get assistantExampleProject =>
      'Crea un proyecto para revisar PR con dos agentes.';

  @override
  String get assistantExampleAgent =>
      'Registra un agente revisor de seguridad y asígnale la skill que acabas de crear.';

  @override
  String get assistantExampleWorkflow =>
      'Crea un workflow para bugs con implementación y una etapa de revisión.';

  @override
  String get assistantExampleSkill =>
      'Crea una skill con las reglas de estilo de este proyecto.';

  @override
  String get assistantExampleRule =>
      'Agrega una regla que prohíba comentarios obvios en el código.';

  @override
  String get labelEnabled => 'Activo';

  @override
  String get labelDisabled => 'Apagado';

  @override
  String get navAssistantTooltip => 'Asistente Keel AI';

  @override
  String get navRegisteredAgents => 'Agentes registrados';

  @override
  String get navTestBoards => 'Tableros de prueba';

  @override
  String get navMcpIntegrations => 'Integraciones MCP';

  @override
  String get navKnowledge => 'Conocimiento';

  @override
  String get navMachine => 'Máquina';

  @override
  String get navBackup => 'Respaldo';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get mapLaneBack => 'regresa';

  @override
  String get mapLaneForward => 'avanza';

  @override
  String get mapLaneDelegate => 'delega';

  @override
  String get mapViewQuery => 'Ver la consulta completa';

  @override
  String get mapZoomOut => 'Alejar  ⌘−';

  @override
  String get mapZoomIn => 'Acercar  ⌘+';

  @override
  String get mapFit => 'Mostrar todo en pantalla  ⌘0';

  @override
  String get mapFollow => 'Seguir el nodo que tiene el turno';

  @override
  String get mapHelp => 'arrastrar = mover · ⌘ + rueda = zoom';

  @override
  String get mapEmptyTitle =>
      'Este proyecto todavía no tiene nodos para mapear';

  @override
  String get mapEmptyDescription =>
      'Agrega miembros y un workflow. El mapa se abre con el elenco en su lugar, en reposo, antes de que corra algo.';

  @override
  String get chatCreateSession => 'Crea una sesión para empezar';

  @override
  String get chatAskForPlan => 'Pide un plan…';

  @override
  String chatSessionPrompt(Object project) {
    return 'Qué necesitas en esta sesión de #$project';
  }

  @override
  String chatMessagePrompt(Object project) {
    return 'Mensaje para #$project';
  }

  @override
  String get chatStop => 'Detener';

  @override
  String get chatQueue => 'Guardar en espera';

  @override
  String get chatSend => 'Enviar';

  @override
  String get chatSessionsCreatedByButton =>
      'Las sesiones se crean con el botón \"Nueva sesión\".';

  @override
  String get chatRunsPreflight =>
      'El preflight del workflow se ejecuta en esta sesión.';

  @override
  String get chatQueueHelp =>
      'Puedes guardar mensajes en espera, programarlos para el final del turno o interrumpir y enviarlos ahora.';

  @override
  String get chatWorkflowHelp =>
      'El workflow coordina el grafo. Escribe cuando quieras corregir el rumbo; queda registrado en el nodo activo.';

  @override
  String get chatReferencesHelp =>
      'Referencias: / directorios · @ agentes · \$ skills y reglas · # conocimiento';

  @override
  String get labelNoOpenSession => 'Sin sesión abierta';

  @override
  String labelSessionTitle(Object title) {
    return 'Sesión: $title';
  }

  @override
  String labelContextUsage(Object percent) {
    return 'contexto $percent%';
  }

  @override
  String assistantLegacyBlocked(Object names) {
    return 'No ejecuté el bloque automático: intentaba cambiar elementos bloqueados ($names). Usa las tools MCP con change_intent y change_reason para pedir permiso.';
  }

  @override
  String assistantSkillExists(Object name) {
    return 'La skill \"$name\" ya existía; la reutilicé.';
  }

  @override
  String assistantSkillCreated(Object name, Object suffix) {
    return 'Creé la skill \"$name\"$suffix.';
  }

  @override
  String assistantRuleExists(Object name) {
    return 'La regla \"$name\" ya existía; la reutilicé.';
  }

  @override
  String assistantRuleCreated(Object name) {
    return 'Creé la regla \"$name\".';
  }

  @override
  String assistantToolExists(Object name) {
    return 'La tool \"$name\" ya existía; la reutilicé.';
  }

  @override
  String assistantToolCreated(Object name, Object runtime) {
    return 'Creé la tool \"$name\" ($runtime).';
  }

  @override
  String assistantAgentCreated(Object details, Object handle) {
    return 'Registré a @$handle.$details';
  }

  @override
  String assistantAgentUpdated(Object details, Object handle) {
    return 'Actualicé a @$handle.$details';
  }

  @override
  String assistantWorkflowCreated(Object kind, Object name) {
    return 'Creé el workflow \"$name\" ($kind).';
  }

  @override
  String assistantProjectCreated(Object name) {
    return 'Creé el proyecto \"$name\".';
  }

  @override
  String updateAvailable(Object version) {
    return 'Nueva versión $version disponible. Haz clic para descargarla.';
  }

  @override
  String get readingInstalledVersion => 'Leyendo la versión instalada';

  @override
  String reviewVersion(Object version) {
    return 'Keel $version. Haz clic para revisar.';
  }

  @override
  String get faultsLabel => 'Fallas';

  @override
  String get faultsNone => 'No hay fallas sin revisar';

  @override
  String get faultsOne => '1 falla sin revisar';

  @override
  String faultsMany(Object count) {
    return '$count fallas sin revisar';
  }

  @override
  String get machineUpdateAvailable => 'Hay una versión nueva de Keel';

  @override
  String get machineStatus => 'Servicios, consumo y estado de la máquina';

  @override
  String get machineOneWork => 'Hay 1 trabajo en curso';

  @override
  String machineManyWork(Object count) {
    return 'Hay $count trabajos en curso';
  }

  @override
  String get backupBusy => 'Respaldando';

  @override
  String get backupLabel => 'Respaldo';

  @override
  String get backupSaving => 'Escribiendo el respaldo sin interrumpirte';

  @override
  String get backupReady => 'Respaldo al día y subido al remoto';

  @override
  String get mapLegend => 'Leyenda';

  @override
  String get fileTypeImages => 'Imágenes';

  @override
  String get chatFilterSystem => 'sistema';

  @override
  String get chatFilterSubagents => 'subagentes';

  @override
  String get chatFilterAll => 'todo';

  @override
  String chatStepLabel(Object title) {
    return 'paso: $title';
  }

  @override
  String get chatNoticeWarningTitle => 'Advertencia';

  @override
  String get chatNoticeFailureTitle => 'Falla';

  @override
  String get chatNoticeInfoTitle => 'Nota';

  @override
  String chatRetryStep(Object title) {
    return 'Reintentar «$title»';
  }

  @override
  String get buttonDeleteAgent => 'Eliminar agente';

  @override
  String deleteAgentConfirmation(Object name) {
    return 'Se eliminarán \"$name\" y su historial de chat.';
  }

  @override
  String get emptyProjectsHint =>
      'Todavía no hay proyectos. Crea uno para que varios agentes trabajen en el mismo repositorio.';

  @override
  String get emptyAgentsHint =>
      'No hay agentes abiertos. Usa un agente registrado para hablarle directamente, sin proyecto.';

  @override
  String get filesystemAccessTitle =>
      'Dar acceso a todo el sistema de archivos';

  @override
  String filesystemAccessBody(Object name) {
    return '\"$name\" podrá leer y escribir en cualquier carpeta del computador, no solo en tu carpeta de usuario.';
  }

  @override
  String get filesystemAccessGrant => 'Dar acceso';

  @override
  String get filesystemAccessEnabledTooltip =>
      'Tiene acceso a todo el sistema de archivos (haz clic para quitarlo)';

  @override
  String get filesystemAccessGrantTooltip =>
      'Dar acceso a todo el sistema de archivos';

  @override
  String get noOpenRequirements =>
      'No hay requisitos abiertos en ninguna dirección.';

  @override
  String get labelSubagents => 'subagentes';

  @override
  String get useAgentTitle => 'Usar un agente';

  @override
  String get filesystemAccessSubtitle =>
      'Esto se decide aquí, no al registrar el agente: el mismo agente puede tener permisos diferentes según dónde lo uses.';

  @override
  String get chatHintStreaming => 'Se enviará cuando termine el turno…';

  @override
  String get chatHintPlan => 'Pide un plan…';

  @override
  String get chatHintMessage => 'Escribe un mensaje…';

  @override
  String get noAgentsTitle => 'Todavía no hay agentes registrados';

  @override
  String get noAgentsDescription =>
      'Registra uno para tenerlo disponible en todas partes: para hablarle directamente, agregarlo a un proyecto y usarlo en pasos de workflow por rol.';

  @override
  String get sidebarSectionProjects => 'Proyectos';

  @override
  String get sidebarSectionSessions => 'Sesiones';

  @override
  String get sidebarSectionStatus => 'Estado';

  @override
  String get sidebarSectionLooseAgents => 'AGENTES SUELTOS';

  @override
  String get sidebarTooltipManageAgents => 'Registrar o editar agentes';

  @override
  String get sidebarTooltipUseAgent => 'Usar un agente registrado';

  @override
  String get sidebarTooltipManageProjects => 'Administrar proyectos';

  @override
  String get sidebarTooltipNewProject => 'Nuevo proyecto';

  @override
  String get sidebarHintProjectName => 'Nombre del proyecto';

  @override
  String get sidebarTooltipReadOnlyProject => 'No lo mantengo: solo lectura';

  @override
  String get sidebarTooltipOneSessionWorking => 'Una sesión trabajando';

  @override
  String sidebarTooltipSessionsWorking(int count) {
    return '$count sesiones trabajando';
  }

  @override
  String get sidebarSectionBoards => 'Tableros';

  @override
  String get sidebarNewBoard => 'Nuevo tablero';

  @override
  String get sidebarTooltipDeleteBoard => 'Eliminar tablero';

  @override
  String get sidebarSectionRequirements => 'REQUERIMIENTOS';

  @override
  String get sidebarTooltipAllRequirements => 'Todos los requerimientos';

  @override
  String get sidebarTooltipOpenRequirement => 'Abrir un requerimiento';

  @override
  String get sidebarRequirementsEmpty =>
      'Ninguno. Aparecen acá cuando un proyecto necesita algo de otro.';

  @override
  String get panelTitleInProgress => 'WORKFLOW EN CURSO';

  @override
  String get panelNoWorkflowSelected =>
      'Este proyecto no tiene un workflow seleccionado.';

  @override
  String panelProgressOf(int done, int active) {
    return '$done de $active';
  }

  @override
  String panelReviewCycles(int done, int max) {
    return 'auditorías $done/$max';
  }

  @override
  String get panelSectionSkills => 'Skills';

  @override
  String get panelSectionRules => 'Reglas';

  @override
  String get panelSectionKnowledge => 'Conocimiento y documentación';

  @override
  String get panelAddRule => 'Agregar regla';

  @override
  String get panelAddKnowledge => 'Agregar conocimiento';

  @override
  String get panelAddToProject => 'Agregar a este proyecto';

  @override
  String get panelRemoveFromProject => 'Quitar de este proyecto';

  @override
  String get panelRequiredByWorkflow => 'Requerido por el workflow';

  @override
  String get panelMissingBlocksPreflight => 'Faltante: bloquea el preflight';

  @override
  String get panelActivateOptional => 'Activar esta capacidad opcional';

  @override
  String get panelChangeDefaultRole => 'Modificar rol default del workflow';

  @override
  String get panelApproveAndContinue => 'Aprobar y continuar';

  @override
  String panelNoAgentForRole(Object role) {
    return 'sin agente para $role';
  }

  @override
  String panelConsultedTo(Object names) {
    return 'consultó a $names';
  }

  @override
  String panelCoverageMatrix(int resolved, int total) {
    return 'matriz $resolved/$total';
  }

  @override
  String get panelChangeSharedDefault => 'Modificar default compartido';

  @override
  String panelUseDefaultRole(Object role) {
    return 'Usar default ($role)';
  }

  @override
  String get panelStateDone => 'listo';

  @override
  String get panelStateCurrent => 'ahora';

  @override
  String get panelStatePending => 'pendiente';

  @override
  String get panelStateBlocked => 'bloqueado';

  @override
  String get panelStateAvailable => 'disponible';

  @override
  String get panelStateNotRequired => 'no requerido';

  @override
  String get panelExecutorNewSession => 'sesión nueva';

  @override
  String get panelExecutorResumeParent => 'reanuda sesión padre';

  @override
  String get panelExecutorSubagent => 'subagente / fallback externo';

  @override
  String get panelExecutorManualApproval => 'requiere aprobación manual';

  @override
  String get nodeKindTriage => 'Triage y contrato';

  @override
  String get nodeKindImpact => 'Impacto end-to-end';

  @override
  String get nodeKindImplementation => 'Implementación';

  @override
  String get nodeKindVerification => 'Verificación';

  @override
  String get mapNodeYou => 'vos';

  @override
  String get mapNodeEnd => 'fin';

  @override
  String get mapChipConsultation => 'consulta';

  @override
  String get mapChipSubagent => 'subagente';

  @override
  String get mapCountEnter => 'entrar';

  @override
  String get mapCalloutAsked => 'le pidió';

  @override
  String get mapCalloutReturned => 'devolvió';

  @override
  String get mapCalloutCut => 'cortó';

  @override
  String get mapCalloutAnswered => 'contestó';

  @override
  String get mapCalloutResolved => 'resolvió';

  @override
  String get mapCalloutThinking => 'pensando';

  @override
  String get mapLegendOpensSubagent => 'abre un subagente';

  @override
  String get mapLegendSubagentReturned => 'el subagente devolvió';

  @override
  String get subagentPhaseWorking => 'trabajando';

  @override
  String get turnPhaseWorking => 'trabajando…';

  @override
  String get mapLegendForward => 'avanza un paso';

  @override
  String get mapLegendBack => 'consulta a otro nodo';

  @override
  String get mapLegendAnswer => 'contesta esa consulta';

  @override
  String get mapLegendSpawn => 'lo registró';

  @override
  String get mapLegendFinish => 'entrega final';

  @override
  String get mapLegendFailed => 'cortó';

  @override
  String get mapLegendUntraveled => 'sin recorrer';

  @override
  String get subagentPhaseThinking => 'pensando';

  @override
  String get subagentPhaseWriting => 'escribiendo';

  @override
  String get subagentPhaseDone => 'terminó';

  @override
  String get subagentPhaseFailed => 'falló';

  @override
  String get turnPhaseThinking => 'pensando…';

  @override
  String get turnPhaseWriting => 'escribiendo…';

  @override
  String threadAdaptiveResolution(Object workflow) {
    return '$workflow · resolución adaptativa';
  }

  @override
  String get threadBackToOwner => 'vuelve al responsable';

  @override
  String threadNextNode(Object node) {
    return 'sigue $node';
  }

  @override
  String threadConsultOf(Object name) {
    return 'consulta de $name';
  }

  @override
  String panelAgentForNode(Object title) {
    return 'Agente para \"$title\"';
  }

  @override
  String panelOverrideScope(Object project) {
    return 'Este override solo afecta #$project. El nodo guardará el agente concreto cuando pase el preflight.';
  }

  @override
  String panelSharedChangeScope(Object workflow) {
    return 'Este cambio modifica el workflow \"$workflow\" en todos los proyectos. Los overrides concretos se conservan.';
  }

  @override
  String get subagentPhaseUnconfirmed => 'resultado sin confirmar';

  @override
  String get sessionAwaitingOutput => 'Esperando salida del proveedor…';

  @override
  String get sessionTurnOpen => 'Turno abierto';
}
