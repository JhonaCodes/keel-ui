/// El estado de un proyecto, armado de una sola pasada y sin tocar nada.
///
/// Cruza tres cosas que hasta ahora no se cruzaban en ningún lado: las tareas
/// del roadmap que están en el repo, las tomas vivas que están en la base
/// local, y las sesiones que corren ahora. Cada una por separado ya se podía
/// mirar; lo que faltaba era la respuesta a "cómo va esto".
///
/// Es una función PURA a propósito: entra data, sale el modelo de la vista.
/// Es lo único de esta pantalla que se puede probar sin la app entera.
library;

import 'package:keel_ui/src/integrations/roadmap_mcp/roadmap_mcp.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_plan_item.dart';
import 'package:keel_ui/src/modules/roadmap/model/task_claim.dart';

part 'src/radar_model.dart';
part 'src/build_radar.dart';
