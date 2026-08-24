# F31 — Mapa de resolución

El mapa de una sesión representa el `ResolutionCase` persistido como un grafo
dirigido. Cada nodo de trabajo muestra responsable, estado, evidencia y
dependencias. La posición horizontal indica profundidad de dependencia; no hay
columnas de una secuencia de pasos.

Los nodos preparados con las mismas dependencias pueden aparecer en paralelo.
Una arista continua indica evidencia satisfecha, una tenue una dependencia aún
pendiente y un hallazgo devuelve únicamente el nodo afectado a reformulación.

Los subagentes aparecen debajo de su nodo padre. El inspector conserva el
pedido, actividad, resultado y síntesis del responsable. Solo se permiten para
investigación, inventario o verificación; no escriben el workspace.

La vista conserva el lienzo navegable, zoom, seguimiento del nodo activo y
fichas de inspección del mockup. El contenido visible se construye desde
`ResolutionCase.nodes`, `Finding` y `Evidence`, por lo que un nodo validado
nunca se vuelve a dibujar como trabajo pendiente por un reinicio global.
