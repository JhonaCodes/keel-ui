# F3 — Skills globales

## Qué es

Una skill marcada como **global** (`Skill.isGlobal`) se inyecta en el system
prompt de TODOS los agentes en cada turno — chats 1:1 (con o sin perfil) y
miembros de proyecto por igual — sin necesidad de asignarla a nadie.

## Dónde se inyecta

- 1:1: `AgentsViewModel._resolveProfileSystemPrompt` — las globales van
  PRIMERO, después el system prompt del perfil, sus skills asignadas y sus
  reglas. Una skill global que además esté asignada se inyecta UNA sola vez.
- Proyectos: `StationsViewModel._turnSystemPrompt` — mismo orden y misma
  regla de deduplicación.

## Cómo se crea

- UI: switch "Skill global" en el formulario de skill; la lista muestra un
  chip `global`.
- Keel AI: `create_skill` acepta `global: true`; el bloque fenced de
  resguardo acepta la clave `global: si|no`.
- El sistema de sugerencias (F10) crea sus propuestas como globales.

## Criterio de uso

Global = normas o conocimiento que aplica a todo el sistema (estilo, reglas
de la casa, contexto del negocio). Especialidades de un rol siguen siendo
skills asignadas.

## Costo

Cada skill global viaja completa en CADA turno de CADA agente (el prompt
cache lo abarata, pero no es gratis) — mantenerlas pocas y cortas.
