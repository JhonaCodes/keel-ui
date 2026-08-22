# F1 — Ventana del asistente (Keel AI)

## Qué es

El chat con Keel AI vive en una VENTANA OS dedicada (reemplaza al panel
lateral, que se eliminó). Mientras conversás ahí, la app principal se
modifica en vivo: el MCP `keelai-actions` muta los ViewModels del engine
principal, y sus pantallas ya son reactivas a esos ViewModels.

## Arquitectura — cliente de presentación tonto

La ventana corre OTRO engine Flutter cuyos singletons están vacíos. No tiene
`AgentsViewModel`, no abre LocalDatabase, no arranca MCPs. Renderiza
snapshots que main le empuja y devuelve intenciones por method channel.

### Protocolo

- **sub→main** (canal existente `keel_ui/agent_bridge`, handler en main):
  métodos con prefijo `assistant.` — `attach`, `sendMessage`, `stop`,
  `deleteMessage` (timestamp en µs epoch), `setModel`, `setEffort`,
  `requestCompact`, `respondPermission`, `setFullFileSystemAccess`,
  `deleteAgent`, `newSession`, `selectSession`. Payload = un String JSON.
  Los métodos que cambian la sesión RETORNAN el estado nuevo.
- **main→sub**: el `WindowController` registrado (F0) + `invokeMethod` con
  `assistantState` (snapshot) y `assistantFocus`. La sub registra su handler
  con `WindowController.fromCurrentEngine()` ANTES de hacer `attach`.

### Estado wire

`AssistantWindowState{seq, activeAgentId, agent, sessions}` con
`AssistantAgentSnapshot` (modelo wire propio, NO `Agent.toJson` que es
persistencia): incluye transitorios (isStreaming, liveReasoning,
currentActivity, pendingPermission). **fileEdits se omiten** (única fuente
sin cota; keelai actúa por MCP, no por edits) y sobre ~1MB se recortan los
mensajes más viejos (solo en el wire; el hilo real queda intacto).

`seq` es monotónico y lo emite solo main; la sub descarta `seq <=` al último
aplicado — pushes y retornos RPC pueden competir sin corromper nada porque
todo snapshot es completo e idempotente.

### Piezas

- `assistant/service/assistant_window_bridge.dart` — lado MAIN (singleton
  plano, no RN: nada de este engine lo renderiza). Listener sobre
  `AgentsService` filtrado por sesiones keelai, comparación profunda para no
  pushear sin cambios, debounce 30ms, detach automático cuando el push no
  encuentra ventana.
- `assistant/viewmodel/assistant_window_viewmodel.dart` — lado SUB: réplica
  pasiva `ViewModel<AssistantWindowState>`; `connect()` con retry/backoff
  (hot-restart de main deja una ventana sin handler); aplica pushes y
  retornos con guard de seq.
- `agents/service/chat_actions.dart` — puerto `ChatActions` con
  `LocalChatActions` (default: singleton del engine; los callers existentes
  no cambian) y `assistant/service/bridge_chat_actions.dart` (RPC).
  `ChatView` y `ChatMessageBubble` ya no tocan el singleton directamente.
- `assistant/ui/screen/assistant_window.dart` — MaterialApp propio con
  `buildAppTheme()`, menú de sesiones + nueva conversación, y el MISMO
  `ChatView` con `actions: BridgeChatActions()`.
- `PermissionRequest` y `AgentToolActivity` ganaron toJson/fromJson (wire).

## El asistente NO aparece en las listas de agentes

Sus sesiones se filtran en las dos superficies que listan agentes: el rail
(por `keelAiProfileId`) y la sección "Agentes sueltos" del sidebar de
proyectos (por `AgentsViewModel.listableAgents`, que es la regla en un
solo lugar). Keel AI vive en su ventana flotante y en ningún otro lado —
mezclar sus sesiones con los agentes que registró el usuario es
exactamente la confusión que esa ventana existe para evitar.

Tampoco puede quedar seleccionado en el área de conversación:
`createAgentSilently` no toca `selectedAgentId`, así que una sesión keelai
nunca se convierte en el agente activo de la ventana principal.

## Flujos

- **Abrir**: ✨ del rail → `AssistantWindowBridge.instance.open()` (resuelve
  la sesión keelai en el tap handler — nunca en build), abre o enfoca la
  ventana única y empuja `assistantFocus`.
- **Permisos**: el banner viaja en el snapshot; `respondPermission` corre la
  lógica real en main (incluida la continuación automática).
- **Eliminar sesión**: main borra y resuelve/crea la siguiente — la ventana
  nunca queda mostrando un agente fantasma.

## Límites conocidos

- Los fileEdits no se renderizan en esta ventana (por diseño).
- Cerrar la app principal cierra el proceso entero (las sub-ventanas mueren
  con él).
- Una sola ventana de asistente a la vez (registro por businessId).

## La ventana abría en negro, y por qué

La primera vez que se abría en una corrida aparecía un rectángulo negro; la
segunda, no. La causa eran **dos `show()` compitiendo**.

Las sub-ventanas nacen ocultas para que las muestre `_showWhenPainted`
después del primer frame. Pero la ventana hacía además su propio
`windowManager.show()` desde `initState`, cuando todavía no existe ningún
frame. Y `waitUntilReadyToShow` redimensiona y centra **después** de mostrar,
así que el área nueva quedaba sin pintar.

La segunda vez no pasaba porque el proceso ya está caliente —snapshot,
fuentes, pipelines— y el primer raster llega antes que la carrera. De ahí que
cerrar y reabrir pareciera arreglarlo.

Ahora `initState` configura y nada más, y el único que muestra es
`_showWhenPainted`, que se lleva también el foco. Además las tres ventanas
declaran `backgroundColor`: cualquier hueco antes del primer raster es el
`FlutterView` vacío, que se ve negro, y con el fondo puesto es el color de la
app. El hueco de la ventana principal es inevitable —se muestra antes de
`runApp`—; lo que se puede elegir es de qué color.
