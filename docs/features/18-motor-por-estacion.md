# F18 — Motor de un miembro por estación

## Qué problema resuelve

Un agente se registra una vez y se reusa en todos lados: esa es la regla, y
es la correcta para su identidad —handle, rol, instrucciones, skills—. Pero
el modelo no es identidad, es costo. `@flutter-expert` haciendo el paso
GREEN de un fix chico y `@flutter-expert` rediseñando una pantalla son la
misma persona pensando distinto, y hasta ahora eran la misma configuración:
cambiarle el modelo en su ficha se lo cambiaba en las seis estaciones.

La consecuencia práctica era elegir mal en las dos direcciones — pagar Opus
en el mantenimiento o quedarse corto en el rediseño— y no tener dónde
mirarlo: el panel decía quién hacía cada paso, nunca con qué.

## El modelo

`Station.memberTuning`: un mapa `profileId → MemberTuning`, donde
`MemberTuning` lleva `provider`, `model` y `effort`, **cada uno anulable**.
Null significa "lo que diga el perfil", no un valor por defecto copiado — un
agente al que le suben el modelo en su ficha lo hereda en todas las
estaciones que no lo hayan fijado.

Un ajuste con los tres campos en null se borra en vez de guardarse: un
override vacío se vería marcado en la UI sin cambiar nada.

`station.tuned(member)` devuelve el perfil entero con el motor aplicado. El
turno lo resuelve **una sola vez**, al principio, y de ahí en más manda ese
—incluido el proveedor, porque cambiarlo cambia qué superficie tiene el
turno: un miembro pasado a codex pierde tools, MCPs y plan, igual que un
agente codex de nacimiento.

Cambiar de proveedor sin elegir modelo no arrastra el alias del anterior:
las dos CLIs no comparten un solo nombre de modelo, así que `sonnet` en
codex es un fallo de arranque, no una degradación. En ese caso cae al modelo
por defecto del proveedor nuevo.

## En la UI

Bajo el nombre del dueño de cada paso, en el panel de workflow: `Opus 5 ·
Alto`. Está a la vista y no detrás de un tooltip porque es la línea que
explica el costo — un paso en Opus vale varias veces uno en Sonnet, y eso no
se nota hasta que llega la factura.

Un punto del color de acento delante marca que es un ajuste de esta
estación; sin punto, es el motor de su ficha. Click abre el panel lateral
con proveedor, modelo y esfuerzo, cada uno con su opción "el del agente", y
una línea que dice cómo queda. Para codex el esfuerzo se deshabilita: lo
resuelve su propia config, así que ofrecerlo sería prometer algo que el
turno nunca manda.

El ajuste es del MIEMBRO en la estación, no del paso. Si `flutter-expert`
tiene tres pasos, los tres cambian juntos: el mismo agente pensando distinto
según el paso es una diferencia que nadie puede sostener en la cabeza.

El cambio entra en el turno siguiente. El que está corriendo termina con el
motor con el que arrancó — la CLI ya está invocada.

## Export

Los ajustes viajan en el archivo de la estación (`memberEngines`), por
handle y no por id, como todo lo demás del mirror. Un ajuste de un perfil
que ya no existe no se escribe, y al importar se aplica solo si el handle
existe de este lado: sin eso, un cambio de máquina perdía en silencio la
mitad de la decisión de costo.
