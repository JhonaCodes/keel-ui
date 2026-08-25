# F31 — Mapa de resolución

El mapa de una sesión representa el `ResolutionCase` persistido como un grafo
dirigido. Su tronco contiene exclusivamente los `WorkNode` del workflow, desde
el pedido hasta el cierre. Los demás miembros del proyecto no se dibujan como
etapas potenciales: aparecen únicamente cuando participaron de una consulta.
Cada nodo de trabajo muestra responsable, estado, evidencia y dependencias.

Los nodos preparados con las mismas dependencias pueden aparecer en paralelo.
Una arista continua indica evidencia satisfecha, una tenue una dependencia aún
pendiente y un hallazgo devuelve únicamente el nodo afectado a reformulación.

Cada `WorkNode` tiene su propio árbol debajo. Una consulta a otro agente nace
del nodo que la originó y una consulta encadenada nace de la consulta anterior.
Los subagentes aparecen debajo del turno que los abrió, sea el trabajo
principal o una consulta. El inspector conserva pedido, actividad, resultado y
síntesis. Solo se permiten para investigación, inventario o verificación; no
escriben el workspace.

La vista conserva el lienzo navegable, zoom, seguimiento del nodo activo y
fichas de inspección del mockup. El contenido visible se construye desde
`ResolutionCase.nodes`, `Finding` y `Evidence`, por lo que un nodo validado
nunca se vuelve a dibujar como trabajo pendiente por un reinicio global.
