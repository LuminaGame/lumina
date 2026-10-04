import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_component_registry.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/blueprint_test_project.dart';

void main() {
  late BlueprintTestProject project;

  setUpAll(() {
    project = BlueprintTestProject.create(name: 'SpotLightProject');
  });
  tearDownAll(() => project.dispose());

  Future<BlueprintEditorViewModel> open(String name) async {
    final path = project.createBlueprint(name, parentClass: 'LuminaActor');
    final vm = BlueprintEditorViewModel(assetPath: path);
    await vm.load();
    return vm;
  }

  Future<void> pumpEditor(WidgetTester tester, BlueprintEditorViewModel vm) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: BlueprintSubEditor(assetName: vm.fileBasename, assetPath: vm.assetPath, viewModel: vm, showPreviewViewport: false),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));
  }

  test('BlueprintComponentRegistry registers LuminaSpotLightComponent with correct properties and icon', () {
    final desc = BlueprintComponentRegistry.getDescriptor('LuminaSpotLightComponent');
    expect(desc, isNotNull);
    expect(desc!.displayName, 'Spot Light');
    expect(desc.category, 'Lighting');
    expect(desc.isSceneComponent, isTrue);
    expect(desc.icon, LucideIcons.flashlight);

    final schema = desc.properties;
    expect(schema.any((p) => p.dartField == 'intensity' && p.defaultValue == 10000.0), isTrue);
    expect(schema.any((p) => p.dartField == 'colorHex' && p.defaultValue == '#FFFFFF'), isTrue);
    expect(schema.any((p) => p.dartField == 'attenuationRadius' && p.defaultValue == 1000.0), isTrue);
    expect(schema.any((p) => p.dartField == 'innerConeAngle' && p.defaultValue == 30.0), isTrue);
    expect(schema.any((p) => p.dartField == 'outerConeAngle' && p.defaultValue == 45.0), isTrue);
    expect(schema.any((p) => p.dartField == 'castShadows' && p.defaultValue == false), isTrue);
  });

  testWidgets('Add Component search for "light" offers Spot Light, and adding it configures preview scene', (tester) async {
    final vm = await tester.runAsync(() => open('BP_SpotLightTest'));
    addTearDown(vm!.dispose);
    await pumpEditor(tester, vm);

    await tester.tap(find.byKey(const ValueKey('add_component_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('add_component_search')), 'light');
    await tester.pumpAndSettle();

    expect(find.text('Directional Light'), findsOneWidget);
    expect(find.byKey(const ValueKey('add_component_LuminaPointLightComponent')), findsOneWidget);
    expect(find.byKey(const ValueKey('add_component_LuminaSpotLightComponent')), findsOneWidget);
    expect(find.text('Spot Light'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add_component_LuminaSpotLightComponent')));
    await tester.pumpAndSettle();

    final spot = vm.getComponent(vm.selectedComponentId!)!;
    expect(spot.type, 'LuminaSpotLightComponent');
    expect(spot.properties['intensity'], 10000.0);
    expect(spot.properties['attenuationRadius'], 1000.0);
    expect(spot.properties['innerConeAngle'], 30.0);
    expect(spot.properties['outerConeAngle'], 45.0);
    expect(spot.properties['colorHex'], '#FFFFFF');
    expect(spot.properties['castShadows'], isFalse);

    // Viewport preview builds LuminaSpotLightComponent with matching properties
    final previewLight = vm.preview.componentFor(spot.id) as LuminaSpotLightComponent;
    expect(previewLight.intensity, 10000.0);
    expect(previewLight.falloffRadius, 1000.0);
    expect(previewLight.innerConeAngleDegrees, 30.0);
    expect(previewLight.outerConeAngleDegrees, 45.0);

    // Modify cone angle and attenuation radius
    vm.commitProperty(spot.id, 'innerConeAngle', 20.0);
    vm.commitProperty(spot.id, 'outerConeAngle', 60.0);
    vm.commitProperty(spot.id, 'attenuationRadius', 1500.0);

    final updatedLight = vm.preview.componentFor(spot.id) as LuminaSpotLightComponent;
    expect(updatedLight.innerConeAngleDegrees, 20.0);
    expect(updatedLight.outerConeAngleDegrees, 60.0);
    expect(updatedLight.falloffRadius, 1500.0);

    await tester.pumpWidget(const SizedBox());
  });
}
