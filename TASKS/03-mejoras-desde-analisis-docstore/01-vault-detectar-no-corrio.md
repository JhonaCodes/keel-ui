---
estado: libre
titulo: El vault no distingue "no corrió" de "corrió y falló"
---

# El vault no distingue "no corrió" de "corrió y falló"

## Qué hay que hacer

Hoy `SystemVaultState.lastFailure`
(`lib/src/integrations/system_vault/src/system_vault_viewmodel.dart:31-39`) es la
ÚNICA señal de falla del respaldo automático, y solo se llena dentro de un `catch` de
una operación que **efectivamente corrió** y tiró excepción (`_failed()`/`_guarded()`,
líneas 588-622). El propio comentario del código ya nombra el problema: *"un respaldo
que revienta es INVISIBLE de otra forma... con el respaldo automático cada quince
minutos, eso son horas de fallar en silencio mientras la pantalla dice que todo está
bien."* Pero la solución implementada no cubre el caso que describe: si el
`Timer.periodic(15 min)` de `vault_auto_backup.dart:10-59` simplemente deja de
dispararse (la máquina durmió, algo bloqueó el isolate, etc.), no hay ninguna
excepción que atrapar, así que `lastFailure` queda vacío y la escalera completa de
`warning` (líneas 60-87: `configured` → `lastFailure.isNotEmpty` → `lastBackupAt ==
null` → `isRepo` → `hasRemote` → `unpushedCommits`) reporta todo verde — ninguno de
esos getters compara `lastBackupAt` (línea 19, viene del `mtime` del zip, nunca de
adentro del zip) contra `DateTime.now()`.

Verificado a mano (no solo por el agente que lo investigó, ver README de esta
carpeta): leí `system_vault_viewmodel.dart:1-95` y `jobs_api.dart:35-84` completos —
la cita del comentario y la escalera de `warning` son exactas.

**Escenario de falla concreto**: la máquina suspende varias horas, o `_backup()` falla
en un punto que no llega a `Log.severe`. `lastBackupAt` apunta a un zip de hace 6+
horas, `lastFailure` es vacío porque nada corrió para tirar la excepción — toda la
escalera de `warning` reporta sano. El panel de Fallas también queda vacío porque no
hubo ninguna excepción que capturar. Cero respaldos por horas, cero indicación de que
algo está mal.

**Por qué priorizar esta primero**: es la más barata de las tres (lee un campo que ya
existe, sin infraestructura nueva) y la que "The Working-Doc Spine" (§02, "The
Outage") nombra como el patrón más caro de dejar pasar — ahí la falla al menos quedó
registrada tres veces (log, contador, unidad systemd) aunque sin lector; acá, sin este
fix, ni siquiera queda un registro que encontrar después.

**Diseño recomendado** (documentarlo en el código, no asumirlo):
1. Comparar `lastBackupAt` contra `DateTime.now()` con un umbral (ej. 2× el intervalo
   de 15 min) **solo mientras la app está en foreground** — apoyándose en la señal que
   `AppLifecycleListener` ya provee en `vault_auto_backup.dart`, para no marcar como
   falla un cierre normal de la app.
2. Cuando ese umbral se cruza, loguearlo vía `Log.severe`/`Log.shout` para que entre
   al pipeline reactivo que YA existe (`installFaultCapture`,
   `fault_journal/src/fault_capture.dart:13-78`) y aparezca en el panel de Fallas —
   más barato que construir un productor nuevo de eventos de "ausencia".

**Riesgo**: bajo técnicamente — es lectura adicional de un timestamp que ya existe.
El riesgo real es de falsos positivos: si el umbral no distingue "la app estuvo
cerrada" (esperado) de "la app corrió y el timer no disparó" (falla real), genera
fatiga de alertas. No universalizar esto a `jobs_api`/knowledge sync/hooks en el mismo
cambio — esos son flujos manuales o externamente disparados por diseño explícito
(`jobs_api.dart:44-45`: *"the scheduling itself lives outside the app"*), y tratarlos
igual sería sobre-ingeniería fuera de lo que Keel controla.

## Bloqueantes

Ninguno.

## Criterio de aceptación

- [ ] `SystemVaultState` (o su ViewModel) compara `lastBackupAt` contra
      `DateTime.now()` con un umbral configurable, activo solo mientras la app está
      en foreground.
- [ ] Al cruzar el umbral, se loguea vía `Log.severe`/`Log.shout` y aparece en el
      panel de Fallas (`faults_panel.dart`) sin necesitar que nada más reviente.
- [ ] Un cierre normal de la app (o la app nunca abierta) NO dispara la alerta — test
      que cubra ese caso explícitamente.
- [ ] Test que fuerce el timer a no dispararse (mock del reloj o del propio timer) y
      confirme que `warning` deja de reportar sano.
- [ ] No se tocó `jobs_api`, knowledge sync, ni hooks en este cambio — quedan fuera de
      alcance a propósito.
