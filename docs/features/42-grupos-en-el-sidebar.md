# F42 — Acomodar el sidebar: grupos y orden

## Qué problema resuelve

Las tres listas del sidebar —proyectos, requerimientos y agentes sueltos—
mostraban lo que había en el orden en que se había creado, y nada más. Con
diez proyectos y veinte agentes, encontrar uno es leer la lista entera; y las
cosas que en la cabeza del usuario van juntas —los tres repos de un cliente,
los agentes de un experimento— quedaban desparramadas entre las demás.

Ahora se pueden **juntar arrastrando** y **ordenar a mano**, en las tres
secciones, con el mismo gesto.

## Un gesto, dos significados

Arrastrar tiene que poder hacer dos cosas distintas sin que haya que elegir
antes cuál. Lo que las separa es **dónde** se suelta dentro de la fila:

| Dónde se suelta | Qué pasa | Qué se ve antes de soltar |
|---|---|---|
| Cuarto de arriba | entra antes | una línea arriba |
| Cuarto de abajo | entra después | una línea abajo |
| Mitad del medio, sobre un ítem | nace un grupo con los dos | la fila se ilumina |
| Mitad del medio, sobre un grupo | se suma a ese grupo | la fila se ilumina |
| Sobre el título de la sección | sale del grupo, a la raíz | el título se ilumina |

Un grupo se renombra con **doble click** —el mismo `InlineRenameField` que ya
renombraba un proyecto o una sesión—, se pliega con el galón, y se deshace
con **click derecho**.

## Las reglas que sostienen todo

**Un solo nivel.** Un grupo no entra en otro. Con anidado, mover algo deja de
tener un significado único y la lista se vuelve un árbol que hay que navegar
en vez de una lista que se lee. Arrastrar un grupo sobre otro lo ordena
detrás; no lo mete adentro.

**Un grupo con menos de dos miembros se disuelve solo**, y el que sobra vuelve
a la raíz en el lugar donde estaba el grupo. Un grupo nace de juntar dos
cosas; con una sola adentro ya no agrupa nada y sería el resto de una mudanza,
no una decisión.

**Las secciones no se mezclan.** Lo que se arrastra lleva adentro de qué
sección salió, así que soltar un proyecto sobre un agente no hace nada.

## Lo que se guarda, y por qué así

Un registro por sección (`sidebar_layout_project`, `…_requirement`,
`…_agent`), con la lista de lugares en orden: cada lugar es un ítem suelto o
un grupo con sus miembros ordenados.

No es un `groupId` en `Project`, `InternalRequirement` y `Agent`: serían tres
modelos, tres repositorios y tres `toJson` para expresar una cosa que es **de
la vista**. Además el repositorio de requerimientos reordena por fecha al
cargar y el de agentes no garantiza orden ninguno, así que un campo por ítem
tendría que pelearse con los dos.

**La disposición es una pista; el catálogo es la verdad.** Al dibujar se
reconcilia: un ítem que existe y no figura aparece igual, al final de su
sección; uno que figura y ya no existe se descarta. Sin esa regla, una
disposición vieja podría esconder un proyecto real — la única forma en que
esto podría hacer daño.

El pliegue de un grupo **sí** se persiste, al revés que el de Tableros o
Sesiones: esos son del proyecto abierto, hay uno solo a la vez, y un grupo que
se despliega solo en cada arranque no sirve para ordenar nada.

## Qué NO se toca

Las secciones de adentro de un proyecto —Estado, Tableros, Sesiones— no son
ítems de una lista: son las partes del proyecto abierto. Cuelgan de la fila
del proyecto pero quedan fuera de la zona de arrastre, porque soltar algo
sobre «Sesiones» no significa nada.

## Verificación

1. Arrastrar un proyecto sobre otro: aparece el grupo con los dos adentro.
2. Doble click en el nombre del grupo: se renombra ahí mismo; vacío se rechaza
   sin cerrar la edición.
3. El galón lo pliega y lo despliega; cerrar y reabrir la app lo conserva.
4. Arrastrar al borde de una fila reordena en vez de agrupar.
5. Arrastrar un miembro al título de la sección lo saca del grupo; si era el
   anteúltimo, el grupo desaparece.
6. Lo mismo, igual, en requerimientos y en agentes sueltos.
7. Borrar un proyecto agrupado no esconde a los demás.
