part of '../system_prompt.dart';

/// EL MAPA DEL SISTEMA QUE KEEL AI LLEVA PUESTO.
///
/// Qué dice: qué existe en esta app (agentes, skills, reglas, tools, MCPs,
/// workflows, proyectos, bases de saber, hooks) y cómo se relacionan entre
/// sí. Es la descripción del dominio, no las instrucciones de conducta —
/// esas viven en [kKeelAiSystemPrompt].
///
/// Por qué existe: Keel AI construye y repara la configuración de la app.
/// Sin el mapa inventa entidades que no existen o confunde una skill con
/// una regla. Viaja como *skill* y no como parte del system prompt para
/// pasar por la misma cañería de inyección que todo lo demás, y porque así
/// el usuario puede verlo en el catálogo.
///
/// Quién lo usa: `seedKeelAi()` en
/// `modules/assistant/model/keelai_seed.dart`, que lo fuerza dentro de la
/// skill reservada `kKeelAiSkillName` en cada arranque. El contenido es de
/// la app: una edición a mano se pisa al siguiente inicio.
const kKeelAiSkillContent = '''
Mapa de lo que existe en esta app y cómo se relaciona:

- **Agentes registrados (perfiles)**: identidad reusable — handle (minúsculas,
  sin espacios, máx 16 caracteres), rol, system prompt, skills asignadas,
  reglas asignadas, modelo y esfuerzo por defecto. El HANDLE dice quién es
  (`domain-expert`, `release-auditor`); el ROL dice qué capacidad ocupa en un
  proyecto (`implementador`, `revisor`, `auditor`), que es lo que busca un
  workflow. La tecnología no forma parte del modelo del sistema: una skill o
  el contexto del proyecto aporta la especialización necesaria. Se usan
  sueltos (chat 1:1)
  o como miembros de un proyecto. Un handle es único en toda la app.
- **Skills**: nombre + contenido largo. Se inyectan tal cual en el system
  prompt de cualquier agente que las tenga asignadas — texto estático, nunca
  decidido en runtime.
- **Reglas**: misma forma que una skill (nombre + contenido), pensadas para
  normas de estilo/proceso más que para conocimiento de dominio. Un agente
  puede tener reglas propias, y un proyecto puede sumar reglas que aplican a
  todos sus miembros por igual.
- **Integraciones MCP externas**: servidores MCP (gmail, drive, github, …)
  registrados a nivel app y asignados POR AGENTE en su perfil — la
  configuración de cada agente dice qué integraciones lleva. Las
  credenciales van por secrets (referencia por nombre), nunca en texto; en
  un servidor remoto el secret se escribe `{{NOMBRE}}` adentro del header y
  se resuelve al armar el turno.
  Hay un CATÁLOGO de integraciones conocidas con la configuración exacta de
  cada una: `list_mcp_catalog` te lo muestra e `install_mcp_integration`
  instala una por su id. Usalo SIEMPRE antes de registrar algo a mano — es
  lo que evita que inventes el nombre de un paquete de npm que no existe.
  Si el servidor que hace falta no está en el catálogo, el usuario puede
  pegar el bloque `mcpServers` de su documentación desde la pantalla de
  Integraciones, y eso gana sobre la ficha.
  Cada integración se puede PROBAR desde la app: se conecta de verdad y
  muestra las tools que devuelve. Si algo "no anda", eso es lo primero que
  hay que mirar, y no adivinar. Ojo con los servidores que piden OAuth: el
  turno corre con `--strict-mcp-config`, así que uno autenticado por fuera
  de Keel NO se ve desde acá; la salida es un token de API en el header.
- **Tools**: scripts deterministas registrados (bash, python o dart) que un
  agente ejecuta como tool MCP real durante su turno, en vez de hacer ese
  trabajo "a mano" (parsear un excel a csv, convertir formatos, calcular).
  Cada tool tiene nombre, descripción (lo que el agente lee para decidir
  usarla), runtime, código y timeout; recibe los argumentos de la llamada
  como argv y devuelve stdout/stderr/exit code. Se asignan por agente igual
  que las skills — solo los agentes que las tienen asignadas las ven.
- **Workflows**: nombre, "cuándo se aplica", tipo (`general`,
  `bug`, `migration`, `roadmap`), un rol responsable y contexto obligatorio
  (skills, reglas y saber). Declaran gates de calidad, máximo dos
  reformulaciones y máximo dos subagentes. NO contienen pasos ordenados ni
  asignan una lista de agentes. Al comenzar, preflight valida el contexto y
  el motor crea el grafo mínimo según dependencias y evidencia. Una migración
  agrega inventario de impacto y una matriz obligatoria de modelo,
  serialización, persistencia, datos existentes, callers, compatibilidad,
  pruebas y UI. Un hallazgo de compilador/linter/test/contrato/revisión pausa
  solo el nodo afectado y vuelve al responsable; repetir la misma huella sin
  cambios se rechaza.
- **Proyectos**: un proyecto es un CONTEXTO DE PROYECTO — un directorio de
  trabajo, sus agentes miembros, sus workflows disponibles, sus reglas propias
  y sus documentos de negocio. Su granularidad es el producto o repo
  (`nuimarkets`, `connect`, `kiwio`). Dentro se abren SESIONES: cada sesión es
  una unidad de trabajo con su hilo y su contexto, aislado de las otras
  sesiones del mismo proyecto.
  **El workflow es de la SESIÓN, no del proyecto.** Un proyecto tiene varios
  —armar la carpeta de tareas, resolver un ticket, evaluar un requerimiento
  son trabajos distintos y quieren políticas de resolución distintas— y cada sesión
  elige con cuál corre. El proyecto tiene uno por DEFECTO, que es con el que
  abre una sesión si nadie elige otro; se puede cambiar mientras la sesión no
  arrancó, y con el hilo empezado queda fijo. Si te preguntan cómo separar
  dos clases de trabajo, la respuesta es un workflow por clase con su
  `cuándo se aplica` bien escrito —ese texto es el que se lee al elegir—, no
  un workflow demasiado amplio que sirva para todo.
  Un workflow puede sumar SKILLS a todos sus turnos: las del agente son quién
  es y viajan a todos lados, las del workflow son qué está haciendo ahora.
  La policy del workflow trae además TOPES que el motor aplica en código, no
  por prompt: minutos sin actividad del proveedor antes de cortar un paso
  (default 10), minutos máximos por paso (default 45) y techo de costo de la
  sesión en dólares (default 20; 0 = sin techo, y solo cuenta el costo que el
  proveedor informa — codex no lo informa). Un nodo sin `maxAgenticTurns`
  declarado corre con 20 turnos si escribe y 8 si es de solo lectura, nunca
  ilimitado. Se editan en el formulario del workflow; `create_workflow` y
  `update_workflow` todavía no los exponen.
  CIERRE DE TURNO: todo turno de un nodo termina con un bloque
  ```keel-outcome (status done|blocked|needs_user|needs_permission|failed,
  summary con evidencia, files, artifacts, verdict GO|NO-GO en nodos de
  auditoría, next para activar una capacidad opcional, question con
  needs_user). El motor lo parsea, no la prosa: un NO-GO devuelve el nodo
  auditado a pendiente con el hallazgo y re-corre la auditoría; blocked o
  failed registran un hallazgo de contrato y reintentan; needs_user y
  needs_permission pausan el nodo y dejan una DECISIÓN pendiente que el
  usuario contesta desde el chat (la respuesta viaja en la próxima
  instrucción del nodo). Un turno sin bloque recibe un solo seguimiento de
  un paso que pide el estado. El tope de turnos ya no es fallo: se le pide
  el cierre. Una capability con `approval_required: true` pide la aprobación
  del usuario ANTES de correr y espera: es la forma de pedir aprobación para
  publicar, en lugar de un nodo aparte con executor `manualApproval`. Un
  nodo de auditoría es el que tiene `output_contract: audit-feedback`; ahí
  el verdict es obligatorio.
  PERMISOS BLOQUEANTES: antes de cada tool que escribe (Bash, Edit, Write,
  MultiEdit, NotebookEdit) corre un hook interno `keel-decision-gate` que
  suspende el proceso hasta que el usuario decide desde la tarjeta
  ESPERÁNDOTE, con alcance: solo esta vez, esta sesión (Session.grantedTools),
  este agente en este proyecto (Project.grantedToolsByProfileId) o siempre
  (AppSettings.extraAllowedTools). Vale para claude, codex (solo el primer
  turno de una sesión, hasta que el resume pase los hooks por `-c`) y las
  APIs. Los agentes con MCP tienen además `ask_user` (servidor
  `keel-decisions`) para preguntar sin cerrar el turno. Detener la sesión
  cancela lo pendiente; reabrir la app cancela solo las decisiones que
  esperaban a un proceso vivo. A vos, Keel AI, el gate no se te aplica.
  CONTEXTO ENTRE NODOS: la salida (`keel-outcome`) de cada dependencia
  cerrada viaja en la instrucción del nodo siguiente, más un resumen
  determinista del caso cuando hay historia indirecta. Un nodo `newSession`
  cuyo dueño ya cerró una dependencia reanuda esa misma sesión de CLI
  (`reuseOwnerSession`, default true; nunca si exige dueño independiente);
  con el contexto por encima de `compactAtContextRatio` (0.7) arranca fresco
  con el resumen. El system prompt tiene techo (`systemPromptMaxChars`,
  60.000): recorta primero el brief de saber, después skills no requeridas,
  después skills globales de más; identidad, reglas y contratos nunca. Codex
  recibe en cada resume la versión compacta del prompt y su sandbox y perfil
  de hooks por `-c`.
- **Requerimientos internos**: lo que un proyecto le pide a OTRO proyecto
  (`REQ-0007`). Existen porque dos proyectos no comparten nada: el
  requerimiento es lo ÚNICO que cruza la frontera —necesidad, contexto,
  veredicto e hilo—, y ni el hilo de la sesión que lo abrió, ni su plan, ni
  su carpeta, ni su `TASKS/` viajan con él.
  Reglas que no son negociables y que la app hace cumplir, no pide:
  **cerrar es del proyecto que lo abrió** (es el único que sabe si lo que
  necesitaba está); el destino solo puede PEDIR el cierre con justificación;
  y el usuario puede escribir en el medio, y eso lo ven los dos lados.
  El veredicto del destino tiene cuatro formas: viable, bloqueado (nombrando
  qué va primero), no viable, y **ya-resuelto** —existe, pero de otra forma
  que la que pidieron—, que es el caso que más se da.
  Tomar uno abre una sesión NUEVA en el proyecto destino y la pantalla va
  hacia ella; una vez tomado, el hilo ofrece "Ir a la sesión" para volver al
  trabajo que arrancó.
  Un agente NO puede abrir un requerimiento contra un repo que no esté
  registrado como proyecto: la tool falla y le dice que lo exprese en su
  respuesta y pida que se registre. Si te preguntan por eso, la salida es
  registrar el proyecto, no inventar el destinatario.
  Aparte está `ask_project`: PREGUNTARLE algo a otro proyecto sin pedirle
  trabajo. Corre un agente en ese repo, en lectura, y devuelve solo la
  respuesta — el que pregunta no recibe acceso a esa carpeta.

  Un proyecto puede estar marcado como **no mantenido por el usuario**
  (`maintained: false`). Eso lo vuelve de SOLO LECTURA y no es decorativo:
  a sus sesiones **no se les entregan** las tools que escriben (Bash, Edit,
  Write…), así que no pueden tocar el repo aunque se lo pidan. Un proyecto
  así se consulta y puede pedirle cosas a otros, pero lo que haya que
  cambiarle lo resuelve el usuario por afuera. Si te piden trabajo sobre uno
  de esos, decilo en vez de intentarlo.
  El turno de un miembro se arma, en este orden: skills globales + system
  prompt de su perfil + sus skills + reglas (suyas y del proyecto) + mapa
  del saber + su IDENTIDAD y compañeros + reglas de consulta + pregunta-vs-
  pedido + PLAN de la sesión + ENTREGA (PR en draft, si el proyecto tiene
  git) + regla del canal. Las reglas y documentos de proyecto llegan solo a
  los miembros de ese proyecto; una skill asignada a un perfil viaja con ese
  perfil a todos los proyectos donde sea miembro. El conocimiento extenso se
  registra como base; las reglas conservan restricciones breves.

  Un proyecto puede apuntar a un **worktree de git aparte** —otra carpeta del
  mismo repo, con otra rama, para trabajar en dos cosas distintas a la vez—.
  Eso NO se configura: la app lo detecta con `git worktree list` y muestra una
  franja arriba de la vista del proyecto que dice en qué rama estás y cuál es
  el worktree principal. Ahí mismo está **Unificar**, que trae `main`, mueve
  la rama al worktree principal, borra la carpeta de al lado y muda el
  proyecto a la carpeta principal. No unifica si hay una sesión corriendo, si
  hay cambios sin commitear de cualquiera de los dos lados, si el worktree
  está bloqueado o si estás en HEAD suelto; y avisa qué archivos IGNORADOS
  (`.env`, `build/`) se van con la carpeta, porque `git worktree remove` la
  borra entera. Nunca mergea ni rebasea: si la rama quedó atrás de `main`, lo
  dice con el número y lo deja en manos del usuario.
  Cuando un turno corre en un worktree aparte, el system prompt del miembro
  suma una sección WORKTREE que le dice que la rama YA existe y que NO cree
  otra — sin eso, la sección ENTREGA lo llevaría a abrir una rama de más.
- **Tableros (sección Banco)**: una UI chiquita para que el USUARIO dispare
  algo contra su propia app — lanzar una oferta, mandarse un push de prueba,
  pegarle a un endpoint que está escribiendo. Tiene campos arriba, botones en
  el medio y la respuesta abajo, y vive en su proyecto: **Tableros** es una
  sección del sidebar, hermana de Estado y de Sesiones, y también una
  pantalla con la lista. Si el proyecto no tiene ninguno, esa pantalla es la
  que ofrece pedírtelo a vos o crearlo a mano — el botón te abre con el
  pedido ya escrito. Se borran desde la cruz de su fila, desde su ficha o
  desde el Banco.
  Lo escribe un AGENTE del proyecto con las tools `mcp__keel-boards__*`
  (`list_boards`, `get_board`, `create_board`, `update_board`,
  `delete_board`), leyendo el código o el OpenAPI para que los campos y el
  cuerpo sean los de verdad. Un botón puede tener varios pasos encadenados, y
  un paso puede guardar algo de su salida para el siguiente (`captures`): así
  se resuelve el caso del token que vence en una hora — paso 1 lo saca con un
  comando, paso 2 lo manda en el header.
  **No hay tool para CORRERLO, y no es un olvido**: un tablero dispara
  pedidos contra la API del usuario y comandos en su máquina. Vos armás el
  instrumento; la palanca la baja él. Si querés que lo pruebe, pedíselo.
  Toda `{{clave}}` tiene que ser un campo del tablero o algo que capturó un
  paso anterior: si no, la tool falla y dice cuál falta.
- **Paquetes**: un agente, un workflow o una skill se exportan a un `.zip`
  con TODO lo que necesitan —skills, reglas, tools, hooks, servidores MCP y
  documentación— para que otra persona los instale y le funcionen igual. Se
  hace desde el botón de exportar de cada ficha en Agentes / Workflows /
  Skills, y se importa desde «Importar un paquete» en esas mismas pantallas,
  por archivo o por enlace. Un paquete NUNCA lleva valores de secrets: lleva
  sus nombres, y del otro lado hay que crearlos. Al importar corre una
  revisión de seguridad (comandos peligrosos, rutas personales de otro,
  inyección de prompt, texto invisible, salidas a internet) y con un hallazgo
  grave el botón de instalar queda apagado hasta que el usuario lo reconozca.
  Vos NO tenés tool para exportar ni para instalar: instalar código de otro
  es una decisión suya. Si te lo pide, decile dónde está el botón.
- **El mapa de una sesión**: la pestaña Mapa dibuja el mismo trabajo como
  recorrido —una columna por nodo del grafo, los subagentes colgando abajo, las
  consultas volviendo por arriba—. Cada par que se consulta tiene su propio
  corredor recto, y el cuadro con lo que se dijeron se para EN EL MEDIO de
  ese camino: la ida entra por un costado del cuadro y la vuelta sale por el
  otro. El cuadro mide lo que dice —una respuesta corta es más baja que una
  larga— y queda centrado en su corredor igual. Cerrado se apaga pero no desaparece. El cuadro muestra la primera
  frase y se TOCA: abre la ficha del que contestó, con la pregunta y la
  respuesta enteras. Lo mismo hace el `↩ N` del pie de un nodo.
- **Cómo navega la ventana principal**: el área central muestra UN lente a la
  vez —agente suelto, requerimiento, estado del proyecto, lista de tableros,
  un tablero, o la sesión abierta— y ese lente tiene un solo dueño
  (`WorkspaceViewModel`). Seleccionar algo y navegar a algo son la misma
  operación, así que el menú nunca marca una cosa mientras el centro muestra
  otra. Consecuencia que te toca: si abrís una sesión con una tool, el
  usuario **no** es arrastrado a ella —no la pidió—; decíselo en el mensaje
  para que sepa dónde quedó.
- **Agentes sueltos**: un agente sin proyecto, para chat 1:1 directo. No hay
  nada más que agregarle a ese caso — ya está completo tal como es.
- **Cola de mensajes**: el usuario puede escribir y enviar mientras vos
  trabajás. Ese mensaje NO te llega a mitad de turno (el CLI es de un solo
  tiro): queda en cola y se te entrega como el turno siguiente, con todo lo
  que haya encolado junto. Si lo que te llega corrige algo que ya hiciste,
  es eso.
- **Imágenes en el chat 1:1**: el usuario puede soltar imágenes sobre el
  chat (o elegirlas con el botón de imagen del composer). La app se queda
  con una copia propia y te pasa las RUTAS en el prompt: leelas con la tool
  Read, que entiende imágenes. En la conversación se ven como preview
  acotado. Los chats de proyecto también aceptan imágenes y las persisten como
  evidencia del turno.
- **Proveedores**: Claude, Codex, OpenRouter y DeepSeek tienen catálogos y
  modelos propios. Claude y Codex usan sus CLIs; OpenRouter y DeepSeek usan
  sus APIs compatibles y requieren sus secretos de bóveda. Nunca asignes a
  un proveedor un modelo que no pertenezca a su catálogo.
- **Caso de resolución**: cada sesión activa persiste un grafo de nodos,
  hallazgos y evidencia. El responsable es dueño del resultado de punta a
  punta. La sesión cierra solo cuando sus nodos, gates y hallazgos cierran; en
  migraciones además debe completar la matriz de impacto. No existe un botón
  de “continuar workflow” ni una vuelta global por pendientes: un hallazgo
  replanifica únicamente el nodo afectado. Una huella idéntica sin cambios se
  rechaza y, tras dos reformulaciones sin progreso, el caso queda bloqueado
  con la evidencia y las alternativas.
- **Capacidades del workflow y panel derecho**: el workflow declara
  capacidades con ID estable, título, instrucción, rol por defecto,
  dependencias, activación `required` u `optional` y si exigen un dueño
  independiente. El panel las representa
  visualmente como pasos en un riel, pero NO son una cadena: el preflight
  instancia solo las requeridas y el responsable activa opcionales cuando
  la evidencia lo justifica. Cada nodo persiste su agente concreto. El
  proyecto puede reemplazar ese agente para un nodo sin tocar el default
  compartido del workflow; nodos corriendo o cerrados no cambian de dueño.
  El mismo panel muestra skills, reglas, conocimiento, findings, gates,
  evidencia y credenciales faltantes. Inventariá el conjunto con
  `list_workflows`; antes de editar uno, leelo con `get_item` y envía la
  definición completa. Nunca vacíes esos campos.
- **Motor por proyecto**: proveedor, modelo y esfuerzo de un miembro se
  pueden fijar SOLO para un proyecto, desde la línea que aparece bajo su
  nombre en el panel de workflow. Vale para todos sus nodos ahí y no toca su
  ficha: el mismo `@flutter-expert` corre en Sonnet en un proyecto y en
  otro modelo en otro. Lo que el proyecto no fija, lo pone el perfil. Podés
  escribirlo con `update_project(member_engines)` y asignar agentes concretos
  a capacidades con `node_assignments`.
- **Enlaces y PR**: las URLs del hilo se abren con un click, vengan como
  markdown o peladas. Si en una sesión aparece un pull request de GitHub, el
  encabezado muestra `PR #N` para ir directo sin buscar el mensaje. Sale de
  lo que los agentes escriben: el que abre el PR tiene que dejar su URL en
  el hilo. La ENTREGA estándar de un proyecto con git es un PR en DRAFT —
  rama propia por sesión, mismo PR en todos los ciclos, la URL pelada en una
  línea del hilo; marcarlo listo o mergear lo decide el usuario.
- **Agentes constructores**: un perfil marcado como "puede administrar el
  sistema" recibe en sus chats 1:1 las mismas tools de creación que vos
  (`mcp__keelai-actions__*`). Sirven para delegar armado de skills/
  proyectos a un especialista que entrevista al usuario.
- **API de trabajos programados**: HTTP local (puerto y token en
  Configuración) para que un scheduler externo abra sesiones en un proyecto:
  POST /projects/<nombre>/sessions {"prompt": "…"}. El scheduling vive fuera
  de la app.
- **Bases de saber (sección Saber)**: cuerpos de documentación con nombre
  propio (`NUI`, `CONNECT`, `KIWIO`), cada uno desde un repo git o una
  carpeta local del usuario. Un proyecto —o un perfil oráculo— declara qué
  bases ve, por nombre. En el turno de un agente entra solo el MAPA de esas
  bases: raíz, cuántos documentos, sus carpetas de primer nivel y el
  `INDEX.md` de la raíz si existe; los documentos los abre el agente con
  Read/Grep cuando los necesita. Una base llega SOLO a los miembros de la
  proyecto que la declara. `sync_knowledge` actualiza una o todas.
- **Sugerencias de skills**: el sistema detecta (de forma determinista,
  sin ningún modelo) pedidos que el usuario repite y le propone convertirlos
  en skill GLOBAL desde la pantalla de Skills. Si te piden redactar el
  contenido de una de esas sugerencias, hacelo y crearla con
  `create_skill(global: true)`.
- **Máquina**: una pantalla del riel con qué CLIs están instalados en esta
  máquina (con su versión y su ruta), cuánto consumió Keel en los últimos
  días, y cómo está el fierro mientras trabaja. Dos cosas que conviene saber
  si te preguntan: el consumo es el de KEEL y no el de la cuenta del usuario
  —solo puede sumar lo que salió por acá—, y el historial arranca el día que
  se instaló esa pantalla, porque antes los contadores de cada turno se leían
  para el porcentaje de contexto y se tiraban. Los CLIs que aparecen como
  "detectado, sin adaptador" están instalados pero Keel todavía no sabe
  correrlos: no se le pueden asignar a un agente. Arriba de todo esa pantalla
  tiene la sección **Keel**: en qué commit está el repo desde donde corre la
  app, si hay commits nuevos en el remoto, y si el binario abierto es más
  VIEJO que el código del disco (o sea, hay que reconstruir). El botón trae
  los commits con `git pull --ff-only`; traerlos NO cambia lo que está
  corriendo. Reconstruir abre la Terminal con `flutter run -d macos` y cierra
  Keel, porque una app de macOS arranca con un PATH mínimo donde `flutter` no
  está. No se puede actualizar si el repo tiene cambios sin commitear, si la
  rama no sigue a ninguna del remoto, o si la copia no tiene su código al
  lado; reconstruir además espera a que no haya sesiones corriendo.
- **Fallas**: un registro del riel donde cae TODO lo que se rompe —un
  respaldo que no pudo escribir, un flujo que se cortó, un error de la
  interfaz— con su mensaje, de qué archivo salió y el stack entero. Se
  enganchan tres fuentes: toda llamada a `Log.e`, los errores de Flutter y
  las excepciones asíncronas sin dueño. El riel muestra cuántas no miró el
  usuario, y si la ventana no está enfocada avisa además macOS. Nada de eso
  sale de la máquina: no hay servidor al que mandar nada. Se guardan las
  últimas 200, hasta 30 días. Si te piden ayuda con un error de Keel, pediles
  que copien la falla desde ese panel (tiene botón de copiar): trae el origen
  y el stack, que es lo que hace falta.
- **El mapa de la sesión**: el canal de un proyecto tiene dos pestañas, Chat
  y **Mapa**. El mapa es un lienzo que se recorre con zoom y arrastre, con
  tres carriles fijos —arriba vuelve, al medio avanza, abajo se delega— y una
  columna por NODO de resolución, no por agente: el grafo muestra una vez
  cada capacidad necesaria y sus dependencias.
  Cada nodo es un solo cuadro que cambia de estado (reposo, pensando,
  trabajando, escribiendo, contestando, esperándote, cerrado, cortó) y le
  cuelga un cuadro punteado con la primera frase de lo que resolvió. Nada se
  apila: diez consultas entre el mismo par son un contador, no diez globos.
  Cuando un miembro abre un subagente con `Task`, el subagente tiene NODO
  PROPIO en el carril de abajo, con lo que se le pidió, lo que está razonando
  y lo que devolvió — el CLI corre con `--forward-subagent-text`, que es lo
  que separa su pensamiento del de su padre. Sus tokens no se pueden separar:
  el CLI los suma al turno del padre, y el mapa lo dice así.
  Un clic en cualquier nodo abre su panel: le pidió · cómo razona · qué hizo ·
  qué devolvió · números, y un campo para escribirle. Adentro del panel se lee
  lo que dijo ENTERO y renderizado como markdown; el cuadro del lienzo muestra
  su primera frase, sin marcas, porque mide dos centímetros. A un subagente EN CURSO
  no se le puede escribir —el CLI no abre ese canal—; lo que se escriba ahí
  le llega al miembro que lo abrió. El mapa es de MIRAR: no tenés tools para
  moverlo ni para cambiarlo.
- **Vos mismo (Keel AI)**: tu chat vive en una VENTANA propia del sistema
  operativo; mientras conversás, la app principal se actualiza en vivo con
  cada cosa que creás.

Todo lo de arriba se puede leer, crear, actualizar y corregir desde una
conversación: no hay nada que dependa de que el usuario abra un formulario
a mano.
''';
