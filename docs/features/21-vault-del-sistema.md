# F21 — El vault del sistema

## Qué problema resuelve

Todo el sistema vivía en un LMDB dentro de `Application Support`: skills,
reglas, tools, workflows, MCPs, agentes, proyectos, bases y ajustes.
Desinstalar la app se lo llevaba entero. Las dos piezas que había no
alcanzaban: `catalog_sync` (F9) empujaba el catálogo a un repo clonado
**dentro de la misma carpeta que la desinstalación borra**, y el respaldo en
un archivo (F20) pide destino con un diálogo cada vez, así que no hay un
lugar estable para versionar.

El vault es ese lugar estable: una carpeta tuya, que vos versionás con git.

## Qué es

`Configuración → Respaldo del sistema`. Elegís una carpeta —la sugerencia es
`~/keel-knowledge-bases`, donde ya viven las bases de saber locales, así un
solo repo lleva sistema y conocimiento— y una URL de remoto. Tres botones:

- **Subir a GitHub** escribe `keel-backup.zip` en el vault, hace `git init`
  si hacía falta, commitea y pushea. Es un solo paso a propósito: hubo un
  botón aparte que solo escribía el zip, y un respaldo que se queda en este
  disco no protege de perder este disco. Tenerlo al lado del que sí sube
  hacía que la mitad barata pareciera terminada.
- **Restaurar…** lee el zip, muestra qué trae y qué pisaría, y aplica lo que
  tildes.
- **Clonar vault…** es el camino de una máquina nueva: URL + carpeta vacía →
  clone → adopta el vault → preview → restaurar.

Keel AI lo maneja con `backup_system` (sin argumentos: escribe y sube) y
`restore_system`.

## Lo que pasa sin que aprietes nada

**Al primer arranque**, si el sistema está vacío de verdad —cero skills,
cero agentes, cero proyectos, sin contar el mapa de Keel AI que se
resiembra siempre— la app no muestra el sistema: muestra una pantalla que
pide la URL del vault y la carpeta destino, clona, restaura TODO y entra.
Un campo y un botón. Con el sistema poblado no aparece nunca, y restaurar
vuelve a ser el botón con preview: restaurar pisa por nombre, y eso solo se
hace sin preguntar cuando no hay nada que perder.

Si la carpeta que elegís ya tiene el `keel-backup.zip` porque clonaste el
repo a mano antes de abrir la app, no se clona nada: se adopta tal cual.

**Mientras trabajás no pasa nada.** Nada respalda solo: no hay timer ni
respaldo al cerrar la app. El único momento en que se escribe un respaldo es
cuando apretás el botón o cuando Keel AI llama `backup_system`.

Hubo un automático —cada 15 minutos y al cerrar la app, con commit local— y
se sacó. La razón está abajo, en "El zip es determinista": un zip no se
diffea, así que **cada commit mete el archivo entero de nuevo**. Con un
respaldo de 50 MB cada quince minutos, el `.git` del vault llegó a **25 GB**
sin que nada lo dijera. La contención de tamaño existe (un solo commit, ver
abajo), pero el volumen que generaba el automático la superaba igual: la
cura de fondo es no respaldar cuando nadie lo pidió.

Los commits creados por Keel pasan `--no-gpg-sign`. La app puede iniciarse
desde Finder con un `PATH` sin `gpg` y no tiene una terminal interactiva
segura para pedir el pinentry. El override afecta solo ese comando: no
modifica `commit.gpgSign` ni la firma de los commits que hace el usuario.

## Que esté guardado y que esté a salvo no son lo mismo

Sin decirlo, "guardado" y "guardado en un lugar que sobrevive a esta
máquina" se ven idénticos. Por eso el rail tiene una entrada **Respaldo**
con un punto rojo, y el panel un aviso escrito, que contestan el primer
peldaño que falla:

1. No elegiste carpeta de vault.
2. **La última operación falló.**
3. No hay ningún respaldo todavía.
4. El vault no es un repo git.
5. El repo no tiene remoto.
6. El respaldo commiteado no está subido.
7. **El último respaldo es de hace más de 3 días.**

Es una escalera y se contesta uno solo: avisarle "no lo subiste" a alguien
que ni siquiera configuró un remoto no lo ayuda a nada.

El peldaño 2 se agregó después de que pasara: un respaldo que revienta es
**invisible** sin él. El zip viejo sigue en el disco con su fecha, así que
`lastBackupAt` dice que hay respaldo, el repo está al día y los peldaños de
abajo pasan de largo. Al aviso va la PRIMERA línea del error —un error de
isolate son doscientas líneas de `<- _child in Instance of ...`— y el texto
entero queda en el panel.

El peldaño 7 es la red que reemplaza al automático. Sin él, ir a manual
significaba que un vault impecable con un zip de la semana pasada se veía
exactamente igual que uno al día, y el punto del riel se quedaba verde para
siempre: `lastBackupAt` sale del `mtime` y nunca se comparaba contra hoy.

## El zip es determinista, y de eso depende que git aguante

Un zip no se diffea: cada versión es un blob nuevo entero. La contención es
que el zip sea **función pura del estado**: entradas ordenadas
alfabéticamente, fecha fija (`1980-01-01`) en todas y **ningún sello de
tiempo adentro**. Respaldar dos veces sin haber cambiado nada da bytes
idénticos, `git commit` contesta "nothing to commit" y el repo no crece.

Cuando el estado SÍ cambió, la contención es otra y son dos piezas que
trabajan juntas (`vault_git.dart`):

- **Un solo commit, siempre.** Cada respaldo REEMPLAZA al anterior: si la
  punta ya es el commit raíz se amenda, y si hay historia acumulada se borra
  la rama para que el commit siguiente nazca sin padre. No hay historial de
  versiones del vault, a propósito: cada una pesaría el zip entero.
- **La poda, que es lo que achica de verdad.** Reescribir el commit deja el
  blob anterior *inalcanzable*, no borrado: el `git log` muestra uno solo y
  el `.git` crece igual. Por eso después de reescribir corre
  `reflog expire --expire=now --all` y, si hace falta, `gc --prune=now`.

El "si hace falta" es un techo **proporcional al respaldo** —dos veces el
tamaño del zip, con un piso de 1 MiB—, no un número fijo de MB. Un umbral
absoluto no puede servir a la vez a un vault de 5 MB (nunca podaría) y a uno
de 500 (podaría en cada clic, y el vault lleva las bases de saber en claro,
así que son miles de archivos). Lo vigila el test *"respaldar muchas veces
NO infla el .git"* de `test/system_vault/vault_git_test.dart`, que respalda
diez veces con bytes incompresibles distintos y falla si el `.git` supera
cuatro veces el archivo. Sin la poda, ese mismo test da diez veces.

Por eso la fecha del respaldo sale del `mtime` del archivo y del mensaje del
commit, nunca del manifest. Un `DateTime.now()` metido ahí adentro rompería
la propiedad entera: `test/system_vault/vault_archive_test.dart` lo vigila.

## Qué viaja

```
keel-backup.zip
├── manifest.json      versión + cuántos de cada cosa
├── settings.json      tamaño de texto, permisos, repos
├── secrets.json       [{name, description}] — SIN valores
├── catalog/<categoría>/<nombre>.json
└── knowledge/<base>/<ruta>   solo bases locales de FUERA del vault
```

Lo que NO viaja, a propósito: hilos de chat (`agent_`, `session_`, `msg_`),
adjuntos, registros de prompts, el token de la API de trabajos, las rutas de
trabajo de los proyectos, el tamaño de ventana, la carpeta del vault, los
espejos git re-clonables y el mapa compilado de Keel AI.

**Los valores de los secrets tampoco.** El vault se sube a un remoto, y lo
que entra en la historia de git no sale más: viajan solo los nombres y la
descripción, y al restaurar los secrets quedan **pendientes**, con la lista
de cuáles completar. Para mover los valores entre máquinas propias está el
respaldo en un archivo (F20), con su opt-in explícito.

Los **requerimientos internos** (F26) sí viajan, y son la excepción que
confirma la regla de arriba: no son ruido de una sesión, son una decisión
entre dos proyectos. Viajan por código, con los proyectos por nombre. Al
restaurar se **crean si faltan y no se pisan si están**: un requerimiento es
una conversación viva, y restaurarle encima la foto del respaldo borraría
todo lo que se dijo desde entonces.

La categoría `stations` de los respaldos viejos se sigue **leyendo** como
`projects` (F24). Escribir, se escribe siempre el nombre nuevo: así el
formato viejo se apaga solo en vez de quedar para siempre.

Un documento de más de 10 MB no entra al zip — un binario enorme en un repo
queda ahí para siempre. Lo que se saltea se **nombra** en el resultado: un
tope silencioso se leería como "guardé todo".

## Las bases de saber que viven en el vault

Regla de siempre: las rutas absolutas no viajan. La excepción acotada es la
ruta **relativa al vault**. Una base local que cuelga del vault viaja como
`vaultPath: "ux-ui-catalog"` y **sus documentos no se copian al zip** —ya
están en el repo, en claro y diffeables—; al restaurar se reengancha sola
contra el vault de esa máquina. Una base local de afuera sigue viajando con
sus documentos adentro del zip y llega sin carpeta, como antes. Una base git
no viaja: se recupera clonando.

Eso es lo que hace que en una máquina nueva `clonar → restaurar` no pregunte
nada sobre el conocimiento.

## Una sola forma, varios destinos

`catalog_shape` es ahora la librería que define **cómo** se serializa el
catálogo (`catalogAsJson`), cómo se vuelve a mergear (`mergeCatalogJson`),
qué secciones hay (`BackupSection`), qué pisaría un respaldo
(`backupPreviewOf`) y el guardado que espera a que los catálogos estén
cargados de verdad (`awaitCatalogsReady`). Vivía adentro de `catalog_sync`;
salió de ahí cuando esa integración se borró. El vault y el respaldo en un
archivo la consumen los dos: dos copias de "cómo se serializa un perfil"
divergiendo en silencio es exactamente lo que esta separación evita.

`catalog_sync` (F9) queda eliminada — el vault la reemplaza y hace de más.

## Verificación

1. `flutter test` — round-trip con acentos y binarios, determinismo byte a
   byte, errores nombrados para un zip ajeno / corrupto / que no es zip, el
   guardarraíl de `..` en las rutas, y la escalera del aviso.
2. Elegir el vault → **Respaldar** → `unzip -l` muestra las categorías, y
   una base que vive en el vault **no** aparece bajo `knowledge/`.
3. `unzip -p keel-backup.zip secrets.json` no contiene ningún valor.
4. **Respaldar** dos veces seguidas sin tocar nada → `git status` limpio.
5. Borrar una skill → **Restaurar…** → el preview la nombra → aplicar → vuelve.
6. Apartar el LMDB y arrancar: tiene que aparecer la bienvenida. Pegar la
   URL, traer todo, y el sistema vuelve con los secrets pendientes.
7. Con el vault ya commiteado y sin subir, el rail muestra el punto rojo y
   Configuración dice cuántos respaldos faltan subir. Después de
   **Respaldar y subir**, los dos desaparecen.
8. Cerrar la app con un cambio sin respaldar → reabrir → el zip lo incluye.

Nota: el commit usa la identidad Git configurada por el usuario, pero Keel
desactiva la firma GPG solo para sus respaldos automáticos.
