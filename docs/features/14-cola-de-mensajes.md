# F14 — Escribir mientras el agente trabaja

## Qué es

El composer ya no se bloquea durante un turno. Podés escribir mientras el
agente responde, mandar, y ese mensaje sale como el turno siguiente — con
las imágenes que le hayas adjuntado (F13).

Antes el `TextField` se deshabilitaba con `enabled: !agent.isStreaming` y
`sendMessage` cortaba con un `return` mudo: se te ocurría la corrección
justo mientras el modelo trabajaba y no había dónde escribirla.

## Por qué es una COLA y no una inyección

Los dos CLIs son de un solo tiro por turno (`claude -p`, `codex exec`): no
hay un stdin abierto donde meter un mensaje a mitad de turno. Así que el
mensaje espera y sale después, en vez de perderse o de bloquear la entrada.

## Flujo

1. Agente streaming + enviar → `AgentsViewModel.sendMessage` ve
   `isStreaming` y encola un `QueuedMessage{text, imagePaths}` en
   `Agent.queuedMessages` (transitorio, como `isStreaming`: NO se
   serializa; una cola solo tiene sentido junto al turno en el que se
   escribió).
2. La cola se ve arriba del composer (`QueuedMessagesStrip`), con X por
   mensaje. Un mensaje que desaparece sin dejar rastro se lee como un
   mensaje perdido.
3. Al terminar el turno, todo lo encolado sale como **UN** turno: los
   textos se unen en orden con línea en blanco entre medio y las imágenes
   se concatenan. El modelo las lee juntas, que es lo que significa "te
   mandé una corrección mientras trabajabas".

## Stop es una excepción a propósito

Si frenaste el turno con Detener, la cola **no** se dispara sola: parar es
un "tomo el control", y arrancar un turno nuevo justo ahí sería lo
contrario de lo que pediste. Los mensajes quedan a la vista y la tira
ofrece **"Enviar ahora"** mientras el agente está libre.

Implementación: `sendMessage` marca `wasStopped` cuando el loop de eventos
corta por stop, y solo llama a `sendQueuedMessages` si terminó normal.

## Botones del composer

Durante un turno conviven dos intenciones, así que hay dos botones en vez
de uno que cambia de significado bajo el cursor: **Detener** (contorno) y
**enviar/encolar** (relleno, con icono de reloj). El hint del campo también
cambia: "Escribí y se envía cuando termine…".

## Puerto y ventana del asistente

`ChatActions` gana `sendQueuedMessages(agentId)` y
`removeQueuedMessage(agentId, index)`; el `BridgeChatActions` los manda
como `sendQueued` / `removeQueued`. `AssistantAgentSnapshot` lleva
`queuedMessages` en el wire para que la ventana dedicada muestre la misma
tira.

## Límite

Los proyectos no tienen cola: su composer es otro y sus turnos los maneja
`StationsViewModel`.
