/// El catálogo de integraciones MCP conocidas.
///
/// Existe por una razón concreta: sin él, "quiero Linear" termina en un
/// formulario vacío o —peor— en un agente inventando un paquete de npm que
/// no existe. Con él, la configuración exacta ya está escrita.
///
/// **No es la fuente de verdad, y el diseño lo asume.** Los comandos y las
/// URLs de los servidores de terceros cambian sin avisar, y este archivo se
/// entera cuando alguien lo actualiza. Por eso cada ficha lleva su enlace a
/// la documentación oficial, todo queda editable después de instalar, y
/// existe el importador de configuración pegada: si la ficha quedó vieja,
/// la del README del servidor gana.
///
/// Es data pura: sin Flutter, sin red, sin estado. El color se expone como
/// índice de la paleta y lo resuelve la UI.
library;

import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';

part 'src/catalog_entry.dart';
part 'src/catalog_seed.dart';
