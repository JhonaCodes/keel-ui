# F36 — Saber qué Keel estás corriendo y descargar el nuevo

## Qué problema resuelve

Keel puede estar instalado desde un `.dmg` o ejecutarse desde su propio código
con `flutter run -d macos`. Son dos casos distintos y la UI no los mezcla:

- debajo de **Ajustes** siempre aparece la versión del bundle abierto;
- si `https://jhonacode.com/keel/latest.json` publica una posterior, esa misma
  versión se enciende con el icono de descarga y abre exclusivamente la URL
  declarada por el canal oficial;
- **Máquina** conserva el diagnóstico del checkout para quien desarrolla:
  commits remotos y código local todavía no reconstruido.

Si el manifiesto no responde, la versión instalada sigue visible y no aparece
un falso aviso. La consulta se hace al arrancar, sin bloquear la app, y respeta
el mismo TTL de seis horas que la revisión del repositorio.

Para una copia ejecutada desde el repo siguen siendo tres preguntas, y la
tercera es la que muerde:

| Pregunta | De dónde sale la respuesta |
|---|---|
| ¿Qué código tengo? | `git log -1` en el repo desde donde arrancó la app |
| ¿Hay algo nuevo? | `git fetch` + los commits que faltan |
| ¿Estoy corriendo lo que tengo? | la fecha del binario contra la del commit |

La tercera no se la hace nadie, y explica el «pero si ya lo arreglé». Traer
commits **no cambia lo que está corriendo**: el binario que tenés abierto es
el de la última vez que construiste. Esta pantalla lo dice en vez de dejarte
creer que ya te pasaste a la versión nueva.

## Encontrar el código

No hay una ruta que configurar. Se sube desde el ejecutable hasta encontrar
una carpeta que tenga el `pubspec.yaml` de Keel **y** un `.git`:

```
…/build/macos/Build/Products/Debug/Keel.app/Contents/MacOS/Keel
                                                     ↑ ocho carpetas para arriba
/repos/keel-ui        ← pubspec.yaml con `name: keel_ui` + .git
```

Las dos condiciones importan: el `build/` de un checkout ajeno podría tener
lo primero, y cualquier repo del mundo tiene lo segundo. Si copiaste el
`.app` a `/Aplicaciones` sin el código al lado, no se encuentra, y eso es
exactamente lo que la pantalla dice — en vez de inventar una ruta.

## La versión debajo de Ajustes

El riel muestra `vMAJOR.MINOR.PATCH` debajo del botón Ajustes. El tooltip
incluye el build. Cuando hay una release posterior, el texto toma el color
primario, aparece el icono de descarga y el clic abre el DMG publicado. Cuando
está al día, el clic fuerza una revisión manual.

La versión instalada se lee del bundle con `package_info_plus`; no está
duplicada como un string de UI. La comparación incluye semver y build.

## La sección de desarrollo en Máquina

Va arriba de todo en **Máquina**, con las otras tres preguntas de esa
pantalla: qué CLIs hay instalados, cuánto se gastó, cómo está el fierro.
Cosas de esta máquina, no del trabajo.

```
KEEL ─────────────────────────────────────────────────────────── main

  5189713   fix: el cuadro de una consulta mide lo que dice
  código de hace 2 h  ·  construido hace 5 h
  /repos/keel-ui

Hay 3 commits nuevos en `main`.
  a1b2c3d  feat: el diario de fallas
  …

                                    [Revisar]  [Traer 3 commits]
```

La línea de la fecha se pone en rojo cuando el binario es más viejo que el
commit: estás corriendo código que ya no es el que tenés en el disco.

## Qué lo impide

Los motivos son datos y no excepciones, igual que al unificar un worktree:
una operación que toca el repo desde donde corre la app se mira entera antes
de empezar.

- **No hay repo al lado** → no hay nada que traer.
- **Cambios sin commitear** → un `pull` con eso encima se niega, y con razón.
- **La rama no sigue a ninguna del remoto** → no hay con qué comparar.

Las sesiones corriendo **no** frenan el `pull`: el repo de Keel no es el repo
de tus proyectos. Frenan la reconstrucción, que cierra la app con los turnos
a medias.

## Un solo paso, y el resto en la Terminal

Actualizar hace exactamente una cosa: `git pull --ff-only`.

Construir necesita el `flutter` de **tu** PATH, y una app de macOS arranca
con uno mínimo —`/usr/bin:/bin:/usr/sbin:/sbin`— donde `git` está y `flutter`
no. Intentarlo igual sería un «no se encontró el comando» disfrazado de bug
de Keel.

Por eso «Reconstruir y reabrir» abre la Terminal, que sí levanta tu shell de
verdad:

```
cd '/repos/keel-ui' && flutter run -d macos
```

…y cierra Keel. Cerrar es parte del trabajo y no un efecto colateral: el
binario que estás corriendo es el que `flutter run` va a reemplazar, y dos
Keel sobre la misma base LMDB es justo el problema que la app evita en todos
lados. La salida es la ordenada —la misma que Cmd+Q— para que el respaldo de
cierre alcance a correr.

## Cuándo se revisa

Una vez al arrancar, callado y sin bloquear, y después cada seis horas como
mucho. Un proyecto que se mueve todos los días no publica commits cada media
hora, y cada revisión es un `git fetch` de verdad. El botón **Revisar**
ignora ese plazo, que es para lo que existe.

Cuando hay commits nuevos o un binario más viejo que el código se prende un
punto en **Máquina**. Cuando hay un DMG nuevo, se enciende la versión debajo de
**Ajustes**. Cada aviso vive donde también está su acción correcta.

## Dónde vive

| Qué | Dónde |
|---|---|
| Encontrar el repo | `integrations/app_update/src/keel_source.dart` |
| Versión y manifiesto instalable | `integrations/app_update/src/release_channel.dart` |
| Semver y validación del manifiesto | `integrations/app_update/release_version.dart` |
| Leer el estado y los commits | `integrations/app_update/src/update_probe.dart` |
| Qué lo impide | `integrations/app_update/src/update_plan.dart` |
| El pull y el relanzamiento | `integrations/app_update/src/update_run.dart` |
| La sección de la pantalla | `integrations/app_update/src/ui/keel_version_section.dart` |
| Compilar, firmar y producir el manifiesto | `scripts/build_macos_release.sh` |
