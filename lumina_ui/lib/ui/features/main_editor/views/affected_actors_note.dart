import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/theme/editor_theme.dart';
import '../view_models/editor_view_model.dart';

/// The placed actors a delete will remove with the assets they reference,
/// listed in the delete confirmations so nothing leaves the level
/// unannounced. Renders nothing when no actor is affected.
class AffectedActorsNote extends StatelessWidget {
  final List<EditorActorNode> actors;

  const AffectedActorsNote({super.key, required this.actors});

  @override
  Widget build(BuildContext context) {
    if (actors.isEmpty) return const SizedBox.shrink();
    const shown = 6;
    final names = actors.take(shown).map((a) => a.name).join(', ');
    final more = actors.length > shown ? ' and ${actors.length - shown} more' : '';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        actors.length == 1
            ? 'Also removes 1 placed actor that uses it: $names. Edit → Undo brings it back.'
            : 'Also removes ${actors.length} placed actors that use them: $names$more. Edit → Undo brings them back.',
        key: const ValueKey('delete_affected_actors'),
        style: const TextStyle(fontSize: 9, color: EditorColors.destructive),
      ),
    );
  }
}
