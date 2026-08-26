# F40 — Las mismas referencias, en todos los chats

## Qué problema resuelve

[F38](38-referencias-del-chat.md) le dio al chat de una sesión cuatro
prefijos para nombrar cosas sin que el agente adivine: `/` carpetas, `@`
agentes, `$` skills y reglas, `#` bases de saber.

Y se quedó ahí. El chat de Keel AI, el de un agente 1:1 y el hilo de un
requerimiento seguían siendo un campo de texto pelado. Justo Keel AI, que
existe para construir la configuración de la app, no podía nombrar la skill
que estaba por tocar.

Ahora los cuatro prefijos son de la app, no de un módulo.

## Lo único que cambia entre un lugar y otro

Qué universo se puede nombrar. Eso es el *scope*:

| Scope | `/` carpetas | `@` agentes |
|---|---|---|
| Sesión de proyecto | las del working directory del proyecto | los miembros del canal |
| Todo lo demás | los proyectos registrados y las raíces conocidas ([F41](41-raices-y-volumenes.md)) | todo el catálogo de perfiles |

Las skills, las reglas y el saber son catálogos globales: se leen igual desde
los dos lados.

Adentro de una sesión, `@handle` además **dirige el turno** a ese miembro.
Afuera no hay canal ni turnos que repartir: ahí `@` sirve para hablar *de* un
agente, y el enlace es texto legible.

## Por qué el enlace de una carpeta ahora dice de dónde cuelga

Con un solo proyecto alcanzaba con la ruta relativa: `keel://directory?path=lib`.
Sin proyecto hay diez raíces posibles y `lib/src` existe en todas, así que el
enlace lleva también su raíz. Los enlaces viejos —los de un mensaje que quedó
en la cola— siguen resolviendo: sin raíz declarada, se usa la única que el
scope tiene.

Una raíz declarada solo vale si sigue siendo una raíz del scope. Un enlace
fabricado a mano apuntando a `/etc` no resuelve nada.

## La ventana de Keel AI no tiene base de datos

Es un engine aparte, y a propósito no abre la base (`markUnavailable`): sus
catálogos están vacíos. No puede armar la lista de sugerencias.

Así que no la arma: se la pide al engine principal por el mismo bridge que ya
usa para mandar un mensaje (`assistant.referenceSuggestions`). Es la única
llamada de ese puerto que espera respuesta — todo lo demás es disparar y
esperar el próximo snapshot. Si el viaje falla, la lista queda vacía y el
compositor sigue siendo un campo de texto normal: nunca rompe el tipeo.

La **resolución** no viaja: el turno corre en el engine principal, que es
donde los `keel://` se convierten en contenido.

## Qué se guarda en un requerimiento

Texto legible, no enlaces. Un requerimiento cruza de proyecto y viaja en el
respaldo, donde las rutas de esta máquina se sacan a propósito: nombrar la
carpeta sirve, guardar su ruta absoluta no.

## Verificación

1. En el chat de Keel AI escribir `$`, `@`, `/` y `#`: cada uno abre su
   catálogo y filtra mientras se escribe.
2. Elegir una skill y enviar: el turno recibe su contenido, y en el hilo se
   sigue leyendo el nombre.
3. Lo mismo en el chat 1:1 y en el hilo de un requerimiento.
4. En una sesión de proyecto, nada cambió: `/` sigue mostrando solo carpetas
   de ese proyecto y `@` solo a sus miembros.
5. Un mensaje en cola escrito antes de este cambio se sigue enviando bien.
