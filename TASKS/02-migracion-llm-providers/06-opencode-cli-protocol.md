---
estado: hecho
titulo: OpenCode CLI — protocolo y traducción de permisos
---

# OpenCode CLI — protocolo y traducción de permisos

## Evidencia del binario verificado

Verificado el 2026-08-24 contra `opencode` 1.18.15 instalado en
`/opt/homebrew/bin/opencode`:

| Necesidad de Keel | Resultado | Evidencia |
|---|---|---|
| System prompt por flag | **No existe** | `opencode run --help` no lista `--append-system-prompt` ni `--system-prompt`; ambas invocaciones salen con código 1. |
| Salida estructurada | **Sí** | `opencode run --format json`; el help la describe como eventos JSON crudos. |
| Reanudar sesión | **Sí** | `opencode run --continue` y `opencode run --session <id>`; `--fork` solo vale con una de esas opciones. |
| Allowlist por flags | **No existe** | `--allowedTools` y `--excludedTools` no están en el help y son rechazados con código 1. |
| Permisos | **Config por turno** | El modelo es `allow | ask | deny` bajo `permission`; las reglas admiten wildcards y la última coincidencia gana. |

El runner no debe inventar equivalentes de flags que el CLI no expone. Para
prompt de sistema debe crear un agente temporal en el contenido de
configuración de la corrida y seleccionarlo mediante `--agent`; el texto va
en `agent.<id>.prompt` (o en el cuerpo Markdown del agente), no prefijado al
mensaje de usuario. Esto conserva la distinción system/user. La configuración
temporal se inyecta con `OPENCODE_CONFIG_CONTENT`; no se agrega un archivo de
proyecto persistente ni se modifica la configuración del usuario.

## Contrato de `allowedTools → permission`

`allowedTools` de Keel significa *permiso automático solo para las tools
enumeradas*. No significa "preguntar por las demás". La traducción tiene que
ser **fail-closed**:

1. Emitir primero `"*": "deny"`.
2. Normalizar cada nombre permitido al nombre de permiso OpenCode.
3. Emitir una regla `"allow"` por cada nombre normalizado, después del deny
   global. Nunca emitir `--auto`: convertiría las reglas `ask` heredadas en
   allow y amplía privilegios.
4. No generar reglas `ask` a partir de `allowedTools`: el contrato de Keel es
   binario. `ask` solo puede provenir de una futura política explícita de
   Keel, distinta de esta función.
5. Rechazar un nombre que no sea builtin reconocido ni un identificador MCP
   válido; no omitirlo silenciosamente ni reemplazarlo por `"*"`.

Mapeo de builtins que debe codificar la función:

| Nombre de Keel | Clave OpenCode |
|---|---|
| `Read` | `read` |
| `Write`, `Edit`, `ApplyPatch` | `edit` |
| `Glob` | `glob` |
| `Grep` | `grep` |
| `List` | `list` |
| `Bash` | `bash` |
| `Task` | `task` |
| `WebFetch` | `webfetch` |
| `WebSearch` | `websearch` |
| `Lsp` | `lsp` |
| `Skill` | `skill` |
| `Question` | `question` |

Para MCP, OpenCode usa la clave canónica `<server>_<tool>`; los caracteres
no soportados se sustituyen por `_`. Una tool de Keel que nombra el servidor
completo se traduce a `<server>_*`, y una que nombra la tool se traduce a
`<server>_<tool>`. No se concede un servidor entero cuando el permiso pidió
una tool concreta. El serializador debe preservar el orden: deny global
primero, allow concretos después, porque OpenCode resuelve la última regla
coincidente.

Ejemplo de salida para `['Read', 'Grep', 'github_search']`:

```json
{
  "permission": {
    "*": "deny",
    "read": "allow",
    "grep": "allow",
    "github_search": "allow"
  }
}
```

La herramienta `edit` agrupa `write`, `edit` y `apply_patch`; por eso la
granularidad inferior no es representable en OpenCode y la función debe
documentar ese ensanchamiento explícito al usar cualquiera de esos tres
nombres.

## Aislamiento y governance

El runner debe usar `--pure` para evitar plugins externos durante una
corrida de Keel y aplicar la configuración temporal de más alta prioridad.
Las políticas administradas de OpenCode pueden prevalecer; si contradicen la
política temporal, la corrida debe fallar de forma visible, no degradarse a
un allowlist parcial.

`experimental.hooks` sigue siendo una capacidad experimental: la
documentación oficial marca todas las opciones bajo `experimental` como
inestables y la versión 1.18.15 no expone hooks como flag de CLI verificable.
Por ello OpenCode no puede ser la única vía de governance mientras esta
interfaz no sea estable y probada en el binario soportado. `audit-gate` y
`tdd-manda` permanecen obligatorios fuera del proceso OpenCode.

OpenCode es deliberadamente una capa de indirección: su configuración elige
el proveedor/modelo final. `OpenCodeCliRunner` debe incluir este hecho en su
doc comment; no es un atajo ni sustituye los runners directos de los
proveedores.

## Fuentes

- `opencode --version`, `opencode --help`, `opencode run --help`, ejecutados
  localmente sobre 1.18.15.
- [CLI de OpenCode](https://opencode.ai/docs/cli/) para el contrato de
  `--format json`, sesión y resume.
- [Permissions de OpenCode](https://opencode.ai/docs/permissions/) y
  [Agents](https://opencode.ai/docs/agents/) para acciones, precedencia y
  wildcards MCP.
- [Config de OpenCode](https://opencode.ai/docs/config/) para precedencia,
  `OPENCODE_CONFIG_CONTENT`, plugins y el carácter experimental de
  `experimental`.
