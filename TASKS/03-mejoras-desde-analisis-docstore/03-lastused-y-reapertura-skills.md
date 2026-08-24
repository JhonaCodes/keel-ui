---
estado: libre
titulo: Las skills sugeridas no tienen señal de uso ni se reabren entre proyectos
---

# Las skills sugeridas no tienen señal de uso ni se reabren entre proyectos

## Qué hay que hacer

`PromptInsightsViewModel` (`lib/src/integrations/prompt_insights/prompt_insights.dart`)
ya hace más de lo que Loop 3 (`docs/the-closed-loop.md`, "Disposal") suele encontrar
ausente: un clustering determinista y sin modelo (Jaccard ≥ 0.55, ≥ 3 prompts
similares, ventana de 30 días — constantes en líneas 14-25) sobre el log global de
prompts (`record()` en `projects_viewmodel.dart:1496` y `agents_viewmodel.dart:373`)
que SÍ produce una decisión de enrutamiento automática: cluster nuevo →
una `SkillSuggestion`. Ese paso —"detectar repetición → decisión de enrutamiento →
artefacto persistido"— es exactamente lo que el documento describe como lo
típicamente ausente, y Keel lo tiene.

El mecanismo se detiene ahí, en dos puntos concretos:
1. `scan()` corre UNA vez al instanciar el singleton (`init()`, líneas 34-38) — no hay
   cron ni re-evaluación periódica.
2. Apenas una `signature` se resuelve (creada o descartada), `knownSignatures` la
   excluye **para siempre** (líneas 91-98, 121-135) — nunca se vuelve a evaluar aunque
   el patrón se repita en más proyectos.

Y `Skill`/`Rule` (`lib/src/modules/skills/model/skill.dart:18-59`,
`lib/src/modules/rules/model/rule.dart:15-51`) no tienen ningún campo de "última vez
usado" — `createdAt` es el único timestamp y nunca se actualiza después de creada.
`isGlobal` es un booleano fijado a mano una sola vez al crear/editar
(`skills_viewmodel.dart:56,80`), nunca inferido ni re-decidido.

**Escenario de falla concreto**: el usuario repite un patrón en el Proyecto A; al
tercer prompt similar, el clustering dispara una `SkillSuggestion`. La acepta como
skill de Proyecto A (`isGlobal=false`) porque en ese momento solo la usó ahí. La
signature queda "resuelta" para siempre. Semanas después repite el mismo patrón en
los Proyectos B, C y D — `record()` sigue logueando esos prompts, pero como la
signature ya está resuelta, el clustering nunca vuelve a proponerla, sin importar
cuántos proyectos nuevos la repitan. El usuario termina con 3-4 variantes casi
idénticas creadas a mano en cada proyecto, y como no existe `lastUsed`/`usageCount`,
nadie puede después determinar cuál sigue viva y cuál quedó obsoleta — se acumulan
hasta que el usuario las borre a mano. Es el mismo patrón que el documento midió en el
store del harness (11 de 12 memorias de comportamiento mal ubicadas y nunca
promovidas).

**Nota de honestidad**: esta es la única de las tres ideas sin evidencia de que el
problema YA se manifestó en producción (no hay reporte de duplicados reales ni quejas
de usuario) — es un diagnóstico estructural/preventivo, verificado contra el código,
no contra un incidente. Vale la pena un spike corto contando skills/reglas reales del
usuario antes de invertir en el mecanismo completo.

**Diseño recomendado**:
1. Agregar un campo mínimo de señal de uso a `Skill`/`Rule` (ej. `lastAppliedAt`,
   actualizado cuando la skill se inyecta efectivamente en un contexto de prompt) —
   hoy es estructuralmente imposible distinguir una skill viva de una obsoleta porque
   `createdAt` es estático.
2. Reemplazar el dedup permanente de `knownSignatures` por uno con reapertura
   condicionada: si una signature ya resuelta (creada como skill project-scoped)
   vuelve a aparecer en clusters de OTROS proyectos tras la resolución, disparar una
   señal distinta ("promover a global") en vez de silenciarla para siempre — no
   reabrir ante simple repetición en el mismo proyecto, solo ante evidencia de scope
   ampliado.
3. Tratar `isGlobal` como un boundary con alguna señal (aunque sea una sugerencia no
   bloqueante en la UI), en vez de un booleano mudo fijado una sola vez.

**Riesgo**: cambiar el esquema JSON de `Skill`/`Rule` requiere `fromJson` con
defaults seguros para registros ya persistidos en LMDB vía `LocalDatabase` (no hay
framework de migración descripto — confirmar cómo se manejan otros cambios de esquema
en este repo antes de tocar esto). Reabrir signatures ya resueltas puede reintroducir
fatiga de sugerencias que el dedup permanente evitaba a propósito — la política de
reapertura tiene que ser conservadora (multi-proyecto, no repetición simple).

## Bloqueantes

Ninguno, pero conviene el spike de conteo real (ver "Nota de honestidad") antes de
escribir código.

## Criterio de aceptación

- [ ] Spike: contar cuántas skills/reglas del usuario real son duplicados
      casi-idénticos entre proyectos, para confirmar que el problema no es solo
      hipotético antes de invertir esfuerzo medio.
- [ ] `Skill` y `Rule` ganan un campo de última vez usado, con `fromJson`
      retrocompatible (default seguro para registros ya persistidos en LMDB).
- [ ] Una signature ya resuelta como skill project-scoped se reabre (con una señal
      distinta, no la misma sugerencia) si el mismo patrón aparece en un
      segundo/tercer proyecto — nunca ante simple repetición en el mismo proyecto.
- [ ] Test que reproduzca el escenario de falla (misma signature en 3 proyectos) y
      confirme que ahora SÍ se propone promoción a global.
- [ ] Regresión: una signature descartada por el usuario sigue sin volver a
      proponerse dentro del mismo proyecto.
