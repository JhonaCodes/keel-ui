# F14 — Escribir mientras los agentes trabajan

## Qué es

Los compositores del chat individual, Keel AI y las sesiones de proyecto no
se bloquean durante un turno. Podés escribir mientras los agentes responden y
guardar el mensaje —con sus imágenes de F13— sin interrumpir lo que estabas
redactando.

Antes el `TextField` se deshabilitaba con `enabled: !agent.isStreaming` y
`sendMessage` cortaba con un `return` mudo: se te ocurría la corrección
justo mientras el modelo trabajaba y no había dónde escribirla.

## Por qué es una COLA y no una inyección

Los dos CLIs son de un solo tiro por turno (`claude -p`, `codex exec`): no
hay un stdin abierto donde meter un mensaje a mitad de turno. Así que el
mensaje espera y sale después, en vez de perderse o de bloquear la entrada.

## Chat individual y Keel AI

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

## Sesiones de proyecto

La sesión tiene una cola persistida propia en `Session.queuedMessages`. Cada
`SessionQueuedMessage` tiene un ID estable, texto, adjuntos, fecha y una
decisión de entrega. No usa índices de lista para editar o eliminar porque la
cola puede avanzar al mismo tiempo que la UI cambia.

Mientras el workflow está ejecutándose, el compositor sigue habilitado y el
botón principal dice **Guardar en espera**. El mensaje queda visible arriba
del campo y ofrece cinco operaciones:

- **Editar** cambia el texto sin desprender sus imágenes.
- **Eliminar** quita el mensaje y descarta sus adjuntos almacenados.
- **Enviar ahora** solicita detener el turno vigente y entrega el mensaje
  solo cuando el proceso anterior realmente devolvió el control.
- **Enviar al terminar** deja finalizar el turno normalmente y despacha el
  mensaje a continuación.
- **Mantener en espera** cancela una programación anterior y devuelve el
  mensaje al control manual.

Los mensajes automáticos salen de a uno. El siguiente no empieza hasta que el
anterior terminó; nunca se abren dos escritores simultáneos sobre el mismo
workspace. Los mensajes en espera manual no se envían por el solo hecho de
detener una sesión.

Al cambiar de pantalla la cola sigue en la sesión. Al revivir la app, una
decisión que dependía de un proceso anterior se vuelve espera manual: el
proceso ya no existe y la app no finge que todavía puede "terminar".

## Stop es una excepción a propósito en el chat individual

Si frenaste el turno con Detener, la cola **no** se dispara sola: parar es
un "tomo el control", y arrancar un turno nuevo justo ahí sería lo
contrario de lo que pediste. Los mensajes quedan a la vista y la tira
ofrece **"Enviar ahora"** mientras el agente está libre.

Implementación: `sendMessage` marca `wasStopped` cuando el loop de eventos
corta por stop, y solo llama a `sendQueuedMessages` si terminó normal.

## Botones de los compositores

Durante un turno conviven dos intenciones, así que hay dos botones:
**Detener** (contorno) y **Guardar en espera** (relleno, con icono de reloj).
Guardar no supone que el usuario quiere interrumpir ni que quiere enviar
automáticamente; esa decisión se toma en la fila visible del mensaje.

## Puerto y ventana del asistente

`ChatActions` gana `sendQueuedMessages(agentId)` y
`removeQueuedMessage(agentId, index)`; el `BridgeChatActions` los manda
como `sendQueued` / `removeQueued`. `AssistantAgentSnapshot` lleva
`queuedMessages` en el wire para que la ventana dedicada muestre la misma
tira.

## Límite técnico

Los runners siguen siendo one-shot. “Enviar ahora” no inyecta texto en un
proceso abierto: lo cancela, espera su cierre y abre un turno nuevo. Esa espera
es parte de la garantía de un único escritor por sesión.
