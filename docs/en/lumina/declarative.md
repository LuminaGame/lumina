[Türkçe](../../tr/lumina/declarative.md)

# Declarative tree

The declarative layer of the engine: a game describes its world with a `build()` tree of `LuminaObject`s, which the build owner turns into elements and then into live runtime objects, with pooling for objects that come and go. File paths are relative to the `lumina/` package directory.

**On this page:**

- [`lib/src/declarative/build_context.dart`](#libsrcdeclarativebuild_contextdart)
- [`lib/src/declarative/build_owner.dart`](#libsrcdeclarativebuild_ownerdart)
- [`lib/src/declarative/element.dart`](#libsrcdeclarativeelementdart)
- [`lib/src/declarative/lumina_object.dart`](#libsrcdeclarativelumina_objectdart)
- [`lib/src/declarative/runtime_object.dart`](#libsrcdeclarativeruntime_objectdart)

## `lib/src/declarative/build_context.dart`

### `class LuminaBuildContext`

Context interface provided to [LuminaObject.build] during tree construction.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `world` | `LuminaWorld? get world` | Reference to the current [LuminaWorld] context. |
| `level` | `LuminaLevel? get level` | Reference to the current active [LuminaLevel]. |
| `actor` | `LuminaActor? get actor` | Reference to the enclosing [LuminaActor], if any. |
| `findAncestorWorld` | `LuminaWorld? findAncestorWorld()` | Convenience finder for the nearest enclosing [LuminaWorld]. |
| `findAncestorLevel` | `LuminaLevel? findAncestorLevel()` | Convenience finder for the nearest enclosing [LuminaLevel]. |
| `findAncestorActor` | `LuminaActor? findAncestorActor()` | Convenience finder for the nearest enclosing [LuminaActor]. |
| `visitAncestorElements` | `void visitAncestorElements(bool Function(LuminaObject node) visitor)` | Walks up the ancestor chain from parent to root, stopping when visitor returns false. |

### `class LuminaElementContext`

`LuminaElementContext`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `world` | `LuminaWorld? world` | Holds the `world` property or configuration state. |
| `level` | `LuminaLevel? level` | Holds the `level` property or configuration state. |
| `actor` | `LuminaActor? actor` | Holds the `actor` property or configuration state. |
| `node` | `LuminaObject node` | Holds the `node` property or configuration state. |
| `parent` | `LuminaElementContext? parent` | Holds the `parent` property or configuration state. |
| `findAncestorWorld` | `LuminaWorld? findAncestorWorld()` | Searches and retrieves matching items or actors. |
| `findAncestorLevel` | `LuminaLevel? findAncestorLevel()` | Searches and retrieves matching items or actors. |
| `findAncestorActor` | `LuminaActor? findAncestorActor()` | Searches and retrieves matching items or actors. |
| `visitAncestorElements` | `void visitAncestorElements(bool Function(LuminaObject node) visitor)` | Executes `visitAncestorElements` operation. |

## `lib/src/declarative/build_owner.dart`

### `class LuminaBuildOwner`

Manages the build and reconciliation cycle of [LuminaElement] trees.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `hasDirtyElements` | `bool get hasDirtyElements` | Whether there are elements waiting to be rebuilt. |
| `scheduleBuildFor` | `void scheduleBuildFor(LuminaElement element)` | Schedules an element for rebuilding in the next flush. |
| `flushBuild` | `void flushBuild()` | Flushes all scheduled element builds, sorted by depth (parents first). |

## `lib/src/declarative/element.dart`

### `enum LuminaElementLifecycle`

Lifecycle state of a [LuminaElement].

### `class LuminaElement`

Lightweight runtime element representing a mounted node in the Lumina tree. Implements [LuminaBuildContext] so all queries walk the live element hierarchy.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `parent` | `LuminaElement? parent` | Holds the `parent` property or configuration state. |
| `runtimeObject` | `LuminaRuntimeObject? get runtimeObject` | The runtime object holding heavy native handles, if this element represents a [LuminaRuntimeObjectNode]. |
| `node` | `LuminaObject get node` | The declarative node configuration represented by this element. |
| `depth` | `int get depth` | Depth of this element in the tree (root is 0). |
| `lifecycle` | `LuminaElementLifecycle get lifecycle` | Current lifecycle state of this element. |
| `isMounted` | `bool get isMounted` | Whether this element is currently active and mounted. |
| `dirty` | `bool get dirty` | Whether this element needs to be rebuilt. |
| `owner` | `LuminaBuildOwner? get owner` | The build owner governing this element tree. |
| `owner` | `owner(LuminaBuildOwner? value)` | Executes `owner` operation. |
| `world` | `LuminaWorld? get world` | Getter accessor returning the current value of `world`. |
| `level` | `LuminaLevel? get level` | Getter accessor returning the current value of `level`. |
| `actor` | `LuminaActor? get actor` | Getter accessor returning the current value of `actor`. |
| `findAncestorWorld` | `LuminaWorld? findAncestorWorld()` | Searches and retrieves matching items or actors. |
| `findAncestorLevel` | `LuminaLevel? findAncestorLevel()` | Searches and retrieves matching items or actors. |
| `findAncestorActor` | `LuminaActor? findAncestorActor()` | Searches and retrieves matching items or actors. |
| `visitAncestorElements` | `void visitAncestorElements(bool Function(LuminaObject node) visitor)` | Executes `visitAncestorElements` operation. |
| `canUpdate` | `static bool canUpdate(LuminaObject oldNode, LuminaObject newNode)` | Whether an element representing [oldNode] can be updated to represent [newNode]. |
| `markNeedsBuild` | `void markNeedsBuild()` | Marks this element as needing a build in the next build flush. |
| `mount` | `void mount(LuminaBuildContext parentContext)` | Mounts this element into the game tree and instantiates underlying imperative objects. |
| `update` | `void update(LuminaObject newConfig)` | Updates the configuration node and rebuilds descendants. |
| `rebuild` | `void rebuild()` | Rebuilds this element and reconciles child and children subtrees. |
| `updateChild` | `LuminaElement? updateChild(LuminaElement? child, LuminaObject? newNode)` | Updates a single child element with a new declarative node configuration. |
| `updateChildren` | `List<LuminaElement> updateChildren(List<LuminaElement> oldChildren, List...` | Reconciles a list of child elements with a new list of declarative nodes. |
| `unmount` | `void unmount()` | Unmounts this element and releases resources in depth-first post-order. |
| `visitChildren` | `void visitChildren(void Function(LuminaElement child) visitor)` | Visits all mounted direct children of this element. |

## `lib/src/declarative/lumina_object.dart`

### `class LuminaObject`

Base root class for all declarative nodes in the Lumina Game Engine. Inspired by Flutter's Widget architecture.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `key` | `Key? key` | Unique key for element identity reconciliation. |
| `build` | `LuminaObject? build(LuminaBuildContext context)` | Builds the child or hierarchy of sub-nodes for this node. |
| `children` | `List<LuminaObject> get children` | Returns children of this node if it contains multiple nodes. |

### `class LuminaNodeGroup`

Helper container node for multiple children.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `children` | `List<LuminaObject> children` | Holds the `children` property or configuration state. |
| `build` | `LuminaObject? build(LuminaBuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/src/declarative/runtime_object.dart`

### `class LuminaRuntimeObject`

Heavy runtime tier object that holds persistent native handles (Filament entities, physics bodies). Survives declarative rebuilds and is updated in place to prevent frame drops.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isAttached` | `bool get isAttached` | Whether this runtime object is currently attached to an active element. |
| `attach` | `void attach(LuminaBuildContext context)` | Acquires native resources and binds to the active build context. |
| `update` | `void update(covariant LuminaObject newConfig)` | Updates internal native state and parameters with a new declarative configuration. |
| `detach` | `void detach()` | Detaches from the active context and releases (or resets) native resources. |

### `class LuminaRuntimeObjectNode`

Declarative configuration node that instantiates and updates a corresponding [LuminaRuntimeObject].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `createRuntimeObject` | `LuminaRuntimeObject createRuntimeObject(LuminaBuildContext context)` | Instantiates a new runtime object for this declarative node. |
| `updateRuntimeObject` | `void updateRuntimeObject(covariant LuminaRuntimeObject runtimeObject)` | Mutates an existing runtime object with this node's updated parameters. |

### `class LuminaObjectPool`

Lightweight, allocation-free object pool for reusing frequently allocated engine objects.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `maxSize` | `int maxSize` | Holds the `maxSize` property or configuration state. |
| `acquire` | `T acquire()` | Retrieves an instance from the pool or creates a new one if the pool is empty. |
| `release` | `void release(T obj)` | Resets an instance and returns it to the pool if below [maxSize]. |
| `pooledCount` | `int get pooledCount` | Number of idle objects currently in the pool. |
| `createCount` | `int get createCount` | Total number of allocations created by this pool. |

---

[Previous: lumina (engine core)](index.md) | [Up: lumina (engine core)](index.md) | [Next: World, levels and streaming](world.md)
