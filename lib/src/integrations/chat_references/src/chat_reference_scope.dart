part of '../chat_references.dart';

/// Una carpeta que se puede nombrar, con el nombre que la identifica.
///
/// [label] es lo que ve el usuario delante de la ruta relativa: vacío
/// adentro de un proyecto (ya sabe en cuál está) y el nombre del proyecto
/// cuando el chat no tiene ninguno.
typedef ChatDirectoryRoot = ({String label, String root});

/// Qué universo se puede nombrar desde este chat.
///
/// Es lo único que cambia entre el compositor de una sesión y el de Keel AI:
/// las skills, las reglas y el saber son catálogos globales y se leen igual
/// desde cualquier lado.
sealed class ChatReferenceScope {
  const ChatReferenceScope();

  /// Los agentes que tiene sentido nombrar con `@`.
  List<AgentProfile> get agents;

  /// Las carpetas raíz sobre las que se ofrecen y se resuelven directorios.
  ///
  /// Es también el cerco: una ruta que no cae adentro de alguna de estas
  /// nunca entra al prompt, por más que el enlace la nombre.
  List<ChatDirectoryRoot> get directoryRoots;

  /// Cuántos niveles se recorren buscando subcarpetas. Adentro de un
  /// proyecto se recorre todo; con diez proyectos a la vez, recorrerlos
  /// enteros en cada tecla no lo paga nadie.
  int get directoryDepth;
}

/// Adentro de una sesión: las carpetas del proyecto y los miembros del canal.
class ProjectReferenceScope extends ChatReferenceScope {
  const ProjectReferenceScope({required this.project, required this.members});

  final Project project;
  final List<AgentProfile> members;

  @override
  List<AgentProfile> get agents => members;

  @override
  List<ChatDirectoryRoot> get directoryRoots {
    final root = project.workingDirectory.trim();
    if (root.isEmpty) return const [];
    return [(label: '', root: root)];
  }

  @override
  int get directoryDepth => _unlimitedDepth;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectReferenceScope &&
          project == other.project &&
          listEquals(members, other.members);

  @override
  int get hashCode => Object.hash(project, Object.hashAll(members));
}

/// Sin proyecto: Keel AI, el chat 1:1 y el hilo de un requerimiento.
///
/// Las carpetas salen de los proyectos registrados y de las raíces que el
/// usuario usó ([WorkspaceRootsService]) — que es lo que hace que un
/// proyecto en otro disco se pueda nombrar. Los agentes son todos los del
/// catálogo: acá `@` sirve para hablar DE un agente, no para darle el turno.
class GlobalReferenceScope extends ChatReferenceScope {
  const GlobalReferenceScope();

  @override
  List<AgentProfile> get agents =>
      AgentProfilesService.instance.notifier.data.profiles;

  @override
  List<ChatDirectoryRoot> get directoryRoots {
    final roots = <ChatDirectoryRoot>[];
    final seen = <String>{};
    for (final project in ProjectsService.instance.notifier.data.projects) {
      final root = project.workingDirectory.trim();
      if (root.isEmpty || !seen.add(root)) continue;
      roots.add((label: project.name, root: root));
    }
    for (final root in WorkspaceRootsService.instance.notifier.recentPaths) {
      if (!seen.add(root)) continue;
      roots.add((label: path.basename(root), root: root));
    }
    return roots;
  }

  @override
  int get directoryDepth => 3;

  @override
  bool operator ==(Object other) => other is GlobalReferenceScope;

  @override
  int get hashCode => (GlobalReferenceScope).hashCode;
}

const _unlimitedDepth = -1;
