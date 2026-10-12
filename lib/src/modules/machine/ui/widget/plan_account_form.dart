import 'package:flutter/material.dart';

import 'package:keel_core/integrations/plan_usage/plan_usage.dart';

/// Alta de una cuenta de [provider], en línea: un nombre y el botón. Al
/// agregarla se abre la Terminal con el login de esa cuenta.
class PlanAccountForm extends StatefulWidget {
  const PlanAccountForm({
    super.key,
    required this.provider,
    required this.onAdd,
  });

  final PlanProvider provider;

  /// Devuelve el motivo si no se pudo, o null.
  final Future<String?> Function(String name) onAdd;

  @override
  State<PlanAccountForm> createState() => _PlanAccountFormState();
}

class _PlanAccountFormState extends State<PlanAccountForm> {
  final _name = TextEditingController();
  String? _error;
  bool _adding = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _adding = true;
      _error = null;
    });
    final error = await widget.onAdd(_name.text);
    if (!mounted) return;
    setState(() {
      _adding = false;
      _error = error;
      if (error == null) _name.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _name,
              enabled: !_adding,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Otra cuenta de ${widget.provider.label}',
                hintText: 'trabajo, personal…',
                helperText:
                    'Se guarda en ~/${widget.provider.dirPrefix}<nombre>',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: FilledButton.icon(
              onPressed: _adding ? null : _submit,
              icon: const Icon(Icons.login, size: 16),
              label: const Text('Agregar e iniciar sesión'),
            ),
          ),
        ],
      ),
    );
  }
}
