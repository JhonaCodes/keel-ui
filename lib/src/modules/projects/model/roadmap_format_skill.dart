import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';

/// El nombre del skill que describe el formato de la carpeta de tareas.
///
/// Reservado: se re-sincroniza en cada arranque, igual que el mapa del
/// sistema de Keel AI. Si alguien lo edita a mano, la próxima vez que abra
/// la app vuelve a lo que dice el código — que es lo correcto, porque el
/// lector y el chequeo están escritos contra esto.
const kRoadmapFormatSkillName = 'keel-formato-de-tareas';

/// Cómo se llama la sesión que arma el formato. Fija a propósito: es la que
/// el chequeo obligatorio busca al cerrar.
const kRoadmapFormatSessionTitle = 'Definir el formato';

const kRoadmapFormatSkillContent = '''
# El formato de la carpeta de tareas (keel-ui)

Esto describe la carpeta `TASKS/` de un proyecto. keel-ui la LEE con un
parser propio, así que el formato no es una convención social: si no está
así, no se lee.

## Dónde va

`TASKS/`, **en la raíz del repo**, al lado del código. No adentro de `docs/`,
no adentro de `lib/`. Se ramifica con el código y se revisa en el PR, porque
la definición de una tarea describe el código: si hacés `checkout` de una
rama de la semana pasada, esa tarea legítimamente no estaba hecha.

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

/// Deja el skill del formato al día en cada arranque.
Future<void> seedRoadmapFormatSkill() async {
  final skills = SkillsService.instance.notifier;
  await skills.ready;

  if (!skills.data.skills.any(
    (skill) => skill.name == kRoadmapFormatSkillName,
  )) {
    skills.createSkill(
      name: kRoadmapFormatSkillName,
      content: kRoadmapFormatSkillContent,
    );
  } else {
    await skills.syncReservedSkillContent(
      kRoadmapFormatSkillName,
      kRoadmapFormatSkillContent,
    );
  }
}
