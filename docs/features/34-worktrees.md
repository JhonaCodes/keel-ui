# F34 — Trabajar en otro worktree, y volver

## Qué problema resuelve

A veces hay que hacer dos cosas del mismo repo a la vez, y son cosas
distintas: una corrección urgente mientras la migración grande sigue abierta.
Git ya resuelve eso con `git worktree`: dos carpetas, dos ramas, un solo
historial y una sola base de objetos.

Lo que faltaba es que **la app se entere**. Sin eso pasan tres cosas, las tres
en silencio:

1. **Dos proyectos que parecen el mismo.** `keel-ui` y `keel-ui-mapa` son dos
   entradas del sidebar con nombres parecidos y ninguna marca que diga que la
   segunda es un desprendimiento de la primera.
2. **El agente no sabe dónde está.** La sección ENTREGA le pide *«creá una
   rama para la sesión»*. En un worktree la rama YA existe —es la razón de que
   la carpeta exista— y crear otra encima parte el mismo trabajo en dos ramas
   y dos PRs.
3. **Un bug de una línea.** `usesGit` se resolvía con
   `Directory('$dir/.git').existsSync()`, y eso fallaba en dos casos: en un
   worktree `.git` es un **archivo** que apunta al principal, y en una
   subcarpeta del repo directamente no está. En los dos la respuesta era
   `false`, y el agente no recibía la sección de entrega. La parte que le dice
   que abra el PR, justo ahí, no llegaba. Ahora la pregunta se la contesta
   git, que acierta en los tres casos.

Y cuando el trabajo paralelo termina, hay un movimiento que se hace siempre
igual y siempre a mano: traer la rama al worktree principal y borrar la
carpeta de al lado.

## Nada que configurar

No hay una casilla de «esto es un worktree». Se detecta, o no se detecta.

Una sola lectura, que no escribe nada:

```
git -C <dir> rev-parse --show-toplevel     → la raíz de ESTA copia
git -C <dir> worktree list --porcelain     → todas las del repo
```

El **primero** de esa lista es siempre el worktree principal —git lo
garantiza— y de eso depende todo lo demás. Si la raíz de acá no es la
primera, estás en uno de al lado.

`--show-toplevel` también resuelve preguntar desde una subcarpeta y devuelve
la ruta canónica, con los symlinks ya resueltos: comparar contra lo que
escribió el usuario en el formulario del proyecto no funcionaría en macOS,
donde `/var` es un enlace a `/private/var`.

Se relee cada veinte segundos mientras haya un proyecto abierto. No porque el
worktree cambie —no cambia— sino porque **la rama sí**: la cambiás vos en una
terminal, o la cambia un agente en su turno. Solo se avisa a la pantalla
cuando la lectura DIFIERE de la anterior; publicar lo mismo cada veinte
segundos sería redibujar para nada.

## El aviso

Una franja de una línea arriba de lo que estés mirando —estado, tableros,
tablero o sesión—, porque la pregunta que contesta no es de ninguna de esas
pantallas en particular:

```
⑂  Worktree aparte · rama feat/worktrees · el principal es keel-ui   [Unificar]
```

Va en `_ConversationArea` y no adentro de cada vista, para que sea imposible
que una de las cuatro se olvide de mostrarla. **Un proyecto en el worktree
principal —lo normal— no paga ni un píxel**: la franja mide cero.

## Unificar

El botón abre un panel. Como cualquier otra cosa que decide algo en esta app,
es un panel lateral y no un diálogo: hay que leer rutas, ramas y una lista de
lo que se va a borrar, y eso no entra en un sí/no.

El panel enumera **antes** de tocar nada:

1. Traigo `main` (o `master`) de `origin` al worktree principal.
2. Saco la carpeta de al lado. Git la desregistra y **la borra del disco**.
3. Pongo la rama en el principal, que recién ahora puede tomarla.
4. El proyecto pasa a correr ahí, con la misma rama y el mismo hilo.

### El orden no es casual

Primero lo que se puede deshacer, después lo que no. Traer la base no
destruye nada; sacar el worktree sí, y para entonces ya se sabe que el resto
del camino está despejado.

El paso 3 no puede ir antes del 2: git se niega a tomar una rama que otro
worktree tiene checkeada, y hasta el paso 2 la tenía.

### Lo ignorado se enumera

`git worktree remove` borra la carpeta entera, y con ella se va lo IGNORADO,
que no aparece en ningún `git status`: el `.env` que escribiste a mano, la
build. Git no lo va a extrañar; vos sí. Por eso el panel lo lista antes, con
nombre y cantidad. No traba —es la carpeta que se está yendo— pero queda
dicho.

### Lo que sí traba

Son datos, no excepciones: una operación que borra una carpeta no se entera a
mitad de camino.

| Traba | Por qué |
|---|---|
| Una sesión corriendo en el proyecto | El CLI está escribiendo adentro de la carpeta que estaríamos borrando |
| El repo principal es `bare` | No tiene copia de trabajo a la que mudarle la rama: este worktree es todo lo que hay |
| HEAD suelto, sin rama | No hay nada que mudar al principal |
| El worktree con `git worktree lock` | Quien lo bloqueó tenía un motivo |
| Cambios sin commitear acá | Se pierden con la carpeta |
| Cambios sin commitear en el principal | Hay que cambiarle de rama, y con eso encima no se puede |

### El pull falla y sigue

Es la única desviación del «todo o nada», y es a propósito: traer `main`
depende de que haya red y de que el remoto conteste, y **ninguna de las dos
cosas tiene que ver con consolidar dos carpetas locales**. Sin red, bloquear
la unificación entera sería castigar lo que sí se puede hacer por lo que no.
Se ve en el informe, marcado, y el resto sigue.

Si el principal ya está parado en la base, es un `pull --ff-only` de verdad.
Si está en otra rama, se adelanta la referencia con
`fetch origin <base>:<base>` —lo mismo, sin el checkout de más.

### No se mezcla nada

Si la rama quedó atrás de la base, el panel lo dice con el número exacto y no
hace nada al respecto. Mergear o rebasear es una decisión, y acá solo se muda
una rama de carpeta.

### Si algo falla a mitad

El proyecto cambia de directorio **en cuanto la carpeta vieja deja de
existir**, salga bien el resto o no. Dejarlo apuntando a lo que se borró es la
única forma de que esto termine peor de lo que empezó.

Y si el `switch` final falla, el informe dice lo único que importa: los
commits están, la rama sigue existiendo, y se toma a mano.

## Lo que el agente recibe

Cuando el proyecto corre en un worktree de al lado, el turno suma una sección
al system prompt, justo después de ENTREGA:

> **WORKTREE**: este directorio es un worktree APARTE del repo, no el
> principal. Ya está parado en la rama `feat/x`, que es la rama de este
> trabajo: commiteá acá y NO crees otra rama ni te cambies de rama. Donde la
> sección ENTREGA dice "creá una rama para la sesión", esa rama ya está creada
> y es esta. El worktree principal del repo está en `…` y NO es tuyo en este
> turno: no le hagas checkout, no le cambies de rama, no escribas adentro.
> Acá `.git` es un archivo y no una carpeta. Es normal en un worktree y no hay
> nada que arreglar.

No es algo que pueda deducir solo: `git status` le dice en qué rama está, no
que esa rama sea la de este worktree ni que haya otra copia del repo al lado.

## Dónde vive

| Qué | Dónde |
|---|---|
| Modelo y lectura | `integrations/git_worktree/src/worktree_place.dart`, `worktree_probe.dart` |
| El plan y sus trabas | `integrations/git_worktree/src/worktree_plan.dart` |
| Los cuatro pasos | `integrations/git_worktree/src/worktree_unify.dart` |
| Caché por ruta y la operación | `integrations/git_worktree/src/worktree_viewmodel.dart` |
| La franja y el panel | `integrations/git_worktree/src/ui/` |
| La declaración en el turno | `modules/projects/viewmodel/projects_viewmodel.dart` (`_worktreePrompt`) |

## Cómo se prueba

El parseo de `worktree list --porcelain` y las trabas del plan son puros y se
prueban solos.

El resto corre **git de verdad** sobre repos de juguete en una carpeta
temporal —incluido un `origin` bare local, sin red— porque lo que puede salir
mal ahí no es el parseo sino el ORDEN de los comandos, y una carpeta que se
borra a destiempo no se descubre con un mock.
