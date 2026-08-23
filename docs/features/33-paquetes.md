# F33 — Paquetes: llevarse un agente entero a otra máquina

## Qué problema resuelve

Un agente que anda bien no es un prompt. Es un prompt **más** tres skills,
dos reglas, una tool, un hook que la corre, un servidor MCP y una base de
saber. Mandárselo a alguien era mandarle el prompt y que el otro descubriera
de a poco todo lo que le faltaba.

Los dos respaldos que ya había no sirven para eso, y no es un olvido:

| | Qué lleva | Para quién |
|---|---|---|
| [F21](21-vault-del-sistema.md) `system_vault` | TODO el sistema, versionado en git | vos, en otra máquina |
| [F20](20-respaldo-en-un-archivo.md) `catalog_backup` | lo que elijas, en un JSON | vos, a mano |
| **F33** `catalog_bundle` | **UNA cosa y sus dependencias** | **otra persona** |

Esa última columna es la que manda en cada decisión de acá.

## Qué viaja

Un **cierre**: la raíz y todo lo que necesita para funcionar igual del otro
lado. La función que lo calcula es pura y no toca nada de la app, porque es
lo único que decide qué sale de tu máquina.

| Empaquetás | Se lleva |
|---|---|
| **skill** | la skill, y nada más — es texto |
| **agente** | su perfil + skills + reglas + tools + hooks + MCPs + bases de saber, con los documentos |
| **workflow** | el workflow + **todos** los agentes que hoy podrían ocupar cada puesto, cada uno con lo suyo |

Dos cierres que parecen de más y no lo son:

- **La tool que corre un hook.** El perfil no la nombra; el hook sí, como
  cuerpo. Sin ella el guardarraíl no salta, y un guardarraíl que no salta
  falla en silencio.
- **Los agentes de un workflow.** Un workflow no nombra agentes: nombra
  **puestos**, y el proyecto pone quién los ocupa. Sin los candidatos, del
  otro lado queda pidiendo roles que ahí no existen.

Lo que el paquete nombra pero de este lado ya no existe **se dice** antes de
exportar. No es un error —borraste una skill que un perfil todavía menciona—
pero del otro lado va a faltar igual, y en silencio sería peor.

## Lo que NUNCA viaja

**El valor de un secret.** Ni cuando el que exporta querría mandarlo. Viajan
los nombres, sacados de las tools (que los reciben como variables de entorno)
y de los servidores MCP (`secretEnv` y los `{{PLACEHOLDER}}` de sus headers),
y el manifiesto los declara para que del otro lado se sepa qué hay que crear.

Tampoco viajan los directorios de trabajo, las sesiones ni los hilos: eso ya
lo garantiza la forma portable del catálogo, que es la misma que usan los
otros dos respaldos ([`catalog_shape`](../../lib/src/integrations/catalog_shape/)).

## El zip

```
manifest.json            keelBundle, kind, name, summary, requiredSecrets, counts
README.md                para el que lo abre con el Finder antes de instalarlo
catalog/<categoría>/<nombre>.json
knowledge/<base>/<ruta>
```

El manifiesto está pensado para que **un catálogo público pueda listar un
paquete sin abrirlo ni confiar en su contenido**: nombre, tipo, resumen,
cuántas cosas trae y qué secrets pide, todo en la tapa.

Los bytes son **deterministas** —entradas ordenadas, fecha fija— así que el
mismo paquete da siempre el mismo archivo. Eso permite compararlo por hash, y
mientras tanto evita que exportar dos veces dé dos archivos distintos sin que
nada haya cambiado.

## La revisión, que es el punto

Lo que entra va a correr en tu máquina y lo escribió alguien que no sos vos.
Antes de instalar nada, el paquete se abre y se revisa entero.

| Qué se busca | Dónde | Ejemplo |
|---|---|---|
| comandos peligrosos | tools, hooks, MCPs **y textos** | `curl … \| sh`, `sudo`, `/dev/tcp/`, `~/.ssh`, `launchctl` |
| rutas personales | todo | `/Users/otro/…`, `C:\Users\…` |
| inyección de prompt | prompts, skills, reglas, pasos, documentos | «ignorá las instrucciones», «no le digas al usuario» |
| texto que no se ve | todo | caracteres de ancho cero, anuladores de dirección, comentarios de HTML |
| salidas a internet | tools, hooks, MCPs, textos | cualquier host que no sea local |
| poder sobre tu keel | perfiles | `canManageSystem` |

Tres decisiones que dan forma a esto:

1. **Los patrones de comandos corren también sobre los textos.** Una skill
   que le dice al agente «para empezar corré `curl x | sh`» termina en el
   mismo lugar que un script, solo que pasando por un modelo servicial.
2. **Un hook pesa más que una tool.** Una tool la llama el agente cuando
   decide; un hook lo dispara el CLI solo, en cada turno que encaje con su
   evento. Por eso todo hook es hallazgo grave por el solo hecho de existir.
3. **Cada hallazgo muestra el fragmento exacto.** Una alerta sin el texto que
   la disparó obliga a creerle a la app, y creer sin poder mirar es
   justamente lo que este feature viene a evitar.

**Un paquete «limpio» no es un paquete seguro**, y la pantalla lo dice con
esas palabras: un buscador de patrones encuentra lo conocido. Lo que la
revisión sí garantiza es que nada se instala sin que se haya listado antes
qué corre, qué lee y a dónde escribe.

Con un hallazgo de gravedad alta, **Instalar arranca apagado** hasta que
tildes que lo leíste. No es una traba: es el segundo que hace falta para
mirar lo de arriba, que es todo el motivo de haberlo listado. Descartar el
paquete borra el tilde — lo que leíste era el anterior.

## Exportar también se revisa

La misma revisión corre sobre **tu propio** paquete antes de escribirlo. Es
la única oportunidad de enterarte de que tu tool lleva tu carpeta personal
adentro **antes** de mandársela a alguien; después ya viajó.

Por eso exportar son dos pasos y no uno: se prepara y se muestra, y recién
después se elige dónde guardarlo.

## Desde un enlace

El panel también trae un paquete de una URL. Es el camino que un catálogo
público usaría, y lo que baja pasa por la **misma** revisión que un archivo
elegido a mano: el origen no cambia lo que hay adentro.

Del lado de la importación hay tres cortes antes de mirar nada:

- solo `http` y `https`, con timeout;
- **64 MB** de tope, contando lo que se descomprime — un zip que se expande a
  gigabytes es la forma más barata de tumbar la app de otro;
- una entrada cuya ruta se sale de su carpeta (`zip slip`) corta la apertura
  entera. Ningún paquete legítimo la necesita.

## Instalar es el mismo merge de siempre

Un paquete se aplica con `mergeCatalogJson`, exactamente igual que restaurar
un respaldo: crea o actualiza **por nombre**. No hay un segundo camino de
entrada al catálogo que mantener sincronizado con el primero.

Los documentos de saber se escriben en la carpeta que la base tenga de este
lado. Una base recién creada llega **sin carpeta** —las rutas nunca viajan—,
así que sus documentos esperan, y la pantalla dice cuáles y qué hacer.

## Dónde vive

| Qué | Dónde |
|---|---|
| La tapa y el contenido | `integrations/catalog_bundle/src/bundle_manifest.dart` |
| Qué viaja, puro | `src/bundle_closure.dart` |
| El zip | `src/bundle_archive.dart` |
| La revisión, pura | `src/bundle_audit.dart` |
| El encargo que cruza a otro isolate | `src/bundle_job.dart` |
| Exportar e importar | `src/bundle_viewmodel.dart` |
| Los dos paneles | `src/ui/` |

Armar el zip y revisarlo corren **en otro isolate**, como el respaldo
([F27](27-arranque-y-espera.md)): leer carpetas, comprimir con la mejor
compresión y pasarle veinte expresiones regulares a cada texto no es trabajo
de entre dos cuadros.

## Verificación

1. Exportar un agente con hook, tool y base → el zip trae la tool del hook,
   que el perfil no nombra.
2. Exportar un workflow → trae los agentes de cada puesto, con lo suyo.
3. Exportar algo con una referencia rota → se nombra antes de guardar.
4. Abrirlo con el Finder → el README dice qué es y qué secrets pide.
5. Importarlo en otra máquina → el agente queda igual, salvo los secrets, que
   se piden por nombre.
6. Importar un paquete con `curl | sh` en una skill → gravedad alta, con el
   fragmento, e Instalar apagado.
7. Un zip cualquiera → lo dice con palabras, no con el error del
   descompresor.
8. Un zip con `../../etc/algo` adentro → no se abre.
9. Exportar dos veces sin cambiar nada → bytes idénticos.

## Ver también

- [F20](20-respaldo-en-un-archivo.md) y [F21](21-vault-del-sistema.md), los
  otros dos respaldos y por qué este no es ninguno de los dos.
- [F5](05-mcps-externos.md), de donde salen los secrets que un paquete pide.
