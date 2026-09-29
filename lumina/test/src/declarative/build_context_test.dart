import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

// Test classes
class MyWorld extends LuminaWorld {
  MyWorld({super.key, super.children});
}

class MyLevel1 extends LuminaLevel {
  MyLevel1({super.key, super.children});
}

class MyLevel2 extends LuminaLevel {
  MyLevel2({super.key, super.children});
}

class ContextCaptureComponent extends LuminaActorComponent {
  LuminaWorld? capturedWorld;
  LuminaLevel? capturedLevel;
  LuminaActor? capturedActor;
  LuminaBuildContext? capturedContext;

  @override
  LuminaObject? build(LuminaBuildContext context) {
    capturedContext = context;
    capturedWorld = context.world;
    capturedLevel = context.level;
    capturedActor = context.actor;
    return null;
  }
}

class ContextCaptureActor extends LuminaActor {
  LuminaActor? selfInActorBuild;

  ContextCaptureActor({super.key, super.components});

  @override
  LuminaObject? build(LuminaBuildContext context) {
    selfInActorBuild = context.actor;
    return super.build(context);
  }
}

class SimpleRootGame extends LuminaObject {
  LuminaLevel? capturedLevel;
  LuminaActor? capturedActor;

  @override
  LuminaObject? build(LuminaBuildContext context) {
    capturedLevel = context.level;
    capturedActor = context.actor;
    return null;
  }
}

class DeepChainNode extends LuminaObject {
  final LuminaObject? childNode;
  DeepChainNode({this.childNode});

  @override
  LuminaObject? build(LuminaBuildContext context) => childNode;
}

class KeyedDynamicLevelHolder extends LuminaObject {
  List<LuminaObject> childrenList;
  KeyedDynamicLevelHolder(this.childrenList);

  @override
  List<LuminaObject> get children => childrenList;
}

void main() {
  group('BuildContext Queries Tests (Task 03)', () {
    test('Scope getters resolve world, level, and actor in sample hierarchy', () {
      final comp = ContextCaptureComponent();
      final actor = LuminaActor(components: [comp]);
      final level = MyLevel1(children: [actor]);
      final world = MyWorld(children: [level]);

      final rootElem = LuminaElement(world);
      rootElem.mount(rootElem);

      expect(comp.capturedWorld, equals(world));
      expect(comp.capturedLevel, equals(level));
      expect(comp.capturedActor, equals(actor));
      expect(identical(comp.capturedWorld, world), isTrue);
      expect(identical(comp.capturedLevel, level), isTrue);
      expect(identical(comp.capturedActor, actor), isTrue);
    });

    test('Self-inclusion rule: Actor sees itself in actor.build; Component sees owning actor', () {
      final comp = ContextCaptureComponent();
      final actor = ContextCaptureActor(components: [comp]);
      final level = LuminaLevel(children: [actor]);

      final rootElem = LuminaElement(level);
      rootElem.mount(rootElem);

      expect(actor.selfInActorBuild, equals(actor));
      expect(identical(actor.selfInActorBuild, actor), isTrue);
      expect(comp.capturedActor, equals(actor));
    });

    test('Root scope has null level and null actor', () {
      final game = SimpleRootGame();
      final rootElem = LuminaElement(game);
      rootElem.mount(rootElem);

      expect(game.capturedLevel, isNull);
      expect(game.capturedActor, isNull);
    });

    test('findAncestorOfExactType vs findAncestorOfType differentiate exact and subtype', () {
      final comp = ContextCaptureComponent();
      final actor = LuminaActor(components: [comp]);
      final level = MyLevel1(children: [actor]);

      final rootElem = LuminaElement(level);
      rootElem.mount(rootElem);

      final ctx = comp.capturedContext!;

      // Exact match for MyLevel1 succeeds
      expect(ctx.findAncestorOfExactType<MyLevel1>(), equals(level));
      // Exact match for LuminaLevel fails (MyLevel1 runtimeType is not LuminaLevel)
      expect(ctx.findAncestorOfExactType<LuminaLevel>(), isNull);
      // Subtype match for LuminaLevel succeeds
      expect(ctx.findAncestorOfType<LuminaLevel>(), equals(level));
      // Finder helper alias
      expect(ctx.findAncestorLevel(), equals(level));
      expect(ctx.findAncestorActor(), equals(actor));
    });

    test('visitAncestorElements visits child->root order and stops early when returning false', () {
      final leaf = ContextCaptureComponent();
      final node4 = DeepChainNode(childNode: leaf);
      final node3 = DeepChainNode(childNode: node4);
      final node2 = DeepChainNode(childNode: node3);
      final node1 = DeepChainNode(childNode: node2);

      final rootElem = LuminaElement(node1);
      rootElem.mount(rootElem);

      final ctx = leaf.capturedContext!;
      final visited = <LuminaObject>[];

      ctx.visitAncestorElements((node) {
        visited.add(node);
        // Stop after visiting 2 ancestors
        return visited.length < 2;
      });

      expect(visited.length, equals(2));
      expect(visited[0], equals(node4));
      expect(visited[1], equals(node3));
    });

    test('Nested actors: inner component resolves innermost actor', () {
      final innerComp = ContextCaptureComponent();
      final innerActor = LuminaActor(components: [innerComp]);
      final outerActor = LuminaActor(components: [innerActor]);

      final rootElem = LuminaElement(outerActor);
      rootElem.mount(rootElem);

      expect(innerComp.capturedActor, equals(innerActor));
    });

    test('Moving a keyed actor subtree across levels updates context.level query on rebuild', () {
      final comp = ContextCaptureComponent();
      const actorKey = ValueKey('hero_actor');
      final actor = LuminaActor(key: actorKey, components: [comp]);

      final level1 = MyLevel1(key: const ValueKey('lvl1'), children: [actor]);
      final level2 = MyLevel2(key: const ValueKey('lvl2'), children: const []);

      final holder = KeyedDynamicLevelHolder([level1, level2]);
      final owner = LuminaBuildOwner();
      final rootElem = LuminaElement(holder)..owner = owner;
      rootElem.mount(rootElem);

      expect(comp.capturedLevel, equals(level1));

      // Move actor to level2
      final newLevel1 = MyLevel1(key: const ValueKey('lvl1'), children: const []);
      final newLevel2 = MyLevel2(key: const ValueKey('lvl2'), children: [actor]);
      holder.childrenList = [newLevel1, newLevel2];

      rootElem.markNeedsBuild();
      owner.flushBuild();

      // Look at updated context level
      expect(comp.capturedContext!.level, equals(newLevel2));
    });

    test('Any query on a defunct context throws StateError', () {
      final comp = ContextCaptureComponent();
      final actor = LuminaActor(components: [comp]);
      final rootElem = LuminaElement(actor);
      rootElem.mount(rootElem);

      final ctx = comp.capturedContext!;
      expect(ctx.actor, equals(actor));

      rootElem.unmount();

      expect(() => ctx.actor, throwsStateError);
      expect(() => ctx.level, throwsStateError);
      expect(() => ctx.world, throwsStateError);
      expect(() => ctx.findAncestorActor(), throwsStateError);
      expect(() => ctx.findAncestorLevel(), throwsStateError);
      expect(() => ctx.findAncestorWorld(), throwsStateError);
      expect(() => ctx.findAncestorOfType<LuminaActor>(), throwsStateError);
      expect(() => ctx.findAncestorOfExactType<LuminaActor>(), throwsStateError);
      expect(() => ctx.visitAncestorElements((n) => true), throwsStateError);
    });
  });
}
