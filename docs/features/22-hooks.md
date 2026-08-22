# F22 — Hooks: guardarraíles que corren solos

## Qué problema resuelve

keel-ui administraba skills, reglas, tools, workflows, MCPs, agentes,
proyectos y bases de saber. De hooks, nada: `grep -i hook` sobre `lib/` no
devolvía un solo resultado.

Lo que había estaba escrito a mano en `~/.claude/settings.json` y se aplicaba
a **todos** los subprocesos que lanza esta app sin que la app lo supiera ni
lo mostrara — `--strict-mcp-config` aísla los MCP, no los hooks. Después una
limpieza se los llevó y los scripts que referenciaban desaparecieron. O sea:
invisibles cuando funcionaban, y silenciosamente muertos después.

## Un hook NO es una regla

Es la confusión que hay que evitar, porque lleva a escribir una regla
esperando que se cumpla sola.

| | Regla | Hook |
|---|---|---|
| Qué es | Prosa en el system prompt | Comando en un evento del CLI |
| Quién decide | El modelo | El proceso, antes del modelo |
| ¿Se puede ignorar? | Sí | No |
| ¿Bloquea? | No | Sí (`exit 2`) |
| ¿Reacciona? | No | Sí (formatear tras un Edit) |
| Cuando falla | En silencio | Con mensaje y código |

*"No commitees sin correr los tests"*: como regla, el agente casi siempre
obedece y cuando no, te enterás después; como hook, el commit **no ocurre**.

Van separados pero vinculados: un hook declara en `enforces` qué reglas hace
cumplir, y la pantalla de Reglas muestra cuáles están **garantizadas** y
cuáles dependen de que el modelo obedezca.

## Cómo llega al CLI

Los dos CLIs tienen hooks nativos y —verificado en la máquina, no supuesto—
la **misma forma** de configuración: evento → matcher → comandos, `exit 2`
bloquea, `hookSpecificOutput.permissionDecision` deniega. Y los 11 eventos de
codex son un **subconjunto exacto** de los ~30 de claude.

Así que no se intercepta nada: un hook se define una vez y se materializa al
lanzar el turno.

- **claude** → `settings.json` con `--settings <ruta>`. Suma a lo que el
  usuario tenga en su config; keel-ui administra los suyos y no adopta los
  ajenos.
- **codex** → un perfil TOML en `$CODEX_HOME` con `-p <perfil>`. Se capa
  encima de la config del usuario, vale para esa invocación y se borra.

`CliTurnWorkspace` (`lib/src/core/services/cli_turn_workspace.dart`) unifica
el temporal 0700 del turno, que antes estaba duplicado entre
`ClaudeCliService` y el isolate del task runner. Ahí van el `mcp.json` que ya
existía, la config de hooks y un wrapper por hook.

### Por qué hay un wrapper

1. **Secrets.** El CLI hereda el entorno de la app, así que meter un secret
   ahí se lo daría a todo lo demás. El wrapper exporta **solo** los que ese
   hook declara.
2. **Tools como cuerpo.** Materializa el código de la tool y lo corre con su
   runtime.
3. **Marca el bloqueo.** Cuando el hook sale con 2, agrega
   `[keel:hook <nombre>]` a stderr.

El cuerpo **siempre** va a un archivo aparte, incluso un comando de una
línea: si estuviera inline, su `exit 2` terminaría el wrapper antes de que
pueda dejar la marca. (Y una tool bash producía un archivo con el mismo
nombre que su wrapper — el wrapper se llamaba a sí mismo en recursión
infinita. Por eso `<hook>.body.<ext>`.)

## Bloquear no es faltar un permiso

keel-ui nunca contesta un pedido de permiso: el CLI corre headless, deniega,
y la app **observa** `system/permission_denied`. Cuando el usuario concedía,
se prendía un ajuste global y se mandaba un turno nuevo. Ese reflejo sería
equivocado para un hook: ningún permiso destraba eso.

Probando contra el CLI real apareció algo que no estaba previsto: **un hook
que bloquea NO llega como `permission_denied`**, llega como el resultado con
error de la herramienta que frenó — un evento `user` que keel-ui no parseaba
en absoluto. Sin eso, el bloqueo solo lo habría contado el modelo en prosa.

Ahora los dos parsers (el del servicio y el del isolate) reconocen ese
resultado **por la marca del wrapper**, así que solo dispara con hooks de
keel-ui: uno que el usuario tenga en su propia config no la lleva, y un error
común de herramienta tampoco. El banner dice qué hook fue y adónde ir, sin
botón de conceder.

## Dónde se asigna

Global, por agente (`AgentProfile.hooks`) y por proyecto
(`Station.hookNames`), igual que las reglas.

**Keel AI queda afuera, siempre.** No es conveniencia: es la salida de
emergencia. Un hook mal escrito puede trabar a todos los agentes, y la forma
de arreglarlo es apagarlo — si lo que puede apagarlo estuviera también
trabado, no habría salida. Por eso Keel AI corre sin restricciones y tiene
`set_hook_enabled` y `delete_hook`.

## Borrar es borrar en todos lados

Acá el módulo se aparta a propósito de cómo se borra una regla, que deja el
nombre colgado en perfiles y proyectos. `deleteHook` **cascadea**, y
renombrar arrastra las asignaciones. Una referencia muerta a un guardarraíl
miente sobre qué está protegido. El diálogo dice qué va a soltar antes de
hacerlo.

## Importar lo que ya tenías

`Hooks → Importar de Claude Code` lee `~/.claude/settings.json` y sus
respaldos, deduplica por evento + matcher + comando, y trae las entidades
**apagadas**, marcando cuáles apuntan a archivos que ya no existen.

## Verificación

1. Un hook `PreToolUse`/`Bash` que deniega `rm -rf`: el comando no corre y la
   UI dice qué hook lo frenó, sin ofrecer "conceder permiso".
2. El mismo hook en una **proyecto** — prueba que el camino del isolate quedó
   cubierto.
3. El mismo hook con un agente **codex**.
4. Un hook "solo Claude" con un agente codex: el formulario lo marca y el
   turno reporta que no se aplicó.
5. Un hook con cuerpo de tool y un secret declarado: corre con el secret en
   su entorno, y ese secret no aparece en el del CLI.
6. Un hook apagado no se escribe en la config generada.
7. **La salida de emergencia**: un hook global que deniega todo. Los agentes
   quedan trabados; Keel AI sigue y lo apaga.
8. **Cascada**: asignarlo a 2 agentes y 1 proyecto, borrarlo, y verificar que
   no queda el nombre en ninguna lista.
9. Respaldar el vault: `catalog/hooks/*.json`; restaurar en limpio los
   devuelve.

### Lo ya verificado contra los CLIs reales

- **claude**: con un `settings.json` generado por esta feature, un hook
  `PreToolUse`/`Bash` bloqueó el comando, el CLI no ejecutó nada, y la marca
  `[keel:hook <nombre>]` llegó en el resultado.
- **codex**: el perfil `-p` se cargó **sin ningún pedido de confianza**, que
  era el riesgo abierto. El hook no llegó a dispararse porque la cuenta
  quedó sin créditos, así que esa mitad sigue sin verificar en vivo.
