import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Lumina Studio does not wait for the GPU on the UI isolate: resource
/// teardown orders its destruction with `flush()` and the next frame, state
/// updates (pose, morph weights, material overrides) are drawn by the next
/// frame as they are, readbacks (thumbnails, movie frames) await a fence.
/// The few places that still block are named sections of the stall audit,
/// each with a reason, and this list is the whole set: the editor's own code
/// and the editor data layer it runs on (thumbnails, importers).
void main() {
  test('every blocking GPU wait in the editor is a justified, audited section', () {
    final uiLib = Directory(p.join(Directory.current.path, 'lib'));
    final dataLib = Directory(p.join(Directory.current.parent.path, 'lumina_editor_data', 'lib'));
    expect(dataLib.existsSync(), isTrue, reason: 'lumina_editor_data is the sibling package');
    final allowed = <String, String>{
      // The whole native scene goes with the level viewport.
      'lumina_ui/ui/features/main_editor/views/viewport_widget/scene_sync.dart': 'level viewport teardown',
      // A build step with its own engine: no viewport is held.
      'lumina_ui/ui/features/sub_editors/services/build_pipeline_service/material_precompile_step.dart': '',
    };
    final found = <String, List<String>>{};
    for (final (name, lib) in [('lumina_ui', uiLib), ('lumina_editor_data', dataLib)]) {
      for (final file in lib.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (!line.contains('flushAndWait') || line.trimLeft().startsWith('//')) continue;
          final rel = '$name/${p.relative(file.path, from: lib.path).replaceAll(r'\', '/')}';
          final entry = found.putIfAbsent(rel, () => <String>[]);
          entry.add('${i + 1}: ${line.trim()}');
        }
      }
    }
    final offenders = <String>[];
    for (final entry in found.entries) {
      final section = allowed[entry.key];
      if (section == null) {
        offenders.add('${entry.key}\n    ${entry.value.join('\n    ')}');
        continue;
      }
      if (entry.value.length != 1) offenders.add('${entry.key}: one wait is allowed, ${entry.value.length} found');
      if (section.isNotEmpty && !entry.value.single.contains("FilamentStallAudit.section('$section'")) {
        offenders.add("${entry.key}: the wait must run as the audit section '$section'");
      }
    }
    for (final rel in allowed.keys) {
      expect(found.containsKey(rel), isTrue, reason: '$rel no longer waits; drop it from the allowed list');
    }
    expect(offenders, isEmpty, reason: 'GPU waits on the UI isolate:\n${offenders.join('\n')}');
  });
}
