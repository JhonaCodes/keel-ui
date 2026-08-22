# F21 — El vault del sistema

## Qué problema resuelve

Todo el sistema vivía en un LMDB dentro de `Application Support`: skills,
reglas, tools, workflows, MCPs, agentes, estaciones, bases y ajustes.
Desinstalar la app se lo llevaba entero. Las dos piezas que había no
alcanzaban: `catalog_sync` (F9) empujaba el catálogo a un repo clonado
**dentro de la misma carpeta que la desinstalación borra**, y el respaldo en
un archivo (F20) pide destino con un diálogo cada vez, así que no hay un
lugar estable para versionar.

El vault es ese lugar estable: una carpeta tuya, que vos versionás con git.

## Qué es

`Configuración → Respaldo del sistema`. Elegís una carpeta —la sugerencia es
`~/keel-knowledge-bases`, donde ya viven las bases de saber locales, así un
solo repo lleva sistema y conocimiento— y una URL de remoto. Cuatro botones:

- **Respaldar** escribe `keel-backup.zip` en el vault.
- **Respaldar y subir** además hace `git init` si hacía falta, commitea y
  pushea.
- **Restaurar…** lee el zip, muestra qué trae y qué pisaría, y aplica lo que
  tildes.
- **Clonar vault…** es el camino de una máquina nueva: URL + carpeta vacía →
  clone → adopta el vault → preview → restaurar.

Keel AI lo maneja con `backup_system` (con `push` opcional) y
`restore_system`.

## El zip es determinista, y de eso depende que git aguante

Un zip no se diffea: cada versión es un blob nuevo entero. La contención es
que el zip sea **función pura del estado**: entradas ordenadas
alfabéticamente, fecha fija (`1980-01-01`) en todas y **ningún sello de
tiempo adentro**. Respaldar dos veces sin haber cambiado nada da bytes
idénticos, `git commit` contesta "nothing to commit" y el repo no crece.

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

Lo que NO viaja, a propósito: hilos de chat (`agent_`, `task_`, `msg_`),
adjuntos, registros de prompts, el token de la API de trabajos, las rutas de
trabajo de las estaciones, el tamaño de ventana, la carpeta del vault, los
espejos git re-clonables y el mapa compilado de Keel AI.

**Los valores de los secrets tampoco.** El vault se sube a un remoto, y lo
que entra en la historia de git no sale más: viajan solo los nombres y la
descripción, y al restaurar los secrets quedan **pendientes**, con la lista
de cuáles completar. Para mover los valores entre máquinas propias está el
respaldo en un archivo (F20), con su opt-in explícito.

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

1. `flutter test test/system_vault/vault_archive_test.dart` — round-trip con
   acentos y binarios, determinismo byte a byte, y errores nombrados para un
   zip ajeno, uno corrupto y algo que ni siquiera es un zip.
2. Elegir el vault → **Respaldar** → `unzip -l` muestra las categorías, y
   una base que vive en el vault **no** aparece bajo `knowledge/`.
3. `unzip -p keel-backup.zip secrets.json` no contiene ningún valor.
4. **Respaldar** dos veces seguidas sin tocar nada → `git status` limpio.
5. Borrar una skill → **Restaurar…** → el preview la nombra → aplicar → vuelve.
6. Clonar el repo en otra carpeta con el LMDB apartado → **Clonar vault…** →
   restaurar → vuelve el sistema y los secrets figuran como pendientes.

Nota: el commit lo hace `git` con la configuración del usuario. Si tenés
firma GPG activada, el primer respaldo puede abrir el pinentry.
