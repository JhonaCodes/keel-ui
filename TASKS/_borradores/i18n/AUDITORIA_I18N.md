# Auditoría de Calidad I18N — Keel UI
**Paso 4/6 · Naturalidad, terminología, tono, placeholders/ICU, formato localizado, longitud**

Audita `TRADUCCIONES_PROPUESTAS.md` (existentes + matriz nueva) contra los
seis criterios. No repite lo ya declarado como pendiente de confirmación
humana por el traductor (Skill/Workflow/Vault/Hook EN vs ES, "traer" vs
"importar", tú vs usted, longitud de "Incluir secrets (con sus VALORES)").

## Nota de proceso

`INVENTARIO_STRINGS_KEEL_UI.md` (paso 2, analista) no existe en `docs/` —
la matriz del traductor se armó igual, mapeando el código directamente.
No es bloqueante para esta auditoría, pero el integrador (paso 5) va a
necesitar ese inventario o esta misma matriz como única fuente.

## Hallazgos

### 1. `message.success.created` — ES-CO — Criterio 1 (Naturalidad / concordancia de género)
**Actual**: `{entity} creado exitosamente.`
**Problema**: "creado" es masculino fijo, pero `{entity}` es una variable
que en el dominio del proyecto toma valores mayormente femeninos:
"Sesión", "Regla", "Skill" (uso habitual "la skill" en el glosario propio),
"Base de saber". Con esos valores el mensaje sale mal concordado:
"Sesión creado", "Regla creado".
**Corrección propuesta**: evitar el participio con género. Reformular sin
concordancia dependiente del sustantivo:
`{entity} — creado.` no resuelve el problema (mismo género fijo). Mejor:
`{entity} creado/a.` no es válido en UI. Usar una construcción neutra:
`Se creó: {entity}` o `{entity} listo.` ("listo" también concuerda mal:
"Sesión listo"). Recomendación real: `{entity} — creación exitosa.` (el
sustantivo "creación" no cambia con el género de `{entity}`), o resolver
el género en la fuente de datos (pasar `{entity}` ya con su artículo/
participio correcto desde el código, ej. `{entityCreatedMessage}`).
**Nota**: esto lo tiene que resolver el paso 5 (integración) porque
depende de cómo el código arma el placeholder — la traducción sola no
puede arreglarlo sin ese dato.

### 2. Ejemplos de plurales del glosario — ES-CO — Criterio 4 (Placeholders/ICU) y Criterio 5 (formato localizado/plurales)
**Actual** (`GLOSARIO_I18N.md`, sección "Plurales y Contextos Variables"):
```
1 agent      → 1 agente
2+ agents    → {count} agentes
{n} sessions found → {count} sesiones encontradas
```
**Problema**: dos fallas simultáneas.
(a) El placeholder original es `{n}` y la traducción lo renombra a
`{count}`. Un placeholder es un identificador exacto que el motor de i18n
interpola desde el código — renombrarlo rompe la interpolación en runtime
si el código sigue emitiendo `{n}`. No es una decisión de traducción, es
un placeholder roto.
(b) Los ejemplos no están en sintaxis ICU real pese a que el glosario dice
"usar `{count, plural, one {...} other {...}}}`". Tal como están escritos
son texto plano con una regla plural implícita, no ejecutable.
**Corrección propuesta**: mantener el nombre de placeholder exacto del
origen y usar ICU real:
```
{n, plural, one {1 agente} other {{n} agentes}}
{n, plural, one {1 sesión encontrada} other {{n} sesiones encontradas}}
```
Si el proyecto usa Flutter `intl` con ARB, el placeholder va también
declarado en los metadatos `@key` del ARB — eso es tarea del paso 5, pero
la traducción debe partir del nombre real, no de uno inventado.

### 3. `"Listo — entrar"` → `"Ready — Enter"` — EN — Criterio 1 (Naturalidad)
**Actual**: `Ready — Enter`
**Problema**: en inglés, "Enter" después de un em dash en un botón se lee
como referencia a la tecla Enter del teclado, no como verbo de acción
("entrar a la sesión"). No es la lectura natural que sí tiene el original
en español.
**Corrección propuesta**: `All set — continue` o `Ready to continue`.

### 4. `hint.required.field` / `hint.invalid.email` — ES-CO vs EN — Criterio 1 (registro)
**Actual**: ES `Campo requerido.` / `Email inválido.` (fragmento nominal)
vs EN `This field is required.` / `Invalid email.` (oración completa /
fragmento — inconsistente entre sí también en inglés: la primera es
oración completa, la segunda es fragmento).
**Problema**: menor, pero vale nivelar el registro entre los tres textos
para que no varíe la formalidad dentro del mismo tipo de mensaje
(validación de formulario).
**Corrección propuesta**: uniformar como fragmentos cortos en los dos
idiomas — `Campo requerido.` / `Field required.` y `Email inválido.` /
`Invalid email.` — o como oraciones completas en los dos. Prioridad baja,
no bloquea longitud, no bloquea colocación en UI de las de validación.

## Confirmaciones (sin hallazgo)

- **Registro tú/CO sin voseo**: revisadas todas las formas verbales
  nuevas ("Verifica", "Intenta", "Busca", "Filtra") — ninguna usa voseo
  argentino ("verificá", "intentá"). Cumple el requisito explícito del
  usuario.
- **Placeholders de la matriz nueva** (`{entity}` en `button.create.new` y
  `message.success.created`, aparte del hallazgo #1 de concordancia): el
  nombre del placeholder se preserva igual en ES y EN en todos los casos.
- **Formato localizado (fechas/números/moneda)**: no hay strings de este
  tipo en la matriz auditada — N/A, confirmado.
- **Longitud**: fuera de lo ya marcado pendiente por el traductor, el
  resto de botones/labels nuevos son cortos (1–3 palabras) y no presentan
  riesgo de overflow.

## Resumen para el paso 5 (integración)

4 hallazgos nuevos: 1 de concordancia de género (requiere decisión de
implementación, no solo texto), 1 de placeholder roto + formato ICU no
ejecutable, 1 de naturalidad en inglés, 1 menor de consistencia de
registro. Los 4 pendientes de confirmación humana que dejó el traductor
siguen abiertos y no se repiten acá.
