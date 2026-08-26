part of '../system_prompt.dart';

/// QUÉ ES "TERMINAR" UNA SESIÓN QUE TOCA CÓDIGO, y dónde se commitea.
///
/// Qué dicen: [kDeliveryPrompt] define la entrega como un pull request en
/// draft —una rama por sesión, un PR por sesión, la URL en el hilo—; y
/// [worktreePrompt] corrige esa instrucción cuando el turno corre en un
/// worktree aparte, donde la rama ya existe.
///
/// Quién los usa: `_turnSystemPrompt` en `projects_viewmodel.dart`, solo
/// cuando el turno no es una consulta y el proyecto tiene git.
///
/// Ojo al armarlos: si el member tiene un MCP de GitHub asignado, la parte
/// de `gh pr create` la reemplaza [githubMcpPrompt] — dejar las dos versiones
/// juntas es un prompt que se contradice a sí mismo.
/// La definición de ENTREGA. Vive en el prompt porque no vivía en ningún
/// lado: ni la doc ni los workflows decían qué es "terminar", y sin esto
/// cada flujo lo inventaba — mergear, no abrir PR, o abrir uno nuevo por
/// ciclo. Solo entra en proyectos cuyo directorio de trabajo tiene git.
const kDeliveryPrompt =
    'ENTREGA: el resultado de una sesión que toca código se entrega como PULL '
    'REQUEST EN DRAFT — nunca mergeado ni marcado listo para review: eso lo '
    'decide el usuario. En el primer ciclo que toque código, creá una rama '
    'para la sesión, commiteá ahí y abrí el PR en draft (`gh pr create '
    '--draft`). En los ciclos siguientes, commiteá a la MISMA rama del mismo '
    'PR — no abras otro. Apenas el PR exista, dejá su URL completa en una '
    'línea propia de tu respuesta, FUERA de bloques de código: así queda '
    'clickeable y el encabezado de la sesión muestra "PR #N". Cerrar el '
    'último ciclo sin la URL del PR en el hilo es cerrar sin entregar.';

/// Lo que hay que decirle a un agente que corre en un worktree de al lado.
///
/// La sección ENTREGA le pide crear una rama para la sesión. Acá eso está
/// MAL: la rama ya existe —es la razón de que la carpeta exista— y abrir otra
/// encima parte el mismo trabajo en dos ramas y dos PRs.
///
/// Y no es algo que pueda deducir solo: `git status` le dice en qué rama
/// está, no que esa rama sea la de este worktree ni que haya otra copia del
/// repo al lado. Por eso se declara, y por eso se declara siempre igual.
String worktreePrompt(WorktreePlace place) {
  if (!place.isLinked) return '';
  final branch = place.branch;
  final root = place.main?.path ?? '';
  return [
    'WORKTREE: este directorio es un worktree APARTE del repo, no el '
        'principal.',
    if (branch.isNotEmpty)
      'Ya está parado en la rama `$branch`, que es la rama de este trabajo: '
          'commiteá acá y NO crees otra rama ni te cambies de rama. Donde la '
          'sección ENTREGA dice "creá una rama para la sesión", esa rama ya '
          'está creada y es esta.'
    else
      'Está en HEAD suelto, sin rama. Antes de commitear, decilo en tu '
          'respuesta y pedí que se resuelva: no inventes una rama.',
    if (root.isNotEmpty)
      'El worktree principal del repo está en `$root` y NO es tuyo en este '
          'turno: no le hagas checkout, no le cambies de rama, no escribas '
          'adentro.',
    'Acá `.git` es un archivo y no una carpeta. Es normal en un worktree y no '
        'hay nada que arreglar.',
  ].join(' ');
}
