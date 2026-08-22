# F19 — Enlaces clickeables y el PR de la tarea

## Qué problema resuelve

El último paso de un flujo termina abriendo un pull request, y lo dice en el
hilo: `https://github.com/org/repo/pull/312`. Esa línea era texto muerto —
había que seleccionarla, copiarla y pegarla en el navegador— y a los cuarenta
mensajes ni siquiera se encontraba.

## Enlaces

`GptMarkdown` solo hace clickeable lo que ya viene con sintaxis de enlace, y
las URLs que importan llegan peladas: `gh pr create` imprime la suya tal
cual. `linkifyBareUrls` las envuelve antes de renderizar.

Dos límites deliberados:

- **Adentro de un bloque de código no se toca nada.** Ahí una URL es parte de
  un comando o de una salida, no algo para ir a visitar.
- **Solo `http(s)`.** Quien escribe el enlace es un modelo; `file://` o un
  esquema de app abriría cosas que nadie pidió.

Se abren con `open`, el mismo camino que ya usaban los documentos de una base
de saber — es una app de escritorio para macOS y el binario está siempre, así
que una dependencia más no compraba nada.

## `PR #N` en el encabezado

Si algún mensaje de la tarea nombra un pull request de GitHub, el encabezado
muestra su número al lado del contexto y el costo. Un click y se abre.

Se lee de los mensajes, no de un campo propio de la tarea: el PR lo abre un
agente con `gh` en su turno y el hilo es donde queda dicho. Guardarlo aparte
sería un segundo lugar donde puede quedar viejo. Si una tarea abrió el PR y
después lo rehízo, gana el último que aparece — el vigente es el de más abajo
en el hilo.

## El contrato de ENTREGA

Hasta acá la app solo garantizaba el click; qué era "entregar" no estaba
escrito en ningún lado, y cada flujo lo inventaba — mergear, no abrir PR, o
abrir uno nuevo por ciclo. Ahora es una sección del system prompt de todo
turno de proyecto cuyo directorio de trabajo tiene git (`_deliveryPrompt`):

- El resultado se entrega como **pull request en DRAFT** — nunca mergeado ni
  marcado listo para review: eso lo decide el usuario.
- Primer ciclo que toca código: rama propia de la tarea, commits ahí,
  `gh pr create --draft`. Ciclos siguientes: la MISMA rama, el mismo PR.
- La URL completa va en una línea propia del hilo, fuera de bloques de
  código — eso la hace clickeable y alimenta el chip `PR #N`.
- "Cerrar el último ciclo sin la URL del PR en el hilo es cerrar sin
  entregar."

En un proyecto sin `.git` la sección no aparece y nada exige PR. Los turnos
de consulta tampoco la llevan: la entrega es del que trabaja.

## Lo que esto NO hace

La app no abre el PR ella misma. Eso sigue siendo trabajo de un agente: la
app no sabe la rama base, ni si el gate dio GO, ni si el repo tiene remoto.
Lo que la app garantiza es el contrato de arriba en el prompt, y que cuando
el agente deje la URL escrita, llegar ahí sea un click.
