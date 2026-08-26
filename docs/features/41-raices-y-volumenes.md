# F41 — Otros discos, y dónde están tus proyectos

## Qué problema resuelve

La app asumía un solo lugar: el disco de arranque.

- El selector de carpeta abría donde el sistema quisiera —la carpeta de
  usuario— así que quien tiene los proyectos en otra partición navegaba el
  árbol entero cada vez que creaba un proyecto o una base de saber.
- Un agente 1:1 —y Keel AI— corre con el directorio de trabajo en `$HOME`,
  porque no tiene proyecto asignado. Pedirle «mirá el proyecto tal» lo
  mandaba a buscar donde no está: recorría la carpeta de usuario, no
  encontraba nada, y concluía que el proyecto no existe o inventaba una ruta.

Con los proyectos en `/Volumes/Data`, `D:\` o un disco externo, las dos cosas
fallan por la misma razón: nadie le dijo a nadie dónde están.

## Dos listas, y ninguna adivina

**Los volúmenes montados** se le preguntan al sistema operativo, y cada uno
los expone en otro lado: macOS bajo `/Volumes`, Linux bajo `/media/$USER`,
`/run/media/$USER` o `/mnt`, Windows como letras de unidad. Se prueban las 26
letras y que exista decida — preguntar sale más barato que cualquier API. Es
lo que existe *ahora*, no lo que se supone.

**Las raíces conocidas** son las carpetas que este usuario usó, ordenadas por
uso y guardadas en la base local. Se alimentan solas de dos lados: cada
carpeta elegida en un selector, y el directorio de trabajo de cada proyecto.
Nadie las administra a mano. Se guardan hasta 30 — es una lista para elegir,
no un historial.

Una ruta que ya no existe no se anota: la lista sirve para ofrecer lugares a
los que se puede ir, y un disco desmontado no es uno.

## Para qué se usan

1. **Todo selector de carpeta** abre en la última que usaste, en vez del
   default del sistema.
2. **El `/` del compositor** sin proyecto ([F40](40-referencias-en-todos-los-chats.md))
   ofrece esas raíces.
3. **El prompt de un agente sin proyecto** lleva una sección con los
   proyectos registrados y su ruta absoluta, y le dice explícitamente que
   pueden estar en otro disco. Si lo que le piden no está en ninguna,
   pregunta en vez de recorrer el disco.

En una sesión de proyecto esa sección no hace falta: ahí el turno ya corre
parado en la carpeta correcta.

## La clave de una raíz no es la ruta

Una ruta trae barras, dos puntos, espacios y acentos, y una clave de base no
es lugar para nada de eso. Se guarda un slug legible más una huella FNV-1a de
la ruta completa: dos carpetas que se llaman igual en discos distintos no se
pisan, y la clave es la misma en la próxima corrida — `String.hashCode` no lo
garantiza, y una clave que cambia al reabrir la app es una fila duplicada por
arranque.

## Verificación

1. Crear un proyecto eligiendo una carpeta en otro volumen; crear otro: el
   selector abre ahí y no en la carpeta de usuario.
2. Preguntarle a un agente 1:1 por ese proyecto: usa la ruta absoluta sin
   salir a buscar.
3. Con `/` en el chat de Keel AI, el proyecto de ese volumen aparece.
4. Desmontar el disco y reabrir la app: la ruta deja de ofrecerse.
