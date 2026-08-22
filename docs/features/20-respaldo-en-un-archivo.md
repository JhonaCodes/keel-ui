# F20 — Respaldo en un archivo

## Qué problema resuelve

El respaldo del sistema (F21) es TODO-o-nada, va siempre a la carpeta del
vault y nunca lleva los valores de los secrets, porque ese repo se sube.
Faltaba la otra mitad: "quiero llevarme ESTO a otra máquina en un archivo" —
elegir qué, ver qué pisa antes de aplicar, que el conocimiento viaje con su
contenido, y poder mover credenciales entre máquinas propias.

## Qué es

`Configuración → Respaldo en un archivo`, dos paneles laterales:

- **Exportar**: checkboxes por sección (skills, reglas, tools, workflows,
  MCPs, bases de saber, agentes, estaciones) y un opt-in aparte para
  secrets. Elegís destino con el diálogo del sistema y sale UN `.json`.
- **Importar**: elegís el archivo, la app lo INSPECCIONA y muestra qué trae
  y qué pisa ("Skills: 12 en el archivo, 3 pisan existentes: …") con
  checkboxes por sección presentes en el archivo. Recién ahí "Aplicar lo
  seleccionado".

## La forma es la del catálogo git — a propósito

`catalog_shape` expone su serialización como `catalogAsJson()` y su merge
por nombre como `mergeCatalogJson()`; el respaldo los reusa tal cual. Dos
destinos (el zip del vault / un solo JSON), UNA forma — dos copias de "cómo
se serializa un perfil" divergiendo en silencio es exactamente lo que no
puede pasar. Mismas reglas de siempre: referencias por NOMBRE, merge
crea-o-actualiza, rutas de trabajo y tareas jamás viajan, el mapa de Keel
AI tampoco (se recompila en cada arranque).

## Lo que el vault nunca lleva y este archivo sí

- **Documentos de saber**: con la sección "Bases de saber" viajan los
  archivos de cada base LOCAL con carpeta (ruta relativa → contenido; los
  ocultos y lo que pase de 256KB quedan afuera; una base git no viaja — su
  contenido se recupera clonando). Al importar se escriben SOLO en bases
  que ya tienen carpeta en esta máquina — las rutas no viajan y no se
  inventan: una base sin carpeta queda anotada en el resultado ("asignale
  una y volvé a importar"). Después de escribir, la base se reindexa.
- **Secrets con sus VALORES, solo por decisión explícita** — y este es el
  único camino que los lleva, porque el vault jamás los sube: el checkbox lo dice sin
  eufemismos — el archivo lleva los VALORES en texto plano; es para mover
  credenciales entre máquinas propias, nunca para compartir. Al importar:
  se crean los que falten y se completa el valor SOLO de los que acá están
  pendientes. Un secret local con valor nunca se pisa desde un archivo.

## Verificación

1. Exportar todo → borrar una skill → importar solo Skills → la skill
   vuelve idéntica y nada más cambió.
2. Import selectivo: destildar una sección presente en el archivo → esa
   sección no se toca.
3. Sin el opt-in de secrets, el JSON exportado no contiene la clave
   `secrets`; con él, el resultado lo advierte.
4. El preview nombra los elementos que pisarían existentes antes de aplicar.
