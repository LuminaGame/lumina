import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_editor_nodes.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';

import '../helpers/scaffold_game_project.dart';

/// Measured with the Blueprint editor's own node layout: a
/// new Third Person project opens BP_ThirdPersonCharacter with one titled
/// comment box per event chain. The boxes are stacked at one left x, and
/// every node sits inside exactly one box without overlapping another node.
void main() {
  late Directory root;
  late BlueprintEditorViewModel vm;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_bp_template_layout_');
    final dir = await scaffoldGameProject(root, name: 'bp_template_layout', widgetLibrary: 'flutter');
    vm = BlueprintEditorViewModel(assetPath: '$dir/${LuminaThirdPersonContent.characterBlueprintPath}');
    await vm.load();
  });
  tearDownAll(() {
    vm.dispose();
    root.deleteSync(recursive: true);
  });

  test('the scaffolded Event Graph draws as stacked comment boxes, each holding its chain without overlaps', () {
    final editor = vm.eventGraph;
    Rect rect(LuminaBlueprintNode n) => BlueprintNodeLayout.of(editor, n).rect;
    final comments = [for (final n in editor.nodes) if (BlueprintEditorNodes.isComment(n)) n];
    final nodes = [for (final n in editor.nodes) if (!BlueprintEditorNodes.isComment(n)) n];
    expect([for (final c in comments) c.literals['title']], ['Move', 'Look', 'Jump', 'Sprint', 'Dash', 'Free Look', 'Wall Trace']);
    expect(comments.map((c) => c.x).toSet(), hasLength(1), reason: 'one left x');
    for (var i = 1; i < comments.length; i++) {
      expect(rect(comments[i]).top, greaterThan(rect(comments[i - 1]).bottom), reason: '${comments[i].title} below ${comments[i - 1].title}');
    }

    final boxOf = <String, String>{};
    for (final c in comments) {
      final inside = BlueprintEditorNodes.nodesInside(c, editor.nodes, sizeOf: (x) {
        final l = BlueprintNodeLayout.of(editor, x);
        return (width: l.width, height: l.height);
      });
      for (final n in inside) {
        expect(boxOf[n.id], isNull, reason: '${n.id} is in ${boxOf[n.id]} and ${c.title}');
        boxOf[n.id] = c.title;
      }
    }
    for (final n in nodes) {
      expect(boxOf[n.id], isNotNull, reason: '${n.id} (${n.title}) at ${rect(n)} is in no comment box');
    }
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        expect(rect(nodes[i]).overlaps(rect(nodes[j])), isFalse, reason: '${nodes[i].id} ${rect(nodes[i])} / ${nodes[j].id} ${rect(nodes[j])}');
      }
    }
    // The editor's graph has no problems, and the engine sees no comment.
    expect(editor.nodes.expand((n) => editor.problems(n)), isEmpty);
    expect(vm.engineDocument.eventGraph.nodes.where(BlueprintEditorNodes.isComment), isEmpty);
  });
}
