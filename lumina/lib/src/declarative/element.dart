import 'package:lumina/src/declarative/build_context.dart';
import 'package:lumina/src/declarative/build_owner.dart';
import 'package:lumina/src/declarative/lumina_object.dart';
import 'package:lumina/src/declarative/runtime_object.dart';
import 'package:lumina/src/world/world.dart';
import 'package:lumina/src/world/level.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/components/base/actor_component.dart';

/// Lifecycle state of a [LuminaElement].
enum LuminaElementLifecycle {
  /// Element created, not yet mounted.
  initial,

  /// Element mounted and active in the declarative tree.
  active,

  /// Element unmounted and discarded. Defunct elements cannot be remounted.
  defunct,
}

/// Lightweight runtime element representing a mounted node in the Lumina tree.
/// Implements [LuminaBuildContext] so all queries walk the live element hierarchy.
class LuminaElement implements LuminaBuildContext {
  LuminaObject _node;
  LuminaElement? parent;
  LuminaBuildOwner? _owner;
  LuminaElement? _child;
  List<LuminaElement> _children = [];

  LuminaElementLifecycle _lifecycle = LuminaElementLifecycle.initial;
  bool _dirty = false;
  int _depth = 0;
  LuminaBuildContext? _initialParentContext;
  LuminaRuntimeObject? _runtimeObject;

  /// The runtime object holding heavy native handles, if this element represents a [LuminaRuntimeObjectNode].
  LuminaRuntimeObject? get runtimeObject => _runtimeObject;

  /// The declarative node configuration represented by this element.
  LuminaObject get node => _node;

  /// Depth of this element in the tree (root is 0).
  int get depth => _depth;

  /// Current lifecycle state of this element.
  LuminaElementLifecycle get lifecycle => _lifecycle;

  /// Whether this element is currently active and mounted.
  bool get isMounted => _lifecycle == LuminaElementLifecycle.active;

  /// Whether this element needs to be rebuilt.
  bool get dirty => _dirty;

  /// The build owner governing this element tree.
  LuminaBuildOwner? get owner => _owner ?? parent?.owner;
  set owner(LuminaBuildOwner? value) => _owner = value;

  LuminaElement(LuminaObject node, {this.parent}) : _node = node;

  void _checkDefunct() {
    if (_lifecycle == LuminaElementLifecycle.defunct) {
      throw StateError('Cannot query a defunct LuminaBuildContext / LuminaElement.');
    }
  }

  @override
  LuminaWorld? get world {
    _checkDefunct();
    if (_node is LuminaWorld) return _node as LuminaWorld;
    LuminaElement? current = parent;
    while (current != null) {
      if (current._node is LuminaWorld) return current._node as LuminaWorld;
      if (current.parent == null) {
        final fallback = current._initialParentContext?.world;
        if (fallback != null) return fallback;
      }
      current = current.parent;
    }
    return _initialParentContext?.world;
  }

  @override
  LuminaLevel? get level {
    _checkDefunct();
    if (_node is LuminaLevel) return _node as LuminaLevel;
    LuminaElement? current = parent;
    while (current != null) {
      if (current._node is LuminaLevel) return current._node as LuminaLevel;
      if (current.parent == null) {
        final fallback = current._initialParentContext?.level;
        if (fallback != null) return fallback;
      }
      current = current.parent;
    }
    return _initialParentContext?.level;
  }

  @override
  LuminaActor? get actor {
    _checkDefunct();
    if (_node is LuminaActor) return _node as LuminaActor;
    LuminaElement? current = parent;
    while (current != null) {
      if (current._node is LuminaActor) return current._node as LuminaActor;
      if (current.parent == null) {
        final fallback = current._initialParentContext?.actor;
        if (fallback != null) return fallback;
      }
      current = current.parent;
    }
    return _initialParentContext?.actor;
  }

  @override
  LuminaWorld? findAncestorWorld() => world;

  @override
  LuminaLevel? findAncestorLevel() => level;

  @override
  LuminaActor? findAncestorActor() => actor;

  @override
  T? findAncestorOfExactType<T extends LuminaObject>() {
    _checkDefunct();
    LuminaElement? current = parent;
    while (current != null) {
      if (current._node.runtimeType == T) {
        return current._node as T;
      }
      if (current.parent == null) {
        final fallback = current._initialParentContext?.findAncestorOfExactType<T>();
        if (fallback != null) return fallback;
      }
      current = current.parent;
    }
    return _initialParentContext?.findAncestorOfExactType<T>();
  }

  @override
  T? findAncestorOfType<T extends LuminaObject>() {
    _checkDefunct();
    LuminaElement? current = parent;
    while (current != null) {
      final cand = current._node;
      if (cand is T) {
        return cand;
      }
      if (current.parent == null) {
        final fallback = current._initialParentContext?.findAncestorOfType<T>();
        if (fallback != null) return fallback;
      }
      current = current.parent;
    }
    return _initialParentContext?.findAncestorOfType<T>();
  }

  @override
  void visitAncestorElements(bool Function(LuminaObject node) visitor) {
    _checkDefunct();
    LuminaElement? current = parent;
    while (current != null) {
      if (!visitor(current._node)) return;
      current = current.parent;
    }
    _initialParentContext?.visitAncestorElements(visitor);
  }

  /// Whether an element representing [oldNode] can be updated to represent [newNode].
  static bool canUpdate(LuminaObject oldNode, LuminaObject newNode) {
    return oldNode.runtimeType == newNode.runtimeType && oldNode.key == newNode.key;
  }

  /// Marks this element as needing a build in the next build flush.
  void markNeedsBuild() {
    if (_lifecycle == LuminaElementLifecycle.defunct) {
      throw StateError('Cannot mark a defunct LuminaElement as needing build.');
    }
    if (_dirty) return;
    _dirty = true;
    owner?.scheduleBuildFor(this);
  }

  /// Mounts this element into the game tree and instantiates underlying imperative objects.
  void mount(LuminaBuildContext parentContext) {
    if (_lifecycle == LuminaElementLifecycle.defunct) {
      throw StateError('Cannot mount a defunct LuminaElement. Create a new element instead.');
    }
    if (_lifecycle == LuminaElementLifecycle.active) {
      return;
    }

    if (parent == null && parentContext != this) {
      _initialParentContext = parentContext;
    }

    _depth = parent != null ? parent!.depth + 1 : 0;

    // Resolve context links
    LuminaWorld? currentWorld = world;
    LuminaLevel? currentLevel = level;
    LuminaActor? currentActor = actor;

    if (_node is LuminaActor) {
      final actor = _node as LuminaActor;
      // A level attached to a world registers the actor itself;
      // only register one that no level brought into a world.
      currentLevel?.registerActor(actor);
      if (currentWorld != null && !actor.isRegistered) {
        actor.onRegister(currentWorld);
      }
    }
    if (_node is LuminaActorComponent && currentActor != null) {
      currentActor.addComponent(_node as LuminaActorComponent);
    }

    if (_node is LuminaRuntimeObjectNode) {
      _runtimeObject = (_node as LuminaRuntimeObjectNode).createRuntimeObject(this);
      _runtimeObject!.attach(this);
    }

    _lifecycle = LuminaElementLifecycle.active;
    _dirty = false;

    // Call build(this) to get child node
    final childNode = _node.build(this);
    if (childNode != null) {
      _child = LuminaElement(childNode, parent: this);
      _child!.mount(this);
    }

    // Process multiple children if present
    for (final child in _node.children) {
      final childElem = LuminaElement(child, parent: this);
      childElem.mount(this);
      _children.add(childElem);
    }
  }

  /// Updates the configuration node and rebuilds descendants.
  void update(LuminaObject newConfig) {
    _node = newConfig;
    if (_node is LuminaRuntimeObjectNode && _runtimeObject != null) {
      (_node as LuminaRuntimeObjectNode).updateRuntimeObject(_runtimeObject!);
      _runtimeObject!.update(_node);
    }
    rebuild();
  }

  /// Rebuilds this element and reconciles child and children subtrees.
  void rebuild() {
    if (_lifecycle != LuminaElementLifecycle.active) return;
    _dirty = false;

    final newChildNode = _node.build(this);
    _child = updateChild(_child, newChildNode);
    _children = updateChildren(_children, _node.children);
  }

  /// Updates a single child element with a new declarative node configuration.
  LuminaElement? updateChild(LuminaElement? child, LuminaObject? newNode) {
    if (newNode == null) {
      if (child != null) {
        child.unmount();
      }
      return null;
    }

    if (child == null) {
      final newElem = LuminaElement(newNode, parent: this);
      newElem.mount(this);
      return newElem;
    }

    if (canUpdate(child.node, newNode)) {
      child.parent = this;
      child.update(newNode);
      return child;
    } else {
      child.unmount();
      final newElem = LuminaElement(newNode, parent: this);
      newElem.mount(this);
      return newElem;
    }
  }

  /// Reconciles a list of child elements with a new list of declarative nodes.
  List<LuminaElement> updateChildren(List<LuminaElement> oldChildren, List<LuminaObject> newNodes) {
    if (newNodes.isEmpty) {
      for (final child in oldChildren) {
        child.unmount();
      }
      return <LuminaElement>[];
    }

    if (oldChildren.isEmpty) {
      final result = <LuminaElement>[];
      for (final node in newNodes) {
        final elem = LuminaElement(node, parent: this);
        elem.mount(this);
        result.add(elem);
      }
      return result;
    }

    final newChildren = <LuminaElement>[];

    // Keyed lookup map
    final Map<Object, LuminaElement> keyedOld = {};
    final List<LuminaElement?> unkeyedOld = [];

    for (final oldChild in oldChildren) {
      if (oldChild.node.key != null) {
        keyedOld[oldChild.node.key!] = oldChild;
      } else {
        unkeyedOld.add(oldChild);
      }
    }

    int unkeyedIndex = 0;

    for (final newNode in newNodes) {
      LuminaElement? matchedOld;

      if (newNode.key != null) {
        matchedOld = keyedOld.remove(newNode.key);
      } else {
        // Find next unkeyed candidate
        while (unkeyedIndex < unkeyedOld.length) {
          final candidate = unkeyedOld[unkeyedIndex];
          unkeyedIndex++;
          if (candidate != null && canUpdate(candidate.node, newNode)) {
            matchedOld = candidate;
            break;
          }
        }
      }

      if (matchedOld != null && canUpdate(matchedOld.node, newNode)) {
        matchedOld.parent = this;
        matchedOld.update(newNode);
        newChildren.add(matchedOld);
      } else {
        final newElem = LuminaElement(newNode, parent: this);
        newElem.mount(this);
        newChildren.add(newElem);
      }
    }

    // Unmount any remaining unmatched keyed elements
    for (final unused in keyedOld.values) {
      unused.unmount();
    }
    // Unmount any remaining unmatched unkeyed elements
    for (int i = unkeyedIndex; i < unkeyedOld.length; i++) {
      unkeyedOld[i]?.unmount();
    }

    return newChildren;
  }

  /// Unmounts this element and releases resources in depth-first post-order.
  void unmount() {
    if (_lifecycle != LuminaElementLifecycle.active) {
      return;
    }

    // Unmount children in reverse list order first
    for (final child in _children.reversed) {
      child.unmount();
    }
    _children.clear();

    if (_child != null) {
      _child!.unmount();
      _child = null;
    }

    // Undo registration
    if (_node is LuminaActorComponent) {
      actor?.removeComponent(_node as LuminaActorComponent);
    }
    if (_node is LuminaActor) {
      level?.unregisterActor(_node as LuminaActor);
    }

    if (_runtimeObject != null) {
      _runtimeObject!.detach();
      _runtimeObject = null;
    }

    _lifecycle = LuminaElementLifecycle.defunct;
    _initialParentContext = null;
  }

  /// Visits all mounted direct children of this element.
  void visitChildren(void Function(LuminaElement child) visitor) {
    if (_child != null) {
      visitor(_child!);
    }
    for (final child in _children) {
      visitor(child);
    }
  }
}
