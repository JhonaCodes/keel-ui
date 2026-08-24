# F37 — Workflows adaptativos por sesión

## Problema que resuelve

Una cadena fija de roles hacía que el coste creciera con la cantidad de pasos,
no con el trabajo real. Un fallo encontrado por linter o test podía quedar
huérfano: alguien lo veía, pero el flujo seguía hacia roles irrelevantes o
reiniciaba toda la secuencia.

## Decisión

La sesión conserva `workflowId` como referencia al workflow elegido, pero el
workflow declara intención, tipo, responsable, capacidades con ID estable,
contexto obligatorio, gates de calidad y límites de
reformulación/delegación. Cada capacidad define título, instrucción, rol por
defecto, dependencias y activación requerida u opcional. Al comenzar, el motor
crea una `ResolutionCase` solo con las capacidades requeridas; las opcionales
se activan si la evidencia las vuelve necesarias. El estado `disponible` del
riel permite activarlas de forma explícita sin reiniciar el caso.

Los presets de bug, migración y roadmap son plantillas editables, no ramas
codificadas del motor. Modificar una capacidad cambia el workflow compartido;
asignar un agente concreto desde el panel crea un override solo para ese
proyecto. El preflight persiste el `ownerProfileId` resuelto en cada nodo.

En migraciones la matriz modelo, serialización, persistencia, datos existentes,
callers, compatibilidad, pruebas y UI debe cerrarse completa. “No aplica” exige
una justificación.

## Replanificación localizada

Un hallazgo estructurado lleva fuente, resumen y huella. Pausa el nodo
afectado, no el caso entero. La misma huella no puede reintentarse sin un
cambio; dos reformulaciones sin progreso bloquean el caso con la evidencia y
las alternativas concretas.

No existe compatibilidad de ejecución para cadenas heredadas, ni progreso por
índice, ni un control para recorrer el workflow de nuevo.

## Preflight y subagentes

Antes de ejecutar, preflight confirma skills, reglas, bases de conocimiento,
agente por capacidad y credenciales del proveedor. Si algo obligatorio falta,
el caso se bloquea sin gastar tokens. Tanto el contexto inyectado como cada
faltante quedan persistidos en el caso y se dibujan desde esa misma fuente.
Claude puede usar hasta dos subagentes solo para investigación, inventario de
impacto o verificación; el responsable sigue siendo el único escritor y debe
sintetizar sus resultados. Codex usa el mismo grafo sin esa delegación interna.

## Panel derecho

El panel conserva la representación visual del producto a 272 px: encabezado
`WORKFLOW EN CURSO`, progreso, riel y filas con estado, agente, proveedor,
modelo, esfuerzo, consultas, findings y evidencia. Las filas opcionales no
activadas muestran `disponible` y al cerrar, `no requerido`. Debajo aparecen
skills, reglas y conocimiento; los requeridos están identificados y los extras
del proyecto se agregan o quitan ahí mismo. Un nodo corriendo o terminado
queda bloqueado para conservar su trazabilidad.

## Migración de datos guardados

Al detectar configuraciones anteriores, Keel exporta el catálogo crudo completo
con fecha fuera del catálogo activo y reescribe cada workflow conservando su
nombre, contenido y agentes como capacidades. Solo diagnóstico, implementación
y cierre quedan requeridos; las revisiones especializadas quedan disponibles.
El respaldo no es una ruta de ejecución ni un adaptador de compatibilidad.

## Eliminación e integridad referencial

Eliminar un workflow lo quita del catálogo y, en la misma operación, elimina
su ID de los workflows asignados a cada proyecto, del workflow por defecto,
de los overrides por capacidad y de las sesiones que todavía lo nombraban.
Las sesiones conservan mensajes, evidencia y su `ResolutionCase` materializado;
solo pierden la referencia que ya no puede resolverse. Si el proyecto conserva
otros workflows, el primero pasa a ser su nuevo default. Al cargar datos, Keel
también detecta y persiste la limpieza de referencias rotas dejadas por
versiones anteriores.
