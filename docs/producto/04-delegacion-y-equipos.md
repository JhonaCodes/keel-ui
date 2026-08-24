# 04 — Delegación y equipos

Los miembros de un proyecto declaran su rol, proveedor, modelo, skills, reglas y conocimiento. El preflight elige un **responsable de resolución** que pueda cubrir las capacidades requeridas por el workflow y registra por qué fue apto. No hay un coordinador separado ni una cadena de roles que se ejecute por inercia.

## Responsabilidades en el grafo

Un caso tiene un responsable único de resultado. Cada nodo puede persistir un agente concreto distinto según su capacidad, pero solo hay un escritor principal activo a la vez y el responsable integra la evidencia end-to-end. Una persona puede cubrir más de una capacidad cuando dividirlas no mejora calidad ni velocidad.

Los nodos se conectan por dependencias y por evidencia. Un revisor puede abrir un hallazgo, pero no deja el hallazgo huérfano: este vuelve al responsable, que reformula el nodo afectado y conserva la trazabilidad de la decisión.

## Subagentes

Los subagentes son investigación acotada, inventario de impacto o verificación independiente; no son escritores del workspace. Hay un único escritor por caso, un máximo de dos subagentes por responsable y cada resultado debe quedar sintetizado explícitamente en el nodo padre.

Claude usa su delegación interna cuando el proveedor la admite. Otros proveedores ejecutan el mismo grafo sin delegación invisible. El mapa los muestra debajo de su nodo padre y el inspector conserva pedido, actividad, resultado y síntesis.

## Contexto explícito

Skills, reglas, bases de conocimiento y perfiles expertos no se suponen. El preflight lista los elementos inyectados y los faltantes. Si falta contexto obligatorio, el caso no comienza. Esto evita tanto delegar sin información suficiente como consumir turnos en una estrategia inválida.

## Mapa de razonamiento

La pestaña **Mapa** representa el DAG real, no una grilla de columnas. Cada nodo muestra responsable, estado, dependencias y evidencia. Los gates y hallazgos aparecen como relaciones de calidad; al abrirlos se ve la evidencia que motivó la reformulación. Consultas entre miembros pueden aportar contexto, pero no transfieren automáticamente la propiedad del caso.

## Siguiente paso

Consultá [09 — Flujos operativos](09-flujos-operativos.md) para ejemplos de resolución adaptativa.
