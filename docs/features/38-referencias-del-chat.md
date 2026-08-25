# F38 — Referencias explícitas en el chat de una sesión

## Qué problema resuelve

Escribir “mirá la carpeta”, “usá la skill” o “consultá el saber” obliga al
agente a adivinar nombres y ubicaciones. También era imposible dirigir un
mensaje a un miembro concreto del proyecto desde el mismo composer.

El chat de las sesiones reconoce cuatro prefijos en cualquier posición del
mensaje y filtra el catálogo mientras se escribe:

| Prefijo | Catálogo | Ejemplo |
|---|---|---|
| `/` | Directorios dentro del proyecto | `/lib/src` |
| `@` | Agentes miembros de esa sesión/proyecto | `@flutter-expert` |
| `$` | Skills y reglas registradas | `$tdd-workflow` |
| `#` | Bases y documentos de Saber | `#arquitectura/decisiones.md` |

Flecha arriba/abajo cambia la opción, Enter o Tab la inserta y Escape cierra
la lista. También se puede seleccionar con mouse. Una leyenda compacta debajo
del composer mantiene los comandos visibles.

## Qué se persiste

Las referencias a directorios, skills, reglas y Saber se guardan como enlaces
Markdown legibles cuyo destino es un URI tipado `keel://`. El usuario ve el
nombre elegido y el runtime conserva el ID o la ruta exacta. Así, dos recursos
con nombres parecidos no se confunden y un mensaje en espera conserva la misma
referencia hasta que se envía.

Una mención `@agente` es texto legible porque el agente ya está limitado a los
miembros resueltos del proyecto. En un seguimiento, esa mención elige quién
recibe el próximo turno. En el primer mensaje no salta el preflight ni el
workflow: solo participa en la resolución normal de responsables.

## Cómo llega al turno

Antes de abrir el proceso del proveedor, Keel resuelve únicamente los enlaces
explícitos del mensaje:

- un directorio aporta su ruta absoluta dentro del working directory;
- una skill o regla aporta el contenido registrado actualmente;
- una base de Saber aporta su brief;
- un documento de texto de Saber aporta su contenido y uno binario aporta su
  ruta para que una herramienta compatible pueda leerlo.

Ese contexto se adjunta a ese turno, no modifica permanentemente el proyecto
ni el workflow. Los enlaces borrados, inválidos o manipulados se ignoran.

## Límites de seguridad y costo

- Los directorios se descubren solo debajo del proyecto, sin seguir enlaces
  simbólicos y omitiendo carpetas pesadas como `.git`, `build` y
  `node_modules`.
- Una ruta que intenta escapar con `..` nunca entra al prompt.
- Cada recurso y la suma total tienen límites de tamaño para no consumir el
  contexto completo con una sola mención.
- Solo los miembros efectivos aparecen con `@`; escribir el nombre de un
  agente de otro proyecto no lo incorpora ni lo ejecuta.
- Las menciones dentro de código inline o bloques de código no cambian el
  responsable del turno.

## Verificación

1. Escribir cada prefijo abre su catálogo y filtra por nombre o descripción.
2. Elegir una opción reemplaza solo el token activo y deja el cursor después.
3. Las referencias funcionan en medio de un mensaje y sobreviven en la cola.
4. El prompt contiene los recursos elegidos, pero no rutas fuera del proyecto.
5. `@miembro` dirige un seguimiento; una mención en código o a un no-miembro
   no cambia el responsable.
