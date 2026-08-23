# F29 — Tableros: la UI que arma un agente y disparás vos

## Qué problema resuelve

Probar tu propia app mientras la escribís es escribir el mismo `curl` a mano,
con el mismo token que venció, la vigésima vez. Y las cosas que no son un
`curl` —mandarte una notificación de FCM para ver qué hace el teléfono— son
peores todavía.

Un **tablero** es una pantallita para eso: campos arriba, botones en el
medio, la respuesta abajo.

## «GenUI» acá es un patrón, no un SDK

Ninguna dependencia nueva, ninguna llamada a un servicio, nada de Gemini.

El que genera la interfaz es **un agente de los que ya tenés registrados** —el
miembro del proyecto, en una sesión normal— leyendo tu código o tu OpenAPI y
escribiendo una especificación por una tool MCP local. La app la renderiza
con widgets de Flutter de verdad.

Es la misma forma que usa todo lo demás acá: el modelo describe, la app
ejecuta. Por eso un tablero se puede leer, versionar, respaldar y corregir a
mano. No es una pantalla opaca que devolvió un servicio: es data.

## Qué tiene adentro

```
Board
├── fields[]     lo que ponés vos antes de disparar
│                texto | multilinea | numero | booleano | opcion | json | secreto
└── actions[]    los botones
    └── steps[]  qué pasa cuando apretás
        ├── http     method, url, headers, body
        ├── comando  command, args
        └── captures qué se guarda para el paso siguiente
```

Las plantillas son `{{clave}}` y valen en la URL, los headers, el cuerpo, el
comando y cada argumento. Lo que va a la URL se codifica; lo que va al cuerpo
o a un header, no — es la diferencia entre un `&` que separa parámetros y un
`&` que es parte de un nombre.

Un argumento se resuelve **entero y por separado**: un valor con espacios
sigue siendo un argumento, que es justamente lo que pasar por una shell
rompería.

### Los pasos encadenados, y por qué existen

El caso que rompe la versión simple es el push. Mandar una notificación de
FCM pide un token de acceso que sale de un comando y **vence en una hora**.
Con un solo pedido HTTP, la respuesta es pegar un token nuevo cada vez.

```
1  comando   gcloud auth print-access-token
             └─ guarda la salida en {{token}}
2  HTTP      POST .../messages:send
             Authorization: Bearer {{token}}
             └─ guarda {{name}} del cuerpo de la respuesta
3  comando   adb logcat -d -s FirebaseMessaging -t 20
```

Una corrida **se corta en el primer paso que falla**. El paso 2 casi siempre
usa lo que capturó el 1, así que seguir sería disparar un pedido con un token
vacío contra tu API: mejor un error corto que una consecuencia larga.

Una captura que no encuentra nada, en cambio, **no voltea la corrida**: el
paso siguiente va a fallar por la clave que falta, y ese error dice más.

## El agente arma; vos disparás

`lib/src/integrations/boards_mcp/` sirve cinco tools, todas de definición:
`list_boards`, `get_board`, `create_board`, `update_board`, `delete_board`.
El alcance sale de la URL (`/boards/<proyecto>/<sesión>/<perfil>`), igual que
el plan, el roadmap y los requerimientos: un turno no puede nombrar un
proyecto que no es el suyo.

**No hay `run_board`, y no es un olvido.** Un tablero dispara pedidos reales
contra tu API y comandos en tu máquina; que eso salga de una decisión tuya, y
no de un turno que se entusiasmó a las tres de la mañana, es la única línea
que lo hace usable.

Los pasos de comando se muestran enteros antes de correr y se confirman **la
primera vez por acción**, no en cada disparo: un diálogo que aparece siempre
se aprieta sin leer.

Un turno de consulta tampoco recibe estas tools: viene a contestar una
pregunta y se va, y dejarle armar una UI en el proyecto de otro es
exactamente la clase de efecto lateral que una consulta no debería tener.

## La frontera

`parseBoardSpec` es el único camino por el que un tablero entra al sistema —
desde el agente y desde el formulario, que edita la misma especificación y
recibe los mismos errores.

La validación que más paga: **toda `{{clave}}` tiene que ser un campo del
tablero o algo que capturó un paso ANTERIOR**. Sin eso el tablero se guarda
prolijo y explota recién cuando lo apretás.

Una clave que falta al correr es un error con su nombre adentro y corta antes
de salir a la red. La alternativa —mandar `{{campo}}` literal— llega a tu API
como un pedido raro y te hace buscar del lado equivocado media hora.

## Dónde vive

En el **sidebar, bajo su proyecto**, entre Estado y las sesiones. Un tablero
prueba la API de ESE repo: sacarlo del proyecto sería pedirte que te acuerdes
a cuál pertenece. Se abre en el área central, donde va el chat.

En el riel está **Banco**, para verlos todos entre proyectos y ordenarlos.

## Qué viaja y qué no

| | Viaja en el respaldo | Por qué |
|---|---|---|
| La definición del tablero | Sí | Es lo mismo que una skill o un workflow |
| Las últimas 20 corridas | No | Lo que contestó tu API de dev no le sirve a nadie |
| El valor de los secrets | No | Se referencian por nombre, como en todos lados |

Un proyecto que se borra **se lleva sus tableros**, al revés que los
requerimientos: sin su directorio de trabajo no prueban nada, y dejar un
botón que dispara contra algo que ya no seguís es peor que no tenerlo.

## Verificación

1. Pedirle a un agente del proyecto un tablero para un endpoint → aparece en
   el sidebar mientras el agente todavía está escribiendo.
2. Correrlo → estado, tiempo y cuerpo formateado.
3. Un tablero de dos pasos: `echo hola` captura `saludo`, el paso 2 lo manda
   en el body → llega `hola`.
4. Un `{{campo}}` que no existe → el error nombra la clave y no sale a la red.
5. Un 4xx corta: el paso siguiente no corre.
6. Una acción con comando pregunta la primera vez y no la segunda.
7. Editar la especificación a mano da los mismos errores que le daría al
   agente.
8. Exportar el respaldo → el tablero viaja, sus corridas no.
9. Borrar el proyecto → sus tableros se van con él.
