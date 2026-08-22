# F13 — Imágenes en el chat

## Qué es

Adjuntar imágenes a un mensaje **soltándolas sobre el chat** (o con el botón
de la imagen en el composer). Cada adjunto se ve en la burbuja como un
**cuadro de preview acotado**, nunca a tamaño completo, y se abre en grande
al hacer clic.

Aplica al chat 1:1 (`ChatView`), que es el mismo widget que usa el panel del
asistente. Los proyectos (`StationChatView`) tienen su propio composer y
**todavía no** aceptan adjuntos.

## Flujo

1. El usuario suelta uno o varios archivos sobre el área del chat
   (`DropTarget` de `desktop_drop` envolviendo TODO el chat, no solo el
   input: se arrastra contra la conversación que se está leyendo). Mientras
   el arrastre está encima se muestra `ChatDropHint`, que ignora punteros
   para no interponerse con el drop nativo.
2. Lo que no sea imagen soportada se descarta en silencio — un drag puede
   traer carpetas o PDFs.
3. Cada imagen se **copia a almacenamiento de la app** antes de mostrarse
   (`ChatAttachmentStore.adoptImages`). Esto es el punto del feature: un
   screenshot se suelta desde una carpeta temporal que el sistema borra
   cuando quiere, y un archivo del Escritorio lo renombra su dueño. La app
   se queda con su propia copia y nunca vuelve a mirar la ruta original.
4. Las imágenes quedan en el composer como `ChatAttachmentStrip`
   (cuadraditos de 64px con una X). Quitar una borra también la copia: no
   se envió, no tiene por qué sobrevivir.
5. Al enviar viajan con el mensaje. Un mensaje **solo con imágenes**, sin
   texto, es válido — soltar un screenshot y dar enviar es el caso central.

## Cómo llega la imagen al modelo

Por **ruta, nunca por bytes**. `AgentsViewModel.sendMessage` agrega al
prompt un bloque `_describeAttachments`:

```
El usuario adjuntó 2 imágenes a este mensaje. Leelas con la tool Read
antes de responder:
- /…/chat_attachments/<uuid>.png
- /…/chat_attachments/<uuid>.png
```

El agente las lee con su propia tool `Read` (que entiende imágenes). Un
screenshot de 4 MB no cuesta nada hasta que el modelo decide mirarlo, el
prompt sigue siendo texto, y la ruta sigue siendo válida porque el archivo
vive en el almacenamiento de la app.

El texto que se muestra en la burbuja (`ChatMessage.text`) queda limpio: el
bloque de rutas es solo para el modelo.

## Modelo y puerto

- `ChatMessage.imagePaths` (`List<String>`, serializado): rutas dentro del
  almacenamiento de la app.
- `ChatActions.sendMessage(agentId, text, {imagePaths})` — el puerto lleva
  **rutas**, así que el `BridgeChatActions` de la ventana del asistente
  sigue enviando un payload JSON chico sin importar el tamaño de la imagen.
  El handler del lado principal (`assistant_window_bridge`) las reenvía al
  `AgentsViewModel` real.

## UI del preview

`ChatImageAttachments` (arriba del texto en `ChatMessageBody`, así que sirve
igual a la burbuja 1:1 y a la de proyecto cuando esta acepte adjuntos):

- Tarjeta fija de 200×140 con `BoxFit.cover`. Una imagen de 3000px cruda
  reventaría el ancho de la burbuja y empujaría el texto fuera de pantalla.
- Clic → `Dialog` con `InteractiveViewer` acotado al 90% de la ventana
  (informativo, sin nada que confirmar).
- Si el archivo ya no está, se dice con palabras ("Imagen no disponible"),
  no con un glifo roto: el texto del mensaje sigue teniendo sentido.

## Almacenamiento

`<applicationSupport>/chat_attachments/<uuid>.<ext>`. Formatos aceptados:
png, jpg, jpeg, gif, webp, bmp — lo que Flutter puede decodificar Y el
modelo puede leer, para que un preview en la burbuja siempre signifique que
el agente ve lo mismo.

## Límites conocidos

- Borrar un mensaje o un agente **no** borra sus imágenes: quedan
  huérfanas en `chat_attachments/`. Lo mismo si se cambia de agente o de
  sesión con adjuntos staged sin enviar (el `ChatView` está keyed por id, y
  el estado se rehace).
- En la ventana dedicada del asistente el drop nativo depende de que
  `desktop_drop` funcione en una sub-ventana de `desktop_multi_window`;
  sin verificar. El botón de adjuntar sí funciona en ambas.
- Los proyectos no aceptan adjuntos todavía.
- Pegar desde el portapapeles (⌘V) no está: el feature es soltar o elegir.
- `desktop_drop` es un plugin nativo nuevo — al actualizar hace falta
  reiniciar la app (no alcanza el hot reload).
