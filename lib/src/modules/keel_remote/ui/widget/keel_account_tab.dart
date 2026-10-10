import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/modules/keel_remote/model/keel_account_state.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/widget/keel_remote_parts.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/keel_account_viewmodel.dart';

/// «Cuenta»: signing this machine in to the person's own Keel API, or out.
class KeelAccountTab extends StatelessWidget {
  const KeelAccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<KeelAccountViewModel, KeelAccountState>(
      viewmodel: KeelAccountService.instance.notifier,
      build: (account, viewmodel, keep) {
        final theme = Theme.of(context);
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            Text(
              AppLocalizations.of(context).keelApiIntro,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 20),
            if (account.isSignedIn)
              _SignedInCard(account: account)
            else
              _SignInForm(account: account),
          ],
        );
      },
    );
  }
}

/// Who is signed in, where, and the way out.
class _SignedInCard extends StatelessWidget {
  const _SignedInCard({required this.account});

  final KeelAccountState account;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final device = account.device;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const KeelOnlineDot(online: true),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.keelApiSignedInAs(account.username),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(t.keelApiServerValue(account.host)),
            if (device != null && device.name.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(t.keelApiDeviceValue(device.name)),
            ],
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: KeelAccountService.instance.notifier.signOut,
                icon: const Icon(Icons.logout, size: 16),
                label: Text(t.keelApiSignOut),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Server, username, password and authenticator code. The password and the
/// code are write-only: never prefilled, cleared after every attempt.
class _SignInForm extends StatefulWidget {
  const _SignInForm({required this.account});

  final KeelAccountState account;

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  late final _server = TextEditingController(text: widget.account.origin);
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _password.text;
    final code = _code.text;
    _password.clear();
    _code.clear();
    await KeelAccountService.instance.notifier.signIn(
      origin: _server.text,
      username: _username.text,
      password: password,
      code: code,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final account = widget.account;
    final busy = account.isSigningIn;
    final failure = account.failure;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _server,
            enabled: !busy,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: t.keelApiServerLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _username,
            enabled: !busy,
            autofillHints: const [AutofillHints.username],
            decoration: InputDecoration(labelText: t.keelApiUsernameLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            enabled: !busy,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(labelText: t.keelApiPasswordLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            enabled: !busy,
            keyboardType: TextInputType.number,
            enableSuggestions: false,
            autocorrect: false,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: InputDecoration(labelText: t.keelApiCodeLabel),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 14),
          KeelLoadingBar(loading: busy),
          if (failure != null) KeelFailureText(failure: failure),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: busy ? null : _submit,
              icon: const Icon(Icons.login, size: 16),
              label: Text(t.keelApiSignIn),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            t.keelApiCredentialsNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
