# Registro de agentes y continuidad del chat

## Plan de trabajo

1. Registrar delegaciones `Agent` y `Task` de Claude y `collab_tool_call` de
   Codex, conservar la identidad y la relación padre-hijo y evitar duplicados.
2. Preservar el orden de texto y herramientas. Mostrar subagentes por defecto
   en el chat y publicar el estado activo antes de preparar los servicios del
   turno. Un plan guardado es progreso, no una orden de pausar la ejecución.
3. Eliminar el contador de herramientas instalado automáticamente para Codex
   y no imponer un límite de seguimiento a capacidades ilimitadas.
4. Verificar con eventos de protocolo, modelos, mapa, pruebas de widgets,
   ejecutores simulados y `flutter analyze`.

## Evidencia inicial

- `ClaudeStreamReader` solo reconoce `Task` y mueve todo el texto al final
  del mensaje, después de las herramientas.
- `CodexStreamReader` descarta `collab_tool_call`.
- `ThreadFilter` oculta todos los subagentes por defecto.
- El estado activo se publica después de esperar la preparación de MCP y
  conocimiento. Durante esa preparación el chat no tiene indicador.
- Los seguimientos imponen cuatro turnos, incluso cuando la capacidad usa
  cero (ilimitado). Codex convierte turnos en un contador de herramientas.
- El ejecutor OpenAI compatible ya no tiene límite de rondas; conserva una
  prueba que ejecuta treinta rondas. El texto exacto de veinte usos no está
  en el código fuente actual.

Las capturas son evidencia del producto. El plan sobre otro proyecto que
aparece en ellas no forma parte de este trabajo.

## Resultado

Los cuatro puntos están implementados y verificados.

- Claude registra `Agent`, `Task`, apertura/progreso/notificación de tareas
  nativas y delegación anidada. La confirmación de arranque en segundo plano
  no cierra prematuramente al subagente. Los eventos duplicados no crean
  nodos adicionales.
- Codex registra `collab_tool_call` y cierra al hijo según `agents_states`,
  no según el cierre de la herramienta que lo abrió.
- La identidad del padre nativo se serializa y el mapa coloca los nietos
  debajo del subagente correcto, incluso al reconstruirlos fuera de orden.
- El chat muestra subagentes por defecto. Reutiliza los indicadores animados
  de actividad existentes y recibe las transiciones por ReactiveNotifier.
- Texto y herramientas conservan su orden; el estado vivo se publica antes
  de esperar la preparación del turno.
- Se corrigió un bloqueo adicional confirmado en el código anterior: al
  interrumpir una sesión marcada como activa sin una ejecución propietaria,
  ahora se limpia ese estado y se despacha el mensaje pendiente.
- La detección de una auditoría nativa consulta el estado actualizado después
  de ejecutarla; la instantánea anterior provocaba una segunda auditoría
  externa innecesaria.
- Los seguimientos heredan el límite declarado de la capacidad (cero sigue
  siendo ilimitado). Codex ya no recibe el hook automático que contaba
  herramientas. También se corrigió la descripción obsoleta de ese contador
  en las instrucciones internas de Keel AI.

## Validación

- Las cuatro pruebas iniciales de regresión fallaron antes de implementar.
- `TZ=UTC flutter test --no-pub test/map test/projects test/workflows test/llm test/hooks test/system_prompt --reporter expanded`: **299 pruebas aprobadas**.
- Tras ajustar el texto interno y un lint, lectores y prompts: **19 pruebas
  aprobadas**.
- Se verificó una cadena de **30 llamadas a herramientas**, cierre de tareas
  en segundo plano, persistencia y geometría del árbol, y cambios visuales
  de pensamiento → herramienta → resultado mediante ReactiveNotifier.
- Las dos pruebas de interrupción fallaban también con `HEAD`; después del
  arreglo pasan las siete pruebas de la cola.
- `flutter analyze --no-pub lib`: **89 diagnósticos previos, ninguno nuevo**,
  comparados por mensaje y archivo con `HEAD`. No hay errores de compilación.
- `flutter build macos --debug --no-pub`: **correcto**. Artefacto local:
  `build/macos/Build/Products/Debug/Keel.app`.
- `git diff --check`: correcto.

## Alcance y límites

La app que ya estaba abierta no fue reiniciada ni reemplazada. La versión
compilada contiene el cambio previo del usuario en `pubspec.yaml`
(`1.2.3+44`), que se conservó.

La observabilidad depende de eventos que emita el proveedor: no se inventan
subagentes a partir de prosa ni se reconstruyen llamadas antiguas que nunca
fueron registradas. La validación usa eventos de protocolo y procesos
simulados; no ejecuta una tarea facturada contra proveedores reales.

Persisten estilos previos fuera del comportamiento modificado, como el
formato inline de duración en
`lib/src/modules/projects/ui/widget/session_subagent_card.dart:36`.

Contrato consultado: [eventos oficiales de Codex](https://github.com/openai/codex/blob/main/codex-rs/exec/src/exec_events.rs)
y [referencia del Agent SDK de Claude](https://code.claude.com/docs/en/agent-sdk/typescript).
