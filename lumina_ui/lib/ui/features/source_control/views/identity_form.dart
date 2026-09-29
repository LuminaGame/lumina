import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/theme/editor_theme.dart';
import '../view_models/source_control_view_model.dart';

/// One-time setup form shown when git refuses to commit because
/// `user.name`/`user.email` are unset. Writes a **repo-local** identity via
/// `git config` — never the Studio user's mail, never global config.
class GitIdentityForm extends StatefulWidget {
  final SourceControlViewModel viewModel;

  const GitIdentityForm({super.key, required this.viewModel});

  @override
  State<GitIdentityForm> createState() => _GitIdentityFormState();
}

class _GitIdentityFormState extends State<GitIdentityForm> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && _email.text.trim().contains('@');

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.viewModel.configureIdentity(name: _name.text, email: _email.text);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Git needs to know who you are before it can commit. This identity is stored in this repository only.',
            style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('sc_identity_name'),
                  controller: _name,
                  placeholder: const Text('Name'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  key: const ValueKey('sc_identity_email'),
                  controller: _email,
                  placeholder: const Text('Email'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 6),
              PrimaryButton(
                key: const ValueKey('sc_identity_save'),
                onPressed: _valid && !_saving ? _save : null,
                child: const Text('Save identity & retry'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
