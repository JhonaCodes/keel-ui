/// Qué hay instalado en esta máquina y cómo está mientras Keel trabaja.
///
/// Tres preguntas que hoy se contestan afuera de la app —en una terminal, en
/// un dashboard y en el Monitor de Actividad— y que son sobre lo mismo.
///
/// Todo sale de comandos de macOS que ya están: `which`, `sysctl`, `vm_stat`
/// y `ps`. Ninguna dependencia nueva, y ninguna llamada a la red. Es de
/// macOS y solo de macOS, igual que la app.
library;

import 'dart:async';
import 'dart:io';

import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';

part 'src/service_probe.dart';
part 'src/hardware_probe.dart';
part 'src/running_processes.dart';
