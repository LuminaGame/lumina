import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

// Instrumented probe classes for testing lifecycle and order
class ProbeNode extends LuminaObject {
  final String name;
  final List<String> eventLog;
  final List<LuminaObject> _childList;
  int buildCount = 0;

  ProbeNode(this.name, this.eventLog, {List<LuminaObject> children = const []})
      : _childList = children;

  @override
  List<LuminaObject> get children => _childList;

  @override
  LuminaObject? build(LuminaBuildContext context) {
    buildCount++;
    eventLog.add('build:$name');
    return null;
  }
}

class ProbeComponent extends LuminaActorComponent {
  final String name;
  final List<String> eventLog;

  ProbeComponent(this.name, this.eventLog);

  @override
  void onRegister(LuminaActor actor) {
    super.onRegister(actor);
    eventLog.add('registerComponent:$name');
  }

  @override
  void onUnregister() {
    eventLog.add('unregisterComponent:$name');
    super.onUnregister();
  }
}

class ProbeActor extends LuminaActor {
  final String name;
  final List<String> eventLog;

  ProbeActor(this.name, this.eventLog, {super.components});

  @override
  void onRegister(LuminaWorld world) {
    super.onRegister(world);
    eventLog.add('registerActor:$name');
  }

  @override
  void onUnregister() {
    eventLog.add('unregisterActor:$name');
    super.onUnregister();
  }
}

class ConcreteChildComponent extends LuminaActorComponent {}

class SampleCharComponent extends LuminaActorComponent {
  @override
  LuminaObject? build(LuminaBuildContext context) {
    return ConcreteChildComponent();
  }
}

void main() {
  group('LuminaElement Lifecycle & Mounting Tests (Task 01)', () {
    test('Mounting declarative sample tree populates levels and actors correctly', () {
      final world = LuminaWorld();
      final charComp = SampleCharComponent();
      final actor = LuminaActor(components: [charComp]);
      final level1 = LuminaLevel(children: [actor]);
      final level2 = LuminaLevel();

      final rootGroup = LuminaNodeGroup(children: [level1, level2]);
      final rootElement = LuminaElement(rootGroup);

      final rootContext = LuminaElementContext(node: rootGroup, world: world);
      rootElement.mount(rootContext);

      expect(rootElement.lifecycle, equals(LuminaElementLifecycle.active));
      expect(level1.actors.length, equals(1));
      expect(level1.actors.first, equals(actor));
      // Actor should have rootComponent + charComp + charComp's built component
      expect(actor.components.length, greaterThanOrEqualTo(2));
      expect(actor.components.contains(charComp), isTrue);

      rootElement.unmount();
      expect(rootElement.lifecycle, equals(LuminaElementLifecycle.defunct));
      expect(level1.actors.isEmpty, isTrue);
      // Components removed on unmount
      expect(actor.components.contains(charComp), isFalse);
    });

    test('build(context) is invoked exactly once per node per mount', () {
      final eventLog = <String>[];
      final nodeA = ProbeNode('A', eventLog);
      final nodeB = ProbeNode('B', eventLog);
      final parent = ProbeNode('Parent', eventLog, children: [nodeA, nodeB]);

      final elem = LuminaElement(parent);
      elem.mount(LuminaElementContext(node: parent));

      expect(parent.buildCount, equals(1));
      expect(nodeA.buildCount, equals(1));
      expect(nodeB.buildCount, equals(1));
    });

    test('Mount order probe: depth-first pre-order for children [A, B, C]', () {
      final eventLog = <String>[];
      final childA = ProbeNode('A', eventLog);
      final childB = ProbeNode('B', eventLog);
      final childC = ProbeNode('C', eventLog);
      final parent = ProbeNode('Parent', eventLog, children: [childA, childB, childC]);

      final elem = LuminaElement(parent);
      elem.mount(LuminaElementContext(node: parent));

      expect(eventLog, equals(['build:Parent', 'build:A', 'build:B', 'build:C']));
    });

    test('Unmount order probe: depth-first post-order and reverse list order', () {
      final eventLog = <String>[];
      final compA = ProbeComponent('A', eventLog);
      final compB = ProbeComponent('B', eventLog);
      final compC = ProbeComponent('C', eventLog);

      final actor = ProbeActor('Actor', eventLog, components: [compA, compB, compC]);
      final level = LuminaLevel(children: [actor]);
      final world = LuminaWorld();

      final elem = LuminaElement(level);
      elem.mount(LuminaElementContext(node: level, world: world));

      eventLog.clear();
      elem.unmount();

      // Unmount should unregister children in reverse order, then actor
      expect(eventLog, contains('unregisterComponent:C'));
      expect(eventLog, contains('unregisterComponent:B'));
      expect(eventLog, contains('unregisterComponent:A'));
      expect(eventLog, contains('unregisterActor:Actor'));

      final cIdx = eventLog.indexOf('unregisterComponent:C');
      final bIdx = eventLog.indexOf('unregisterComponent:B');
      final aIdx = eventLog.indexOf('unregisterComponent:A');
      final actorIdx = eventLog.indexOf('unregisterActor:Actor');

      expect(cIdx, lessThan(bIdx));
      expect(bIdx, lessThan(aIdx));
      expect(aIdx, lessThan(actorIdx));
    });

    test('After unmount, actor.components and level.actors are cleared', () {
      final eventLog = <String>[];
      final comp = ProbeComponent('Comp1', eventLog);
      final actor = ProbeActor('Actor1', eventLog, components: [comp]);
      final level = LuminaLevel(children: [actor]);
      final world = LuminaWorld();

      final elem = LuminaElement(level);
      elem.mount(LuminaElementContext(node: level, world: world));

      expect(level.actors.contains(actor), isTrue);
      expect(actor.components.contains(comp), isTrue);

      elem.unmount();

      expect(level.actors.isEmpty, isTrue);
      expect(actor.components.contains(comp), isFalse);
    });

    test('unmount then mount on the same element throws StateError', () {
      final node = ProbeNode('Node', []);
      final elem = LuminaElement(node);
      elem.mount(LuminaElementContext(node: node));
      expect(elem.lifecycle, equals(LuminaElementLifecycle.active));

      elem.unmount();
      expect(elem.lifecycle, equals(LuminaElementLifecycle.defunct));

      expect(() => elem.mount(LuminaElementContext(node: node)), throwsStateError);
    });

    test('Mounting the same declarative tree into two separate roots creates independent element trees', () {
      final actor = LuminaActor();
      final level = LuminaLevel(children: [actor]);

      final world1 = LuminaWorld();
      final elem1 = LuminaElement(level);
      elem1.mount(LuminaElementContext(node: level, world: world1));

      expect(level.actors.length, equals(1));
      elem1.unmount();
      expect(level.actors.isEmpty, isTrue);

      final world2 = LuminaWorld();
      final elem2 = LuminaElement(level);
      elem2.mount(LuminaElementContext(node: level, world: world2));
      expect(level.actors.length, equals(1));
      elem2.unmount();
      expect(level.actors.isEmpty, isTrue);
    });

    test('visitChildren traverses all mounted children', () {
      final eventLog = <String>[];
      final childA = ProbeNode('A', eventLog);
      final childB = ProbeNode('B', eventLog);
      final parent = ProbeNode('Parent', eventLog, children: [childA, childB]);

      final elem = LuminaElement(parent);
      elem.mount(LuminaElementContext(node: parent));

      final visitedNodes = <LuminaObject>[];
      elem.visitChildren((child) {
        visitedNodes.add(child.node);
      });

      expect(visitedNodes, equals([childA, childB]));
    });
  });
}
