import 'package:flutter/widgets.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
export 'package:lumina_editor_api/lumina_editor_api.dart' show EditorCommand;

class EditorCommandRegistry extends ChangeNotifier {
  final Map<String, EditorCommand> _commands = {};
  
  // Callback to log executions
  final void Function(String id)? onCommandExecuted;

  EditorCommandRegistry({this.onCommandExecuted});

  void register(EditorCommand command) {
    _commands[command.id] = command;
    notifyListeners();
  }
  
  void registerAll(List<EditorCommand> commands) {
    for (var c in commands) {
      _commands[c.id] = c;
    }
    notifyListeners();
  }

  EditorCommand? byId(String id) => _commands[id];

  List<EditorCommand> get all => _commands.values.toList();

  bool execute(String id, [BuildContext? context]) {
    final cmd = _commands[id];
    if (cmd != null && cmd.canExecute()) {
      cmd.execute(context);
      onCommandExecuted?.call(id);
      return true;
    }
    return false;
  }
}
