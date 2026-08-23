/// Los términos de uso de Keel, tal como se muestran en la app.
///
/// Están escritos como datos y no dentro de un widget por una razón práctica:
/// un término que se lee en pantalla y otro que dice el `LICENSE` es un
/// problema, y teniéndolos acá hay UN solo lugar donde cambiarlos.
///
/// El tono es el de alguien explicando su herramienta, no el de un contrato
/// de banco. Lo que sí es literal es el alcance: lo que dice la sección de
/// datos es lo que el código hace, no lo que sería lindo que hiciera.
library;

/// Un bloque de los términos: un título y lo que dice.
typedef TermsSection = ({String title, String body});

abstract final class KeelTerms {
  /// Qué versión está leyendo la persona. Sirve para poder decir "aceptaste
  /// la 1" cuando la 2 diga otra cosa.
  static const version = 'Versión 1 — agosto de 2026';

  static const sections = <TermsSection>[
    (
      title: '1. Qué es Keel',
      body:
          'Keel es una herramienta de escritorio que trabaja sobre los CLI de '
          'agentes que ya tenés instalados en tu máquina. No es un servicio: '
          'no hay un servidor de Keel al que te conectes, no hay cuenta que '
          'crear y no hay registro. Si apagás internet, Keel sigue abriéndose.\n\n'
          'Usar Keel significa aceptar estos términos. Si no estás de acuerdo '
          'con alguno, no lo uses.',
    ),
    (
      title: '2. De quién es',
      body:
          'Keel —su código, su diseño, su nombre, su documentación y todo lo '
          'que lo acompaña— es propiedad intelectual de Jhonatan Ortiz '
          '(JhonaCode), ingeniero de software. Todos los derechos reservados.\n\n'
          'No es software libre ni de código abierto. No se distribuye bajo '
          'MIT, Apache, BSD, GPL ni ninguna otra licencia permisiva. Tener una '
          'copia no te da derecho a usarla: hace falta permiso escrito del '
          'autor. El texto completo está en el archivo LICENSE.',
    ),
    (
      title: '3. Solo se descarga de jhonacode.com',
      body:
          'El autor se reserva de forma exclusiva el derecho a distribuir '
          'Keel. El ÚNICO canal autorizado es jhonacode.com.\n\n'
          'Queda prohibido republicar, espejar, subir a otro sitio, incluir en '
          'un repositorio de paquetes, en una tienda de aplicaciones, en una '
          'imagen de contenedor o en cualquier otro canal de distribución, sea '
          'gratis o cobrando. Tampoco se puede revender, alquilar, sublicenciar '
          'ni ofrecer Keel como servicio a terceros.',
    ),
    (
      title: '4. Copias que no vinieron de ahí',
      body:
          'Cualquier copia de Keel obtenida fuera de jhonacode.com no está '
          'autorizada, y el autor no tiene forma de saber qué le hicieron: '
          'pudo ser modificada, empaquetada con otra cosa o alterada para '
          'hacer algo que Keel no hace.\n\n'
          'El autor no responde por esas copias ni por lo que provoquen, y '
          'nada de lo que hagan puede atribuírsele. Una compilación modificada '
          'por un tercero no es Keel, aunque se llame así. Si te importa lo '
          'que corre en tu máquina, bajala del sitio oficial.',
    ),
    (
      title: '5. Keel no te pide datos',
      body:
          'No te pide nombre, correo, contraseñas ni claves de nada. No hay '
          'inicio de sesión. Todo lo que armás —proyectos, agentes, skills, '
          'tools, bases de saber, hilos de chat y ajustes— se guarda en tu '
          'propia máquina.\n\n'
          'Los valores de tus secrets nunca salen en un respaldo: el respaldo '
          'lleva solo los nombres, para que del otro lado sepas cuáles '
          'completar. La API de trabajos programados escucha únicamente en '
          'loopback, o sea que no es alcanzable desde fuera de tu equipo.',
    ),
    (
      title: '6. Lo único que sí sale de tu máquina',
      body:
          'Si esta compilación trae configurado un canal de reportes, cuando '
          'algo se rompe se envía a ese canal: el mensaje del error, su traza, '
          'el archivo de Keel donde ocurrió, el nombre de tu equipo y si la '
          'compilación es de desarrollo o de producción.\n\n'
          'No se envía nada más. Ni el contenido de tus chats, ni tus '
          'archivos, ni tus secrets, ni qué proyectos tenés. Sirve para una '
          'sola cosa: que quien mantiene Keel se entere de que algo falló.',
    ),
    (
      title: '7. Keel es una herramienta, y vos la manejás',
      body:
          'Keel lanza agentes con los permisos que vos les das, y esos '
          'permisos pueden incluir acceso completo a tu disco. Un agente puede '
          'crear, modificar y borrar archivos, ejecutar comandos y hacer '
          'commits en tus repositorios.\n\n'
          'Vos decidís qué permisos otorgás, sobre qué carpetas y qué le pedís '
          'a cada agente. Keel ejecuta esas decisiones; no las toma por vos y '
          'no las supervisa. El autor no se hace responsable del uso que le '
          'des a la herramienta ni de las consecuencias de lo que los agentes '
          'hagan siguiendo tus instrucciones.',
    ),
    (
      title: '8. Tus archivos son tuyos, y tus respaldos también',
      body:
          'Una herramienta que le da acceso a tu disco a un agente puede '
          'terminar en archivos perdidos, sobrescritos o cambiados de una '
          'forma que no querías. Puede pasar por un error de Keel, por un '
          'error del agente o por una instrucción tuya que salió distinta a '
          'como la pensaste.\n\n'
          'Mantener respaldos de lo que te importa es responsabilidad tuya. El '
          'autor no responde por pérdida ni por corrupción de datos.',
    ),
    (
      title: '9. No es para usos críticos',
      body:
          'Keel no está diseñado ni probado para entornos donde una falla '
          'ponga en riesgo la vida, la salud, la seguridad o infraestructura '
          'esencial: medicina, aviación, transporte, energía, control '
          'industrial o similares. No lo uses ahí.',
    ),
    (
      title: '10. Lo que no depende de Keel',
      body:
          'Los CLI de agentes y los servidores MCP que uses son de terceros. '
          'Cada uno tiene sus propios términos, sus precios y su propia forma '
          'de tratar lo que le mandás. Keel no responde por ellos, ni por lo '
          'que cobren, ni por lo que hagan con la información que reciben, ni '
          'por lo que decidan cambiar o discontinuar.\n\n'
          'Cumplir los términos de esos servicios es cosa tuya.',
    ),
    (
      title: '11. Lo que te comprometés a no hacer',
      body:
          'No copiar, modificar, traducir ni crear obras derivadas de Keel.\n'
          'No aplicar ingeniería inversa, descompilar ni desensamblar, salvo '
          'donde la ley lo permita de forma imperativa.\n'
          'No eludir ni desactivar ninguna medida técnica de protección.\n'
          'No quitar ni tapar los avisos de autoría, copyright o licencia.\n'
          'No usar el nombre, el logo ni la imagen de Keel o de JhonaCode sin '
          'permiso escrito.\n'
          'No usar Keel ni ninguna parte de él para entrenar modelos de '
          'aprendizaje automático o sistemas de inteligencia artificial.\n'
          'No usar Keel para nada ilegal, ni para vulnerar derechos de '
          'terceros.',
    ),
    (
      title: '12. Si tu uso le trae un problema al autor',
      body:
          'Si un tercero reclama algo por la forma en que vos usaste Keel, o '
          'por lo que hiciste con lo que produjo, ese reclamo es tuyo. Te '
          'comprometés a mantener al autor libre de todo daño, gasto o '
          'responsabilidad que salga de tu uso de la herramienta o del '
          'incumplimiento de estos términos.',
    ),
    (
      title: '13. Sin garantía',
      body:
          'Keel se entrega TAL CUAL ESTÁ y SEGÚN DISPONIBILIDAD, sin garantía '
          'de ningún tipo, expresa o implícita. No se garantiza que funcione '
          'sin errores ni interrupciones, que esté disponible, que sea '
          'compatible con tu equipo o con tus herramientas, ni que sirva para '
          'un propósito determinado.',
    ),
    (
      title: '14. Hasta dónde llega la responsabilidad',
      body:
          'En la medida en que la ley lo permita, el autor no responde por '
          'daños indirectos, incidentales, especiales ni consecuentes, ni por '
          'lucro cesante, pérdida de datos, pérdida de tiempo de trabajo o '
          'interrupción de actividad, aunque se le hubiera advertido de esa '
          'posibilidad.\n\n'
          'Si aun así se determinara alguna responsabilidad, su límite total '
          'será lo que vos hayas pagado por Keel en los doce meses previos al '
          'hecho, que en la práctica es cero: Keel no se cobra y las '
          'donaciones no son un pago por el software.',
    ),
    (
      title: '15. Donaciones',
      body:
          'Si Keel te sirve y querés apoyar el trabajo, se agradece. Es '
          'completamente voluntario.\n\n'
          'Una donación es eso y nada más: no es una compra, no es una '
          'licencia, no da derecho a usar el software sin permiso, no incluye '
          'soporte, no da prioridad en nada, no crea ninguna obligación del '
          'autor hacia quien dona y no se devuelve.',
    ),
    (
      title: '16. Cuándo se termina el permiso',
      body:
          'Cualquier uso fuera de lo autorizado extingue de inmediato y sin '
          'aviso todo permiso concedido. También puede revocarse un permiso '
          'otorgado antes. Al terminar, tenés que dejar de usar Keel y borrar '
          'las copias que tengas.\n\n'
          'Las secciones sobre propiedad, responsabilidad, garantía e '
          'indemnidad siguen vigentes después de eso.',
    ),
    (
      title: '17. Si alguna cláusula no vale',
      body:
          'Si un tribunal declara inválida o inaplicable alguna parte de estos '
          'términos, el resto sigue en pie, y esa parte se interpreta de la '
          'forma más cercana posible a su intención original.\n\n'
          'Que el autor no ejerza un derecho en algún momento no significa que '
          'renuncie a él. Entre Keel y vos no hay sociedad, empleo, franquicia '
          'ni representación de ningún tipo.',
    ),
    (
      title: '18. Ley aplicable',
      body:
          'Estos términos se rigen por las leyes del país de residencia del '
          'autor, y cualquier controversia se somete a los tribunales '
          'competentes de ese lugar.',
    ),
    (
      title: '19. Estos términos pueden cambiar',
      body:
          'Si cambian, la versión que vale es la que muestra esta pantalla. '
          'Seguir usando Keel después de un cambio significa que lo aceptás.',
    ),
    (
      title: '20. Contacto',
      body:
          'Para pedir permiso de uso, donar, reportar algo o cualquier otra '
          'consulta: jhonacode.com',
    ),
  ];
}
