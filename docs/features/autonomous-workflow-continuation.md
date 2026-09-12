# Continuidad autónoma entre roles

## Pedido y plan

Un plan debe conducir a la implementación y a la verificación sin que el
usuario vuelva a escribir «inicia la implementación». Los agentes consultan
por especialidad y retoman su contrato con las respuestas. La captura es
evidencia del problema, no un pedido para modificar el proyecto Rust mostrado.

1. Reproducir el recorrido desde `sendToChannel` hasta un archivo implementado
   y auditado, con un solo mensaje humano.
2. Separar avance de cierre y conservar contexto, ejecución y resultado al
   consultar a otro rol.
3. Mantener decisiones humanas, presupuestos y cuotas configuradas.
4. Verificar la regresión, compilar macOS y agregar la prueba a Actions.

## Especialización, contexto compartido y planificación visual

- Los prompts de colaboración y continuidad usan español neutro. La identidad
  incluye una regla de idioma común para los proveedores del proyecto.
- Antes de una decisión que requiera otra especialidad, el agente debe consultar
  al experto correspondiente o reutilizar su evidencia previa. Una consulta
  incluye objetivo, archivos/contexto, pregunta y resultado esperado; la respuesta
  debe distinguir evidencia, objeciones, incertidumbres y recomendación.
- Los especialistas nuevos necesitan rol, propósito e instrucciones. El bloque
  `agente` admite `skills`, valida los nombres y contenidos contra el catálogo y
  las asigna al perfil. Se rechazan declaraciones incompletas o skills inexistentes.
  Los perfiles existentes se reutilizan con su configuración conservada.
- Cada nodo recibe el reparto del workflow: responsables concretos, encargos,
  dependencias, contratos de salida y skills asignadas. El traspaso exige archivos,
  verificaciones, decisiones y pendientes para el siguiente responsable.
- La delegación nativa exige especialidad, skills aplicables, pregunta, evidencia
  y contrato de respuesta en cada encargo; conserva las cuotas y permisos vigentes.
- Toda planificación solicita Mermaid con la lógica de la solución. La herramienta
  `set_session_plan` exige `logic_mermaid`; los proveedores también pueden entregar
  bloques `plan`, `mermaid` y `cumplido`, que se aplican al estado de la sesión.
  Planes y replanificaciones conservan el diagrama en sus mensajes históricos.
  Los clientes antiguos que omiten la lógica reciben un mapa de responsabilidades
  identificado como tal, sin inventar dependencias o decisiones del dominio.

Validación ampliada: **160 pruebas del área correctas**, más la integración por
proceso ejecutada mediante su wrapper. El especialista de la fixture se crea
durante la conversación y solo responde correctamente si recibe la skill real.
Se verifica el rechazo de dos declaraciones inválidas, el reparto del workflow,
el plan guardado y su finalización. Retirar temporalmente la asignación de skills
rompe la integración por falta del archivo implementado; la mutación fue restaurada.
Una prueba de widget verifica que la replanificación sobreviva a JSON y llegue al
componente `MermaidDiagram` del hilo, sin sustituirlo por texto plano. La generación
de la imagen sigue usando el servicio Mermaid existente.

## Contrato de prueba y auditoría

| Disparador / riesgo | Resultado observable | Evidencia |
| --- | --- | --- |
| Implementador responde solamente con un avance | Continúa con el plan y el avance anterior | Integración por proceso: produce `implementation.txt` sin otro mensaje humano |
| Consulta a un especialista | Vuelve a la misma ejecución con contrato y respuesta; el motor recibe su resultado | Fixture exige `--resume fake-implementer`, contexto y salida `in_progress` |
| Queda trabajo después de la consulta | Se reanuda; la auditoría espera a la implementación | Archivo validado y caso terminado, siete turnos de cuatro roles |
| Una corrección aún está en progreso | No resuelve el hallazgo ni pide intervención humana | `resolution_engine_test`: parseo, JSON, `pending`, hallazgo conservado y posterior GO |
| Presupuesto finito | Cada llamada recibe el remanente actualizado | Siete llamadas: 20, 19.5, 19, 18.5, 18, 17.5 y 17 USD; consumo simulado total 3.5 |
| Pausas, Stop y cuotas existentes | Se conserva su semántica | Regresión de proyectos, workflows y prompts: 150 pruebas correctas |

La causa raíz era doble: el seguimiento prohibía herramientas y convertía
prosa en `done`; además, el motor descartaba el resultado posterior a la
consulta y el agente retomaba con otra identidad de ejecución.

## Validación del 13 de septiembre de 2026

- **RED causal:** el test de proceso, antes del cambio, falló porque no
  existía la implementación; el auditor recibió un trabajo sin realizar.
- **GREEN:** `test/run_workflow_continuation.sh` pasa con el motor, ViewModel,
  isolates y procesos reales. El proveedor es una fixture, no un LLM real.
- **Contrafactual:** descartar temporalmente el resultado de la consulta
  vuelve a romper el mismo test por falta del archivo. Mutación restaurada.
- `TZ=UTC flutter test --no-pub test/projects test/workflows test/system_prompt`:
  **150 correctos**, una prueba omitida que se ejecuta mediante el wrapper
  anterior para aislar el CLI real del usuario.
- Suite ampliada con `test/workspace`: **207 correctos y 11 fallos previos**
  en el setup de `session_workflow_test.dart:72` (`Bad state: No element`).
  Los 11 se reprodujeron sobre `775499b`, antes del cambio.
- Análisis de los archivos Dart modificados: **sin diagnósticos**.
  `flutter analyze` completo: **178 diagnósticos previos, cero nuevos**;
  comparación por mensaje, archivo y cantidad contra `775499b`.
- `flutter build macos --debug --no-pub`: correcto. Artefacto:
  `build/macos/Build/Products/Debug/Keel.app`.
- ShellCheck, sintaxis Bash, parseo YAML y `git diff --check`: correctos.

## Evaluación

Estimación de revisión, no porcentaje de cobertura medido:

| Métrica | Confianza | Sustento |
| --- | --- | --- |
| Arquitectura | 95% | Transiciones en servicio puro y ejecución en ViewModel; sin lógica en widgets |
| Estándares | 95% | Estado tipado, serialización y ReactiveNotifier existentes |
| Cobertura útil | 90% | RED/GREEN causal y mutación en el borde proceso/protocolo |
| Riesgo de regresión | 90% | Regresión del área y comparación con baseline |
| Seguridad | 90% | Conserva pausas y ámbito de consulta; verifica remanente de costo |
| Lint del cambio | 100% | Sin diagnósticos en los archivos modificados |

**GO para la corrección local.** Confianza global estimada: 90%.
Riesgo medio: la obediencia de un proveedor real al contrato de salida sigue
dependiendo del modelo; esta prueba valida la orquestación determinista.
Los fallos de setup y avisos previos impiden declarar verde toda la base.
La compilación local está lista; este cambio no corresponde a una nueva
versión publicada en GitHub Releases.
