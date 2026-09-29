import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

// Test nodes
class ConfigNodeA extends LuminaObject {
  final String label;
  final List<LuminaObject> _children;
  int buildCount = 0;

  ConfigNodeA({super.key, this.label = 'A', this._children = const []});

  @override
  List<LuminaObject> get children => _children;

  @override
  LuminaObject? build(LuminaBuildContext context) {
    buildCount++;
    return null;
  }
}

class ConfigNodeB extends LuminaObject {
  final String label;
  const ConfigNodeB({super.key, this.label = 'B'});

  @override
  LuminaObject? build(LuminaBuildContext context) => null;
}

class SelfRebuildingNode extends LuminaObject {
  LuminaElement? attachedElement;
  int buildCount = 0;

  SelfRebuildingNode({super.key});

  @override
  LuminaObject? build(LuminaBuildContext context) {
    buildCount++;
    attachedElement?.markNeedsBuild();
    return null;
  }
}

class ReconcileProbeActor extends LuminaActor {
  final String name;
  int unregisterCount = 0;

  ReconcileProbeActor({super.key, required this.name, super.components});

  @override
  void onUnregister() {
    unregisterCount++;
    super.onUnregister();
  }
}

class ReconcileProbeComponent extends LuminaActorComponent {
  final String name;
  int unregisterCount = 0;

  ReconcileProbeComponent(this.name);

  @override
  void onUnregister() {
    unregisterCount++;
    super.onUnregister();
  }
}

class DynamicParentNode extends LuminaObject {
  LuminaObject? currentChild;
  List<LuminaObject> currentChildren;
  int buildCount = 0;

  DynamicParentNode({this.currentChild, this.currentChildren = const []});

  @override
  LuminaObject? build(LuminaBuildContext context) {
    buildCount++;
    return currentChild;
  }

  @override
  List<LuminaObject> get children => currentChildren;
}

void main() {
  group('Tree Reconciliation Tests (Task 02)', () {
    test('canUpdate returns true only for matching runtimeType and key', () {
      const k1 = ValueKey(1);
      const k2 = ValueKey(2);

      final a1 = ConfigNodeA(key: k1);
      final a1Prime = ConfigNodeA(key: k1, label: 'A_prime');
      final a2 = ConfigNodeA(key: k2);
      const b1 = ConfigNodeB(key: k1);

      expect(LuminaElement.canUpdate(a1, a1Prime), isTrue);
      expect(LuminaElement.canUpdate(a1, a2), isFalse);
      expect(LuminaElement.canUpdate(a1, b1), isFalse);
      expect(LuminaElement.canUpdate(ConfigNodeA(), ConfigNodeA()), isTrue);
    });

    test('Rebuild with new config instance of same type/key preserves element and actor instance', () {
      final actor = ReconcileProbeActor(name: 'Hero');
      final parent = DynamicParentNode(currentChild: actor);

      final owner = LuminaBuildOwner();
      final rootElem = LuminaElement(parent)..owner = owner;
      rootElem.mount(LuminaElementContext(node: parent, world: LuminaWorld()));

      expect(rootElem.visitChild(), isNotNull);
      final actorElemBefore = rootElem.visitChild()!;

      // Change to new instance of same actor type/key
      final newActorConfig = ReconcileProbeActor(name: 'Hero_Renamed');
      parent.currentChild = newActorConfig;
      rootElem.markNeedsBuild();
      owner.flushBuild();

      final actorElemAfter = rootElem.visitChild();
      expect(identical(actorElemBefore, actorElemAfter), isTrue);
      expect(actor.unregisterCount, equals(0));
    });

    test('Rebuild that changes child runtimeType unmounts old and mounts new', () {
      final compA = ReconcileProbeComponent('CompA');
      final parent = DynamicParentNode(currentChild: compA);

      final owner = LuminaBuildOwner();
      final actor = LuminaActor();
      final rootElem = LuminaElement(parent)..owner = owner;
      rootElem.mount(LuminaElementContext(node: parent, actor: actor));

      expect(actor.components.contains(compA), isTrue);

      // Swap to ConfigNodeB (different type)
      parent.currentChild = const ConfigNodeB();
      rootElem.markNeedsBuild();
      owner.flushBuild();

      expect(compA.unregisterCount, equals(1));
      expect(actor.components.contains(compA), isFalse);
    });

    test('Keyed reorder [A(k1), B(k2)] -> [B(k2), A(k1)] reuses elements without unmount', () {
      const k1 = ValueKey('k1');
      const k2 = ValueKey('k2');

      final nodeA = ConfigNodeA(key: k1, label: 'A');
      final nodeB = ConfigNodeA(key: k2, label: 'B');

      final parent = DynamicParentNode(currentChildren: [nodeA, nodeB]);

      final owner = LuminaBuildOwner();
      final rootElem = LuminaElement(parent)..owner = owner;
      rootElem.mount(LuminaElementContext(node: parent));

      final childrenBefore = rootElem.childrenList;
      final elemA = childrenBefore[0];
      final elemB = childrenBefore[1];

      // Reorder
      parent.currentChildren = [nodeB, nodeA];
      rootElem.markNeedsBuild();
      owner.flushBuild();

      final childrenAfter = rootElem.childrenList;
      expect(childrenAfter.length, equals(2));
      expect(identical(childrenAfter[0], elemB), isTrue);
      expect(identical(childrenAfter[1], elemA), isTrue);
    });

    test('Unkeyed list shrink [A, B, C] -> [A, B] unmounts exactly the tail', () {
      final nodeA = ConfigNodeA(label: 'A');
      final nodeB = ConfigNodeA(label: 'B');
      final nodeC = ConfigNodeA(label: 'C');

      final parent = DynamicParentNode(currentChildren: [nodeA, nodeB, nodeC]);

      final owner = LuminaBuildOwner();
      final rootElem = LuminaElement(parent)..owner = owner;
      rootElem.mount(LuminaElementContext(node: parent));

      final childrenBefore = rootElem.childrenList;
      final elemA = childrenBefore[0];
      final elemB = childrenBefore[1];
      final elemC = childrenBefore[2];

      parent.currentChildren = [nodeA, nodeB];
      rootElem.markNeedsBuild();
      owner.flushBuild();

      final childrenAfter = rootElem.childrenList;
      expect(childrenAfter.length, equals(2));
      expect(identical(childrenAfter[0], elemA), isTrue);
      expect(identical(childrenAfter[1], elemB), isTrue);
      expect(elemC.lifecycle, equals(LuminaElementLifecycle.defunct));
    });

    test('Dirty subtree isolation: only leaf rebuilds', () {
      final leaf = ConfigNodeA(label: 'Leaf');
      final middle = DynamicParentNode(currentChild: leaf);
      final root = DynamicParentNode(currentChild: middle);

      final owner = LuminaBuildOwner();
      final rootElem = LuminaElement(root)..owner = owner;
      rootElem.mount(LuminaElementContext(node: root));

      final middleElem = rootElem.visitChild()!;
      final leafElem = middleElem.visitChild()!;

      expect(root.buildCount, equals(1));
      expect(middle.buildCount, equals(1));
      expect(leaf.buildCount, equals(1));

      // Mark only leaf dirty
      leafElem.markNeedsBuild();
      expect(owner.hasDirtyElements, isTrue);
      owner.flushBuild();

      expect(root.buildCount, equals(1));
      expect(middle.buildCount, equals(1));
      expect(leaf.buildCount, equals(2));
    });

    test('markNeedsBuild called twice before flushBuild only rebuilds once', () {
      final node = ConfigNodeA();
      final owner = LuminaBuildOwner();
      final elem = LuminaElement(node)..owner = owner;
      elem.mount(LuminaElementContext(node: node));

      expect(node.buildCount, equals(1));

      elem.markNeedsBuild();
      elem.markNeedsBuild();
      owner.flushBuild();

      expect(node.buildCount, equals(2));
    });

    test('Depth ordering: parent rebuild removing child cancels child rebuild', () {
      final child = ConfigNodeA(label: 'Child');
      final parent = DynamicParentNode(currentChild: child);

      final owner = LuminaBuildOwner();
      final rootElem = LuminaElement(parent)..owner = owner;
      rootElem.mount(LuminaElementContext(node: parent));

      final childElem = rootElem.visitChild()!;

      // Both marked dirty
      childElem.markNeedsBuild();
      rootElem.markNeedsBuild();

      // Parent rebuild removes child
      parent.currentChild = null;

      expect(() => owner.flushBuild(), returnsNormally);
      expect(childElem.lifecycle, equals(LuminaElementLifecycle.defunct));
      // Child build was not invoked again
      expect(child.buildCount, equals(1));
    });

    test('markNeedsBuild from inside build() trips re-entrancy cap at 100', () {
      final owner = LuminaBuildOwner();
      final selfNode = SelfRebuildingNode();
      final elem = LuminaElement(selfNode)..owner = owner;
      selfNode.attachedElement = elem;

      elem.mount(LuminaElementContext(node: selfNode));

      expect(() => owner.flushBuild(), throwsStateError);
    });
  });
}

// Extension for testing child inspection
extension ElementTestHelper on LuminaElement {
  LuminaElement? visitChild() {
    LuminaElement? found;
    visitChildren((child) {
      found ??= child;
    });
    return found;
  }

  List<LuminaElement> get childrenList {
    final list = <LuminaElement>[];
    visitChildren((child) {
      list.add(child);
    });
    return list;
  }
}
