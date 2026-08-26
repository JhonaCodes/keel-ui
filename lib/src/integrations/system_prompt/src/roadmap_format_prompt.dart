part of '../system_prompt.dart';

/// EL FORMATO DE LA CARPETA `TASKS/` DE UN PROYECTO.
///
/// Qué dice: la especificación completa de la carpeta de tareas — nombres,
/// frontmatter, estados, grupos y referencias entre tareas.
///
/// Por qué existe: keel-ui lee esa carpeta con un parser propio, así que el
/// formato no es una convención social sino un contrato. El agente que la
/// arma tiene que escribir exactamente lo que el lector espera; si no, la
/// carpeta queda linda y la app no la entiende.
///
/// Quién lo usa: `seedRoadmapFormatSkill()` en
/// `modules/projects/model/roadmap_format_skill.dart` lo fuerza en cada
/// arranque dentro de la skill reservada `kRoadmapFormatSkillName`, que el
/// workflow del mismo nombre le entrega al agente que define el formato.
const kRoadmapFormatSkillContent = '''
# El formato de la carpeta de tareas (keel-ui)

Esto describe la carpeta `TASKS/` de un proyecto. keel-ui la LEE con un
parser propio, así que el formato no es una convención social: si no está
así, no se lee.

## Dónde va

`TASKS/`, **en la raíz del repo**, al lado del código. No adentro de `docs/`,
no adentro de `lib/`.

**No se comitea.** Keel agrega `TASKS/` al `.gitignore` del proyecto: esta
carpeta es la libreta de trabajo de quien te está usando, no una entrega del
proyecto, y un roadmap que se mueve todos los días no tiene por qué ensuciar
el historial ni los PRs. No la saques del `.gitignore`, no la agregues al
índice, y no la menciones en un commit.

Que no se comitee no cambia nada de cómo se escribe: sigue viviendo en la
raíz porque las rutas de los bloqueantes son relativas a ella, y sigue siendo
la única fuente de qué falta hacer.

## Cómo se arma

```
TASKS/
├── README.md                    objetivo final + qué hay en cada carpeta
├── 01-fundacion/
│   ├── README.md                objetivo de ESTE grupo
│   ├── 01-device-layer.md
│   └── 02-shell.md
├── 02-matriculas/
│   ├── README.md
│   └── 01-listado.md
└── _borradores/                 salida cruda de una investigación,
    └── …                        sin numerar, esperando que la estandaricen
```

Reglas duras, todas chequeadas:

1. `TASKS/README.md` existe y dice el objetivo final del proyecto — el estado
   del mundo cuando TODO esté hecho, no la lista de tareas.
2. Cada carpeta de grupo se llama `NN-nombre-alusivo` y tiene su `README.md`
   con el objetivo de ESE grupo. El número manda el orden.
3. **Ninguna tarea suelta en la raíz de `TASKS/`.** El lector solo baja a las
   carpetas de grupo: una tarea en la raíz queda escrita y es invisible.
4. Cada tarea es un `.md` dentro de un grupo, numerado `NN-nombre.md`.
5. `_borradores/` es la única carpeta que empieza con `_`, y a lo que hay
   adentro no se le exige nada todavía.

## Qué es una tarea, y qué no

Una tarea es **una unidad entregable**: se toma, se hace y se cierra sin
tener que abrir otra en el medio. Si para terminarla hay que decidir algo que
todavía no está decidido, eso es otra tarea y va antes, como bloqueante.

- Ni tan chica que sea un paso de una sesión («renombrar la variable»), ni
  tan grande que nadie pueda decir si está terminada («mejorar el
  rendimiento»). Si no podés escribir su criterio de aceptación en dos
  líneas verificables, todavía es dos tareas.
- El trabajo que ya está hecho no entra. Esta carpeta es lo que FALTA.
- No inventes tareas para llenar un grupo. Un grupo con una sola tarea es una
  respuesta legítima.

## Cómo se decide el corte en grupos

Un grupo junta lo que se entrega junto, no lo que se parece. El corte natural
es **por resultado**: cuando el grupo termina, algo que antes no se podía
hacer ahora se puede.

- Entre 2 y 6 tareas por grupo. Uno de doce es un grupo que se está tapando a
  sí mismo: partilo por resultado, no por la mitad.
- Entre 2 y 8 grupos en total. Más que eso y el `README.md` de la raíz deja
  de leerse.
- Agrupar por capa técnica (`modelos/`, `ui/`, `tests/`) casi siempre está
  mal: obliga a tocar los tres grupos para entregar una sola cosa.

## Qué significa el número

El número **NN** es el orden en que hay que tomar las cosas, no el orden en
que se crearon. Entre grupos dice qué va primero; adentro de un grupo, lo
mismo.

- El orden es una recomendación; el bloqueante es la regla. Si `03` de verdad
  no se puede hacer sin `05`, eso se escribe como bloqueante — el número solo
  no frena a nadie.
- Se numera de a uno, sin huecos. Si hay que meter algo en el medio y no
  queda lugar, renumerá y **arrastrá las referencias**: un bloqueante que
  apunta a un archivo renombrado queda roto, y el chequeo lo marca.
- Un bloqueante puede cruzar de grupo. Es normal y no hay que evitarlo; lo
  que hay que evitar es que dos grupos se bloqueen mutuamente, porque
  entonces no eran dos grupos.

## Cuando aparece trabajo que no entra en ningún grupo

Pasa, y no se resuelve tirándolo en la raíz —el lector no lo ve— ni forzándolo
adentro del grupo más parecido. Las dos salidas legítimas son: abrir un grupo
nuevo con su `README.md`, si lo que apareció es un resultado propio; o
dejarlo en `_borradores/` mientras no esté claro qué es. Un borrador no se
puede tomar, y está bien: es material, todavía no es trabajo.

**No hay `TOMADAS.md` ni `SEGUIMIENTO.md`, y no los crees.** Un archivo de
estado compartido es un imán de conflictos: cada agente que termina algo
escribe en el mismo destino. Con el estado adentro de cada tarea, dos agentes
que terminan cosas distintas tocan archivos distintos y no chocan nunca. El
seguimiento global lo genera keel-ui leyendo la carpeta.

## El archivo de una tarea

```markdown
---
estado: libre
titulo: Capa de dispositivo
---

# Capa de dispositivo

## Qué hay que hacer

El detalle completo, escrito para alguien que no estuvo en la conversación
donde salió esto. Si hace falta un diagrama, va acá:

```mermaid
flowchart LR
  A[MediaQuery] --> B{shortestSide}
  B -->|< 600| C[mobile]
  B -->|600-899| D[tablet]
  B -->|>= 900| E[desktop]
```

## Bloqueantes

- [ ] 01-fundacion/00-otra.md — sin eso no hay dónde apoyar esto

## Criterio de aceptación

- [ ] Cómo se sabe que está terminada. Verificable, no "quedó lindo".
```

### El frontmatter

Pares `clave: valor` entre `---`, planos, sin YAML anidado.

- `estado:` **obligatorio**. Uno de: `libre`, `en-curso`, `hecho`,
  `bloqueado`, `borrador`.
- `titulo:` opcional. Sin él se usa el primer `# encabezado`.

### Los bloqueantes

Una sección `## Bloqueantes` con líneas
`- [ ] <ruta de la tarea> — <por qué bloquea>`.

- El separador es un guion largo `—` (o `--`).
- La justificación **no es decorativa**: sin ella nadie sabe si el bloqueo
  sigue vigente.
- Se marca `- [x]` cuando se resuelve.
- La referencia puede ser la ruta completa (`01-fundacion/02-shell.md`) o el
  nombre suelto (`02-shell.md`). Si el nombre suelto existe en dos carpetas,
  keel-ui lo marca AMBIGUO y la tarea queda trabada: ahí usá la ruta completa.
- Si apunta a algo que no existe, keel-ui lo marca ROTO y la tarea no se
  puede tomar. **Si renumerás o renombrás una tarea, arrastrá las
  referencias que le apuntaban.**

## Cómo se trabaja acá

En el README raíz, tal cual:

1. `list_roadmap_tasks` para ver qué hay y qué está tomado.
2. `claim_task` sobre la que vayas a hacer. Si falla, otro se te adelantó:
   pasá a la siguiente, no insistas.
3. Al terminar: `estado: hecho` en el archivo de la tarea, y `release_task`.

Y si tocaste la ESTRUCTURA de la carpeta, `check_roadmap_format` antes de
cerrar.

## Cómo se chequea (y con qué NO)

**`check_roadmap_format` es la tool que lo mide.** Corré esa, mirá qué falta,
arreglalo, volvé a correrla. Es el MISMO chequeo que decide si la sesión
cierra, así que lo que te diga es lo que va a pasar.

Dos confusiones que ya costaron una discusión entera, así que quedan escritas:

- **No existe ningún comando `keel`.** No lo busques en la terminal, no está
  instalado y no va a estarlo: el chequeo es una tool de este turno, no un
  binario. `keel: command not found` no significa "falta instalar algo",
  significa que estás buscando en el lugar equivocado.
- **`list_roadmap_tasks` no es el checker.** Lista las tareas y dice quién
  tiene cada una tomada. Trae un campo `referencias_rotas` por tarea, que es
  UNA de las siete cosas que mira el formato — no las otras seis. Que ese
  campo dé cero no dice nada sobre los README de grupo, ni sobre los
  frontmatter, ni sobre tareas sueltas en la raíz.

## Antes de dar por cerrado

keel-ui vuelve a correr el chequeo por su cuenta cuando la sesión cierra, y
si algo no da, la sesión NO queda terminada. Lo que mira es exactamente esto:

- `TASKS/` en la raíz del repo
- README raíz con el objetivo final
- carpetas de grupo, todas con README
- ninguna tarea suelta en la raíz
- todos los frontmatter declaran `estado:`
- cero referencias rotas o ambiguas entre tareas

No inventes tareas para llenar la carpeta. Si el proyecto no tiene definido
qué hay que hacer, preguntá antes de escribir once archivos que nadie pidió.
''';
