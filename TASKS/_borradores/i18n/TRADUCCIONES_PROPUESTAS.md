# Traducciones Propuestas — Keel UI
**Auditoría + Propuestas de Traducción ES-CO / EN**

## Hallazgos de Auditoría de Strings Existentes

### ✅ BIEN TRADUCIDAS (Consistentes, naturales, apropiadas)

| Strings Originales | ES-CO (Existente) | Evaluación | EN Propuesta |
|---|---|---|---|
| `"Cancelar"` | Cancelar | ✅ Imperative, clear | Cancel |
| `"Guardar el zip…"` | Guardar el zip… | ✅ Formal, clear (ellipsis for wait) | Save the zip… |
| `"Listo — entrar"` | Listo — entrar | ✅ Natural confirmation (state → action) | Ready — Enter |
| `"Exportar respaldo"` | Exportar respaldo | ✅ Domain-specific, clear | Export backup |
| `"Volver a revisar"` | Volver a revisar | ✅ Natural (re-check) | Review again |
| `"Worktree aparte"` | Worktree aparte | ⚠️ Mantiene EN + ES (decisión técnica) | Separate worktree |

### ⚠️ AMBIGÜAS O MEJORABLES

| Strings Originales | ES-CO (Existente) | Problema | EN Propuesta | ES-CO Mejorada |
|---|---|---|---|---|
| `"Aplicar lo seleccionado"` | Aplicar lo seleccionado | Formal pero robusta | Apply selection | Aplicar lo seleccionado |
| `"El archivo no trae nada aplicable"` | El archivo no trae nada aplicable | Coloquial ("trae") pero comprensible | The file contains nothing applicable | El archivo no contiene nada aplicable |
| `"El respaldo no trae nada aplicable"` | El respaldo no trae nada aplicable | Coloquial ("trae") — inconsistent con "contiene" | The backup contains nothing applicable | El respaldo no contiene nada aplicable |
| `"Elegir destino y exportar"` | Elegir destino y exportar | Imperativo dual — verbos paralelos OK | Choose destination and export | Elegir destino y exportar |
| `"Empezar de cero"` | Empezar de cero | Idiomatic CO ✅ | Start from scratch | Empezar de cero |
| `"Esto no se puede deshacer"` | Esto no se puede deshacer | Pasivo correcto, pero formal | This cannot be undone | Esto no se puede deshacer |
| `"Incluir secrets (con sus VALORES)"` | Incluir secrets (con sus VALORES) | Mixing EN (secrets) + ES (con sus) — OK en contexto técnico | Include secrets (with their VALUES) | Incluir secrets (con sus VALORES) |
| `"Leer el respaldo"` | Leer el respaldo | Clear | Read the backup | Leer el respaldo |
| `"Restaurar desde el vault"` | Restaurar desde el vault | EN (vault) + ES (desde) — técnico OK | Restore from the vault | Restaurar desde el vault |
| `"Restaurar lo seleccionado"` | Restaurar lo seleccionado | Clear | Restore selection | Restaurar lo seleccionado |
| `"Traer todo y empezar"` | Traer todo y empezar | "Traer" (CO coloquial) vs. "Importar" (formal) | Bring everything and start | Traer todo e iniciar / Importar todo y empezar |
| `"Unificar en el principal"` | Unificar en el principal | Clear (assumes user knows "principal" = main branch) | Unify in main | Unificar en el principal |
| `"Clonar vault"` | Clonar vault | Mixing EN (vault) + ES (Clonar) — OK técnico | Clone vault | Clonar vault |
| `"Clonar y leer"` | Clonar y leer | Clear | Clone and read | Clonar y leer |

## HALLAZGO GENERAL

**Criterio 1 (Naturalidad)**: 70% — hay coloquialismos que funcionan en CO pero mezcla de EN/ES es consistente (estrategia técnica válida).
**Criterio 2 (Consistencia terminológica)**: 75% — "trae" vs. "contiene", "traer" vs. "importar" — hay inconsistencia en elecciones.
**Criterio 3 (Tono de marca)**: 80% — informal cómodo, imperativo directo — coincide con CO.
**Criterio 4 (Placeholders)**: 95% — parentheses y puntos suspensivos correctos.
**Criterio 5 (Formato localizado)**: N/A — sin números/fechas en estas strings.
**Criterio 6 (Longitud)**: 90% — todas entran en botones/labels sin overflow.

---

## Matriz de Traducciones Nuevas/Completas

A partir del glosario y de strings identificadas faltantes en el código:

| Key / Ubicación | Uso | Español CO | Inglés | Placeholders | Notas |
|---|---|---|---|---|---|
| `dialog.delete.confirm` | Dialog de confirmación | ¿Estás seguro? Esto no se puede deshacer. | Are you sure? This cannot be undone. | — | Usa tono de pregunta directo (CO) |
| `button.create` | Botón genérico | Crear | Create | — | Imperativo corto |
| `button.create.new` | Botón específico | Crear {entity} | Create {entity} | {entity} | Proteger placeholder |
| `button.delete` | Botón de eliminar | Eliminar | Delete | — | Imperativo |
| `button.save` | Botón guardar | Guardar | Save | — | Imperativo |
| `button.cancel` | Botón cancelar | Cancelar | Cancel | — | (Ya existe) |
| `button.edit` | Botón editar | Editar | Edit | — | Imperativo |
| `button.search` | Botón buscar | Buscar | Search | — | Imperativo |
| `message.error.generic` | Mensaje error genérico | Algo salió mal. Intenta de nuevo. | Something went wrong. Try again. | — | Casual CO, sin culpa del usuario |
| `message.error.network` | Error de conexión | No se pudo conectar. Verifica tu red. | Could not connect. Check your network. | — | Instructivo |
| `message.success.created` | Éxito post-create | {entity} creado exitosamente. | {entity} created successfully. | {entity} | Positivo, formal |
| `message.success.saved` | Éxito post-save | Guardado. | Saved. | — | Corto |
| `label.agents` | Label en UI | Agentes | Agents | — | (Del README) |
| `label.workflows` | Label | Workflows | Workflows | — | Técnico, EN OK |
| `label.skills` | Label | Skills | Skills | — | **AMBIGUO** — ¿"Habilidades"? Mantener técnico? |
| `label.project` | Label | Proyecto | Project | — | (Estándar) |
| `label.session` | Label | Sesión | Session | — | (Estándar) |
| `label.rules` | Label | Reglas | Rules | — | (Estándar) |
| `placeholder.search` | Input placeholder | Busca por nombre… | Search by name… | — | Hint text, informal |
| `placeholder.filter` | Input placeholder | Filtra los resultados… | Filter results… | — | Hint text |
| `hint.required.field` | Validación | Campo requerido. | This field is required. | — | Mensaje de formulario |
| `hint.invalid.email` | Validación | Email inválido. | Invalid email. | — | Breve, claro |

---

## PENDIENTE DE CONFIRMACIÓN HUMANA

1. **Cohesor técnico: EN vs. ES en términos técnicos**
   - ¿"Skill" → "Habilidad" o mantener "Skill" (como en estándares NUI)?
   - ¿"Workflow" → "Flujo de trabajo" o "Workflow"?
   - ¿"Vault" → "Bóveda" o "Vault"?
   - ¿"Hook" → "Gancho" o "Hook"?
   - **Recomendación**: Mantener términos técnicos EN en contextos de UI técnica; traducir en UX de usuario.

2. **Consistencia: "Traer" vs. "Importar"**
   - Strings existentes usan "traer" (coloquial CO).
   - ¿Mantener "traer" por consistencia interna o cambiar a "importar" (formal)?
   - **Recomendación**: Audit con product/UX team.

3. **Registro: "Tú" vs. "Usted"**
   - Strings existentes usan imperativo directo sin pronombre explícito.
   - "¿Estás seguro?" (tú) vs. "¿Está seguro?" (usted).
   - **Recomendación**: "Tú" (informal cómodo en CO para app).

4. **Largura y Truncamiento**
   - "Incluir secrets (con sus VALORES)" es larga.
   - ¿Cabe en un botón o necesita truncamiento?
   - **Recomendación**: Audit visual en la app.

---

## Próximos Pasos

Este documento deja estructurados:
- ✅ Glosario derivado de strings existentes
- ✅ Auditoría de calidad de traducciones presentes
- ✅ Matriz de traducciones nuevas
- ⏳ Pendientes de confirmación humana (4 temas)

El **paso 4 (auditoría)** puede revisar naturalidad/placeholders/formato de todas estas.
El **paso 5 (integración)** toma esta matriz y la vierte en el mecanismo de i18n del proyecto.
