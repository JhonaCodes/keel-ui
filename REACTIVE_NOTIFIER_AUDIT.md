# Auditoría `reactive_notifier` — keel-ui

Revisión realizada por @notifier-expert sobre los 27 archivos de `lib/` que usan `reactive_notifier` (7 ViewModels: `agent_profiles`, `agents`, `rules`, `settings`, `skills`, `stations`, `workflows`, y toda su capa `ui/`), evaluada contra el estándar de 4 puntos del proyecto:

1. Lógica de negocio en el ViewModel, no en el widget.
2. Comunicación entre ViewModels vía el mecanismo de dependencias de la librería.
3. Capa de servicio como singleton de app (`mixin XService { static final instance = ReactiveNotifier<X>(X.new); }`).
4. Documentación del ciclo de vida de esa capa de servicio.

## Versión de la librería

**Última versión estable: `reactive_notifier: 2.18.1`** (pub.dev, publisher verificado jhonacode.com). Es la que el proyecto debe usar.

`keel-ui` ya está al día — `pubspec.yaml:37` y `pubspec.lock:522` fijan `2.18.1`, no hay nada que actualizar.

> Nota aparte: el doc canónico interno (`nui-app/docs/libraries/reactive_notifier.md`) está escrito para `2.17.0`, una minor detrás. No se detectaron cambios rotos entre `2.17.0` y `2.18.1`, pero conviene revalidar ese doc contra `2.18.1` cuando se audite `nui-app`.

**Veredicto general: base sólida, con dos gaps concretos y corregibles** — no hay que rehacer nada, hay que mover código de sitio.

## Bien hecho

- Cero `ReactiveNotifier` instanciado fuera de un `mixin ...Service`; cero `addListener`/`listenVM` manual; cero `loadNotifier()` desde un widget.
- Patrón `ReactiveViewModelBuilder<X, XState>` correctamente tipado y consistente en toda la capa `ui/`.
- Suscripción deliberadamente estrecha para evitar over-rebuild, documentada con comentarios que explican el motivo (`station_message_bubble.dart:43-47`, `chat_message_bubble.dart:28-36`).
- Dos comentarios ejemplares que documentan por qué se suscribe en vez de leer off-singleton — usar como plantilla de estilo:
  - `lib/src/modules/stations/ui/view/station_chat_view.dart:39-43`
  - `lib/src/modules/stations/ui/view/stations_sidebar.dart:36-37`
- Separación correcta entre la ventana secundaria (`file_editor_window.dart`) y el VM principal, vía `WindowMethodChannel` en vez de tocar `AgentsService.instance` cross-isolate (`lib/src/core/services/agent_bridge_channel.dart:1-8`).
- Los 7 servicios siguen el patrón singleton de app sin excepción, y ninguno necesita `autoDispose` (son catálogos globales, no estado por pantalla).

## Dónde mejorar

### 1. Combinación de VMs hecha en el widget en vez del ViewModel (viola el punto 2)

- `lib/src/modules/stations/ui/view/station_chat_view.dart:46-64` — anida `ReactiveViewModelBuilder<AgentProfilesViewModel>` dentro de `ReactiveViewModelBuilder<WorkflowsViewModel>` y combina ambos estados con `StationsService.instance.notifier.membersOf()/.activeWorkflowOf()` dentro del `build`.
- `lib/src/modules/agents/ui/screen/agents_screen.dart:46-93` — anida `ReactiveViewModelBuilder<AgentsViewModel>` dentro de `ReactiveViewModelBuilder<StationsViewModel>` para decidir qué conversación mostrar.

**Mejora:** mover esta combinación a `onDependenciesStateChanged` en el VM dueño (`StationsViewModel`), exponiendo el resultado ya combinado en su propio state. Es el punto de mayor prioridad.

### 2. Comunicación cross-VM resuelta con lectura directa en vez de `DependencyState.on<T>`

`onDependenciesStateChanged`/`DependencyState.on<T>` no se usa en ningún archivo del proyecto. `StationsViewModel` y `AgentsViewModel` leen otros servicios al vuelo, sin garantía de orden de inicialización:

- `stations_viewmodel.dart:311,316,226,237,535,723`
- `agents_viewmodel.dart:115,235,355,362-363`

**Mejora:** reemplazar por `DependencyState.on<T>` declarado en el VM.

### 3. Lógica de dominio filtrada a la capa `ui/` (viola el punto 1)

- `lib/src/modules/agent_profiles/ui/widget/role_field.dart:74-90` — `_rolesWantedBy` agrupa pasos de workflows por rol; es agregación de dominio.
- `lib/src/modules/stations/ui/widget/workflow_progress_panel.dart:32-38,79-93,95-102` — interpreta metadata de mensajes para derivar estado de cada paso.
- `lib/src/modules/stations/ui/widget/workflow_progress_panel.dart:43-45` y `lib/src/modules/stations/ui/screen/station_form_screen.dart:52,108` — leen `Service.instance.notifier.data` **fuera de un builder** para traducir id↔nombre de workflow/reglas.
- `lib/src/modules/stations/ui/view/station_chat_view.dart:186-189` y `station_map_view.dart:50-56` — invocan en cada `build` transformaciones de dominio no triviales (`buildThreadEntries`, `TaskGraph.fromMessages`) sin memoización.

**Mejora:** mover esta lógica al ViewModel correspondiente.

### 4. Servicios sin documentar (viola el punto 4)

Ninguno de los 7 `mixin ...Service` documenta cuándo se inicializa (lazy, primer acceso) ni por qué no se destruye (singleton de toda la vida de la app):

- `agent_profiles_viewmodel.dart:116`, `agents_viewmodel.dart:527`, `rules_viewmodel.dart:88`, `settings_viewmodel.dart:46`, `skills_viewmodel.dart:88`, `stations_viewmodel.dart:1139`, `workflows_viewmodel.dart:100`

**Mejora:** agregar comentario de ciclo de vida en cada uno, con el estilo ya usado en `station_chat_view.dart:39-43`.

### 5. `stations_viewmodel.dart` — 1140 líneas

Mezcla persistencia, orquestación de turnos de CLI, resolución de @mentions y lectura cruzada de 4 servicios. Es consecuencia directa de los puntos 2 y 3: resolverlos primero probablemente reduce el archivo por sí solo antes de considerar dividirlo.

## Prioridad sugerida

1. `station_chat_view.dart:46-64` y `agents_screen.dart:46-93` → mover combinación de VMs a `onDependenciesStateChanged`.
2. Reemplazar lecturas pull en `stations_viewmodel.dart` / `agents_viewmodel.dart` por `DependencyState.on<T>`.
3. Sacar traducción id↔nombre (`station_form_screen.dart`) e interpretación (`workflow_progress_panel.dart`) hacia el VM.
4. Documentar los 7 `mixin ...Service`.
5. Revisar el tamaño de `stations_viewmodel.dart` una vez resueltos 1-3.

---
*Auditoría realizada por @notifier-expert, canal nuimarkets, 2026-08-21.*
