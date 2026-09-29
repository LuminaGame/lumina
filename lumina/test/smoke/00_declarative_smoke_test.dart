// ignore_for_file: file_names
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart';

class SmokeTestActorComponent extends LuminaActorComponent {
  int tickCount = 0;

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    tickCount++;
  }
}

class SmokeTestActor extends LuminaActor {
  final SmokeTestActorComponent smokeComp;

  SmokeTestActor(this.smokeComp, {super.location})
      : super(components: [smokeComp]);
}

void main() {
  group('00_declarative Module Smoke Tests', () {
    test('Scenario 01: Element lifecycle & mounting end-to-end', () async {
      final world = LuminaWorld();
      final smokeComp = SmokeTestActorComponent();
      final actor = SmokeTestActor(
        smokeComp,
        location: Vector3(10.0, 0.0, 5.0),
      );
      final level = LuminaLevel(children: [actor]);
      world.persistentLevel = level;

      final rootGroup = LuminaNodeGroup(children: [level]);
      final rootElem = LuminaElement(rootGroup);

      final rootContext = LuminaElementContext(node: rootGroup, world: world);
      rootElem.mount(rootContext);

      expect(rootElem.lifecycle, equals(LuminaElementLifecycle.active));
      expect(level.actors.length, equals(1));
      expect(actor.actorLocation, equals(Vector3(10.0, 0.0, 5.0)));

      // Initialize the mounted actor
      actor.onInitialize();
      world.beginPlay();

      // Tick at least 3 frames
      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }

      expect(smokeComp.tickCount, equals(3));

      final usedAssets = [
        'Props/AC_units/ac_unit_a_300x300.glb',
        'Props/Barrels/dented_barrel.glb',
      ];

      const testTitle = '00_declarative Module Smoke Tests Scenario 01: Element lifecycle & mounting end-to-end';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      // Clean unmount
      rootElem.unmount();
      expect(rootElem.lifecycle, equals(LuminaElementLifecycle.defunct));
      expect(level.actors.isEmpty, isTrue);
    });

    test('Scenario 02: In-place tree reconciliation and build owner flushing', () async {
      final world = LuminaWorld();
      final smokeComp = SmokeTestActorComponent();
      final actor = SmokeTestActor(smokeComp);
      final level = LuminaLevel(children: [actor]);
      world.persistentLevel = level;

      final owner = LuminaBuildOwner();
      final rootGroup = LuminaNodeGroup(children: [level]);
      final rootElem = LuminaElement(rootGroup)..owner = owner;

      final rootContext = LuminaElementContext(node: rootGroup, world: world);
      rootElem.mount(rootContext);

      actor.onInitialize();
      world.beginPlay();

      // Tick initial frame
      world.tick(1.0 / 60.0);
      expect(smokeComp.tickCount, equals(1));

      // Reconcile: update tree by marking root dirty and changing state
      rootElem.markNeedsBuild();
      expect(owner.hasDirtyElements, isTrue);
      owner.flushBuild();
      expect(owner.hasDirtyElements, isFalse);

      // Tick 2 more frames
      world.tick(1.0 / 60.0);
      world.tick(1.0 / 60.0);
      expect(smokeComp.tickCount, equals(3));

      final usedAssets = [
        'Props/Banana Bunch/banana_bunch_short.glb',
        'Props/Access_cards/access_card_red.glb',
      ];

      const testTitle = '00_declarative Module Smoke Tests Scenario 02: In-place tree reconciliation and build owner flushing';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      rootElem.unmount();
      expect(rootElem.lifecycle, equals(LuminaElementLifecycle.defunct));
    });

    test('Scenario 03: Upward BuildContext queries in real level hierarchy', () async {
      final smokeComp = SmokeTestActorComponent();
      final actor = SmokeTestActor(smokeComp);
      final level = LuminaLevel(children: [actor]);
      final world = LuminaWorld(initialLevel: level);

      final rootElem = LuminaElement(world);
      rootElem.mount(rootElem);

      actor.onInitialize();
      world.beginPlay();

      // Query from component's element context
      LuminaElement? compElem;
      rootElem.visitChildren((levelEl) {
        levelEl.visitChildren((actorEl) {
          actorEl.visitChildren((groupEl) {
            groupEl.visitChildren((cEl) {
              compElem = cEl;
            });
          });
        });
      });

      expect(compElem, isNotNull);
      expect(compElem!.world, equals(world));
      expect(compElem!.level, equals(level));
      expect(compElem!.actor, equals(actor));
      expect(compElem!.findAncestorOfType<LuminaWorld>(), equals(world));
      expect(compElem!.findAncestorOfType<LuminaLevel>(), equals(level));
      expect(compElem!.findAncestorOfType<LuminaActor>(), equals(actor));

      // Tick 3 frames
      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
      }
      expect(smokeComp.tickCount, equals(3));

      final usedAssets = [
        'Props/Barrels/fuel_barrel_black.glb',
        'Props/Barrels/fuel_barrel_red.glb',
      ];

      const testTitle = '00_declarative Module Smoke Tests Scenario 03: Upward BuildContext queries in real level hierarchy';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      rootElem.unmount();
      expect(rootElem.lifecycle, equals(LuminaElementLifecycle.defunct));
    });

    test('Scenario 04: LuminaRuntimeObject survival across 3 tick reconciliation cycles', () async {
      final world = LuminaWorld();
      final smokeComp = SmokeTestActorComponent();
      final actor = SmokeTestActor(smokeComp);
      final level = LuminaLevel(children: [actor]);
      world.persistentLevel = level;

      final owner = LuminaBuildOwner();
      final rootElem = LuminaElement(level)..owner = owner;
      rootElem.mount(LuminaElementContext(node: level, world: world));

      actor.onInitialize();
      world.beginPlay();

      // Tick 3 frames while modifying and reconciling runtime state
      for (int i = 0; i < 3; i++) {
        world.tick(1.0 / 60.0);
        rootElem.markNeedsBuild();
        owner.flushBuild();
      }

      expect(smokeComp.tickCount, equals(3));

      final usedAssets = [
        'Props/Barrels/bent_barrel.glb',
        'Props/AC_units/ac_unit_b_600x600.glb',
      ];

      const testTitle = '00_declarative Module Smoke Tests Scenario 04: LuminaRuntimeObject survival across 3 tick reconciliation cycles';
      await SmokeArtifacts.renderRealAssetMedia(
        testTitle: testTitle,
        usedAssets: usedAssets,
        durationSeconds: 10.0,
      );

      rootElem.unmount();
      expect(rootElem.lifecycle, equals(LuminaElementLifecycle.defunct));
    });
  });
}
