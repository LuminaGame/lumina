import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/theme/editor_theme.dart';
import '../view_models/marketplace_view_model.dart';

/// Sign in to the Marketplace (email or username + password), or create an
/// account. The session is kept for the next editor run.
void showMarketplaceSignInDialog(BuildContext context, MarketplaceViewModel viewModel) {
  showOverlay(
    context,
    const DialogConfiguration(),
    builder: (dialogContext) => MarketplaceSignInDialog(viewModel: viewModel),
  );
}

class MarketplaceSignInDialog extends StatefulWidget {
  const MarketplaceSignInDialog({super.key, required this.viewModel});

  final MarketplaceViewModel viewModel;

  @override
  State<MarketplaceSignInDialog> createState() => _MarketplaceSignInDialogState();
}

class _MarketplaceSignInDialogState extends State<MarketplaceSignInDialog> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _email = TextEditingController();
  final _displayName = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    _email.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final vm = widget.viewModel;
    final ok = _creating
        ? await vm.signUp(
            email: _email.text,
            username: _login.text,
            password: _password.text,
            displayName: _displayName.text.trim().isEmpty ? null : _displayName.text.trim())
        : await vm.signIn(_login.text, _password.text);
    if (ok && mounted) Navigator.of(context).pop();
  }

  Widget _field(String label, TextEditingController controller, Key key, {bool obscure = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
            const SizedBox(height: 3),
            TextField(key: key, controller: controller, obscureText: obscure, onSubmitted: (_) => _submit()),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => AlertDialog(
        title: Text(_creating ? 'Create a Marketplace account' : 'Sign in to the Marketplace'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(vm.serverUrl.toString(), style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
              const SizedBox(height: 10),
              if (_creating) _field('Email', _email, const ValueKey('marketplace_signup_email')),
              _field(_creating ? 'Username' : 'Email or username', _login, const ValueKey('marketplace_login_field')),
              if (_creating) _field('Display name (optional)', _displayName, const ValueKey('marketplace_signup_display_name')),
              _field('Password', _password, const ValueKey('marketplace_password_field'), obscure: true),
              if (vm.sessionError != null)
                Text(vm.sessionError!,
                    key: const ValueKey('marketplace_session_error'),
                    style: TextStyle(fontSize: 10, color: EditorColors.destructive)),
              const SizedBox(height: 4),
              GhostButton(
                key: const ValueKey('marketplace_toggle_signup'),
                density: ButtonDensity.compact,
                onPressed: () => setState(() => _creating = !_creating),
                child: Text(_creating ? 'I have an account' : 'Create an account', style: const TextStyle(fontSize: 10)),
              ),
            ],
          ),
        ),
        actions: [
          OutlineButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          PrimaryButton(
            key: const ValueKey('marketplace_sign_in_submit'),
            onPressed: vm.sessionBusy ? null : _submit,
            child: Text(_creating ? 'Create account' : 'Sign in'),
          ),
        ],
      ),
    );
  }
}
