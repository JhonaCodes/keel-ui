part of '../system_prompt.dart';

/// DÓNDE ESTÁN LAS COSAS EN ESTA MÁQUINA, para un agente que no tiene
/// proyecto.
///
/// Qué dice: la lista de proyectos registrados con su ruta absoluta, y los
/// otros lugares donde este usuario trabaja. Nada más: no es una invitación
/// a recorrer el disco.
///
/// Por qué existe: un agente 1:1 —y Keel AI— corre con el directorio de
/// trabajo en `$HOME`, porque no tiene proyecto asignado. Si los proyectos
/// del usuario viven en otra partición (`/Volumes/Data`, `D:\`, un disco
/// externo), pedirle "mirá el proyecto tal" lo manda a buscar donde no está:
/// termina recorriendo la carpeta de usuario, no encuentra nada y concluye
/// que el proyecto no existe, o peor, inventa una ruta. La app sabe dónde
/// están —las guarda cada vez que se elige una carpeta— así que se las dice.
///
/// Quién lo usa: `_resolveProfileSystemPrompt` en
/// `modules/agents/viewmodel/agents_viewmodel.dart`, para el chat 1:1 y para
/// Keel AI. En una sesión de proyecto no hace falta: ahí el turno ya corre
/// parado en la carpeta correcta.
String knownRootsPrompt({
  required List<({String name, String path})> projects,
  required List<String> otherRoots,
}) {
  if (projects.isEmpty && otherRoots.isEmpty) return '';

  final buffer = StringBuffer();
  buffer.writeln(
    'DÓNDE ESTÁN LAS COSAS: no estás parado adentro de ningún proyecto — tu '
    'directorio de trabajo es la carpeta del usuario. Estas son las rutas '
    'reales en esta máquina; usalas tal cual, con ruta absoluta, en vez de '
    'salir a buscar o suponer dónde están. Pueden estar en otro disco o en '
    'otra partición, así que buscar desde tu carpeta de trabajo no las '
    'encuentra.',
  );
  if (projects.isNotEmpty) {
    buffer.writeln('Proyectos registrados:');
    for (final project in projects) {
      buffer.writeln('- ${project.name}: ${project.path}');
    }
  }
  if (otherRoots.isNotEmpty) {
    buffer.writeln('Otras carpetas donde el usuario trabaja:');
    for (final root in otherRoots) {
      buffer.writeln('- $root');
    }
  }
  buffer.writeln(
    'Si lo que te piden no está en ninguna de estas rutas, preguntá dónde '
    'está en vez de recorrer el disco.',
  );
  return buffer.toString().trimRight();
}
