part of '../../system_vault.dart';

/// Decide qué se ve al abrir la app: la bienvenida del vault o el sistema.
///
/// La bienvenida aparece SOLO cuando no hay nada que perder —cero skills,
/// cero agentes, cero estaciones— y el usuario no la contestó antes. Es el
/// caso exacto de "reinstalé y quiero todo de vuelta": con el sistema
/// poblado, restaurar vuelve a ser una decisión con preview.
class VaultBootGate extends StatefulWidget {
  final Widget child;

  const VaultBootGate({super.key, required this.child});

  @override
  State<VaultBootGate> createState() => _VaultBootGateState();
}

class _VaultBootGateState extends State<VaultBootGate> {
  late Future<bool> _shouldWelcome = _decide();

  Future<bool> _decide() async {
    // Preguntar antes de que carguen los catálogos daría "vacío" siempre, y
    // la bienvenida se le aparecería a alguien que tiene todo.
    await awaitCatalogsReady();
    if (SettingsService.instance.notifier.data.vaultOnboardingDone) {
      return false;
    }
    return catalogIsEmpty();
  }

  void _finish() {
    SettingsService.instance.notifier.markVaultOnboardingDone();
    setState(() => _shouldWelcome = Future.value(false));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _shouldWelcome,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snapshot.data != true) return widget.child;
        return VaultWelcomeScreen(onFinish: _finish);
      },
    );
  }
}

/// "Este sistema está vacío: ¿lo traigo de tu repo o empezás de cero?".
class VaultWelcomeScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const VaultWelcomeScreen({super.key, required this.onFinish});

  @override
  State<VaultWelcomeScreen> createState() => _VaultWelcomeScreenState();
}

class _VaultWelcomeScreenState extends State<VaultWelcomeScreen> {
  final TextEditingController _url = TextEditingController();
  String _destination = '';
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    _url.text = SettingsService.instance.notifier.data.vaultRepoUrl;
    _destination = SettingsService.instance.notifier.data.vaultPath;
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _pickDestination() async {
    final path = await getDirectoryPath(
      confirmButtonText: 'Usar esta carpeta',
    );
    if (path == null) return;
    setState(() => _destination = path);
  }

  Future<void> _bringEverything() async {
    await SystemVaultService.instance.notifier.bootstrapFrom(
      url: _url.text,
      destination: _destination,
    );
    if (!mounted) return;
    // Si el respaldo entró, el sistema ya no está vacío: se entra a la app.
    // Si falló, el error queda a la vista y la pantalla no se va.
    if (catalogIsEmpty()) return;
    setState(() => _restored = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ReactiveViewModelBuilder<
            SystemVaultViewModel,
            SystemVaultState
          >(
            viewmodel: SystemVaultService.instance.notifier,
            build: (vault, viewmodel, keep) {
              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(32),
                children: [
                  Text(
                    'Este sistema está vacío',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Si ya tenías keel en otra máquina, tu vault trae todo de '
                    'vuelta: skills, reglas, tools, workflows, MCPs, agentes, '
                    'estaciones, bases de saber y ajustes. Los hilos de chat '
                    'no vuelven, y los secrets vuelven por nombre — sin sus '
                    'valores.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _url,
                    decoration: const InputDecoration(
                      labelText: 'URL del repo del vault',
                      hintText:
                          'git@github.com:usuario/keel-knowledge-bases.git',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: vault.busy ? null : _pickDestination,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: Text(
                      _destination.isEmpty
                          ? 'Elegir dónde va a vivir el vault…'
                          : _destination,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Si esa carpeta ya tiene el $kVaultBackupFileName porque '
                    'clonaste el repo a mano, la adopto tal cual y no clono '
                    'nada.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  _WelcomeActions(
                    busy: vault.busy,
                    restored: _restored,
                    canBring: _destination.isNotEmpty,
                    onBring: _bringEverything,
                    onSkip: widget.onFinish,
                    onEnter: widget.onFinish,
                  ),
                  _VaultStatus(state: vault),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WelcomeActions extends StatelessWidget {
  final bool busy;
  final bool restored;
  final bool canBring;
  final VoidCallback onBring;
  final VoidCallback onSkip;
  final VoidCallback onEnter;

  const _WelcomeActions({
    required this.busy,
    required this.restored,
    required this.canBring,
    required this.onBring,
    required this.onSkip,
    required this.onEnter,
  });

  @override
  Widget build(BuildContext context) {
    if (restored) {
      return FilledButton.icon(
        onPressed: onEnter,
        icon: const Icon(Icons.arrow_forward, size: 18),
        label: const Text('Listo — entrar'),
      );
    }

    return Row(
      children: [
        FilledButton.icon(
          onPressed: busy || !canBring ? null : onBring,
          icon: const Icon(Icons.cloud_download_outlined, size: 18),
          label: const Text('Traer todo y empezar'),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: busy ? null : onSkip,
          child: const Text('Empezar de cero'),
        ),
      ],
    );
  }
}
