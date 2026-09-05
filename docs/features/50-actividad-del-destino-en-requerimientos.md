# F50 — Un requerimiento dice qué está haciendo el proyecto destino

## Problema que resuelve

Quien abría un requerimiento hacia otro proyecto veía «tomado» y nada más. No
había forma de saber si del otro lado había un agente trabajando, uno
esperando al usuario, o nadie: la sesión que tomó el requerimiento
(`takenInSessionId`) existía en el modelo pero nunca se consultaba para
decirlo.

## Decisión

`requirementTargetActivity(Session?)`
(`modules/requirements/service/requirement_target_activity.dart`) resume en
una frase el estado de esa sesión: «trabajando (pensando | escribiendo |
trabajando | entre turnos)», «esperándote: hay una decisión pendiente» (F44),
«terminó su sesión», «su sesión falló o se detuvo», «sin turno vivo ahora».
Null cuando no hay sesión.

El header del hilo del requerimiento muestra «destino: …» en el color del
destino, debajo de la línea de origen → destino. Se deriva del estado vivo de
proyectos, así que cambia sola mientras el otro lado trabaja.

## Cómo verificarlo

- `test/requirements/requirement_thread_view_test.dart`: la frase por cada
  estado de sesión, y el header con una sesión destino corriendo dice
  «trabajando».
