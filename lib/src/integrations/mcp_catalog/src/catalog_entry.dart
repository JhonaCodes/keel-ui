part of '../mcp_catalog.dart';

/// En qué cajón del catálogo cae una integración. Agrupa por para-qué-sirve
/// y no por transporte: cuando buscás Jira no estás pensando en si el
/// servidor es stdio.
enum McpCatalogCategory {
  trabajo('Trabajo y equipo'),
  datos('Datos y nube'),
  codigo('Código y documentación'),
  navegador('Navegador y diseño');

  final String label;
  const McpCatalogCategory(this.label);
}

/// Cómo se autentica un servidor, que es lo único que decide si Keel lo
/// puede configurar entero o no.
enum McpCatalogAuth {
  /// No pide nada.
  ninguna,

  /// Un token que se pega y viaja en un header o en el entorno. Keel lo
  /// configura entero.
  token,

  /// Un flujo OAuth en el navegador. Keel **no** lo puede completar: cada
  /// turno corre con `--strict-mcp-config`, así que un servidor que
  /// autenticaste por fuera tampoco se ve desde acá. La salida, cuando el
  /// servicio la ofrece, es sacar un token de API y usarlo como [token].
  oauth,

  /// Credenciales en un archivo del disco (el JSON de una service account,
  /// por ejemplo), que se pasa por ruta.
  archivo,
}

/// Un secret que la integración pide, descrito para que el formulario pueda
/// explicarlo en vez de mostrar un campo vacío.
class McpCredential {
  /// El nombre sugerido del secret. Sigue el formato de [Secret]: mayúsculas,
  /// números y `_`.
  final String name;

  /// Cómo lo llama el servicio en su propia documentación.
  final String label;

  /// Dónde se saca, con las palabras del servicio.
  final String hint;

  const McpCredential({
    required this.name,
    required this.label,
    required this.hint,
  });
}

/// Una integración conocida, con la configuración exacta que necesita.
class McpCatalogEntry {
  /// Identificador estable del catálogo (`github`, `linear`). Queda guardado
  /// en el servidor instalado para poder mostrar su ficha después.
  final String id;

  /// El nombre del servicio, como lo escribe el servicio.
  final String name;

  /// Para qué sirve, en una línea.
  final String tagline;

  final McpCatalogCategory category;
  final McpCatalogAuth auth;
  final McpTransport transport;

  /// El nombre con el que se registra por defecto. Es el prefijo de sus
  /// tools (`mcp__<nombre>__*`), así que va en minúsculas.
  final String serverName;

  /// stdio.
  final String command;
  final List<String> args;

  /// stdio: valores literales del entorno, sin secreto adentro.
  final Map<String, String> env;

  /// stdio: clave del entorno → nombre del secret que la llena.
  final Map<String, String> secretEnv;

  /// Remoto.
  final String url;

  /// Remoto: header → plantilla, con `{{NOMBRE}}` donde va un secret.
  final Map<String, String> headers;

  /// Los secrets que pide, explicados.
  final List<McpCredential> credentials;

  /// La documentación oficial. Es lo que salva la ficha cuando envejece.
  final String docsUrl;

  /// Una advertencia que conviene leer antes de instalar, o vacío.
  final String note;

  /// Dos letras para el glifo, en vez de un logo descargado: cero red, cero
  /// archivo que se pudre, y se ve igual sin conexión.
  final String glyph;

  /// Posición en la paleta de miembros; la UI la resuelve a color.
  final int colorIndex;

  const McpCatalogEntry({
    required this.id,
    required this.name,
    required this.tagline,
    required this.category,
    required this.auth,
    required this.transport,
    required this.serverName,
    required this.docsUrl,
    required this.glyph,
    required this.colorIndex,
    this.command = '',
    this.args = const [],
    this.env = const {},
    this.secretEnv = const {},
    this.url = '',
    this.headers = const {},
    this.credentials = const [],
    this.note = '',
  });

  /// Los nombres de secret que pide, en el orden en que los declara.
  List<String> get secretNames => [
    for (final credential in credentials) credential.name,
  ];

  /// Cómo se resume en una línea: el comando o la URL.
  String get detail => switch (transport) {
    McpTransport.stdio => '$command ${args.join(' ')}'.trim(),
    McpTransport.http || McpTransport.sse => url,
  };
}

/// La ficha con ese id, o null si no está — un servidor instalado a mano no
/// tiene ficha, y uno instalado desde una versión anterior puede apuntar a
/// una que ya no existe.
McpCatalogEntry? mcpCatalogEntryFor(String id) {
  if (id.isEmpty) return null;
  for (final entry in kMcpCatalog) {
    if (entry.id == id) return entry;
  }
  return null;
}

/// El catálogo agrupado por categoría, en el orden en que se declaran las
/// categorías y, adentro, en el orden del catálogo.
Map<McpCatalogCategory, List<McpCatalogEntry>> mcpCatalogByCategory({
  Set<String> excludingIds = const {},
}) {
  final grouped = <McpCatalogCategory, List<McpCatalogEntry>>{};
  for (final category in McpCatalogCategory.values) {
    final entries = [
      for (final entry in kMcpCatalog)
        if (entry.category == category && !excludingIds.contains(entry.id))
          entry,
    ];
    if (entries.isNotEmpty) grouped[category] = entries;
  }
  return grouped;
}
