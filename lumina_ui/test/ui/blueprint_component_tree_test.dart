import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/component_tree.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  testWidgets('BlueprintComponentTree renders parsed component nodes and root badge', (tester) async {
    final vm = BlueprintEditorViewModel(
      assetPath: 'contents/blueprints/BP_Player.lmas',
      initialAsset: LuminaAsset(
        assetId: 'BP_Player',
        name: 'BP_Player',
        type: AssetType.actor,
      ),
    );

    final root = vm.addComponent('LuminaCapsuleComponent')!;
    vm.addComponent('LuminaCameraComponent', parentId: root.id);
    vm.addComponent('LuminaCharacterMovementComponent'); // non-scene actor comp

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: BlueprintComponentTree(
            viewModel: vm,
          ),
        ),
      ),
    );

    expect(find.text('COMPONENTS'), findsOneWidget);
    expect(find.text('CapsuleComponent'), findsOneWidget);
    expect(find.text('CameraComponent'), findsOneWidget);
    expect(find.text('CharacterMovementComponent'), findsOneWidget);
    expect(find.text('ROOT'), findsOneWidget);
  });

  testWidgets('BlueprintSubEditor displays Class Defaults and reflection property editors for selected component', (tester) async {
    final vm = BlueprintEditorViewModel(
      assetPath: 'contents/blueprints/BP_Hero.lmas',
    );
    final capsule = vm.addComponent('LuminaCapsuleComponent')!;

    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: BlueprintSubEditor(
            assetName: 'BP_Hero',
            viewModel: vm,
          ),
        ),
      ),
    );

    // Initial load: root selected or Class Defaults visible
    expect(find.text('BLUEPRINT ACTOR'), findsOneWidget);
    expect(find.textContaining('BP_Hero'), findsAtLeastNWidgets(1));
    expect(find.text('CapsuleComponent'), findsWidgets);

    // Tap component to inspect properties
    await tester.tap(find.text('CapsuleComponent'));
    await tester.pump();

    expect(find.text('SHAPE / COLLISION'), findsOneWidget);
    expect(find.text('Capsule Radius'), findsOneWidget);
    expect(find.text('Capsule Half Height'), findsOneWidget);
  });
}
