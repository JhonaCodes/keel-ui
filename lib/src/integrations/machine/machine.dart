/// Qué hay instalado en esta máquina y cómo está mientras Keel trabaja.
///
/// Tres preguntas que hoy se contestan afuera de la app —en una terminal, en
/// un dashboard y en el Monitor de Actividad— y que son sobre lo mismo.
///
/// Todo sale de comandos de macOS que ya están: `sysctl`, `vm_stat` y `ps`,
/// más el PATH del usuario para encontrar los binarios. Ninguna dependencia
/// nueva, y ninguna llamada a la red.
library;

import 'dart:async';
import 'dart:io';

import 'package:keel_ui/src/core/services/user_shell_path.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';

part 'src/service_probe.dart';
part 'src/hardware_probe.dart';
part 'src/running_processes.dart';
