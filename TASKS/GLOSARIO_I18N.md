# Glosario I18N — Keel UI
**Base de terminología consistente para traducciones ES-CO / EN**

Derivado de README.md + estándares de dominio (gobernanza de agentes, workflows, desarrollo).

## Términos de Dominio Técnico

| Concepto EN | ES-CO | Contexto | Notas |
|---|---|---|---|
| agent/agent profile | agente / perfil de agente | Identidades reusables de AI | Singular/colectivo según contexto |
| skill | skill | Unidad de conocimiento inyectado | **AMBIGUO**: ¿"habilidad"? No — el término técnico es "skill" (NUI estándar) |
| rule | regla | Norma de comportamiento | Reglas globales, del proyecto, de skills |
| workflow | workflow | Secuencia de pasos ordenados | **AMBIGUO**: ¿"flujo de trabajo"? "pipeline"? Mantener "workflow" si es en contexto técnico |
| session | sesión | Unidad de trabajo dentro de proyecto | |
| turn | turno | Ejecución del CLI (una corrida) | |
| project | proyecto | Repo + agentes + reglas | Directorio de trabajo |
| knowledge base | base de saber | Contexto compartido (modelos, docs) | |
| workbench / desktop | escritorio | La ventana principal de la app | |
| panel | panel | Ventanas que se abren/cierran | |
| board | tablero | Pizarra de estado/progreso | |
| toggle | switch/cambiar | UI binario | Según contexto (ajuste, checkbox) |
| hook | hook | Trigger automático | Mantener "hook" (estándar) |
| roadmap | roadmap / hoja de ruta | Plan de tareas | **AMBIGUO**: Mantener "roadmap" en contexto técnico |
| requirement | requerimiento | Solicitud entre proyectos | |
| payload | payload | Datos en tránsito | Técnico, mantener EN |
| token | token | Credencial de acceso | |
| CLI | CLI | Interfaz de línea de comandos | |
| MCP | MCP | Model Context Protocol | Técnico |
| Gherkin | Gherkin | Formato de spec ejecutable | Técnico |

## Términos de UI / Acciones Comunes

| EN | ES-CO | Variante | Tono |
|---|---|---|---|
| Create | Crear | Crear nuevo | Imperativo, directo |
| Delete | Eliminar | Borrar/Remover | Imperativo |
| Save | Guardar | Persistir | Imperativo |
| Cancel | Cancelar | Abortar | Imperativo |
| Edit | Editar | Modificar | Imperativo |
| Submit | Enviar | Entregar/Confirmar | Imperativo |
| Close | Cerrar | --- | Imperativo |
| Open | Abrir | --- | Imperativo |
| Add | Agregar | Añadir | Imperativo, directo |
| Remove | Quitar | Eliminar/Remover | Imperativo |
| Search | Buscar | --- | Imperativo |
| Filter | Filtrar | --- | Imperativo |
| Sort | Ordenar | --- | Imperativo |
| Copy | Copiar | --- | Imperativo |
| Paste | Pegar | --- | Imperativo |
| Undo | Deshacer | --- | Imperativo |
| Redo | Rehacer | --- | Imperativo |
| Back | Atrás | Volver | Imperativo/Locación |
| Next | Siguiente | Próximo | Imperativo/Locación |
| Previous | Anterior | --- | Locación |
| Done | Hecho | Completado | Estado |
| Loading | Cargando | En proceso | Gerundio |
| Error | Error | Fallo | Estado |
| Success | Éxito | Completado | Estado |
| Warning | Advertencia | Precaución | Estado |
| Info | Información | --- | Estado |

## Plurales y Contextos Variables

**ES-CO**: usar `{count, plural, one {...} other {...}}` — el nombre del
placeholder es el que declara el origen (código/ARB), nunca se renombra en
la traducción.

**Ejemplos traducidos (ICU real, ejecutable)**:
- `{count, plural, one {1 agente} other {{count} agentes}}`
- `{count, plural, one {1 sesión encontrada} other {{count} sesiones encontradas}}`

Ver `lib/l10n/app_en.arb` / `app_es_CO.arb` (`countAgent`, `countSession`,
`countFound`) para el placeholder real (`count`) ya usado en ambos idiomas.

## Notas de Registro y Tono

- **Registro**: Profesional pero accesible. "Tú" (informal cómodo), no "usted".
- **Imperativos**: directos y cortos (1-2 palabras ideales en botones).
- **Mensajes de error**: breves, explícitos, sin culpa del usuario ("No se pudo conectar" no "Fallaste").
- **Confirmaciones**: claras y positivas ("Agente creado" no "OK").

## Variantes Colombianas (NO Argentina)

- **"¡Órale!" → "¡Dale!"** (colombiano)
- **"Vos" → "Tú"** (formal cómodo en CO)
- **"Boludo" → (no usar)** — usar formas neutrales
- **Diminutivos**: "-ita/-ito" (natural en CO, usar con cuidado en UI)
- **Vocabulario específico CO**:
  - "Plata" (dinero, pero técnico es "dinero")
  - "Parcero" (colega, pero formal es "compañero")
  - "Chamba" (trabajo, pero formal es "trabajo")
  - **Para Keel**: usar "compañero" (agente → "compañero" de workflow)

---

**PENDIENTE DE CONFIRMACIÓN HUMANA:**
- [ ] ¿"Skill" se traduce o se mantiene EN en la UI?
- [ ] ¿"Workflow" → "flujo de trabajo" o mantener EN?
- [ ] ¿"Hook" se traduce a "gancho automático" o se mantiene?
- [ ] Registro: ¿"tú" o "usted" en confirmaciones/avisos?
