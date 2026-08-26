part of '../system_prompt.dart';

/// GITHUB SE USA POR EL MCP, NO POR LA LÍNEA DE COMANDOS.
///
/// Qué dice: si el agente tiene un servidor MCP de GitHub asignado, todo lo
/// que sea GitHub —pull requests, issues, reviews, releases, comentarios—
/// va por las tools de ese MCP. Nada de `gh`, nada de `curl` a la API REST,
/// nada de scripts propios para lo que el MCP ya cubre. `git` sigue siendo
/// `git`: el MCP no reemplaza commitear ni pushear.
///
/// Por qué existe: teniendo el MCP autorizado, los agentes igual salían por
/// `gh` o por la API cruda. Eso es peor por tres razones concretas — el
/// token del MCP está guardado en el vault y `gh` depende de una sesión
/// distinta que puede no existir en esta máquina; una llamada de tool queda
/// registrada y visible en el hilo, un `curl` con token adentro no; y el
/// resultado de la tool vuelve estructurado, mientras que el texto de `gh`
/// hay que adivinarlo.
///
/// Ojo: [kDeliveryPrompt] pide crear el PR con `gh pr create --draft`. Con
/// MCP presente esa frase se reemplaza por [kGithubDeliveryPrompt] — dejar
/// las dos es un prompt que se contradice a sí mismo.
///
/// Quién lo usa: `_turnSystemPrompt` en `projects_viewmodel.dart` y
/// `_resolveProfileSystemPrompt` en
/// `modules/agents/viewmodel/agents_viewmodel.dart`, resolviendo los MCPs
/// del member con [isGithubMcpServer].
const kGithubMcpPrompt =
    'GITHUB GOES THROUGH ITS MCP SERVER. You have a GitHub MCP server '
    'attached to this turn, so every GitHub operation — pull requests, '
    'issues, reviews, comments, releases, repository and file reads on the '
    'remote — must go through its tools. Do not shell out to `gh`, do not '
    'call the REST or GraphQL API with `curl`, and do not write a script '
    'that does either: those depend on credentials this machine may not '
    'have, they leave no visible record in the thread, and they hand you '
    'text you have to guess at instead of a structured result. Local `git` '
    'is unaffected — clone, branch, commit and push exactly as usual. If a '
    'GitHub operation you need has no tool in the server, say so plainly '
    'instead of working around it.';

/// La variante de ENTREGA cuando hay MCP de GitHub: mismo contrato, otro
/// instrumento.
const kGithubDeliveryPrompt =
    'ENTREGA: el resultado de una sesión que toca código se entrega como PULL '
    'REQUEST EN DRAFT — nunca mergeado ni marcado listo para review: eso lo '
    'decide el usuario. En el primer ciclo que toque código, creá una rama '
    'para la sesión con `git`, commiteá y pusheá ahí, y abrí el PR en draft '
    'CON LA TOOL DEL MCP DE GITHUB (no con `gh`). En los ciclos siguientes, '
    'commiteá a la MISMA rama del mismo PR — no abras otro. Apenas el PR '
    'exista, dejá su URL completa en una línea propia de tu respuesta, FUERA '
    'de bloques de código: así queda clickeable y el encabezado de la sesión '
    'muestra "PR #N". Cerrar el último ciclo sin la URL del PR en el hilo es '
    'cerrar sin entregar.';

/// Si un servidor registrado es el de GitHub.
///
/// El `catalogId` es la señal fuerte: lo escribe la instalación desde el
/// catálogo de integraciones (`mcp_catalog/src/catalog_seed.dart`). El
/// nombre es el respaldo, para un servidor que alguien registró a mano
/// apuntando al mismo endpoint.
bool isGithubMcpServer(McpServerConfig server) {
  if (server.catalogId == 'github') return true;
  final name = server.name.toLowerCase();
  return name == 'github' || name.startsWith('github-');
}
