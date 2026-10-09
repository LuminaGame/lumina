import 'dart:convert';
import 'dart:io';

import 'package:lumina_editor_data/lumina_editor.dart';

import 'blueprint_test_project.dart';
import 'widget_class_test_project.dart';

/// A First Person project on disk whose level carries a placed `BP_Clicker`:
/// every tick it prints Get Mouse Position and Get Viewport Size; on a left
/// click it deprojects the cursor, line-traces 1 km into the level (from
/// 60 cm ahead of the camera: the first-person camera sits inside the
/// player's capsule), prints
/// the hit's Impact Point and Location. With `withMenu`, BeginPlay also adds
/// `WBP_Menu` (one button at the top left) to the viewport; with `drawDebug`
/// the trace draws its line and hit point; [extraActors] are placed too.
class PiePointerProject {
  PiePointerProject._(this.root, this.dir, this.name);

  final Directory root;
  final String dir;
  final String name;

  static const String clickerPath = 'contents/blueprints/BP_Clicker.lmas';
  static const String levelPath = 'contents/levels/L_DefaultLevel.lmas';

  static PiePointerProject create({
    String name = 'PiePointer',
    bool withMenu = false,
    bool drawDebug = false,
    List<Map<String, dynamic>> extraActors = const [],
  }) {
    final root = Directory.systemTemp.createTempSync('lumina_pie_pointer_');
    final dir = '${root.path}/$name';
    Directory('$dir/contents/levels').createSync(recursive: true);
    final template = GameTemplateCatalog.byId(kFirstPersonTemplateId);
    final project = LuminaProject(
      projectName: name,
      activeLevel: levelPath,
      template: kFirstPersonTemplateId,
      input: template.input,
    );
    File('$dir/$name.lmproject').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(project.toMap()));
    writeBlueprint(dir, 'BP_Clicker', clickerDocument(withMenu: withMenu, drawDebug: drawDebug));
    if (withMenu) writeWidgetBlueprint(dir, 'WBP_Menu', menuDocument());
    File('$dir/$levelPath').writeAsStringSync(jsonEncode(<String, dynamic>{
      'assetId': 'level_L_DefaultLevel',
      'name': 'L_DefaultLevel',
      'type': 'level',
      'relativePath': levelPath,
      'rawPayload': null,
      'metadata': <String, dynamic>{
        'actors': [
          ...template.levelActors,
          {
            'id': 'clicker_01',
            'name': 'Clicker',
            'type': 'Blueprint',
            'blueprintClass': clickerPath,
            'location': [0.0, 0.0, 0.0],
            'rotation': [0.0, 0.0, 0.0],
            'scale': [1.0, 1.0, 1.0],
          },
          ...extraActors,
        ],
      },
    }));
    return PiePointerProject._(root, dir, name);
  }

  LuminaProject manifest() =>
      LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(File('$dir/$name.lmproject').readAsStringSync()) as Map));

  /// BP_Clicker's graph (see the class comment).
  static LuminaBlueprintDocument clickerDocument({bool withMenu = false, bool drawDebug = false}) {
    final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
      LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
    ]);
    final ctx = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Clicker');
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: ctx);
    doc.eventGraph.nodes.addAll([
      p('event_tick', 'tick'),
      p('get_mouse_position', 'mouse'),
      p('get_viewport_size', 'size'),
      p('break_vector2d', 'mouse_xy'),
      p('make_vector', 'mouse_v'),
      p('vector_to_string', 'mouse_text'),
      p('append_3', 'mouse_line', {'a': 'Mouse '}),
      p('break_vector2d', 'size_xy'),
      p('make_vector', 'size_v'),
      p('vector_to_string', 'size_text'),
      p('append', 'size_line', {'a': ' of viewport '}),
      p('print_string', 'say_mouse', {'key': 'mouse', 'duration': 0.0, 'print_to_log': false}),
      p('was_input_key_just_pressed', 'clicked', {'key': 'LeftMouseButton'}),
      p('branch', 'if_clicked'),
      p('deproject_screen_to_world', 'ray'),
      p('vector_scale', 'far', {'b': 100000.0}),
      p('vector_add', 'ray_end'),
      p('line_trace_by_channel', 'trace', {'draw_debug': drawDebug}),
      p('vector_scale', 'near', {'b': 60.0}),
      p('vector_add', 'ray_start'),
      p('break_hit_result', 'hit'),
      p('vector_to_string', 'impact_text'),
      p('append', 'impact_line', {'a': 'Impact Point '}),
      p('print_string', 'say_impact', {'key': 'impact', 'duration': 10.0}),
      p('vector_to_string', 'location_text'),
      p('append', 'location_line', {'a': 'Location '}),
      p('print_string', 'say_location', {'key': 'location', 'duration': 10.0}),
    ]);
    var n = 0;
    void w(String from, String fromPin, String to, String toPin) => doc.eventGraph.wires.add(
        LuminaBlueprintWire(id: 'w${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin));
    // Tick: print the cursor.
    w('tick', 'exec_tick_out', 'say_mouse', 'exec_in');
    w('mouse', 'return_value', 'mouse_xy', 'in_vec');
    w('mouse_xy', 'x', 'mouse_v', 'x');
    w('mouse_xy', 'y', 'mouse_v', 'y');
    w('mouse_v', 'return_value', 'mouse_text', 'in_vec');
    w('mouse_text', 'return_value', 'mouse_line', 'b');
    w('size', 'return_value', 'size_xy', 'in_vec');
    w('size_xy', 'x', 'size_v', 'x');
    w('size_xy', 'y', 'size_v', 'y');
    w('size_v', 'return_value', 'size_text', 'in_vec');
    w('size_text', 'return_value', 'size_line', 'b');
    w('size_line', 'return_value', 'mouse_line', 'c');
    w('mouse_line', 'return_value', 'say_mouse', 'in_string');
    // A left click: trace from the cursor into the level.
    w('say_mouse', 'exec_out', 'if_clicked', 'exec_in');
    w('clicked', 'return_value', 'if_clicked', 'condition');
    w('if_clicked', 'true_out', 'trace', 'exec_in');
    w('mouse', 'return_value', 'ray', 'screen_position');
    w('ray', 'world_direction', 'far', 'a');
    w('ray', 'world_location', 'ray_end', 'a');
    w('far', 'return_value', 'ray_end', 'b');
    w('ray', 'world_direction', 'near', 'a');
    w('ray', 'world_location', 'ray_start', 'a');
    w('near', 'return_value', 'ray_start', 'b');
    w('ray_start', 'return_value', 'trace', 'start');
    w('ray_end', 'return_value', 'trace', 'end');
    w('trace', 'out_hit', 'hit', 'hit');
    w('trace', 'exec_out', 'say_impact', 'exec_in');
    w('hit', 'impact_point', 'impact_text', 'in_vec');
    w('impact_text', 'return_value', 'impact_line', 'b');
    w('impact_line', 'return_value', 'say_impact', 'in_string');
    w('say_impact', 'exec_out', 'say_location', 'exec_in');
    w('hit', 'location', 'location_text', 'in_vec');
    w('location_text', 'return_value', 'location_line', 'b');
    w('location_line', 'return_value', 'say_location', 'in_string');
    if (withMenu) {
      doc.eventGraph.nodes.addAll([
        p('event_beginplay', 'begin'),
        p('create_widget', 'menu', {'class': 'WBP_Menu'}),
        p('add_to_viewport', 'show_menu'),
      ]);
      w('begin', 'exec_out', 'menu', 'exec_in');
      w('menu', 'exec_out', 'show_menu', 'exec_in');
      w('menu', 'return_value', 'show_menu', 'target');
    }
    return doc;
  }

  void dispose() {
    try {
      if (root.existsSync()) root.deleteSync(recursive: true);
    } on FileSystemException {
      // The editor's watchers may still hold the folder on Windows.
    }
  }
}
