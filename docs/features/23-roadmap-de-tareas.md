# F23 — El roadmap de un proyecto

## Qué problema resuelve

Una lista de tareas para varios agentes tiene dos partes con naturalezas
opuestas, y meterlas en el mismo lugar rompe una de las dos.

La **definición** de una tarea describe el código: se ramifica con él, se
revisa en un PR, la lee cualquiera que abra el repo, y en una rama vieja esa
tarea legítimamente no estaba hecha. Eso pertenece al repo.

La **toma** —quién la está haciendo ahora— no describe el código, describe
este momento. Y necesita ser atómica: entre que un agente lee "libre" y
escribe "mía", otro no puede colarse. Un archivo en git no da esa garantía:
dos agentes leen "libre" a la vez y los dos creen que ganaron.

La pregunta que separa las dos: **si hago `git checkout` de una rama de la
semana pasada, ¿esto debería cambiar?**

## Qué es

Una carpeta `TASKS/` en el repo del proyecto, y tres tools en el turno.

```
TASKS/
├── README.md                    objetivo final + qué hay en cada carpeta
├── 01-fundacion/
│   ├── README.md                objetivo de ESTE grupo
│   ├── 01-device-layer.md
│   └── 02-shell.md
└── _borradores/                 salida cruda de una investigación,
    └── …                        sin numerar, esperando al estandarizador
```

**No hay `TOMADAS.md` ni `SEGUIMIENTO.md`.** Es deliberado: un archivo de
estado compartido es un imán de conflictos, porque cada agente que termina
algo escribe en el mismo destino. Con el estado adentro de cada tarea, dos
agentes que terminan dos tareas distintas tocan archivos distintos y no
chocan nunca. El seguimiento global se genera leyendo la carpeta.

El formato del `.md` es mínimo a propósito —un frontmatter de pares
`clave: valor` y una sección `## Bloqueantes` con checkboxes— para que se
pueda escribir a mano, se revise a ojo en un PR, y se parsee sin sumar una
dependencia de YAML. La plantilla está en `docs/plantillas/TASKS/`.

## Nadie puede cruzar proyectos

El alcance **no es un argumento que manda el modelo**: sale de la URL con la
que se le entregó el servidor MCP a ese turno
(`/roadmap/<proyecto>/<sesión>/<perfil>`), igual que ya hacía el MCP del
plan. Del proyecto sale su directorio de trabajo, y ese directorio es la
identidad del proyecto.

La sesión está en la ruta por una razón concreta, y no es simetría: sin ella
la toma sabe QUÉ tarea y CON QUÉ agente, pero no en cuál de las sesiones
abiertas del proyecto. El estado del proyecto (F25) necesita esa tercera
columna, y una toma que no sabe dónde vive obliga a adivinarla.

Un turno del proyecto A no puede tomar una tarea del proyecto B aunque lo
pida: no tiene cómo nombrarlo. Y la clave de la toma lleva la ruta del
proyecto adentro, así que `02-shell.md` de un repo y `02-shell.md` de otro
son cosas distintas.

## La toma es síncrona, y de eso depende todo

`TaskClaimsViewModel.claimTask` no es `async`. Dart corre un isolate por vez,
así que entre la lectura y la escritura no hay ningún `await` donde otro
pueda meterse — eso, y no otra cosa, es lo que hace la operación atómica. La
persistencia en LMDB va después, sin esperarla: la decisión ya se tomó en
memoria.

Una toma **vence a los 30 minutos**. No es un extra: si un agente se cae con
la tarea tomada, sin vencimiento esa tarea queda trabada para siempre y nadie
entiende por qué. Volver a llamar `claim_task` sobre la misma tarea la
renueva, así que un turno largo no la pierde por el reloj.

La toma guarda el proyecto, la tarea, el agente y **la sesión**. Lo que no
guarda —y guardaba— es el nombre del proyecto por duplicado: cuando la
estación pasó a llamarse proyecto quedó a la vista que `stationName` y
`projectName` escribían el mismo valor.

Los claims **no se respaldan** en el vault: restaurarlos en otra máquina
revivirían candados de tareas que nadie está haciendo.

## Las tools

| Tool | Qué hace |
|---|---|
| `list_roadmap_tasks` | Lee la carpeta y devuelve tareas, estado, bloqueantes y quién tiene cada una tomada |
| `claim_task` | Toma una tarea. Falla si otro se adelantó, o si tiene bloqueantes abiertos |
| `release_task` | La suelta. Solo podés soltar las tuyas |

`list_roadmap_tasks` **no cachea**. Un índice guardado en la base se
desactualiza solo: un `git pull`, un cambio de rama, otro agente agregando
tareas — y la base muestra la foto vieja. Recorrer la carpeta es barato.

El servidor solo se le entrega a un turno si el proyecto **tiene** carpeta
`TASKS/`. Un proyecto sin roadmap no ve tres tools que no aplican.

## Renumerar sin arrastrar las referencias

Es el modo de falla que más caro sale: alguien renumera una carpeta, no
actualiza los bloqueantes que apuntaban ahí, y esa tarea queda trabada por
algo que nadie puede terminar porque ya no existe. El síntoma aparece lejos
de la causa.

Se podría pedir por prompt que quien renumere arrastre las referencias, pero
eso **pide**; no garantiza. El lector lo detecta: después de juntar todas las
tareas hace una segunda pasada y resuelve cada referencia contra las que
existen de verdad.

- Acepta la ruta completa (`01-fundacion/02-shell.md`) y también el nombre
  suelto (`02-shell.md`, o `02-shell`), porque así lo escribe cualquiera.
- Si no coincide con ninguna → `missing`.
- Si el nombre suelto coincide con dos tareas → `ambiguous`, en vez de elegir
  una.

Una tarea con una referencia rota **no se puede tomar**, y `claim_task` dice
exactamente cuál está rota y qué hacer. Cierra la puerta a propósito: no hay
forma de saber si la dependencia desapareció o solo cambió de nombre, y
adivinar en cualquiera de las dos direcciones se equivoca en silencio. Lo que
sí se puede hacer es nombrar el problema.

## Cómo convive con el plan de tarea

No lo reemplaza: son granularidades distintas que se componen.

| | Dura | Vive en |
|---|---|---|
| Roadmap | Meses | El repo |
| Toma | Minutos | LMDB |
| Plan de tarea (F17) | Una tarde | El canal |

El ciclo cierra en el repo: lo último que hace el turno es marcar
`estado: hecho` en el `.md`, que se commitea con el código que lo justifica.

## Verificación

1. Un proyecto con `TASKS/` y dos tareas: `list_roadmap_tasks` las devuelve,
   con el README excluido y los bloqueantes leídos.
2. Una tarea con un bloqueante abierto no es tomable; al marcarlo con `x`, sí.
3. `claim_task` sobre una ya tomada falla y nombra a quién la tiene.
4. Volver a llamar `claim_task` sobre la propia la renueva, no falla.
5. `release_task` sobre una ajena se rechaza.
6. Dos proyectos con proyectos distintos y una tarea del mismo nombre: tomar
   una no bloquea la otra.
7. Un proyecto sin `TASKS/` no recibe las tools.
8. Un bloqueante que apunta a una tarea inexistente marca la tarea como no
   tomable, y `claim_task` nombra la referencia rota.
9. Un bloqueante escrito con el nombre suelto resuelve solo; si ese nombre
   existe en dos carpetas, queda ambiguo en vez de elegir una.
