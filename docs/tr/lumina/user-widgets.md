[English](../../en/lumina/user-widgets.md)

# User widget'lar (Widget Blueprint script'i)

UMG'nin motor tarafı: bir Widget Blueprint graph'ının üzerinde çalıştığı nesne. Hiçbir Flutter widget'ı tutmaz; script'lediği widget'ları `lumina_widgets` çizer ([UMG sayfası](../lumina_widgets/umg.md)). Dosya yolları `lumina/` paket dizinine görelidir.

## `lib/src/umg/user_widget.dart`

### `abstract class LuminaUserWidget`

A widget's own script: the object a Widget Blueprint graph runs on, bound to one widget instance map (the one `Create Widget` built). It is a hidden actor with no components so every Blueprint node that reaches `self.world` (the widget subsystem, the player, timers) keeps working.

The VM (`LuminaBlueprintUserWidget`) and each generated `WBP<Name>Graph` override the hooks: Pre Construct and Construct when the widget is added to the viewport, Destruct when it is removed, Tick every world tick while it is on screen, and [onWidgetEvent] when one of its elements is pressed, hovered or changed.

**Yapıcı Metotlar (Constructors):**

- `LuminaUserWidget({super.key})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `widgetInstance` | `Map<String, Object?> get widgetInstance` | The widget instance map this script scripts. |
| `widgetClassName` | `String get widgetClassName` | The widget class (`WBP_Clicker`). |
| `isWidgetConstructed` | `bool get isWidgetConstructed` | Whether Construct ran since the widget last entered the viewport. |
| `isWidgetInViewport` | `bool get isWidgetInViewport` | Whether the widget is on screen now. |
| `widgetElement` | `Map<String, Object?>? widgetElement(String name)` | The state map of the element named [name] (its designer name), or null. |
| `bindWidgetInstance` | `void bindWidgetInstance(Map<String, Object?> instance)` | Binds this script to [instance] (done once, by [LuminaUserWidgets.attach]). |
| `onWidgetPreConstruct` | `void onWidgetPreConstruct(bool isDesignTime)` | Event Pre Construct; [isDesignTime] is false at run time. |
| `onWidgetConstruct` | `void onWidgetConstruct()` | Event Construct. |
| `onWidgetDestruct` | `void onWidgetDestruct()` | Event Destruct. |
| `onWidgetTick` | `void onWidgetTick(double inDeltaTime)` | Event Tick (In Delta Time), while the widget is on screen. |
| `onWidgetEvent` | `void onWidgetEvent(String element, String event, Map<String, Object?> args)` | A bound element event: [event] (`OnClicked`, `OnValueChanged`, …) of the element named [element], with the event's outputs in [args] (`value`, `text`, `commit_method`). |

### `abstract final class LuminaUserWidgets`

The widget classes whose instances run a graph: the factory of each class's script, registered by the generated `widget_registry.g.dart` (the compiled `WBP<Name>Graph`) or by Play-In-Editor (a VM script over the editor's graph). The widget nodes call into here, so the VM and generated code share one lifecycle.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `register` | `static void register(String className, LuminaUserWidget Function() factory)` |  |
| `registerAll` | `static void registerAll(Map<String, LuminaUserWidget Function()> factories)` |  |
| `unregister` | `static void unregister(String className)` |  |
| `clear` | `static void clear()` |  |
| `has` | `static bool has(String className)` |  |
| `classNames` | `static Iterable<String> get classNames` |  |
| `of` | `static LuminaUserWidget? of(Object? instance)` | The script of widget instance [instance], or null (no graph, or not a widget). |
| `attach` | `static LuminaUserWidget? attach(LuminaWorld? world, Map<String, Object?> instance)` | Creates [instance]'s script when its class has a graph, binds it and spawns it into [world] (`Create Widget`). Returns the script, or null. |
| `addedToViewport` | `static void addedToViewport(Object? instance)` | `Add to Viewport`: Pre Construct then Construct, once per stay on screen. |
| `removedFromParent` | `static void removedFromParent(Object? instance)` | `Remove from Parent`: Destruct. |
| `fire` | `static void fire(Map<String, Object?>? instance, String element, String event, [Map<String, Object?> args = co...` | A generated widget's (or Play-In-Editor's) element event: runs the graph's `On <Event> (<element>)` node, if the widget has one. |
| `instanceOfElement` | `static Map<String, Object?>? instanceOfElement(Object? element)` | [element] durum map'inin ait olduğu widget instance'ı (instance bir graph çalıştırıyorsa; [attach] hatırlar); Combo Box setter'ları On Selection Changed'i (`Direct`) bununla çalıştırır. |

## `lib/src/umg/combo_box_options.dart`

Bir Combo Box seçeneği oyuncunun gördüğü **etiketi** herhangi bir Blueprint tipindeki bir **değerle** eşler (`Vector2` çözünürlük, bir enum adı, bir aktör, …). Element durumu bunları `options` altında tutar; her saklama biçimi aynı okunur:

| Saklanan biçim | Nereden gelir | Okunuşu |
| :--- | :--- | :--- |
| `'Low,High'` | seçeneklerin değeri olmadan önce kaydedilmiş widget belgeleri (designer açınca liste biçimine taşınır) | etiketler, her biri kendi değeri |
| `['Easy', 'Hard']` | değersiz Add Option | etiketler, her biri kendi değeri |
| `[{'label': '720p', 'value': Vector2(1280, 720)}]` | değerli Add Option | etiket + değerin kendisi |
| `[{'label': '4K', 'value': [3840.0, 2160.0], 'type': 'vector2D'}]` | designer'ın tipli literal'i | etiket + `luminaBlueprintLiteral(type, value)` (`Vector2(3840, 2160)`) |

Seçim `selectedOption` (etiket; designer bunu `selected` olarak tohumlar) ile tekrarlanan etiketleri ayıran `selectedIndex`'tir.

### `class LuminaComboBoxOption`

`LuminaComboBoxOption(label, value)`; `LuminaComboBoxOption.text(label)` kendi etiketini temsil eder. Eşitlik etiketi ve değeri içerikle karşılaştırır.

### `class LuminaComboBoxSelection`

On Selection Changed'in verdiği: `label` (Selected Item), `value`, `index` (seçim yoksa -1), `selectType` (`ESelectInfo`). `eventArgs` olayın çıktılarıdır, pin id'sine göre (`selected_item`, `value`, `index`, `select_type`); `none` seçimsizliktir.

### `abstract final class LuminaComboBoxOptions`

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `optionsKey`, `selectedKey`, `designerSelectedKey`, `selectedIndexKey` | `static const String` | `options`, `selectedOption`, `selected`, `selectedIndex`. |
| `selectInfoEnum`, `selectInfos` | `static const` | `ESelectInfo`: `Direct`, `OnKeyPress`, `OnNavigation`, `OnMouseClick` (sabitler `direct`, `onKeyPress`, `onNavigation`, `onMouseClick`). |
| `parse` | `static List<LuminaComboBoxOption> parse(Object? stored)` | Saklanan bir değerin bütün seçenekleri (yukarıdaki tablo). |
| `labels` | `static List<String> labels(Object? stored)` | Saklanan değerin etiketleri. |
| `entry` | `static Object entry(LuminaComboBoxOption option)` | Element durumundaki kayıt: değer etiketin kendisiyse yalnız etiket, değilse `{label, value}`. |
| `designerEntry` | `static Map<String, Object?> designerEntry(String label, {Object? value, String? type})` | Designer belgesi kaydı (`{label}` ya da `{label, value, type}`). |
| `migrateDesignerOptions` | `static List<Map<String, Object?>> migrateDesignerOptions(Object? stored)` | Eski virgülle ayrılmış metni (ya da string listesini) `{label}` kayıtlarına çevirir; kayıt listesi olduğu gibi kalır. |
| `of` | `static List<LuminaComboBoxOption> of(Object? element)` | Bir element durum map'inin seçenekleri. |
| `selectedLabel` / `selectedIndex` / `selected` | `static …(Object? element, …)` | Seçili etiket; hâlâ o etiketi gösteriyorsa saklanan indeks, değilse o etiketli ilk seçenek, yoksa -1; seçimin tamamı. |
| `writeSelection` | `static bool writeSelection(Map<String, Object?> element, List<LuminaComboBoxOption> options, int index)` | [index] numaralı seçeneğin seçimini yazar (-1: seçim yok); değişip değişmediğini döner. |
| `indexOfLabel` / `indexOfValue` | `static int …(List<LuminaComboBoxOption> options, …)` | Etiketi / eşit değeri olan ilk seçenek, yoksa -1. |
| `valueEquals` | `static bool valueEquals(Object? a, Object? b)` | Liste ve map içerikle, sayılar sayı olarak, diğerleri `==` ile (vektör ve rotator bileşenleriyle) karşılaştırılır. |

Bu model üzerindeki Blueprint düğümleri (joker Value'lu Add Option, Set Selected Value / Index, Get Selected Option → Label, Value, Index, …) [fonksiyon kütüphanesinde](blueprint/function-library.md); On Selection Changed [`LuminaWidgetEvents`](blueprint/runtime.md) içindedir.

## Viewport öğesi (`lib/src/umg/viewport/`)

UMG **Viewport** öğesi (tasarımcı tipi `viewport`) bir widget'ın içinde gerçek bir Filament önizleme sahnesi gösterir: bir karakter özelleştirme ekranı, bir eşya inceleme görünümü, bir mesh'i ya da bir pozu önizleyen bir editör paneli. Sahnesi **öğe durumundaki veridir**: Blueprint çağrıları yalnızca `elements[<ad>].scene` altındaki JSON-düz açıklamayı düzenler; Viewport widget'ı (`LuminaUmgViewport`, [UMG sayfası](../lumina_widgets/umg.md)) onu gösterdiğiyle karşılaştırır ve yalnızca farkı uygular. Böylece VM ve üretilen kod birebir aynı davranır, bir eklenti süreci aynı açıklamayı yazabilir ve kardeş bir öğedeki `Set Text` 3B sahneye hiç dokunmaz. Yörünge, gizmo sürüklemeleri, oynatma ve kaplama çizimi her karede widget'ın içinde çalışır; graph yalnızca öğenin ayrık olaylarını alır.

### `class LuminaViewportScene` (`viewport_scene.dart`)

Açıklama: öğenin `scene` haritasını sarar ve yerinde düzenler. Dönüşümler yazım uzayındadır (`{location, rotation, scale}`, Z yukarı, santimetre; Blueprint Transform pin'inin taşıdığı gibi); onları yalnızca runtime çevirir.

| Anahtar | İçerik |
| :--- | :--- |
| `nodes` | `{id, kind (staticMesh / skeletalMesh / light / marker), asset (proje .lmas'ı), transform, visible, pickable, parent, socket, materialParams {slot: {param: değer}}, morphs {ad: ağırlık}, animation {asset ya da file, loop, rate, time, playing, serial}, light {type, color, intensity}}` |
| `environment` | `{mode (sky / color / transparent), ibl, intensity}` |
| `grid` | bool |
| `camera` | `{preset (perspective / front / back / left / right / top), orbitTarget, yaw, pitch, distance, fov, orthographic, frame, frameSerial, autoFrame}` — yaw 0 bir glTF modelinin önüne bakar (yazım −Y); `autoFrame` (yeni bir açıklamada true) `Set Orbit`, yörünge hedefi, `Frame Node` ya da oyuncunun bıraktığı sürükleme kamerayı yerleştirene kadar (yalnızca otomatik dönüş kamerayı oynatmış sayılmaz), mesh kümesi her değiştiğinde yüklenen tüm mesh'leri kadraja alır; viewport boyutu değişince yeniden kadrajlar, sınırları dikey ve yatay görüş alanından dar olanına sığdırır |
| `skeletonOverlays` | `{node, color, joints, ghostPose {eklem: [x, y, z, qx, qy, qz, qw]} ya da null, ghostAnimation, ghostColor, label}` |
| `gizmo` | `{node, bone ya da null, mode (translate / rotate / scale), space (world / local), snap}` ya da null |
| `markers` | `{id, label, kind (point / line / arrow), from, to, color}` |
| `interaction` | `{orbit, pan, zoom, pick, autoRotate (derece/sn)}` |
| `nextId` | düğüm ve işaret kimliklerinin sayacı (`skeletal_1`, `mesh_2`, `marker_3`); VM ve üretilen kod aynı numaralar |

`LuminaViewportScene.of(element)` (yoksa oluşturulur), `encode()` / `decode()` (bayt bayt aynı gidiş-dönüş), `copy()`, `addNode`, `removeNode` (ona bağlı düğümleri ve üzerlerindeki kaplamaları / gizmo'yu da kaldırır), `clear`, `setNodeTransform`, `setNodeVisible`, `setNodeAsset` (parça değişimi dönüşümü korur), `attachToSocket`, `setMaterialParameter`, `setMorphTargetWeight`, `playAnimation`, `playAnimationFile`, `stopAnimation`, `setAnimationTime`, `addLight`, `setEnvironment`, `gridVisible`, `setInteraction`, `setCameraPreset`, `frameNode`, `setOrbit`, `showSkeleton`, `showGhostPose`, `hideSkeleton`, `setGizmo`, `hideGizmo`, `addMarker`, `removeMarker`. Sabitler `LuminaViewportNodeKind`, `LuminaViewportCameraPreset`, `LuminaViewportEnvironmentMode` ve `LuminaViewportLightType` içindedir.

### `abstract final class LuminaViewportSceneDiff` (`viewport_scene_diff.dart`)

`diff(old, next)` → en küçük `LuminaViewportSceneOp` listesi (`LuminaViewportSceneOpKind`: değişen `fields` ile düğüm ekle / kaldır / güncelle, environment, grid, camera, interaction, kaplama ekle / kaldır / güncelle, gizmo, işaret ekle / kaldır / güncelle). Bir düğümün dönüşümünü değiştirmek tam olarak bir `updateNode {transform}`; bir işareti kaldırmak tek bir `removeMarker`'dır. `jsonEquals` JSON değerlerini karşılaştırır (sayılar değerce).

### `class LuminaViewportSceneRuntime` (`viewport_runtime.dart`)

Paylaşılan engine üzerindeki önizleme: bir `FilamentScene`, `FilamentView` ve kamera (kendisininkiler ya da bir `FilamentWidget`'ın verdikleri) ve aktörleri açıklamanın düğümleri olan bir önizleme `LuminaWorld`'ü. Mesh'ler `LuminaAssets` ve engine'in mesh önbelleği üzerinden yüklenir (asla bir `File` okuması değil), skeletal mesh'ler gltfio'nun animatörüyle canlanır (bir animasyon `.lmas`'ı adını verdiği `clip_name`'i mesh'inde oynatır; düz bir klip adı da olur), bir sokete bağlı düğümler her karede kemiği izler (soket adları mesh'in `.lmas`'ındaki `sockets`'tan, yoksa kemik adlarından), materyal parametreleri örneğin materyal örneklerine gider (renk → `float4`, skaler → `float`, bir doku varlık yolu → yuvanın örnekleyicisi; `LuminaMaterialTextures` ile okunur ve düğümle birlikte bırakılır), morph ağırlıkları mesh'in morph hedeflerine. `ghostAnimation` ve bir zaman taşıyan hayalet poz, düğümün mesh'indeki o klipten arka planda bir kez örneklenir (canlı poz geri konur); `ghostPoseFor(id, overlay)` hazır olunca onu döndürür ve `onOverlaysChanged` bir kare ister. `Play Animation File` (yalnızca editör panelleri, `allowFiles`) bir eklenti sürecinin yazdığını okur: paketli hareket dosyası (`KMO1`: kare × eklem × öteleme, dönüş, ölçek; `LuminaViewportMotion`, eklemler `LuminaViewportMotion.skeletonOrder` sırasıyla: her skin'in eklemleri ve ataları glTF düğüm sırasında; böylece ilk skin'i başın yalnızca bir parçası olan MetaHuman gibi çok skin'li bir mesh bütün olarak oynar) düğümde kare kare oynar, klibi mesh'te bulunan bir `.lmas` animasyonu o klibi oynatır, diğer her animasyon dosyası (`.glb`, başka bir iskeletin animasyon `.lmas`'ı) arka plan isolate'inde düğümün mesh'ine retarget edilir (`GlbAnimationRetargeter`) ve bellekten oynatılır. Bir mesh'in dünya sınırları dünya dönüşümünü kullanır (yerel sınırları varlık birim ölçeğini zaten taşır). Önizleme görünümleri sabit bir özellik setiyle çizilir: MSAA 4×, gölgeli tek yönlü ışık, IBL; oyunun ışın izleme, ReSTIR, SSR, upscaler veya kare üretimi hiçbir zaman.

| Üye | Açıklama |
| :--- | :--- |
| `apply(scene)` | Gösterilenle `scene` arasındaki işlemleri uygular ve döndürür (değişiklik yoksa boş). |
| `advance(dt)` | Bir kare: animasyon, soket izleme, otomatik dönüş, kamera. |
| `animating` | Bir şeyin kendiliğinden hareket edip etmediği (oynayan animasyon, otomatik dönüş). |
| `whenReady` / `isReady` / `failures` | Her mesh yüklendi ya da başarısız oldu; başarısızlıklar asset'e göre. `OnSceneReady` ve `OnAssetLoadFailed (asset, message)` olayları `onEvent`'e gider. |
| `orbit` | Görünümün gösterdiği `LuminaViewportCamera` (oyuncunun sürüklemesi onu oynatır). |
| `frameNode(id)` / `boundsOf(id)` | Bir düğümü kadraja alır (`'*'`: her mesh); deri (skinned) mesh eklemleriyle sınırlanır. `autoFrame` açık ve kamera elle oynanmamışken her mesh yüklenince kadraja alınır. |
| `boundTextureCount(id)` / `playsMotion(id)` | Bir düğüme bağlı doku parametreleri; paketli bir hareket dosyası oynatıp oynatmadığı. |
| `ghostPoseFor(id, overlay)` | Bir kaplamanın hayalet pozu (`ghostPose`'u ya da zamanında `ghostAnimation`'dan örneklenen; örneklenirken null). |
| `onOverlaysChanged` | Bir kaplamanın içeriği açıklama dışından değişince çağrılır (örneklenen bir hayalet poz). |
| `pick(x, y)` | CPU seçimi: ışının sınırlarına girdiği en yakın düğüm, bir skeletal mesh'in en yakın kemiği ve çarpma konumu (yazım uzayı). |
| `jointsOf(id)` / `ghostJointsOf(id, pose)` | Eklem adları, ebeveynleri ve dünya konumları (canlı ya da bir hayalet pozla); mesh'in her skin'i ve eklemlerinin ataları üzerinden. |
| `setLocalTransform(id, t)` / `transformOf(id)` | Bir gizmo sürüklemesi düğümü açıklamaya dokunmadan taşır. |
| `setLocalAnimationTime(id, s)` | Bağlı bir zaman çizelgesinin zamanı, açıklama farkı olmadan. |
| `project` / `projectAuthoring` | Kaplamalar için noktaları viewport piksellerine çevirir. |
| `allowFiles` | `Play Animation File`'ın bir dosya okuyup okuyamayacağı (editör panelleri); bir oyun `OnAssetLoadFailed` bildirir. |
| `dispose()` | Düğümleri, gökyüzünü, ızgarayı ve oluşturduğu sahne, görünüm ve kamerayı yok eder. |

### `class LuminaViewportController` (`viewport_controller.dart`)

Bir Viewport'u sürer: `sync(scene)` yalnızca açıklamanın farkını uygular, `frame(dt)` bir `LuminaViewportFrameClock` ile bu karenin çizilip çizilmeyeceğine karar verir ve girdi olaylara dönüşür: `orbitDrag`, `panDrag`, `zoom` sonra `endCameraGesture` (bırakınca tek bir `OnCameraChanged (yaw, pitch, distance)`; açıklama kamerayı alır, böylece `Viewport Get Camera` onu okur), `tap` (`OnPicked (node_id, bone, hit_location)`), `frameSelection` (F), `beginGizmoDrag` / `updateGizmoDrag` (düğüm hemen kayar; `OnGizmoPreview` en fazla 1/30 sn'de bir) / `commitGizmoDrag` (tek bir `OnGizmoCommit (node_id, bone, transform)`; açıklama dönüşümü alır) / `cancelGizmoDrag` (Escape: `OnGizmoCancel`, düğüm geri döner). İskeletler, eklem artıları, hayalet iskeletler, işaretçiler ve `extraSegments` (widget'ın gizmosu) önizlemenin kendi sahnesinde Filament çizgileri olarak çizilir (`LuminaViewportOverlayLines`: dönüşümlerle yerleştirilen birim çizgi parçalarından bir havuz; derinlik testi ve yazımı yok, her mesh'in üstünde çizilsin diye 7. çizim kanalında; `overlayLineCount`) ve her `advance`'ten sonra güncellenir; iki sunum yolunda da fazladan görünüm yoktur ve Flutter yalnızca etiketleri boyar. `LuminaSkeletonOverlay.bones(joints, visible, selected)`, hem çizgilerin hem lumina_widgets'taki `LuminaSkeletonPainter`'ın çizdiği kemik listesidir.

### `class LuminaViewportBudget` (`viewport_budget.dart`)

`renderSize(w, h, devicePixelRatio, renderScale)`: yerleşim × DPR × çizim ölçeği (0,25–1), uzun kenar 2048 piksele kırpılır. `acquire(owner)` / `release(owner)`: bir oyunda en fazla 4 çizen Viewport (`LuminaViewportScope.game`), editörde 8, web'de 2; `maxViewports` (1–8) bunu belirler; `LuminaViewportBudget.projectMaxViewports` projenin `umg.maxViewports`'u (Project Settings > UI > Max Viewports, `ProjectUiSettings.maxViewports`): üretilen oyunun `main()`'i, Play ve editör (proje açılınca ya da ayarları kaydedilince) onu atar ve kendi sınırı olmayan her kapsam onu kullanır (web en fazla 2'de kalır); `LuminaViewportBudget.shared` bir web derlemesinde web kapsamını alır; reddedilen Viewport bir yer tutucu gösterir ve ret bir kez günlüğe yazılır. `counts(...)`: Collapsed, Hidden, ekran dışı, sıfır boyutlu ya da etkin olmayan sekmedeki bir Viewport sayılmaz. `LuminaViewportFrameClock`: boşta bir Viewport (animasyon yok, otomatik dönüş yok, 1 sn girdi yok) açıklama, boyut ya da girdi değişene kadar hiçbir şey çizmez; geri kalanı `maxFps` sınırlar.

### `abstract final class LuminaViewportNodes` (`viewport_nodes.dart`)

`Widget|Viewport` Blueprint düğümleri ([function library](blueprint/function-library.md)); VM ve üretilen kod için bir kez yazılmıştır. `LuminaViewportTransforms` açıklama dönüşümlerini `LuminaAxes` / `LuminaUnits` üzerinden çevirir ((0, 0, 100) cm Z-yukarı konum (0, 1, 0) m Y-yukarıdır).

## Oyun ve editör kayıt defterleri

`LuminaUserWidgets` iki `LuminaUserWidgetRegistry` örneği tutar: `game` (üretilen `widget_registry.g.dart` ile
Play-In-Editor'ın doldurduğu; `LuminaUserWidgets.register` / `clear` / `has` / `attach` onun üzerinde çalışır ve Play
her başlangıçta onu temizler) ve `editor` (editörün yerleşik editör panelleri). `of`, `fire`, `addedToViewport` ve
`removedFromParent` betiği hangi kayıt defteri bağladıysa bulur; oyun kayıt defterini temizlemek yerleşik bir panele
asla dokunmaz.

---

[Önceki: Oyun çatısı (game framework)](game.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Kayıt (save game)](save.md)
