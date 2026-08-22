# F10 — Sugerencias de skills recurrentes

## Qué es

Detección DETERMINISTA (cero tokens, ningún modelo) de pedidos que el
usuario repite, con propuesta de convertirlos en skill global.

## Mecánica (`integrations/prompt_insights/`)

1. Cada prompt del usuario (chats 1:1 y canal de proyecto; nunca los
   auto-retries) se registra normalizado: minúsculas, sin acentos ni
   puntuación, sin stopwords ES/EN, tokens >2 chars. Log con tope FIFO de
   500 entradas (`promptlog_`).
2. Al arrancar (y tras cada registro relevante) corre un clustering greedy
   por similitud de Jaccard (umbral 0.55) sobre la ventana de 30 días. Un
   cluster con ≥3 pedidos genera una `SkillSuggestion` con firma estable
   (top tokens) — una firma descartada no se vuelve a proponer jamás.
3. UI: banda en la pantalla de Skills con hasta 3 sugerencias pendientes:
   "N× · «ejemplo»" + **Crear skill** (abre el formulario prefillado como
   GLOBAL con las muestras como borrador) o **Descartar**.

## Rol de Keel AI

Ninguno en la detección (es determinista a propósito). El seed le cuenta
que el sistema sugiere, para que pueda redactar el contenido definitivo con
`create_skill(global: true)` si el usuario se lo pide.
