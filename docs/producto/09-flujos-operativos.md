# 09 — Flujos operativos

## Escenario 1: bug de tipo

Una sesión abre el workflow de corrección. El preflight asigna un responsable, inserta las reglas Flutter, la skill de pruebas y el conocimiento del proyecto. El responsable crea diagnóstico, implementación y gate de verificación; si el mismo agente puede cubrirlos sin perder independencia, el grafo conserva menos turnos.

El linter encuentra que un valor no corresponde al campo. Keel registra un `Finding` con el diagnóstico y pausa solo el nodo de implementación. El responsable ajusta el alcance, corrige el puente tipado y vuelve a verificar. No reinicia nodos ya validados ni hace recorrer roles irrelevantes. Si la huella del linter aparece de nuevo sin cambio material, el reintento se rechaza como estéril.

## Escenario 2: migración de datos

Una migración inicia con la matriz de impacto. El integrador abre los nodos que requiere la evidencia: inventario de lectores/escritores, adaptación de modelo, persistencia y compatibilidad. La matriz mantiene explícitamente modelo, serialización/API, datos existentes, callers, pruebas y UI.

Una prueba de compatibilidad que falla genera un hallazgo en ese nodo. El integrador decide si corrige el contrato o añade una conversión de datos y deja la decisión documentada. El caso no puede entregarse mientras exista una fila pendiente o una justificación ausente.

## Escenario 3: investigación acotada

El responsable puede abrir hasta dos subagentes para inventariar dependencias o validar una hipótesis. Cada subagente trabaja en alcance de solo lectura; el responsable sintetiza su resultado antes de usarlo en un nodo escritor. El mapa permite inspeccionar el vínculo entre ambos y la evidencia usada.

## Resultado

Un workflow reutiliza su política entre proyectos, pero cada caso ejecuta solo el grafo que su evidencia necesita. El cierre ocurre cuando los gates muestran evidencia real y no quedan hallazgos ni filas pendientes, no porque se haya recorrido una cantidad prefijada de pasos.
