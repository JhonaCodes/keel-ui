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

Cada línea es `- [ ] <ruta de la tarea> — <por qué bloquea>`. La
justificación no es decorativa: sin ella nadie sabe si el bloqueo sigue
vigente. Se marca con `x` cuando se resuelve.

- [ ] 01-nombre-alusivo/00-otra.md — sin eso no hay dónde apoyar esto

## Criterio de aceptación

Cómo se sabe que está terminada. Verificable, no "quedó lindo".

- [ ] …
