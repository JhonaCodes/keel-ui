import 'dart:io';

import 'package:logger_rs/logger_rs.dart';

/// Abre la Terminal de macOS y corre [command] en una pestaña nueva.
///
/// Para lo que necesita el shell de verdad del usuario —su PATH, una TTY,
/// un navegador que se abre y espera—, que una app de macOS no tiene: arranca
/// con un PATH mínimo y sin terminal. Devuelve si la Terminal lo aceptó.
Future<bool> openInTerminal(String command) async {
  final script =
      'tell application "Terminal"\n'
      '  activate\n'
      '  do script ${_applescriptString(command)}\n'
      'end tell';
  final opened = await Process.run('osascript', ['-e', script]);
  if (opened.exitCode != 0) {
    Log.e('No pude abrir la Terminal: ${opened.stderr}');
    return false;
  }
  return true;
}

/// Un comando trae comillas y barras: sin escaparlas, `osascript` no lo
/// lee como un solo texto.
String _applescriptString(String text) {
  final escaped = text.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}
