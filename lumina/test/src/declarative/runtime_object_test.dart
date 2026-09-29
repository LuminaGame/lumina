import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

int _globalHandleCounter = 1000;

class TestMeshRuntimeObject extends LuminaRuntimeObject {
  final int nativeHandle;
  bool _attached = false;
  int attachCount = 0;
  int detachCount = 0;
  int updateCount = 0;
  String currentMeshPath = '';
  final List<String> updateLog = [];

  TestMeshRuntimeObject() : nativeHandle = _globalHandleCounter++;

  @override
  bool get isAttached => _attached;

  @override
  void attach(LuminaBuildContext context) {
    _attached = true;
    attachCount++;
  }

  @override
  void update(covariant TestMeshNode newConfig) {
    updateCount++;
    updateLog.add('$currentMeshPath->${newConfig.meshPath}');
    currentMeshPath = newConfig.meshPath;
  }

  @override
  void detach() {
    _attached = false;
    detachCount++;
  }
}

class TestMeshNode extends LuminaRuntimeObjectNode {
  final String meshPath;
  static int createCount = 0;
  static int updateNodeCount = 0;

  const TestMeshNode({super.key, required this.meshPath});

  @override
  LuminaRuntimeObject createRuntimeObject(LuminaBuildContext context) {
    createCount++;
    final ro = TestMeshRuntimeObject();
    ro.currentMeshPath = meshPath;
    return ro;
  }

  @override
  void updateRuntimeObject(covariant TestMeshRuntimeObject runtimeObject) {
    updateNodeCount++;
  }
}

class OtherRuntimeObject extends LuminaRuntimeObject {
  bool _attached = false;
  int attachCount = 0;
  int detachCount = 0;

  @override
  bool get isAttached => _attached;

  @override
  void attach(LuminaBuildContext context) {
    _attached = true;
    attachCount++;
  }

  @override
  void update(covariant LuminaObject newConfig) {}

  @override
  void detach() {
    _attached = false;
    detachCount++;
  }
}

class OtherRuntimeNode extends LuminaRuntimeObjectNode {
  const OtherRuntimeNode({super.key});

  @override
  LuminaRuntimeObject createRuntimeObject(LuminaBuildContext context) {
    return OtherRuntimeObject();
  }

  @override
  void updateRuntimeObject(covariant OtherRuntimeObject runtimeObject) {}
}

class DynamicRuntimeParentNode extends LuminaObject {
  LuminaObject currentChild;
  DynamicRuntimeParentNode(this.currentChild);

  @override
  LuminaObject? build(LuminaBuildContext context) => currentChild;
}

void main() {
  setUp(() {
    TestMeshNode.createCount = 0;
    TestMeshNode.updateNodeCount = 0;
  });

  group('LuminaRuntimeObject & Element Split Tests (Task 04)', () {
    test('Mounting a LuminaRuntimeObjectNode creates and attaches runtime object once', () {
      const node = TestMeshNode(meshPath: 'contents/meshes/cube.lmas');
      final elem = LuminaElement(node);
      elem.mount(elem);

      expect(elem.runtimeObject, isNotNull);
      final ro = elem.runtimeObject! as TestMeshRuntimeObject;
      expect(ro.isAttached, isTrue);
      expect(ro.attachCount, equals(1));
      expect(TestMeshNode.createCount, equals(1));
    });

    test('100 rebuilds with fresh configs preserve same runtimeObject and native handle', () {
      final initialNode = const TestMeshNode(meshPath: 'contents/meshes/cube.lmas');
      final parent = DynamicRuntimeParentNode(initialNode);

      final owner = LuminaBuildOwner();
      final rootElem = LuminaElement(parent)..owner = owner;
      rootElem.mount(rootElem);

      LuminaElement? childElem;
      rootElem.visitChildren((c) => childElem = c);
      expect(childElem, isNotNull);

      final initialRo = childElem!.runtimeObject! as TestMeshRuntimeObject;
      final initialHandle = initialRo.nativeHandle;

      for (int i = 1; i <= 100; i++) {
        parent.currentChild = TestMeshNode(meshPath: 'contents/meshes/cube_$i.lmas');
        rootElem.markNeedsBuild();
        owner.flushBuild();

        LuminaElement? currentChildElem;
        rootElem.visitChildren((c) => currentChildElem = c);
        expect(identical(currentChildElem, childElem), isTrue);

        final currentRo = currentChildElem!.runtimeObject! as TestMeshRuntimeObject;
        expect(identical(currentRo, initialRo), isTrue);
        expect(currentRo.nativeHandle, equals(initialHandle));
      }

      expect(TestMeshNode.createCount, equals(1));
      expect(TestMeshNode.updateNodeCount, equals(100));
      expect(initialRo.updateCount, equals(100));
    });

    test('Changing node runtimeType in rebuild detaches old runtime object and creates new', () {
      final parent = DynamicRuntimeParentNode(const TestMeshNode(meshPath: 'cube.lmas'));

      final owner = LuminaBuildOwner();
      final rootElem = LuminaElement(parent)..owner = owner;
      rootElem.mount(rootElem);

      LuminaElement? childElem1;
      rootElem.visitChildren((c) => childElem1 = c);
      final oldRo = childElem1!.runtimeObject! as TestMeshRuntimeObject;
      expect(oldRo.isAttached, isTrue);

      // Swap to OtherRuntimeNode
      parent.currentChild = const OtherRuntimeNode();
      rootElem.markNeedsBuild();
      owner.flushBuild();

      expect(oldRo.isAttached, isFalse);
      expect(oldRo.detachCount, equals(1));

      LuminaElement? childElem2;
      rootElem.visitChildren((c) => childElem2 = c);
      final newRo = childElem2!.runtimeObject! as OtherRuntimeObject;
      expect(newRo.isAttached, isTrue);
      expect(newRo.attachCount, equals(1));
    });

    test('update receives new config and enables diffing against stored state', () {
      final parent = DynamicRuntimeParentNode(const TestMeshNode(meshPath: 'initial.lmas'));
      final owner = LuminaBuildOwner();
      final rootElem = LuminaElement(parent)..owner = owner;
      rootElem.mount(rootElem);

      LuminaElement? childElem;
      rootElem.visitChildren((c) => childElem = c);
      final ro = childElem!.runtimeObject! as TestMeshRuntimeObject;

      parent.currentChild = const TestMeshNode(meshPath: 'updated_1.lmas');
      rootElem.markNeedsBuild();
      owner.flushBuild();

      parent.currentChild = const TestMeshNode(meshPath: 'updated_2.lmas');
      rootElem.markNeedsBuild();
      owner.flushBuild();

      expect(ro.updateLog, equals(['initial.lmas->updated_1.lmas', 'updated_1.lmas->updated_2.lmas']));
    });
  });
}
