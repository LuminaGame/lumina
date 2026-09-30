import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';

import '../helpers/widget_class_test_project.dart';

/// A Blueprint editor that is already open when a widget Blueprint is
/// created and saved types that widget's elements: `Get <Element>` of the
/// new widget is a Text Block that wires into `Set Text (Text)`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a widget saved after a Blueprint editor opened types its Get <Element> in that editor', () async {
    final project = WidgetClassTestProject.create();
    addTearDown(project.dispose);
    final vm = BlueprintEditorViewModel(assetPath: project.characterPath);
    addTearDown(vm.dispose);
    await vm.load();
    expect(vm.widgetClassCatalog!.widgetClass('WBP_Score'), isNull);

    // The designer creates WBP_Score with a Text and saves it.
    await AssetRepository().createAsset(projectPath: project.dir, subFolder: 'widgets', fileName: 'WBP_Score.lmas', type: AssetType.widget);
    final umg = UmgEditorViewModel(assetPath: '${project.dir}/contents/widgets/WBP_Score.lmas');
    addTearDown(umg.dispose);
    await umg.load();
    final text = umg.addWidget(UmgWidgetType.text, parentId: umg.document.root.id, canvasPosition: const Offset(40, 30))!;
    expect(await umg.save(), isTrue);
    await pumpEventQueue();

    vm.addVariable('HUD', 'Widget:WBP_Score');
    final hud = vm.eventGraph.placeVariable('HUD', set: false, position: const Offset(0, 0))!;
    final element = vm.addGraphNode(LuminaBlueprintNodeLibrary.getWidgetElement, const Offset(200, 0), literals: {'element': text.name})!;
    final setText = vm.addGraphNode('set_element_text', const Offset(400, 0))!;
    expect(vm.eventGraph.whyNotConnect(hud.id, 'value', element.id, 'target'), isNull);
    expect(vm.eventGraph.pin(element.id, 'return_value', output: true)!.objectClass, 'WidgetElement:text',
        reason: 'the open editor read the widget saved after it opened');
    expect(vm.eventGraph.whyNotConnect(element.id, 'return_value', setText.id, 'target'), isNull);
  });
}
