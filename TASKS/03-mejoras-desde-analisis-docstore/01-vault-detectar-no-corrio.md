---
estado: libre
titulo: Un respaldo que no se hizo tiene que llegar al panel de Fallas
---

# Un respaldo que no se hizo tiene que llegar al panel de Fallas

## La premisa original cambió — leé esto antes que el resto

Esta tarea se escribió cuando el respaldo corría solo cada 15 minutos, y
apuntaba a detectar que el `Timer.periodic` de `vault_auto_backup.dart`
hubiera dejado de dispararse.

**Ese timer ya no existe.** El respaldo automático se eliminó porque cada
respaldo es un zip entero que no se diffea: commitearlo cada quince minutos
llevó el `.git` del vault a 25 GB. Hoy nada respalda solo — el respaldo pasa
cuando el usuario aprieta "Subir a GitHub" o cuando Keel AI llama
`backup_system`. El archivo `vault_auto_backup.dart` que cita el texto viejo
no está en el árbol.

Eso **agrava** el problema de fondo en vez de resolverlo: si antes el riesgo
era que el timer no disparara, ahora la ausencia de respaldo es el
comportamiento normal de un martes cualquiera.

## Qué ya se hizo

`SystemVaultState.warningAt(DateTime now)`
(`lib/src/integrations/system_vault/src/system_vault_viewmodel.dart`) suma un
peldaño al final de la escalera: si `lastBackupAt` tiene más de
`kVaultStaleDays` (3), el aviso lo dice y el punto del riel se pone rojo.
El "ahora" entra por parámetro justamente para que sea testeable; lo cubren
`un respaldo viejo se avisa, aunque esté subido` y `un respaldo de ayer
todavía no molesta` en `test/system_vault/vault_warning_test.dart`.

Eso cierra el primer criterio de aceptación de la versión vieja.

## Qué queda abierto

El aviso vive **solo** en la UI del vault: hay que abrir el panel o mirar el
punto del riel. No entra al panel de Fallas, así que no queda registro de que
el sistema estuvo días sin respaldar.

- [ ] Al cruzar `kVaultStaleDays`, loguearlo vía `Log.severe`/`Log.shout` para
      que entre al pipeline que YA existe (`installFaultCapture`,
      `fault_journal/src/fault_capture.dart:13-78`) y aparezca en
      `faults_panel.dart`. Es más barato que construir un productor nuevo de
      eventos de "ausencia".
- [ ] Que se emita UNA vez por cruce, no en cada `refreshStatus()`: el estado
      se relee al arrancar y después de cada operación, y repetir la misma
      falla cada vez es fatiga de alertas garantizada.
- [ ] Test de que un vault al día no emite nada.

## Fuera de alcance, a propósito

No universalizar esto a `jobs_api`, knowledge sync ni hooks: son flujos
manuales o disparados desde afuera por diseño explícito
(`jobs_api.dart:44-45`: *"the scheduling itself lives outside the app"*), y
tratarlos igual sería sobre-ingeniería.

## Bloqueantes

Ninguno.
