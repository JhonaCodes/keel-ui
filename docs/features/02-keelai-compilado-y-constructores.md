# F2 — Keel AI compilado + agentes constructores

## Qué es

1. **Conocimiento compilado**: el system prompt de Keel AI Y su skill de mapa
   del sistema (`keelai-mapa-del-sistema`) se sincronizan con las constantes
   del código en CADA arranque (`seedKeelAi` → `syncReservedProfilePrompt` +
   `SkillsViewModel.syncReservedSkillContent`). Antes el mapa se sembraba una
   vez y quedaba desactualizado en instalaciones existentes; ahora editar esa
   skill a mano se pierde en el próximo arranque — es conocimiento de la app,
   no del usuario.
2. **Entrevista de proyecto completa**: el seed instruye a Keel AI a armar
   un proyecto entrevistando de a UNA pregunta (propósito → carpeta
   verificada → miembros/roles → workflow → tools → reglas) y a ejecutar
   todas las creaciones en orden de dependencia en una sola respuesta.
3. **Agentes constructores** (`AgentProfile.canManageSystem`): un perfil
   marcado como constructor recibe el MCP `keelai-actions` completo en sus
   chats 1:1 — puede crear skills/reglas/tools/agentes/workflows/proyectos
   igual que Keel AI. La verificación es en vivo por turno
   (`AgentsViewModel._canManageSystem`), así que revocar el switch aplica al
   turno siguiente.

## Cómo se otorga

- UI: switch "Puede administrar el sistema" en el formulario de agente
  registrado.
- Keel AI: `create_or_update_agent` acepta `system_builder: bool` (nullable
  en update: si no viene, se conserva lo que había). La línea de trace en el
  hilo hace visible el otorgamiento.

## Límites

- El fallback de CREACIÓN por bloques fenced (```skill, ```regla,
  ```workflow, ```proyecto) es de Keel AI — los constructores actúan por
  tools MCP reales. Ojo: NO es el único dialecto fenced del sistema. Un
  miembro de proyecto declara especialistas con un bloque ```agente propio
  (4 claves: handle/rol/proposito/instrucciones, ver F8), y un miembro
  codex escribe el plan con ```plan/```cumplido (ver F6/F17). Son parsers
  distintos con claves distintas.
- `canManageSystem` no viaja al export sin revisión (ver F21): al importar se
  respeta lo que diga el JSON, que el usuario revisa.
