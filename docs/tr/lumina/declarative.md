[English](../../en/lumina/declarative.md)

# Deklaratif ağaç

Engine'in deklaratif katmanı: bir oyun, dünyasını `LuminaObject`'lerden oluşan bir `build()` ağacıyla tanımlar; build owner bu ağacı element'lere, ardından canlı runtime object'lere dönüştürür ve gelip giden nesneler için pooling uygular. Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/src/declarative/build_context.dart`](#libsrcdeclarativebuild_contextdart)
- [`lib/src/declarative/build_owner.dart`](#libsrcdeclarativebuild_ownerdart)
- [`lib/src/declarative/element.dart`](#libsrcdeclarativeelementdart)
- [`lib/src/declarative/lumina_object.dart`](#libsrcdeclarativelumina_objectdart)
- [`lib/src/declarative/runtime_object.dart`](#libsrcdeclarativeruntime_objectdart)

## `lib/src/declarative/build_context.dart`

### `class LuminaBuildContext`

Context interface provided to [LuminaObject.build] during tree construction. `LuminaObjectContext`'i (ata aramaları) uygular; dünyayı, seviyeyi ve actor'ü ekler.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `world` | `LuminaWorld? get world` | Reference to the current [LuminaWorld] context. |
| `level` | `LuminaLevel? get level` | Reference to the current active [LuminaLevel]. |
| `actor` | `LuminaActor? get actor` | Reference to the enclosing [LuminaActor], if any. |
| `findAncestorWorld` | `LuminaWorld? findAncestorWorld()` | Convenience finder for the nearest enclosing [LuminaWorld]. |
| `findAncestorLevel` | `LuminaLevel? findAncestorLevel()` | Convenience finder for the nearest enclosing [LuminaLevel]. |
| `findAncestorActor` | `LuminaActor? findAncestorActor()` | Convenience finder for the nearest enclosing [LuminaActor]. |
| `visitAncestorElements` | `void visitAncestorElements(bool Function(LuminaObject node) visitor)` | Walks up the ancestor chain from parent to root, stopping when visitor returns false. |

### `class LuminaElementContext`

`LuminaElementContext`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `world` | `LuminaWorld? world` | `world` alanını (field/property) ve ilişkili veriyi saklar. |
| `level` | `LuminaLevel? level` | `level` alanını (field/property) ve ilişkili veriyi saklar. |
| `actor` | `LuminaActor? actor` | `actor` alanını (field/property) ve ilişkili veriyi saklar. |
| `node` | `LuminaObject node` | `node` alanını (field/property) ve ilişkili veriyi saklar. |
| `parent` | `LuminaElementContext? parent` | `parent` alanını (field/property) ve ilişkili veriyi saklar. |
| `findAncestorWorld` | `LuminaWorld? findAncestorWorld()` | Belirtilen arama kriterlerine uyan nesneleri veya aktörleri bulup listeler. |
| `findAncestorLevel` | `LuminaLevel? findAncestorLevel()` | Belirtilen arama kriterlerine uyan nesneleri veya aktörleri bulup listeler. |
| `findAncestorActor` | `LuminaActor? findAncestorActor()` | Belirtilen arama kriterlerine uyan nesneleri veya aktörleri bulup listeler. |
| `visitAncestorElements` | `void visitAncestorElements(bool Function(LuminaObject node) visitor)` | `visitAncestorElements` işlemini gerçekleştirir. |

## `lib/src/declarative/build_owner.dart`

### `class LuminaBuildOwner`

Manages the build and reconciliation cycle of [LuminaElement] trees.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `hasDirtyElements` | `bool get hasDirtyElements` | Whether there are elements waiting to be rebuilt. |
| `scheduleBuildFor` | `void scheduleBuildFor(LuminaElement element)` | Schedules an element for rebuilding in the next flush. |
| `flushBuild` | `void flushBuild()` | Flushes all scheduled element builds, sorted by depth (parents first). |

## `lib/src/declarative/element.dart`

### `enum LuminaElementLifecycle`

Lifecycle state of a [LuminaElement].

### `class LuminaElement`

Lightweight runtime element representing a mounted node in the Lumina tree. Implements [LuminaBuildContext] so all queries walk the live element hierarchy.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `parent` | `LuminaElement? parent` | `parent` alanını (field/property) ve ilişkili veriyi saklar. |
| `runtimeObject` | `LuminaRuntimeObject? get runtimeObject` | The runtime object holding heavy native handles, if this element represents a [LuminaRuntimeObjectNode]. |
| `node` | `LuminaObject get node` | The declarative node configuration represented by this element. |
| `depth` | `int get depth` | Depth of this element in the tree (root is 0). |
| `lifecycle` | `LuminaElementLifecycle get lifecycle` | Current lifecycle state of this element. |
| `isMounted` | `bool get isMounted` | Whether this element is currently active and mounted. |
| `dirty` | `bool get dirty` | Whether this element needs to be rebuilt. |
| `owner` | `LuminaBuildOwner? get owner` | The build owner governing this element tree. |
| `owner` | `owner(LuminaBuildOwner? value)` | `owner` işlemini gerçekleştirir. |
| `world` | `LuminaWorld? get world` | `world` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `level` | `LuminaLevel? get level` | `level` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `actor` | `LuminaActor? get actor` | `actor` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `findAncestorWorld` | `LuminaWorld? findAncestorWorld()` | Belirtilen arama kriterlerine uyan nesneleri veya aktörleri bulup listeler. |
| `findAncestorLevel` | `LuminaLevel? findAncestorLevel()` | Belirtilen arama kriterlerine uyan nesneleri veya aktörleri bulup listeler. |
| `findAncestorActor` | `LuminaActor? findAncestorActor()` | Belirtilen arama kriterlerine uyan nesneleri veya aktörleri bulup listeler. |
| `visitAncestorElements` | `void visitAncestorElements(bool Function(LuminaObject node) visitor)` | `visitAncestorElements` işlemini gerçekleştirir. |
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

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `key` | `LuminaObjectKey? key` | Unique key for element identity reconciliation (the engine's own key, see [object](object.md#libsrcobjectlumina_object_keydart)). |
| `build` | `LuminaObject? build(covariant LuminaObjectContext context)` | Builds the child or hierarchy of sub-nodes for this node. The tree passes a `LuminaBuildContext`; overrides declare that type. |
| `children` | `List<LuminaObject> get children` | Returns children of this node if it contains multiple nodes. |

### `abstract interface class LuminaObjectContext`

`LuminaObject.build`'in dünyayı bilmeden ağaçtan isteyebildikleri: ataları (`findAncestorOfExactType`, `findAncestorOfType`, `visitAncestorElements`). `LuminaBuildContext` bunu uygular ve dünyayı, seviyeyi ve kapsayan actor'ü ekler. `lumina_object.dart` yalnızca `LuminaObjectKey`'i import eder; böylece nesne modelinin kökü hiçbir Flutter kütüphanesine ulaşmaz (`test/architecture/flutter_free_object_root_test.dart` bunu korur).

### `class LuminaNodeGroup`

Helper container node for multiple children.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `children` | `List<LuminaObject> children` | `children` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `LuminaObject? build(LuminaObjectContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/src/declarative/runtime_object.dart`

### `class LuminaRuntimeObject`

Heavy runtime tier object that holds persistent native handles (Filament entities, physics bodies). Survives declarative rebuilds and is updated in place to prevent frame drops.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isAttached` | `bool get isAttached` | Whether this runtime object is currently attached to an active element. |
| `attach` | `void attach(LuminaBuildContext context)` | Acquires native resources and binds to the active build context. |
| `update` | `void update(covariant LuminaObject newConfig)` | Updates internal native state and parameters with a new declarative configuration. |
| `detach` | `void detach()` | Detaches from the active context and releases (or resets) native resources. |

### `class LuminaRuntimeObjectNode`

Declarative configuration node that instantiates and updates a corresponding [LuminaRuntimeObject].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `createRuntimeObject` | `LuminaRuntimeObject createRuntimeObject(LuminaBuildContext context)` | Instantiates a new runtime object for this declarative node. |
| `updateRuntimeObject` | `void updateRuntimeObject(covariant LuminaRuntimeObject runtimeObject)` | Mutates an existing runtime object with this node's updated parameters. |

### `class LuminaObjectPool`

Lightweight, allocation-free object pool for reusing frequently allocated engine objects.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `maxSize` | `int maxSize` | `maxSize` alanını (field/property) ve ilişkili veriyi saklar. |
| `acquire` | `T acquire()` | Retrieves an instance from the pool or creates a new one if the pool is empty. |
| `release` | `void release(T obj)` | Resets an instance and returns it to the pool if below [maxSize]. |
| `pooledCount` | `int get pooledCount` | Number of idle objects currently in the pool. |
| `createCount` | `int get createCount` | Total number of allocations created by this pool. |

---

[Önceki: lumina (engine çekirdeği)](index.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Dünya, level'lar ve streaming](world.md)
