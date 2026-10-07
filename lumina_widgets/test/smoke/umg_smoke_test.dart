import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' show LuminaBlueprintClass;
import 'package:lumina/lumina_runtime.dart';
import 'package:lumina/testing.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

import '../../../lumina/test/blueprint/generated/widget_script/wbp_clicker.g.dart';
import '../../../lumina/test/blueprint/widget_blueprint_fixture.dart';

/// UMG smoke — the plain-Flutter UMG widget set drawn in one real frame (a
/// pause menu as a game would show it), with no Material and no shadcn above
/// it. Text uses the SDK's Roboto so the PNG is readable.
const _name = 'umg: plain Flutter widget set';

/// UMG HUD smoke — a HUD widget in a headless game host.
const _hudName = 'umg: HUD widget in a headless game host';

/// UMG graph smoke — a widget's own graph (the generated `WbpClickerGraph`)
/// running in a headless game host.
const _graphName = 'umg: widget blueprint graph in a headless game host';

/// UMG interface smoke — a character sends an interface message to the widget
/// `Create Widget` returned, and the widget's own graph sets its text.
const _interfaceName = 'umg: interface message updates the created widget in a headless game host';

/// What lumina_ui's codegen emits for WBP_Clicker's Title, StartButton and
/// Charge: elements read through the binding, the button's handler fires
/// the element event into the instance's graph script.
class _WbpClicker extends StatelessWidget {
  const _WbpClicker({this.instance});

  final Map<String, Object?>? instance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LuminaUmgElement(
            instance: instance,
            name: 'Title',
            builder: (context, e) => Text(LuminaUmgElementBinding.value<String>(e, 'text', 'Text Block'), style: const TextStyle(fontSize: 44)),
          ),
          const SizedBox(height: 32),
          LuminaUmgElement(
            instance: instance,
            name: 'StartButton',
            builder: (context, e) => LuminaUmgButton(
              key: const ValueKey('startButton'),
              onPressed: () => LuminaUserWidgets.fire(instance, 'StartButton', 'OnClicked'),
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12), child: Text('Start', style: TextStyle(fontSize: 28))),
            ),
          ),
          const SizedBox(height: 32),
          LuminaUmgElement(
            instance: instance,
            name: 'Charge',
            builder: (context, e) => SizedBox(
              width: 640,
              height: 28,
              child: LuminaUmgProgressBar(progress: LuminaUmgElementBinding.value<double>(e, 'percent', 0.0), color: const Color(0xFF4ADE80)),
            ),
          ),
        ],
      ),
    );
  }
}

/// A character whose BeginPlay does what the Third Person BeginPlay of the
/// editor's UMG smoke does: Create Widget WBP_Clicker, Add to Viewport.
class _ClickerCharacter extends LuminaCharacter {
  Map<String, Object?>? widget;

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    widget = LuminaBlueprintFunctionLibrary.createWidget(this, clickerClass) as Map<String, Object?>;
    LuminaBlueprintFunctionLibrary.addToViewport(this, widget, 0);
  }
}

/// A runner character: Create Widget WBP_Clicker + Add to Viewport at
/// BeginPlay, then every tick `Update Score (Message)` on the widget with the
/// distance run so far, as a HUD Blueprint Interface does.
class _ScoreCharacter extends LuminaCharacter {
  Map<String, Object?>? hud;
  double distance = 0;

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    hud = LuminaBlueprintFunctionLibrary.createWidget(this, clickerClass) as Map<String, Object?>;
    LuminaBlueprintFunctionLibrary.addToViewport(this, hud, 0);
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    distance += 6 * deltaTime;
    LuminaBlueprintFunctionLibrary.interfaceMessage(this, hud, 'BPI_ScoreHUD', 'UpdateScore', {'Text': 'Distance: ${distance.round()} m'});
  }
}

/// WBP_Clicker implementing BPI_ScoreHUD: its graph's Event Update Score sets
/// the Title to the message's Text.
LuminaWidgetBlueprintDocument _scoreHudBlueprint() {
  final doc = clickerBlueprint();
  doc.blueprint.interfaces.add('BPI_ScoreHUD');
  final c = LuminaBlueprintTypeContext.forWidget(doc, widgetClasses: const [clickerWidgetClass]);
  doc.blueprint.eventGraph.nodes.addAll([
    LuminaBlueprintNodeLibrary.place('event_interface_function', nodeId: 'update',
        literals: {'interface': 'BPI_ScoreHUD', 'function': 'UpdateScore'}, context: c),
    LuminaBlueprintNodeLibrary.place('set_element_text', nodeId: 'score_text', context: c),
  ]);
  doc.blueprint.eventGraph.wires.addAll([
    LuminaBlueprintWire(id: 's0', fromNodeId: 'update', fromPinId: 'exec_out', toNodeId: 'score_text', toPinId: 'exec_in'),
    LuminaBlueprintWire(id: 's1', fromNodeId: 'update', fromPinId: 'Text', toNodeId: 'score_text', toPinId: 'in_text'),
    LuminaBlueprintWire(id: 's2', fromNodeId: 'title', fromPinId: 'return_value', toNodeId: 'score_text', toPinId: 'target'),
  ]);
  return doc;
}

/// The widget class `umg_widget_codegen` emits for a WBP_HUD (Text
/// `FPSCounter`, Progress Bar `Health`): every element wrapped in a
/// [LuminaUmgElement] reading its runtime state through the binding.
class _WbpHud extends StatelessWidget {
  const _WbpHud({this.instance});

  final Map<String, Object?>? instance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LuminaUmgElement(
            instance: instance,
            name: 'FPSCounter',
            builder: (context, e) => Text(
              LuminaUmgElementBinding.value<String>(e, 'text', 'FPS: 0'),
              style: TextStyle(fontSize: LuminaUmgElementBinding.value<double>(e, 'fontSize', 28.0), color: LuminaUmgElementBinding.color(e, 'color', const Color(0xFFFFFFFF))),
            ),
          ),
          const SizedBox(height: 12),
          LuminaUmgElement(
            instance: instance,
            name: 'Health',
            builder: (context, e) => SizedBox(
              width: 220,
              height: 12,
              child: LuminaUmgProgressBar(
                progress: LuminaUmgElementBinding.value<double>(e, 'percent', 1.0),
                color: LuminaUmgElementBinding.color(e, 'fillColor', const Color(0xFF4ADE80)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A character whose Tick does what the FPS HUD Blueprint does: Create Widget
/// + Add to Viewport once, then `Get FPSCounter → Set Text (Text)` each frame.
class _HudCharacter extends LuminaCharacter {
  Map<String, Object?>? hud;
  int ticks = 0;

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    ticks++;
    if (hud == null) {
      hud = LuminaBlueprintFunctionLibrary.createWidget(this, 'WBP_HUD') as Map<String, Object?>;
      LuminaBlueprintFunctionLibrary.addToViewport(this, hud, 0);
      return;
    }
    final fps = LuminaBlueprintFunctionLibrary.getWidgetElement(hud, 'FPSCounter');
    LuminaBlueprintFunctionLibrary.setElementText(this, fps, 'FPS: ${(1 / deltaTime).round()}');
    final health = LuminaBlueprintFunctionLibrary.getWidgetElement(hud, 'Health');
    LuminaBlueprintFunctionLibrary.setElementPercent(this, health, 1.0 - ticks / 60.0);
  }
}

Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'] ??
      Platform.resolvedExecutable.substring(0, Platform.resolvedExecutable.indexOf('/bin/cache/'));
  final font = File('$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
  if (!font.existsSync()) return;
  final loader = FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
  await loader.load();
}

void main() {
  testWidgets(_name, (tester) async {
    await tester.runAsync(_loadRoboto);
    tester.view.physicalSize = const Size(640, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final boundary = GlobalKey();
    var volume = 0.7;
    var invertY = true;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(fontFamily: 'Roboto', color: LuminaUmgColors.foreground, fontSize: 14),
        child: Overlay(initialEntries: [
          OverlayEntry(
            builder: (_) => RepaintBoundary(
              key: boundary,
              child: Container(
                color: const Color(0xFF0B0B0E),
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: SizedBox(
                    width: 360,
                    child: LuminaUmgBorder(
                      padding: const EdgeInsets.all(20),
                      child: StatefulBuilder(
                        builder: (context, setState) => Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('PAUSED', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 14),
                            const LuminaUmgTextField(initialValue: 'Quinn'),
                            const SizedBox(height: 12),
                            const Text('Volume', style: TextStyle(color: LuminaUmgColors.muted, fontSize: 12)),
                            LuminaUmgSlider(value: volume, onChanged: (v) => setState(() => volume = v)),
                            const SizedBox(height: 8),
                            LuminaUmgCheckbox(value: invertY, onChanged: (v) => setState(() => invertY = v), label: const Text('Invert Y')),
                            const SizedBox(height: 12),
                            const SizedBox(height: 8, child: LuminaUmgProgressBar(progress: 0.62, color: Color(0xFF4ADE80))),
                            const SizedBox(height: 14),
                            LuminaUmgComboBox(value: 'High', options: const ['Low', 'Medium', 'High'], onChanged: (_) {}),
                            const SizedBox(height: 16),
                            Row(children: [
                              Expanded(child: LuminaUmgButton(onPressed: () {}, child: const Text('Resume'))),
                              const SizedBox(width: 8),
                              Expanded(child: LuminaUmgButton(style: LuminaUmgButtonStyle.outline, onPressed: () {}, child: const Text('Settings'))),
                              const SizedBox(width: 8),
                              Expanded(child: LuminaUmgButton(style: LuminaUmgButtonStyle.destructive, onPressed: () {}, child: const Text('Quit'))),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    ));
    await tester.pump();

    final png = await tester.runAsync(() async {
      final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes!.buffer.asUint8List();
    });
    SmokeArtifacts.saveScreenshot(_name, png!);
    expect(png.length, greaterThan(2000));
    expect(find.text('Resume'), findsOneWidget);
  });

  testWidgets(_hudName, (tester) async {
    await tester.runAsync(_loadRoboto);
    tester.view.physicalSize = const Size(640, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    LuminaWidgetBuilderRegistry.register(
      'WBP_HUD',
      const LuminaBlueprintWidgetClass(name: 'WBP_HUD', elements: [
        LuminaBlueprintWidgetElement(name: 'FPSCounter', fieldName: 'fpsCounter', typeName: 'text', props: {'text': 'FPS: 0', 'fontSize': 28.0, 'color': '#FFFFFF'}),
        LuminaBlueprintWidgetElement(name: 'Health', fieldName: 'health', typeName: 'progressBar', props: {'percent': 1.0, 'color': '#4ADE80'}),
      ]),
      (context, instance) => _WbpHud(instance: instance),
    );
    addTearDown(LuminaWidgetBuilderRegistry.clear);

    // A real game world, ticked by hand like the frame driver would.
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final character = _HudCharacter();
    world.persistentLevel.registerActor(character);
    world.beginPlay();

    final boundary = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(fontFamily: 'Roboto', color: LuminaUmgColors.foreground, fontSize: 14),
        child: RepaintBoundary(
          key: boundary,
          child: Container(
            color: const Color(0xFF16202A),
            child: LuminaWidgetLayer(world: world),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('FPS: 0'), findsNothing, reason: 'no widget before the first tick');

    final subsystem = world.getSubsystem<LuminaWidgetSubsystem>()!;
    var notified = 0;
    subsystem.activeWidgets.addListener(() => notified++);
    for (var frame = 0; frame < 30; frame++) {
      world.tick(1 / 60);
      await tester.pump();
    }
    expect(subsystem.widgets.single['class'], 'WBP_HUD');
    expect(find.text('FPS: 60'), findsOneWidget);
    expect(find.text('FPS: 0'), findsNothing);
    expect(notified, 1 + 29 * 2, reason: 'Add to Viewport once, then Set Text + Set Percent per tick');
    expect(tester.widget<LuminaUmgProgressBar>(find.byType(LuminaUmgProgressBar)).progress, closeTo(0.5, 1e-9));

    final png = await tester.runAsync(() async {
      final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes!.buffer.asUint8List();
    });
    SmokeArtifacts.saveScreenshot(_hudName, png!);
    expect(png.length, greaterThan(2000));

    // Remove from Parent takes it off the screen.
    LuminaBlueprintFunctionLibrary.removeFromParent(character, character.hud);
    await tester.pump();
    expect(find.text('FPS: 60'), findsNothing);
  });

  testWidgets(_graphName, (tester) async {
    await tester.runAsync(_loadRoboto);
    const width = 1024;
    const height = 768;
    tester.view.physicalSize = const Size(width * 1.0, height * 1.0);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    LuminaWidgetBuilderRegistry.register(clickerClass, clickerWidgetClass, (context, instance) => _WbpClicker(instance: instance));
    // The compiled graph, as the built game's widget registry registers it.
    LuminaUserWidgets.register(clickerClass, WbpClickerGraph.new);
    addTearDown(() {
      LuminaUserWidgets.clear();
      LuminaWidgetBuilderRegistry.clear();
    });

    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final character = _ClickerCharacter();
    world.persistentLevel.registerActor(character);
    final boundary = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(fontFamily: 'Roboto', color: LuminaUmgColors.foreground, fontSize: 14),
        child: RepaintBoundary(key: boundary, child: Container(color: const Color(0xFF16202A), child: LuminaWidgetLayer(world: world))),
      ),
    ));
    world.beginPlay();
    await tester.pump();
    final script = LuminaUserWidgets.of(character.widget);
    expect(script, isA<WbpClickerGraph>(), reason: 'Create Widget gave the instance its compiled graph');
    expect(find.text('Ready'), findsOneWidget, reason: 'Event Construct set the Title');

    Future<ui.Image> capture() async => (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
    Future<Uint8List> png() async {
      final image = await capture();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes!.buffer.asUint8List();
    }

    SmokeArtifacts.saveScreenshot('$_graphName (before the click)', (await tester.runAsync(png))!);
    final video = SmokeVideoRecorder(width: width, height: height, fps: 30, testName: _graphName);
    addTearDown(video.discard);
    // 11 s at 30 fps: the world ticks, the Volume slider's value sweeps the
    // Charge bar through the graph, and the button is clicked at 5 s.
    for (var frame = 0; frame < 330; frame++) {
      world.tick(1 / 30);
      LuminaUserWidgets.fire(character.widget, 'Volume', 'OnValueChanged', {'value': (frame % 90) / 90.0});
      if (frame == 150) await tester.tap(find.byKey(const ValueKey('startButton')));
      await tester.pump();
      final rgba = await tester.runAsync(() async {
        final image = await capture();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return bytes!.buffer.asUint8List();
      });
      video.addFrame(rgba!);
    }
    expect(find.text('Clicked!'), findsOneWidget, reason: 'On Clicked (StartButton) → Set Text (Title)');
    expect((script! as dynamic).clicks, 1);
    SmokeArtifacts.saveScreenshot('$_graphName (after the click)', (await tester.runAsync(png))!);
    SmokeArtifacts.saveVideo(_graphName, video.finish());
  });

  testWidgets(_interfaceName, (tester) async {
    await tester.runAsync(_loadRoboto);
    const width = 1024;
    const height = 768;
    tester.view.physicalSize = const Size(width * 1.0, height * 1.0);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    LuminaBlueprintInterfaces.register(const LuminaBlueprintInterfaceDocument(name: 'BPI_ScoreHUD', functions: [
      LuminaBlueprintFunctionSignature(name: 'UpdateScore', inputs: [LuminaBlueprintVariable(name: 'Text', typeName: 'String', defaultValue: '')]),
    ]));
    LuminaWidgetBuilderRegistry.register(clickerClass, clickerWidgetClass, (context, instance) => _WbpClicker(instance: instance));
    // The widget's graph as Play-In-Editor runs it: a VM script.
    final cls = LuminaBlueprintClass.forWidget(_scoreHudBlueprint());
    expect(cls.diagnostics.where((d) => d.isError), isEmpty, reason: '${cls.diagnostics}');
    LuminaUserWidgets.register(clickerClass, cls.instantiateUserWidget);
    addTearDown(() {
      LuminaUserWidgets.clear();
      LuminaWidgetBuilderRegistry.clear();
      LuminaBlueprintInterfaces.clear();
    });

    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final character = _ScoreCharacter();
    world.persistentLevel.registerActor(character);
    final boundary = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(fontFamily: 'Roboto', color: LuminaUmgColors.foreground, fontSize: 14),
        child: RepaintBoundary(key: boundary, child: Container(color: const Color(0xFF16202A), child: LuminaWidgetLayer(world: world))),
      ),
    ));
    world.beginPlay();
    await tester.pump();
    expect(find.text('Ready'), findsOneWidget, reason: 'Event Construct set the Title');
    expect(LuminaBlueprintFunctionLibrary.doesImplementInterface(character, character.hud, 'BPI_ScoreHUD'), isTrue);

    Future<ui.Image> capture() async => (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
    Future<Uint8List> png() async {
      final image = await capture();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes!.buffer.asUint8List();
    }

    SmokeArtifacts.saveScreenshot('$_interfaceName (before play ticks)', (await tester.runAsync(png))!);
    final video = SmokeVideoRecorder(width: width, height: height, fps: 30, testName: _interfaceName);
    addTearDown(video.discard);
    // 11 s at 30 fps: every tick the character messages the HUD; the text follows.
    for (var frame = 0; frame < 330; frame++) {
      world.tick(1 / 30);
      await tester.pump();
      if (frame == 29) {
        expect(find.text('Distance: 6 m'), findsOneWidget, reason: 'one second of play');
        SmokeArtifacts.saveScreenshot('$_interfaceName (after 1 s)', (await tester.runAsync(png))!);
      }
      final rgba = await tester.runAsync(() async {
        final image = await capture();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return bytes!.buffer.asUint8List();
      });
      video.addFrame(rgba!);
    }
    expect(find.text('Distance: 66 m'), findsOneWidget, reason: 'the widget graph set the text the message carried');
    expect(find.text('Ready'), findsNothing);
    SmokeArtifacts.saveScreenshot('$_interfaceName (after 11 s)', (await tester.runAsync(png))!);
    SmokeArtifacts.saveVideo(_interfaceName, video.finish());
  });
}
