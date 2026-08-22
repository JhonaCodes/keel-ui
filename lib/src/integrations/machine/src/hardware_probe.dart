part of '../machine.dart';

/// Cómo está la máquina ahora.
class MachineState {
  /// El chip, como lo nombra el sistema.
  final String cpu;
  final int cores;

  /// Promedio de carga del último minuto. Contra [cores] dice si la máquina
  /// está cómoda: 4 en doce núcleos es tranquilo, 4 en dos no.
  final double load;

  final int memoryTotalBytes;
  final int memoryUsedBytes;

  /// Los procesos que largó Keel y siguen vivos.
  final List<MachineProcess> processes;

  const MachineState({
    this.cpu = '',
    this.cores = 0,
    this.load = 0,
    this.memoryTotalBytes = 0,
    this.memoryUsedBytes = 0,
    this.processes = const [],
  });

  double get loadRatio => cores == 0 ? 0 : (load / cores).clamp(0, 1);
  double get memoryRatio =>
      memoryTotalBytes == 0 ? 0 : memoryUsedBytes / memoryTotalBytes;
}

/// Un proceso que Keel largó.
class MachineProcess {
  final int pid;
  final String command;
  final double cpuPercent;
  final double memoryPercent;
  final int residentBytes;

  const MachineProcess({
    required this.pid,
    required this.command,
    required this.cpuPercent,
    required this.memoryPercent,
    required this.residentBytes,
  });
}

/// Lee el estado de la máquina.
///
/// Se llama solo con la pantalla abierta. Un timer que corre siempre para
/// dibujar un número que nadie está mirando es exactamente lo que hacía que
/// la app tardara veinte segundos en dejarse tocar.
Future<MachineState> readMachineState({Set<int> pids = const {}}) async {
  final results = await Future.wait([
    Process.run('sysctl', [
      '-n',
      'machdep.cpu.brand_string',
      'hw.ncpu',
      'hw.memsize',
      'vm.loadavg',
    ]),
    Process.run('vm_stat', const []),
    if (pids.isEmpty)
      Future.value(ProcessResult(0, 0, '', ''))
    else
      Process.run('ps', [
        '-o',
        'pid=,pcpu=,pmem=,rss=,comm=',
        '-p',
        pids.join(','),
      ]),
  ]);

  final sysctl = '${results[0].stdout}'.trim().split('\n');
  final memoryTotal = sysctl.length > 2
      ? int.tryParse(sysctl[2].trim()) ?? 0
      : 0;

  return MachineState(
    cpu: sysctl.isNotEmpty ? sysctl.first.trim() : '',
    cores: sysctl.length > 1 ? int.tryParse(sysctl[1].trim()) ?? 0 : 0,
    load: sysctl.length > 3 ? _firstLoadAverage(sysctl[3]) : 0,
    memoryTotalBytes: memoryTotal,
    memoryUsedBytes: _usedMemory('${results[1].stdout}'),
    processes: _parseProcesses('${results[2].stdout}'),
  );
}

/// `vm.loadavg` sale como `{ 2.51 3.02 3.31 }`. Interesa el primero: el del
/// último minuto es el que se corresponde con lo que está pasando ahora.
double _firstLoadAverage(String raw) {
  final numbers = RegExp(r'[\d.]+').allMatches(raw);
  if (numbers.isEmpty) return 0;
  return double.tryParse(numbers.first.group(0)!) ?? 0;
}

/// La memoria realmente ocupada, según `vm_stat`.
///
/// No es "total menos libre": en macOS lo inactivo y el caché de archivos se
/// devuelven cuando hacen falta, así que contarlos daría siempre 95% y no
/// diría nada. Lo que ocupa de verdad es activo + wired + comprimido, que es
/// lo mismo que muestra el Monitor de Actividad.
int _usedMemory(String vmStat) {
  var pageSize = 4096;
  final header = RegExp(r'page size of (\d+) bytes').firstMatch(vmStat);
  if (header != null) pageSize = int.parse(header.group(1)!);

  int pages(String label) {
    final match = RegExp('$label:\\s+(\\d+)').firstMatch(vmStat);
    return match == null ? 0 : int.parse(match.group(1)!);
  }

  final used =
      pages('Pages active') +
      pages('Pages wired down') +
      pages('Pages occupied by compressor');
  return used * pageSize;
}

List<MachineProcess> _parseProcesses(String raw) {
  final processes = <MachineProcess>[];
  for (final line in raw.split('\n')) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 5) continue;
    final pid = int.tryParse(parts[0]);
    if (pid == null) continue;
    processes.add(
      MachineProcess(
        pid: pid,
        // El comando puede traer espacios: lo que sobra después de las
        // cuatro columnas numéricas es todo suyo.
        command: parts.sublist(4).join(' '),
        cpuPercent: double.tryParse(parts[1]) ?? 0,
        memoryPercent: double.tryParse(parts[2]) ?? 0,
        residentBytes: (int.tryParse(parts[3]) ?? 0) * 1024,
      ),
    );
  }
  processes.sort((a, b) => b.cpuPercent.compareTo(a.cpuPercent));
  return processes;
}
