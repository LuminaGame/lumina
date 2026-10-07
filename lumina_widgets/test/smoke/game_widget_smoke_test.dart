import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:lumina_smoke/flutter.dart' show SmokeCapture, SmokeRecorder;
import 'package:lumina_widgets/lumina_widgets.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

/// Game widget smoke: a real level of `test-assets/` props rendered by
/// Filament through the game host of `lumina_widgets`, a pawn (a fuel
/// barrel) driven by keyboard keys sent to the host, and a UMG HUD the game
/// adds to the viewport on BeginPlay, drawn over the 3D view and updated
/// from the pawn's position every tick.
const _name = 'game widget: keyboard drives a pawn through the game host under a UMG HUD';

const _pawnAsset = 'Props/Barrels/fuel_barrel_red.glb';
/// Where each prop stands (cm, Y-up): the AC unit at the back, the others
/// around the pawn's path.
final _propSpots = [Vector3(420, 0, -520), Vector3(-330, 0, 40), Vector3(260, 0, 160), Vector3(-120, 0, 330), Vector3(-420, 0, -260)];

const _props = [
  'Props/AC_units/ac_unit_a_300x300.glb',
  'Props/Barrels/dented_barrel.glb',
  'Props/Banana Bunch/banana_bunch_medium.glb',
  'Props/Access_cards/access_card_red.glb',
  'Props/Barrels/fuel_barrel_black.glb',
];

/// What a compiled WBP_HUD would declare.
const _hudClass = LuminaBlueprintWidgetClass(name: 'WBP_HUD', elements: [
  LuminaBlueprintWidgetElement(name: 'Title', typeName: 'text', props: {'text': 'Lumina game widget'}),
  LuminaBlueprintWidgetElement(name: 'Position', typeName: 'text', props: {'text': 'X 0  Z 0'}),
  LuminaBlueprintWidgetElement(name: 'Keys', typeName: 'text', props: {'text': 'Keys: none'}),
  LuminaBlueprintWidgetElement(name: 'Travel', typeName: 'progressBar', props: {'percent': 0.0}),
]);

/// The HUD as the UMG codegen writes a plain-Flutter widget class: every
/// element read through its binding.
Widget _hud(BuildContext context, Map<String, Object?> instance) {
  Widget text(String name, double size, Color color) => LuminaUmgElement(
        instance: instance,
        name: name,
        builder: (context, e) => Text(
          LuminaUmgElementBinding.value<String>(e, 'text', ''),
          style: TextStyle(fontFamily: 'Roboto', fontSize: size, color: color, fontWeight: FontWeight.w600, shadows: const [
            Shadow(color: Color(0xCC000000), blurRadius: 3, offset: Offset(1, 1)),
          ]),
        ),
      );
  return Align(
    alignment: Alignment.topLeft,
    child: Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(18),
      width: 420,
      decoration: BoxDecoration(color: const Color(0xB0141820), borderRadius: BorderRadius.circular(10)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          text('Title', 26, const Color(0xFFFFFFFF)),
          const SizedBox(height: 10),
          text('Position', 20, const Color(0xFF9BE7FF)),
          const SizedBox(height: 6),
          text('Keys', 20, const Color(0xFFFFE08A)),
          const SizedBox(height: 12),
          LuminaUmgElement(
            instance: instance,
            name: 'Travel',
            builder: (context, e) => SizedBox(
              height: 16,
              child: LuminaUmgProgressBar(progress: LuminaUmgElementBinding.value<double>(e, 'percent', 0.0), color: const Color(0xFF4ADE80)),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A barrel the arrow-less WASD keys move over the ground (cm/s), through
/// the input subsystem the game host feeds.
class _KeyDrivenPawn extends LuminaPawn {
  _KeyDrivenPawn({required this.mesh}) : super(root: mesh, location: Vector3(0, 0, 250));

  final LuminaStaticMeshComponent mesh;
  static const double speed = 160;
  Map<String, Object?>? hud;
  double travelled = 0;

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    hud = LuminaBlueprintFunctionLibrary.createWidget(this, 'WBP_HUD') as Map<String, Object?>?;
    LuminaBlueprintFunctionLibrary.addToViewport(this, hud);
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    final input = world?.getSubsystem<LuminaInputSubsystem>();
    if (input == null) return;
    final held = <String>[
      for (final (key, label) in [
        (LuminaKey.keyW, 'W'),
        (LuminaKey.keyA, 'A'),
        (LuminaKey.keyS, 'S'),
        (LuminaKey.keyD, 'D'),
      ])
        if (input.isKeyDown(key)) label,
    ];
    final move = Vector3(
      (input.isKeyDown(LuminaKey.keyD) ? 1 : 0) - (input.isKeyDown(LuminaKey.keyA) ? 1 : 0).toDouble(),
      0,
      (input.isKeyDown(LuminaKey.keyS) ? 1 : 0) - (input.isKeyDown(LuminaKey.keyW) ? 1 : 0).toDouble(),
    );
    if (move.length2 > 0) {
      move.normalize();
      final step = move * (speed * deltaTime);
      actorLocation = actorLocation + step;
      actorRotation = Quaternion.axisAngle(Vector3(0, 1, 0), travelled / 60);
      travelled += step.length;
    }
    final at = actorLocation;
    final hud = this.hud;
    if (hud == null) return;
    LuminaBlueprintFunctionLibrary.setElementText(
        this, LuminaBlueprintFunctionLibrary.getWidgetElement(hud, 'Position'), 'X ${at.x.toStringAsFixed(0)}  Z ${at.z.toStringAsFixed(0)} cm');
    LuminaBlueprintFunctionLibrary.setElementText(
        this, LuminaBlueprintFunctionLibrary.getWidgetElement(hud, 'Keys'), 'Keys: ${held.isEmpty ? 'none' : held.join(' + ')}');
    LuminaBlueprintFunctionLibrary.setElementPercent(
        this, LuminaBlueprintFunctionLibrary.getWidgetElement(hud, 'Travel'), (travelled / 1200).clamp(0.0, 1.0));
  }
}

/// The level: ground, sun and fill, a camera looking over the props, and
/// the pawn among them.
class _SmokeGame extends LuminaGame {
  _SmokeGame(this.assetsDir);

  final String assetsDir;
  final meshes = <LuminaStaticMeshComponent>[];
  _KeyDrivenPawn? pawn;

  @override
  LuminaObject? build(LuminaBuildContext context) {
    final world = context.world;
    if (world != null && world.getSubsystem<LuminaInputSubsystem>() == null) {
      world.registerSubsystem(LuminaInputSubsystem());
    }
    LuminaStaticMeshComponent mesh(String asset) {
      final m = LuminaStaticMeshComponent(meshAssetPath: '$assetsDir/$asset');
      meshes.add(m);
      return m;
    }

    final pawn = this.pawn = _KeyDrivenPawn(mesh: mesh(_pawnAsset));
    final ring = <LuminaActor>[
      for (var i = 0; i < _props.length; i++)
        LuminaActor(
          root: mesh(_props[i]),
          location: _propSpots[i],
        ),
    ];
    // Looking down the level from behind and above.
    final camera = LuminaCameraComponent(
      rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -math.atan2(520, 1050)),
      fieldOfViewInDegrees: 60,
    )..isActive = true;
    return LuminaNodeGroup(children: [
      LuminaPrimitiveActor(shape: LuminaPrimitiveShape.plane, size: Vector3(1600, 1, 1200), color: Vector3(0.32, 0.36, 0.33)),
      LuminaActor(
        root: LuminaDirectionalLightComponent(
          rotation: Quaternion.axisAngle(Vector3(0, 1, 0), 0.6) * Quaternion.axisAngle(Vector3(1, 0, 0), -0.95),
          intensity: 110000,
          castShadows: true,
        ),
      ),
      LuminaActor(
        root: LuminaDirectionalLightComponent(
          rotation: Quaternion.axisAngle(Vector3(0, 1, 0), 2.8) * Quaternion.axisAngle(Vector3(1, 0, 0), -0.4),
          intensity: 45000,
          isSun: false,
        ),
      ),
      LuminaActor(root: camera, location: Vector3(0, 520, 1150)),
      ...ring,
      pawn,
    ]);
  }
}

/// The SDK's Roboto, so the HUD's text is readable in the PNG and video
/// (tests otherwise draw the box glyphs of their Ahem font).
Future<void> _loadRoboto() async {
  final exe = Platform.resolvedExecutable.replaceAll(r'\', '/');
  final root = Platform.environment['FLUTTER_ROOT'] ?? (exe.contains('/bin/cache/') ? exe.substring(0, exe.indexOf('/bin/cache/')) : null);
  if (root == null) return;
  final font = File('$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
  if (!font.existsSync()) return;
  final loader = FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
  await loader.load();
}

void main() {
  testWidgets(_name, (tester) async {
    await tester.runAsync(_loadRoboto);
    final assetsDir = SmokeArtifacts.testAssetsDir.path;
    for (final a in [_pawnAsset, ..._props]) {
      expect(File('$assetsDir/$a').existsSync(), isTrue, reason: 'test asset $a');
    }
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    LuminaWidgetBuilderRegistry.register('WBP_HUD', _hudClass, _hud);
    addTearDown(LuminaWidgetBuilderRegistry.clear);
    LuminaLevelPreloader.instance.manifestResolver = (_) => const <LuminaAssetRef>[];
    addTearDown(LuminaLevelPreloader.instance.reset);

    _SmokeGame? game;
    final boundary = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: boundary,
        child: LuminaGameHost(
          initialLevel: 'L_Smoke',
          captureMouse: false,
          createGame: (_) => game = _SmokeGame(assetsDir),
        ),
      ),
    ));

    // The scene, the game's BeginPlay and every mesh load (real disk reads
    // and uploads) finish outside the fake clock.
    for (var i = 0; i < 100 && !(game?.world?.hasBegunPlay ?? false); i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    final g = game!;
    expect(g.world?.hasBegunPlay, isTrue, reason: 'the game widget mounted the game and began play');
    // Mesh loads complete on the test's clock: pump while they finish.
    for (var i = 0; i < 3000 && !g.meshes.every((m) => m.isLoaded); i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    expect([for (final m in g.meshes) if (!m.isLoaded) m.meshAssetPath], isEmpty, reason: 'every prop loaded');
    final pawn = g.pawn!;
    final input = g.world!.getSubsystem<LuminaInputSubsystem>()!;
    expect(g.world!.getSubsystem<LuminaWidgetSubsystem>()!.activeWidgets.value, hasLength(1), reason: 'the HUD is on screen');

    final rec = SmokeRecorder(tester, boundary: find.byKey(boundary));
    await rec.hold(const Duration(milliseconds: 1500));
    expect(find.text('Lumina game widget'), findsOneWidget, reason: 'the UMG HUD draws over the 3D view');

    final start = pawn.actorLocation.clone();
    // Each key goes to the host's focus node, through LuminaKey.fromKeyId into
    // the input subsystem the pawn reads.
    Future<void> drive(List<LogicalKeyboardKey> keys, Duration time) async {
      for (final k in keys) {
        await tester.sendKeyDownEvent(k);
      }
      await rec.hold(const Duration(milliseconds: 100));
      expect(input.isKeyDown(LuminaKey.fromKeyId(keys.first.keyId)!), isTrue);
      await rec.hold(time);
      for (final k in keys) {
        await tester.sendKeyUpEvent(k);
      }
      await rec.hold(const Duration(milliseconds: 300));
    }

    await drive([LogicalKeyboardKey.keyW], const Duration(milliseconds: 2400));
    expect(pawn.actorLocation.z, lessThan(start.z - 150), reason: 'W drove the pawn forward');
    await drive([LogicalKeyboardKey.keyD], const Duration(milliseconds: 1600));
    expect(pawn.actorLocation.x, greaterThan(start.x + 150), reason: 'D drove it right');
    await drive([LogicalKeyboardKey.keyS, LogicalKeyboardKey.keyA], const Duration(milliseconds: 2200));
    await drive([LogicalKeyboardKey.keyA], const Duration(milliseconds: 1000));
    await rec.hold(const Duration(milliseconds: 800));
    expect(find.textContaining('Keys: none'), findsOneWidget);
    expect(find.textContaining(' cm'), findsOneWidget, reason: 'the HUD follows the pawn');

    final png = await SmokeCapture.captureWidgetPng(tester, find.byKey(boundary));
    SmokeArtifacts.saveScreenshot(_name, png, usedAssets: [_pawnAsset, ..._props]);
    rec.save(_name, usedAssets: [_pawnAsset, ..._props]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
