# Puntos de Integración I18N — Keel UI
**Dónde enganchar las traducciones y el selector de idioma**

---

## 1. SETUP: Crear estructura ARB

**Ubicación**: `lib/l10n/` (crear directorio)

**Archivos a copiar**:
- `lib/l10n/app_en.arb` — Traducciones EN (ya generado)
- `lib/l10n/app_es_CO.arb` — Traducciones ES-CO (ya generado)

**Verificación**:
```bash
ls -la lib/l10n/
# Debe mostrar:
# app_en.arb
# app_es_CO.arb
```

---

## 2. SETUP: Actualizar pubspec.yaml

**Ubicación**: Raíz del proyecto (`pubspec.yaml`)

**Cambios necesarios**:

```yaml
# En la sección "dependencies:", agregar:
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:      # ← AGREGAR
    sdk: flutter
  intl: ^0.19.0              # ← AGREGAR
  # ... resto de dependencias

# En "dev_dependencies:", intl_utils es OPCIONAL (para generar helpers automáticos):
dev_dependencies:
  flutter_test:
    sdk: flutter
  intl_utils: ^2.8.0         # ← OPCIONAL
```

**Comando post-actualización**:
```bash
flutter pub get
flutter pub run intl_utils:generate  # Si incluye intl_utils
# O manualmente: flutter pub run intl:generate_from_arb --output-dir=lib/generated ...
```

**Verificación**: Después de `flutter pub run intl_utils:generate`, debe existir:
- `lib/generated/l10n.dart` (AppLocalizations class)
- `lib/generated/intl_messages_en.arb`
- `lib/generated/intl_messages_es_CO.arb`

---

## 3. INTEGRACIÓN: Cargar idioma en main.dart (init)

**Ubicación**: `lib/main.dart`, función `void main()` o `Future<void> main()`

**Línea aproximada**: ~76 (antes de `runApp()`)

**Código a agregar**:

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'generated/l10n.dart';  // ← Generado por intl_utils

Locale? _loadedLocale;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cargar idioma persistido (si existe)
  _loadedLocale = await _loadPersistedLocale();
  
  runApp(const MyApp());
}

// Helper para leer idioma del almacenamiento
Future<Locale?> _loadPersistedLocale() async {
  // Lee de AppSettings/SettingsRepository (ver punto 6)
  // Retorna Locale('en') o Locale('es', 'CO') o null (default: device locale)
  // Implementación: usa SettingsRepository.instance.getLanguage()
}
```

**Nota**: Si `_loadPersistedLocale()` es async, `main()` debe ser `async`.

---

## 4. INTEGRACIÓN: Configurar MaterialApp

**Ubicación**: `lib/main.dart`, widget `MyApp` / `App`, builder del `MaterialApp`

**Línea aproximada**: ~159

**Código a reemplazar/agregar**:

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Localizaciones - agregar estos 3 campos:
      localizationsDelegates: const [
        AppLocalizations.delegate,                    // ← AGREGAR
        GlobalMaterialLocalizations.delegate,         // ← AGREGAR
        GlobalCupertinoLocalizations.delegate,        // ← AGREGAR
      ],
      supportedLocales: AppLocalizations.supportedLocales,  // ← AGREGAR
      locale: _loadedLocale,  // ← Usar valor persistido (ver punto 3)
      
      // Resto de configuración:
      title: 'Keel',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const MainScreen(),
    );
  }
}
```

**Nota**: `AppLocalizations.delegate` y `AppLocalizations.supportedLocales` son generados por `intl_utils` desde los archivos `.arb`.

---

## 5. INTEGRACIÓN: Selector de idioma en Settings

**Ubicación**: `lib/src/ui/settings_panel.dart`

**Línea aproximada**: ~340 (donde está o irá el panel de configuración)

**Situación actual**: No existe `DropdownButton` de idioma. Hay que crear uno.

**Código a agregar** (dentro de `SettingsPanelState` o donde corresponda):

```dart
import 'generated/l10n.dart';

class SettingsPanelState extends State<SettingsPanel> {
  late AppSettings _settings;
  
  @override
  void initState() {
    super.initState();
    _settings = SettingsRepository.instance.appSettings;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // ... otras settings ...
        
        // NUEVA SECCIÓN: Idioma
        ListTile(
          title: Text(AppLocalizations.of(context)!.settingLanguage),
          subtitle: Text(_settings.language ?? 'Device default'),
          trailing: DropdownButton<String>(
            value: _settings.language,
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(AppLocalizations.of(context)!.languageEnglish),
              ),
              DropdownMenuItem(
                value: 'es_CO',
                child: Text(AppLocalizations.of(context)!.languageSpanish),
              ),
            ],
            onChanged: (value) async {
              await SettingsRepository.instance.setLanguage(value);
              
              // Notificar a MaterialApp de cambio de idioma
              Locale newLocale = value == 'es_CO' 
                ? const Locale('es', 'CO')
                : const Locale('en');
              
              if (mounted) {
                // Método 1: Usar un notificador global de idioma
                LanguageProvider.of(context).changeLocale(newLocale);
              }
            },
          ),
        ),
        
        // ... resto del panel ...
      ],
    );
  }
}
```

**Nota**: El cambio de idioma en tiempo real requiere un `StateNotifier` o `ChangeNotifier` global que notifique al `MaterialApp`. Alternativa simple: usar un `Provider` o `Riverpod`.

---

## 6. INTEGRACIÓN: Persistencia (AppSettings / SettingsRepository)

**Ubicación**: `lib/src/core/settings_repository.dart` (o donde esté hoy)

**Línea aproximada**: ~45 (constructor o getter de appSettings)

**Cambios necesarios**:

Agregar field y métodos:

```dart
class AppSettings {
  // Campos existentes...
  
  String? language;  // ← AGREGAR: 'en' / 'es_CO' / null (device default)
  
  AppSettings({
    // ... parámetros existentes ...
    this.language,  // ← AGREGAR
  });
  
  // copyWith, fromJson, toJson si aplica
  AppSettings copyWith({
    // ... existentes ...
    String? language,  // ← AGREGAR
  }) {
    return AppSettings(
      // ... existentes ...
      language: language ?? this.language,  // ← AGREGAR
    );
  }
}

class SettingsRepository {
  static const _languageKey = 'app_language';
  
  // Getter para el idioma actual
  String? getLanguage() {
    return appSettings.language;
  }
  
  // Setter para cambiar idioma
  Future<void> setLanguage(String? languageCode) async {
    _appSettings = _appSettings.copyWith(language: languageCode);
    
    // Persistir en base de datos local
    if (languageCode == null) {
      await localDb.delete(_languageKey);
    } else {
      await localDb.put(_languageKey, languageCode);
    }
  }
}
```

**Verificación**: `getLanguage()` debe devolver:
- `null` → usar locale del dispositivo
- `'en'` → forzar inglés
- `'es_CO'` → forzar español colombiano

---

## 7. INTEGRACIÓN: Pasar Locale a Windows Secundarias

**Ubicación A**: `lib/src/integrations/file_editor_window.dart`

**Línea aproximada**: ~28 (constructor de FileEditorWindow)

**Cambio**:

```dart
class FileEditorWindow extends StatelessWidget {
  const FileEditorWindow({
    super.key,
    required this.filePath,
    required this.locale,  // ← AGREGAR parámetro
  });
  
  final String filePath;
  final Locale locale;    // ← AGREGAR field

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: locale,  // ← AGREGAR
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // ... resto del build
    );
  }
}
```

**Ubicación B**: `lib/src/integrations/assistant_window.dart`

**Línea aproximada**: ~35 (constructor de AssistantWindow)

**Cambio idéntico al anterior**.

**Cómo invocar** (desde main):

```dart
// Antes de crear la window:
Locale currentLocale = _loadedLocale ?? const Locale('en');

desktopMultiWindow.createWindow(
  FileEditorWindow(
    filePath: path,
    locale: currentLocale,  // ← Pasar locale
  ),
);
```

---

## 8. INTEGRACIÓN: Reemplazar Text() Hardcodeados

**Ubicación**: ~218 archivos con `Text()` widgets

**Patrón de cambio**:

**Antes**:
```dart
Text('Guardar')
Text('¿Estás seguro?')
Text('Agentes')
```

**Después**:
```dart
Text(AppLocalizations.of(context)!.buttonSave)
Text(AppLocalizations.of(context)!.confirmationDeleteMessage)
Text(AppLocalizations.of(context)!.labelAgents)
```

**Proceso sistemático**:
1. Listar archivos con `Text()` (ver comando más abajo)
2. Por cada archivo, reemplazar strings por keys de AppLocalizations
3. Asegurar que el widget está dentro de un `BuildContext` (casi siempre true)

**Comando para encontrar**:
```bash
grep -r "Text(['\"]" lib/src --include="*.dart" | wc -l
# Debería mostrar ~218+

# Listar por archivo:
grep -r "Text(['\"]" lib/src --include="*.dart" -h | cut -d: -f1 | sort | uniq -c | sort -rn
```

**Prioridad de reemplazo**:
1. **CRÍTICA**: Botones, labels, títulos (~50 strings)
2. **ALTA**: Mensajes de error, confirmaciones (~30 strings)
3. **MEDIA**: Hints, placeholders (~20 strings)
4. **BAJA**: Tooltips, debug text (~118+ strings)

---

## Checklist de Integración

- [ ] Crear `lib/l10n/` con `app_en.arb` y `app_es_CO.arb`
- [ ] Actualizar `pubspec.yaml`: agregar `flutter_localizations` + `intl`
- [ ] Correr `flutter pub run intl_utils:generate`
- [ ] Actualizar `main.dart`: cargar idioma + configurar MaterialApp
- [ ] Crear selector de idioma en `settings_panel.dart`
- [ ] Agregar métodos de persistencia a `SettingsRepository`
- [ ] Pasar `locale` a windows secundarias
- [ ] Reemplazar ~218 `Text()` hardcodeados (por prioridad)
- [ ] Testing: cambiar idioma en settings → verificar UI en ambos idiomas
- [ ] Testing: reiniciar app → verifica que persista el idioma elegido

---

## Notas Finales

- **AppLocalizations class**: Generada automáticamente por `intl_utils`. No editar manualmente.
- **Nuevas strings**: Si se agregan strings futuras, agregar a `app_en.arb` y `app_es_CO.arb`, luego correr `flutter pub run intl_utils:generate` de nuevo.
- **Plurales ICU**: Ya incluidos en los archivos ARB (ej: `countAgent`, `countFound`). Dart los maneja automáticamente.
- **Device locale**: Si language = null, Flutter usa el idioma del dispositivo automáticamente (si está en supportedLocales).
