# F35 — El diario de fallas

## Qué problema resuelve

La app sabía perfectamente cuándo algo se rompía. Lo decía cuarenta y cuatro
veces:

```dart
Log.e('System vault operation failed', error: error);
Log.e('Knowledge sync failed for ${base.name}', error: error);
Log.e('Workflow run failed', error: error);
```

Y lo decía **en la consola**, que existe solo si arrancaste Keel desde una
terminal y todavía la tenés abierta. Un respaldo que no pudo escribir, un
índice que quedó a medias o un flujo que se cortó a las tres de la mañana no
dejaban rastro en ningún lado que se pueda abrir después. El síntoma típico:
«el respaldo dice que está al día» —porque `lastBackupAt` lee la fecha del
zip viejo— mientras el que falló se lo llevó el scrollback.

## Una sola puerta, tres fuentes

Lo importante del diseño no es la lista: es **dónde se engancha**. Nadie tuvo
que ir a modificar cuarenta y cuatro llamadas, y nadie va a tener que
acordarse de la número cuarenta y cinco.

| De dónde viene | Cómo entra |
|---|---|
| `Log.e` / `Log.f` en cualquier archivo | el listener de `Logger.root` |
| Un error de build, de layout o de pintado | `FlutterError.onError` |
| Una excepción asíncrona sin dueño | `PlatformDispatcher.onError` |

`logger_rs` publica todo en `Logger.root` —de `package:logging`— así que un
solo listener alcanza para toda llamada a `Log.e` que exista hoy, que se
escriba mañana, o que venga de un paquete de terceros.

Las tres fuentes **no reemplazan lo que ya hacía la app**: el handler de
Flutter se encadena con el que estaba, así que el cartel rojo de la consola y
el recuadro gris en pantalla siguen apareciendo igual. La consola sirve
mientras la estás mirando; el diario sirve para todo el resto del tiempo.

## Lo que se guarda

```
El flujo se cortó en "con-app" · Migrar el carrito
hace 3 min  ·  projects_viewmodel.dart:1412                        ×2
```

Una línea que se lee sin abrir nada, y el stack entero adentro. El origen
—`projects_viewmodel.dart:1412`— sale del primer frame de Keel del stack, con
los frames del propio diario salteados: sin eso, todas las fallas dirían que
salieron de acá.

El stack casi nunca viene en un `Log.e` (la mayoría de las llamadas pasan
`error:` y nada más). Cuando el error es un `Error` de Dart se usa el suyo
propio, que trae la misma información.

Al flujo de un proyecto se le agregó el nombre del proyecto y de la sesión
**en el mensaje**, no como campos aparte: `Workflow run failed` a las tres de
la mañana no dice cuál de los seis proyectos fue.

## Lo que NO hace

**No manda nada afuera.** Keel no tiene servidor ni cuenta, y una falla que
se sube a algún lado es una falla que viaja con las rutas de tus proyectos,
los nombres de tus repos y a veces un pedazo de tu código adentro. El diario
vive en la misma base local que todo el resto.

Tampoco lleva ids de proyecto ni de sesión: guardar el id invita a poner un
botón que navegue, y para eso el diario tendría que conocer a los proyectos y
a la navegación —que ya lo conocen a él—. El nombre en el mensaje da la misma
respuesta sin el ciclo.

## Que no se coma la app

Un sistema que captura errores y puede amplificarlos es peor que no tener
ninguno. Los tres bucles posibles, y cómo se cortan:

| El bucle | Qué lo corta |
|---|---|
| Escribir la falla falla → `LocalDatabase` avisa por `Log.e` → escribir la falla falla | La primera escritura fallida **apaga la persistencia para siempre**. El diario sigue en memoria hasta que reinicies. |
| Un error de layout falla una vez **por frame** → publicar redibuja → vuelve a fallar | La repetida no publica: suma al contador en silencio y avisa como mucho una vez por segundo. |
| Publicar redibuja → el redibujo revienta → vuelve a entrar a anotar | Una guarda sincrónica: una vuelta y se corta. |

Y dos topes: **200 fallas** o **30 días**, lo que llegue primero. El tope
importa más que la ventana, porque dos bugs alternándose no se juntan entre
sí y llenarían la lista en segundos.

## El aviso

Un registro nuevo en el rail, con el número de las que no miraste:

```
  ⚠ ③
Fallas
```

Es el único del rail que se abre **porque se prendió** y no porque lo fuiste
a buscar. Abrir el panel las marca vistas —mirarlas ES verlas, y pedir además
un click en «ya lo vi» es pedir dos veces lo mismo—; que una falla se repita
la vuelve a poner sin ver, porque que ya la hayas leído no dice nada sobre
que siga pasando.

Si la ventana **no está enfocada**, además sale una notificación de macOS.
Con Keel adelante alcanza el punto rojo: ya estás acá. Lo que el punto rojo
no puede hacer es avisarte mientras el flujo corre veinte minutos y vos
estás en otra cosa, que es justo cuando una falla se pierde.

Sale por `osascript` y no por un paquete nuevo —la app ya habla con macOS así
(`which`, `sysctl`, `ps`)—. El costo es que macOS le atribuye el globo al
Editor de Scripts, y si nunca le diste permiso de notificar, no aparece. Por
eso el punto rojo es el aviso de verdad y esto es el extra. Como mucho uno
cada dos minutos, con cinco segundos de tope: un `osascript` que se queda
esperando algo no puede quedarse con el aviso de que otra cosa falló. En una
corrida de tests no se dispara nunca.

## Dónde vive

| Qué | Dónde |
|---|---|
| Modelo, estado y repositorio | `integrations/fault_journal/src/fault.dart` |
| Las tres fuentes | `integrations/fault_journal/src/fault_capture.dart` |
| La notificación de macOS | `integrations/fault_journal/src/fault_notice.dart` |
| El panel | `integrations/fault_journal/src/ui/faults_panel.dart` |
| El registro del rail | `modules/agents/ui/view/agent_rail.dart` |

Se instala en `main`, **después** de la base y antes que todo lo demás: un
diario que arranca sin dónde guardar se apaga solo en el primer intento. Solo
en la ventana principal — las sub-ventanas son otro engine sin base donde
escribir.
