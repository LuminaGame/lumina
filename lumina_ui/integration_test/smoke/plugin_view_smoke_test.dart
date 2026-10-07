import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/plugin_3d_viewport_container.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_asset_ref_field_control.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_view_renderer.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Smoke — a declarative plugin panel drawn by the editor.
///
/// A scatter tool's panel arrives as a [PluginViewSpec] (as a plugin process
/// sends it) and is drawn in a dock-style panel with every control kind: a
/// section of inputs (text, number, slider, checkbox, enum, colour, asset
/// reference from a real temp project), a button row, a progress bar and a
/// log the "plugin" drives with patches, an image from a real PNG, and a 3D
/// preview of real test-assets models in the editor's plugin viewport. The
/// user edits fields, presses Generate (progress animates through patches
/// while the name field keeps the user's typing), and picks another scene
/// node. The events the plugin received are listed beside the panel.
///
/// Runs on GPU 1 (NVIDIA RTX PRO 2000) — `tool/smoke_report.dart` injects the
/// GPU environment.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const testName = 'Plugin view: a declarative plugin panel renders every control, sends events and animates through patches';

  testWidgets(testName, (tester) async {
    final assets = SmokeArtifacts.testAssetsDir.path;
    const barrelRel = 'Props/Barrels/fuel_barrel_red.glb';
    const acRel = 'Props/AC_units/ac_unit_a_300x300.glb';
    const pngRel = 'FBX/TextureFixtures/SM_Slot_Machine/SM_Slot_Machine_MI_Display_1_Emissive.png';
    for (final rel in [barrelRel, acRel, pngRel]) {
      if (!File('$assets/$rel').existsSync()) {
        markTestSkipped('test-assets/$rel is missing');
        return;
      }
    }

    // A real project with two materials and a texture for the asset field.
    final root = Directory.systemTemp.createTempSync('lumina_smoke_pview_');
    addTearDown(() {
      try {
        root.deleteSync(recursive: true);
      } on FileSystemException catch (_) {}
    });
    final projectDir = '${root.path}/ScatterGame';
    Directory('$projectDir/contents/materials').createSync(recursive: true);
    Directory('$projectDir/contents/textures').createSync(recursive: true);
    for (final m in ['M_Rock_Granite', 'M_Rock_Mossy']) {
      File('$projectDir/contents/materials/$m.lmas').writeAsBytesSync(LuminaAsset(
        assetId: m,
        name: m,
        type: AssetType.filamat,
        rawMatSource: 'material {\n    name : $m,\n    shadingModel : lit\n}\n',
      ).toProtoBufferBytes());
    }
    File('$projectDir/contents/textures/T_Noise.lmas')
        .writeAsBytesSync(const LuminaAsset(assetId: 'T_Noise', name: 'T_Noise', type: AssetType.texture).toProtoBufferBytes());

    const viewId = 'scatter';
    final scene = PluginSceneSpec(cameraDistance: 260, nodes: [
      PluginSceneNode(name: 'Fuel barrel', meshPath: '$assets/$barrelRel'),
      PluginSceneNode(name: 'AC unit', meshPath: '$assets/$acRel'),
    ]);
    final spec = ValueNotifier(PluginViewSpec(id: viewId, children: [
      PluginControl.section('settings', 'Scatter settings', [
        PluginControl.text('intro', 'Scatters props over the selected landscape.', style: 'muted'),
        PluginControl.textField('name', label: 'Layer name', value: 'Props', placeholder: 'Layer name'),
        PluginControl.numberField('count', label: 'Count', value: 120, step: 1),
        PluginControl(kind: PluginControlKind.numberField, id: 'density', props: {
          'label': 'Density',
          'value': 0.4,
          'min': 0,
          'max': 1,
          'step': 0.05,
        }),
        PluginControl.boolField('align', label: 'Align to normal', value: false),
        PluginControl.enumField('mode', label: 'Distribution', value: 'poisson', options: [
          ('poisson', 'Poisson disk'),
          ('grid', 'Jittered grid'),
        ]),
        PluginControl(kind: PluginControlKind.colorField, id: 'tint', props: {'label': 'Tint', 'value': '#C08040'}),
        PluginControl(kind: PluginControlKind.assetRefField, id: 'material', props: {
          'label': 'Material',
          'value': 'contents/materials/M_Rock_Granite.lmas',
          'assetTypes': ['filamat'],
        }),
        PluginControl(kind: PluginControlKind.numberField, id: 'seed', props: {'label': 'Seed', 'value': 7, 'enabled': false}),
      ]),
      PluginControl.row('actions', [
        PluginControl(kind: PluginControlKind.button, id: 'run', props: {'text': 'Generate', 'tone': 'primary'}),
        PluginControl(kind: PluginControlKind.button, id: 'clear', props: {'text': 'Clear', 'tone': 'destructive'}),
        PluginControl(kind: PluginControlKind.button, id: 'bake', props: {'text': 'Bake', 'tone': 'success'}),
      ]),
      PluginControl.progress('job', value: 0, text: 'Idle'),
      PluginControl(kind: PluginControlKind.log, id: 'log', props: {'lines': ['ready'], 'maxLines': 8, 'height': 110}),
      PluginControl.divider('sep'),
      PluginControl.section('previewSection', 'Preview', [
        PluginControl(kind: PluginControlKind.image, id: 'thumb', props: {'path': '$assets/$pngRel', 'height': 90}),
        PluginControl(kind: PluginControlKind.preview3d, id: 'preview', props: {'scene': scene.toJson(), 'height': 260}),
      ]),
      const PluginControl(kind: 'heatmap', id: 'future', props: {}),
    ]));
    final events = ValueNotifier<List<PluginViewEvent>>([]);
    void patch(List<PluginViewPatchOp> ops) => spec.value = spec.value.apply(PluginViewPatch(ops));

    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 600,
                child: _DockPanel(
                  title: 'ROCK SCATTER',
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(EditorDensity.gutter),
                    child: ValueListenableBuilder<PluginViewSpec>(
                      valueListenable: spec,
                      builder: (context, s, _) => PluginViewRenderer(
                        spec: s,
                        projectDir: projectDir,
                        onEvent: (e) => events.value = [...events.value, e],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 1, child: ColoredBox(color: EditorColors.borderSolid)),
              Expanded(
                child: _DockPanel(
                  title: 'EVENTS RECEIVED BY THE PLUGIN',
                  child: ValueListenableBuilder<List<PluginViewEvent>>(
                    valueListenable: events,
                    builder: (context, list, _) => ListView(
                      padding: const EdgeInsets.all(EditorDensity.gutter),
                      children: [
                        for (final e in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('${e.viewId}/${e.controlId}  ${e.kind}  ${e.value ?? ''}',
                                style: EditorTypography.mono(fontSize: 11, color: EditorColors.foreground)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));

    Future<void> settle([int frames = 10]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    Finder control(String id) => find.byKey(ValueKey('$viewId/$id'));
    await settle(30);

    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(milliseconds: 1500));

    expect(find.text('unsupported control heatmap'), findsOneWidget);
    expect(find.byType(Plugin3DViewportContainer), findsOneWidget);
    expect(find.text('M_Rock_Granite'), findsOneWidget);

    // Type a layer name and submit it.
    final name = find.descendant(of: control('name'), matching: find.byType(EditableText));
    await tester.tap(name);
    await settle(3);
    await rec.typeText(name, 'Granite boulders');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await rec.hold(const Duration(milliseconds: 500));

    // Toggle, pick a distribution, pick another material.
    await tester.tap(find.descendant(of: control('align'), matching: find.byType(Checkbox)));
    await rec.hold(const Duration(milliseconds: 500));
    await tester.tap(find.text('Poisson disk'));
    await settle(10);
    await rec.hold(const Duration(milliseconds: 500));
    await tester.tap(find.text('Jittered grid'));
    await settle(10);
    await rec.hold(const Duration(milliseconds: 500));
    final prefix = PluginAssetRefFieldControl.pickerPrefix(viewId, 'material');
    await tester.tap(find.text('M_Rock_Granite'));
    await settle(10);
    await rec.hold(const Duration(milliseconds: 600));
    expect(find.byKey(ValueKey('${prefix}_item_T_Noise.lmas')), findsNothing);
    await tester.tap(find.byKey(ValueKey('${prefix}_item_M_Rock_Mossy.lmas')));
    await settle(10);
    await rec.hold(const Duration(milliseconds: 500));

    // Generate: the "plugin" answers with progress and log patches from a
    // timer while the user types a new name (not submitted yet): the
    // patches must leave the field being typed in alone.
    await tester.tap(find.text('Generate'));
    await settle(2);
    expect(events.value.last.controlId, 'run');
    final lines = <String>['ready', 'generating 120 instances'];
    const steps = 60;
    var tick = 0;
    final job = Timer.periodic(const Duration(milliseconds: 300), (t) {
      tick++;
      final v = tick / steps;
      if (tick % 5 == 0) lines.add('placed ${(v * 120).round()} / 120 instances');
      patch([
        PluginViewPatchOp.set('job', {'value': v, 'text': tick == steps ? 'Done: 120 instances placed' : 'Placing instances'}),
        PluginViewPatchOp.set('log', {'lines': [...lines]}),
      ]);
      if (tick == steps) t.cancel();
    });
    addTearDown(job.cancel);
    await rec.hold(const Duration(milliseconds: 800));
    await tester.tap(name);
    await settle(3);
    await rec.typeText(name, 'Granite boulders v2');
    expect(tick, inInclusiveRange(3, steps - 1), reason: 'the job was patching while the user typed');
    while (job.isActive) {
      await rec.hold(const Duration(milliseconds: 200));
    }
    await rec.hold(const Duration(milliseconds: 400));
    expect(find.text('Done: 120 instances placed'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    final typing = tester.widget<EditableText>(name);
    expect(typing.controller.text, 'Granite boulders v2', reason: 'patches never clobber the field being typed in');
    // Leaving the field sends the new name.
    FocusManager.instance.primaryFocus?.unfocus();
    await rec.hold(const Duration(milliseconds: 600));

    // Pick the other scene node in the preview.
    await tester.ensureVisible(find.byKey(const ValueKey('$viewId/preview/node/AC unit')));
    await settle(5);
    await rec.hold(const Duration(milliseconds: 800));
    await tester.tap(find.byKey(const ValueKey('$viewId/preview/node/AC unit')));
    await settle(20);
    await rec.hold(const Duration(seconds: 2));
    expect(tester.widget<Plugin3DViewportContainer>(find.byType(Plugin3DViewportContainer)).options.meshPath, '$assets/$acRel');

    final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
    SmokeArtifacts.saveScreenshot(testName, png, usedAssets: [barrelRel, acRel, pngRel]);
    await rec.hold(const Duration(seconds: 1));
    rec.save(testName, usedAssets: [barrelRel, acRel, pngRel]);

    final sent = [for (final e in events.value) '${e.controlId}:${e.kind}:${e.value}'];
    expect(sent, [
      'name:changed:Granite boulders',
      'align:changed:true',
      'mode:changed:grid',
      'material:changed:contents/materials/M_Rock_Mossy.lmas',
      'run:pressed:null',
      'name:changed:Granite boulders v2',
      'preview:picked:{node: AC unit}',
    ]);
  });
}

/// A dock panel frame: the editor's panel header over its body.
class _DockPanel extends StatelessWidget {
  const _DockPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: EditorColors.sidebar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: EditorDensity.panelHeaderHeight,
              padding: const EdgeInsets.symmetric(horizontal: EditorDensity.gutter),
              alignment: Alignment.centerLeft,
              color: EditorColors.cardHeader,
              child: Text(title, style: EditorTypography.panelHeading),
            ),
            Expanded(child: child),
          ],
        ),
      );
}
