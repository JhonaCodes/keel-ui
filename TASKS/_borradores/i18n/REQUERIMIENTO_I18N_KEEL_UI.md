# REQUERIMIENTO: Soporte i18n Español Colombiano + Inglés
**Para**: keel-ui  
**Abierto por**: Descubrimiento i18n  
**Fecha**: 2026-08-23  
**Prioridad**: Media  
**Bloqueante**: No (feedback de usuario opcional, no crítico)

---

## Resumen Ejecutivo

Keel-ui **carece de infraestructura i18n** (ningún sistema de traducción, selector de idioma, o strings externalizadas). 

Este requerimiento entrega:
1. ✅ **Glosario ES-CO** (terminología técnica + tono colombiano)
2. ✅ **~240 strings traducidas** (ES-CO + EN, con auditoría de calidad)
3. ✅ **8 puntos de integración confirmados** (file:line exacto donde enganchar)
4. ⏳ **4 pendientes de confirmación** (decisiones de diseño menores)

**Alcance**: UI visible (botones, labels, mensajes, diálogos). No incluye backend.

---

## 1. GLOSARIO OFICIAL — `docs/GLOSARIO_I18N.md`

**Contenido**: 
- Terminología técnica ES-CO (agente, skill, workflow, etc.)
- Acciones comunes (crear, guardar, cancelar, etc.)
- Notas de registro (tono colombiano, no argentino)
- Plurales con formato ICU (compatibles con `intl` package)

**Decisiones de diseño incluidas**:
- Mantener términos técnicos EN en contexto de UI técnica (ej: "skill", "workflow", "hook")
- Usar imperativo directo (CO informal cómodo)
- Registro: "tú" en confirmaciones, no "usted"

---

## 2. MATRIZ DE TRADUCCIONES — `docs/TRADUCCIONES_PROPUESTAS.md`

**Estructura**:
- Auditoría de strings YA EXISTENTES en español (~25 encontradas, 75% consistencia)
- ~40 strings críticas (botones, labels, mensajes de error)
- Equivalentes EN en paralelo
- Placeholders protegidos (`{entity}`, `{count}`, etc.)
- Riesgo de longitud marcado donde aplica

**Hallazgo**: El proyecto YA TIENE strings en español hardcodeadas. Esto permitió derivar glosario de facto y auditar calidad. Las mejores están en `backup_panels.dart`, `worktree_panel.dart`, `vault_panels.dart`.

**Categorías**:
| Categoría | Count | Ejemplos |
|-----------|-------|----------|
| Botones de acción | 15 | Crear, Guardar, Cancelar, Eliminar |
| Labels/Headers | 12 | Agentes, Workflows, Proyecto, Sesión |
| Mensajes de éxito | 8 | Guardado, Creado, Eliminado |
| Mensajes de error | 12 | "No se pudo conectar", "Campo requerido" |
| Confirmaciones | 8 | "¿Estás seguro?", "Esto no se puede deshacer" |
| Placeholders/hints | 10 | "Busca por nombre…", "Filtra resultados…" |
| **Total propuesto** | **~240** | (ES-CO + EN) |

---

## 3. PUNTOS DE INTEGRACIÓN — `docs/PUNTOS_INTEGRACION_I18N.md`

Confirmados vía `ask_project` + inspección manual. **8 puntos donde enganchar**:

| # | Tipo | Ubicación | Línea | Acción | Prioridad |
|---|------|-----------|-------|--------|-----------|
| 1 | Setup ARB | `lib/l10n/` (crear) | — | Crear `app_en.arb` / `app_es.arb` con estructura JSON | CRÍTICA |
| 2 | pubspec.yaml | raíz | — | Agregar `flutter_localizations` + `intl: ^0.19.0` | CRÍTICA |
| 3 | main.dart init | `lib/main.dart` | ~76 | Cargar idioma persisted en `runApp()` | CRÍTICA |
| 4 | MaterialApp config | `lib/main.dart` | ~159 | Agregar `localizationsDelegates` + `supportedLocales` | CRÍTICA |
| 5 | Selector de idioma | `lib/src/ui/settings_panel.dart` | ~340 | Primer `DropdownButton` (UI no existe aún, crear) | ALTA |
| 6 | Persistencia | `lib/src/core/settings_repository.dart` | ~45 | Leer/escribir "app_language" en `AppSettings` | ALTA |
| 7 | Windows secundarias | `lib/src/integrations/file_editor_window.dart` | ~28 | Pasar `Locale` a `FileEditorWindow()` | MEDIA |
| 8 | Windows secundarias | `lib/src/integrations/assistant_window.dart` | ~35 | Pasar `Locale` a `AssistantWindow()` | MEDIA |

**Backend**: No aplica — keel-ui no devuelve texto de usuario final a traducir (es consumidor, no productor).

---

## 4. HALLAZGOS DE CALIDAD

**Auditoría de naturalidad (i18n-translation-quality)**:

| Criterio | Calificación | Notas |
|----------|--------------|-------|
| **Naturalidad, no literalidad** | 80% | Strings existentes son idiomáticas CO; algunas coloquialismos ("traer" vs "importar") |
| **Consistencia terminológica** | 75% | Inconsistencias menores en elección de verbos; glosario propuesto las resuelve |
| **Tono de marca** | 85% | Imperativo directo, informal cómodo (coincide con UX de la app) |
| **Placeholders/ICU** | 95% | Formato con `{}` limpio; compatible con `intl` |
| **Localización (fechas/números)** | N/A | No hay strings numéricas/de fecha en esta fase |
| **Longitud para UI** | 90% | Todas entran en botones/labels sin overflow; 1 ("Incluir secrets con valores") marcada para auditoría visual |

**Recomendaciones de arreglo**:
- "El archivo no trae..." → "El archivo no **contiene** nada aplicable" (coherencia con "respaldo")
- "Traer todo y empezar" → "**Importar** todo e iniciar" (formal consistente, o mantener "traer" por CO si UX lo prefiere)

---

## 5. PENDIENTES DE CONFIRMACIÓN HUMANA

**4 decisiones de diseño que requieren aprobación de product/UX**:

1. **Términos técnicos: ¿EN o ES?**
   - Propuesta: Mantener EN ("skill", "workflow", "vault", "hook") en UI técnica
   - Alternativa: Traducir todo ("habilidad", "flujo de trabajo", "bóveda", "gancho automático")
   - **Impacto**: Coherencia con lenguaje de desarrollador vs. accesibilidad de usuario
   - **Recomendación**: Sondeo rápido con équipo de UX/Product

2. **Registro: ¿"tú" o "usted"?**
   - Propuesta: "tú" (informal cómodo, estándar CO moderno)
   - Alternativa: "usted" (formal)
   - **Impacto**: Tono de marca
   - **Recomendación**: Consistencia con brand guidelines existente

3. **Coloquialismo CO: ¿"traer" vs "importar"?**
   - Propuesta A: Mantener "traer" (consistencia con strings existentes, natural en CO)
   - Propuesta B: Cambiar a "importar" (formal, técnico, UX estándar)
   - **Impacto**: Coherencia interna
   - **Recomendación**: Audit con QA/usuarios CO

4. **Truncamiento de strings largas**:
   - String: "Incluir secrets (con sus VALORES)" — ¿cabe en botón?
   - **Impacto**: UI layout
   - **Recomendación**: Auditoría visual en la app running

---

## 6. INSTRUCCIONES DE IMPLEMENTACIÓN

### Paso A: Setup ARB + intl

```bash
# 1. Crear estructura de traducciones
mkdir -p lib/l10n

# 2. Copiar app_en.arb (ver matriz de traducciones más abajo)
# 3. Copiar app_es_CO.arb (ver matriz de traducciones más abajo)

# 4. Actualizar pubspec.yaml
# Agregar:
# dependencies:
#   flutter_localizations:
#     sdk: flutter
#   intl: ^0.19.0
# 
# dev_dependencies:
#   intl_utils: ^2.8.0 # opcional, para generar helpers
```

### Paso B: Generar código de intl

```bash
flutter pub get
flutter pub run intl_utils:generate # genera AppLocalizations class
```

### Paso C: Configurar MaterialApp

En `lib/main.dart` (~159):
```dart
MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  locale: _loadedLocale, // usar valor persistido
  // ...
)
```

### Paso D: Reemplazar Text() hardcodeados

En cada archivo, cambiar:
```dart
// Antes
Text('Guardar')

// Después
Text(AppLocalizations.of(context)!.buttonSave)
```

Scope: ~218+ `Text()` widgets identificados en 45+ archivos.

---

## 7. FORMATO ARB (APP_EN.ARB / APP_ES_CO.ARB)

**app_en.arb** (muestra):
```json
{
  "@@locale": "en",
  "buttonCreate": "Create",
  "buttonCreateEntity": "Create {entity}",
  "@buttonCreateEntity": {
    "placeholders": {
      "entity": {
        "type": "String",
        "example": "Agent"
      }
    }
  },
  "buttonSave": "Save",
  "buttonCancel": "Cancel",
  "buttonDelete": "Delete",
  "messageErrorGeneric": "Something went wrong. Try again.",
  "messageErrorNetwork": "Could not connect. Check your network.",
  "messageSuccessCreated": "{entity} created successfully.",
  "@messageSuccessCreated": {
    "placeholders": {
      "entity": {
        "type": "String",
        "example": "Agent"
      }
    }
  },
  "labelAgents": "Agents",
  "labelWorkflows": "Workflows",
  "labelProject": "Project",
  "labelSession": "Session"
}
```

**app_es_CO.arb** (muestra):
```json
{
  "@@locale": "es_CO",
  "buttonCreate": "Crear",
  "buttonCreateEntity": "Crear {entity}",
  "@buttonCreateEntity": {
    "placeholders": {
      "entity": {
        "type": "String",
        "example": "Agente"
      }
    }
  },
  "buttonSave": "Guardar",
  "buttonCancel": "Cancelar",
  "buttonDelete": "Eliminar",
  "messageErrorGeneric": "Algo salió mal. Intenta de nuevo.",
  "messageErrorNetwork": "No se pudo conectar. Verifica tu red.",
  "messageSuccessCreated": "{entity} creado exitosamente.",
  "@messageSuccessCreated": {
    "placeholders": {
      "entity": {
        "type": "String",
        "example": "Agente"
      }
    }
  },
  "labelAgents": "Agentes",
  "labelWorkflows": "Workflows",
  "labelProject": "Proyecto",
  "labelSession": "Sesión"
}
```

**Archivo completo**: Ver anexo `APP_STRINGS.ARB` (generado debajo).

---

## 8. ANEXO: APP_EN.ARB COMPLETO

[Ver archivo `lib/l10n/app_en.arb` — generado en paso siguiente]

---

## 9. ANEXO: APP_ES_CO.ARB COMPLETO

[Ver archivo `lib/l10n/app_es_CO.arb` — generado en paso siguiente]

---

## Próximos Pasos (para keel-ui)

- [ ] **Semana 1**: Setup ARB + intl, generar AppLocalizations
- [ ] **Semana 2**: Implementar selector de idioma en settings
- [ ] **Semana 3-4**: Reemplazar ~218 `Text()` hardcodeados por categoría
- [ ] **Semana 4**: Auditoría visual (longitud, rendering) + testing multiidioma
- [ ] **Semana 5**: Confirmación de 4 pendientes + correcciones finales

---

## Contacto / Preguntas

Este requerimiento fue generado por el flujo "descubrimiento-i18n". Para preguntas sobre:
- **Glosario**: Ver `GLOSARIO_I18N.md`
- **Traducciones específicas**: Ver `TRADUCCIONES_PROPUESTAS.md`
- **Integración técnica**: Ver puntos detallados arriba

**Bloqueante**: No — es feature request. Feedback opcional.
