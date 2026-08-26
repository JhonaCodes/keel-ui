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
/// El límite que SÍ hay que marcar: el MCP escribe en GitHub, no en el
/// repo. Un commit hecho con `create_or_update_file` / `push_files` nace en
/// los servidores de GitHub, no en esta máquina, así que la clave GPG del
/// usuario nunca lo toca y el commit queda `unsigned` — «Unverified» en la
/// interfaz, aunque su git local esté perfectamente configurado para
/// firmar. Pasó de verdad: un agente rehízo un commit por el MCP «para
/// usarlo mejor» y le rompió la firma a un PR. Por eso commitear y pushear
/// son `git`, siempre, y está dicho como prohibición y no como omisión.
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
    'text you have to guess at instead of a structured result.\n'
    'THE LINE: the MCP writes to GitHub, never to the repository. Cloning, '
    'branching, staging, committing, amending, rebasing and pushing are '
    'local `git` — always, no exceptions. Never create or change a commit '
    'with the server\'s file-writing tools (`create_or_update_file`, '
    '`push_files`, `create_commit`, `delete_file`) even when it looks like '
    'the more MCP-native way to do it. A commit made through the API is '
    'born on GitHub\'s servers, so the user\'s signing key never touches '
    'it: it lands unsigned and GitHub shows it as Unverified, on a machine '
    'whose git was signing correctly a minute earlier. You cannot fix that '
    'afterwards from here — the commit has to be rewritten locally. Use the '
    'server\'s file tools only to READ what is on the remote.\n'
    'If a GitHub operation you need has no tool in the server, say so '
    'plainly instead of working around it.';

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
