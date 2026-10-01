[English](../../../en/lumina_ui/sub-editors/sequencer.md)

# Sequencer

Sinematikler için Sequencer: timeline, track ağacı ve eğri editörü, sequencer view model'i, track'leri örnekleyen evaluator ve offscreen bir frame kaynağı üzerinden film render'ı. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/sub_editors/views/sequencer/curve_editor_widget.dart`](#libuifeaturessub_editorsviewssequencercurve_editor_widgetdart)
- [`lib/ui/features/sub_editors/views/sequencer/level_viewport.dart`](#libuifeaturessub_editorsviewssequencerlevel_viewportdart)
- [`lib/ui/features/sub_editors/models/sequencer_viewport_camera.dart`](#libuifeaturessub_editorsmodelssequencer_viewport_cameradart)
- [`lib/ui/features/sub_editors/views/sequencer/render_dialog.dart`](#libuifeaturessub_editorsviewssequencerrender_dialogdart)
- [`lib/ui/features/sub_editors/views/sequencer/sequencer_sub_editor.dart`](#libuifeaturessub_editorsviewssequencersequencer_sub_editordart)
- [`lib/ui/features/sub_editors/views/sequencer/timeline_widget.dart`](#libuifeaturessub_editorsviewssequencertimeline_widgetdart)
- [`lib/ui/features/sub_editors/views/sequencer/track_tree_widget.dart`](#libuifeaturessub_editorsviewssequencertrack_tree_widgetdart)
- [`lib/ui/features/sub_editors/view_models/sequencer_view_model.dart`](#libuifeaturessub_editorsview_modelssequencer_view_modeldart)
- [`lib/ui/features/sub_editors/services/sequencer_evaluator.dart`](#libuifeaturessub_editorsservicessequencer_evaluatordart)
- [`lib/ui/features/sub_editors/services/sequencer_movie_render_service.dart`](#libuifeaturessub_editorsservicessequencer_movie_render_servicedart)
- [`lib/ui/features/sub_editors/services/sequencer_offscreen_frame_source.dart`](#libuifeaturessub_editorsservicessequencer_offscreen_frame_sourcedart)

## `lib/ui/features/sub_editors/views/sequencer/curve_editor_widget.dart`

### `class CurveView`

The visible window of the curve canvas in data space (frames × values).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `minFrame` | `double minFrame` | `minFrame` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxFrame` | `double maxFrame` | `maxFrame` alanını (field/property) ve ilişkili veriyi saklar. |
| `minValue` | `double minValue` | `minValue` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxValue` | `double maxValue` | `maxValue` alanını (field/property) ve ilişkili veriyi saklar. |
| `frameSpan` | `double get frameSpan` | `frameSpan` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `valueSpan` | `double get valueSpan` | `valueSpan` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `frameToX` | `double frameToX(double frame, Size size)` | `frameToX` işlemini gerçekleştirir. |
| `valueToY` | `double valueToY(double value, Size size)` | `valueToY` işlemini gerçekleştirir. |
| `xToFrame` | `double xToFrame(double x, Size size)` | `xToFrame` işlemini gerçekleştirir. |
| `yToValue` | `double yToValue(double y, Size size)` | `yToValue` işlemini gerçekleştirir. |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class CurveChannelRef`

A channel shown on the canvas together with the track that owns it.

**Yapıcı Metotlar (Constructors):**
- `CurveChannelRef(this.track, this.channel)`: `CurveChannelRef(this.track, this.channel)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `track` | `SequencerTrack track` | `track` alanını (field/property) ve ilişkili veriyi saklar. |
| `channel` | `SequencerChannel channel` | `channel` alanını (field/property) ve ilişkili veriyi saklar. |
| `id` | `String get id` | `id` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class SequencerCurvePainter`

`SequencerCurvePainter`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `channels` | `List<CurveChannelRef> channels` | `channels` alanını (field/property) ve ilişkili veriyi saklar. |
| `view` | `CurveView view` | `view` alanını (field/property) ve ilişkili veriyi saklar. |
| `selectedKeys` | `Set<SequencerKeyRef> selectedKeys` | `selectedKeys` alanını (field/property) ve ilişkili veriyi saklar. |
| `primaryKey` | `SequencerKeyRef? primaryKey` | `primaryKey` alanını (field/property) ve ilişkili veriyi saklar. |
| `playheadFrame` | `double playheadFrame` | `playheadFrame` alanını (field/property) ve ilişkili veriyi saklar. |
| `boxSelect` | `Rect? boxSelect` | `boxSelect` alanını (field/property) ve ilişkili veriyi saklar. |
| `lengthFrames` | `int lengthFrames` | `lengthFrames` alanını (field/property) ve ilişkili veriyi saklar. |
| `channelColor` | `static Color channelColor(String name)` | X → red, Y → green, Z → blue; other channels cycle a distinct palette. |
| `keyScreenPosition` | `static Offset keyScreenPosition(SequencerKey key, CurveView view, Size s...` | `keyScreenPosition` özelliğine yeni değer atayan setter değiştiricisi. |
| `Offset` | `Offset(view.frameToX(key.frame.toDouble(), size), view.valueToY(key.valu...` | `Offset` işlemini gerçekleştirir. |
| `slopeFromHandle` | `static double slopeFromHandle(Offset keyPos, Offset handlePos, int direc...` | Converts a dragged handle position back into a tangent slope (value units per frame); [direction] is +1 for the out handle, -1 for in. |
| `niceStep` | `static double niceStep(double span, int targetDivisions)` | `niceStep` işlemini gerçekleştirir. |
| `paint` | `void paint(Canvas canvas, Size size)` | `paint` işlemini gerçekleştirir. |
| `shouldRepaint` | `bool shouldRepaint(covariant SequencerCurvePainter oldDelegate)` | `shouldRepaint` işlemini gerçekleştirir. |

### `class SequencerCurveEditorWidget`

The Curves tab: every keyed channel as a coloured curve with draggable keys and bezier tangent handles, box-select, pan/zoom/fit, per-channel visibility and a key context menu.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `SequencerViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `initialView` | `CurveView? initialView` | `initialView` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<SequencerCurveEditorWidget> createState() => SequencerCurveEditorW...` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `enum _DragMode`

`_DragMode`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class SequencerCurveEditorWidgetState`

`SequencerCurveEditorWidgetState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `SequencerViewModel get vm` | `vm` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `view` | `CurveView get view` | `view` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `isChannelVisible` | `bool isChannelVisible(String trackId, String channelName) => !_hiddenCha...` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `setChannelVisible` | `void setChannelVisible(String trackId, String channelName, bool visible)` | `ChannelVisible` parametresini günceller ve sisteme uygular. |
| `fitAll` | `void fitAll()` | `fitAll` işlemini gerçekleştirir. |
| `panBy` | `void panBy(double dFrames, double dValues)` | `panBy` işlemini gerçekleştirir. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/views/sequencer/level_viewport.dart`

### `class SequencerLevelViewport`

Sequencer'ın 3D Viewport sekmesi: sekansın sürdüğü level, level viewport'unun kendi Filament sahnesinden (`EditorViewModel.levelScene`) ikinci bir view ile çizilir; Sequencer'ın level aktörlerine yazdığı her scrub ve oynatma karesi burada aynı karede görünür. Kendi editör kamerasından bakar (level viewport kamerasının olduğu yerden başlar: sürükleyerek yörünge, orta tuş veya Shift+sürükleme ile kaydırma, tekerlekle dolly, sağ tuş + W/A/S/D/Q/E ile uçuş, F veya çerçeve düğmesiyle animasyonlu aktörleri kadraja alma) ya da kamera menüsünden kilitlenince sekansa bağlı bir kamera aktöründen (konumu, +Y ileri yönü ve kamera bileşeninin görüş açısı, bileşen yoksa 60°) 16:9 film kapısı içinde, `PILOTING <ad>` rozetiyle bakar. Pozlama level viewport kamerasını izler. Kilitli bir kameradan bakarken editör yardımcıları (grid, gizmo, seçim kutuları, ışık çizgileri) çizilmez (`EditorViewLayers.cameraView`); editör kamerası onları gösterir. View bir `LevelSceneView`'dır; level viewport'unun kamera önizlemesi de aynı ikinci-view çekirdeğini kullanır. Level editörü olmadan açılan bir sekans bunun yerine bir uyarı gösterir.

| Üye | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `editorViewModel` | `EditorViewModel editorViewModel` | Sahnesini ve aktörlerini view'ın çizdiği level editörü. |
| `sequencer` | `SequencerViewModel sequencer` | Sekans; track'leri view'ın kilitlenebileceği kamera aktörlerini belirtir. |
| `filmAspect` | `static const double filmAspect = 16 / 9` | Kilitli kameranın kadrajladığı film kapısı. |

### `class SequencerLevelViewportState`

| Üye | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `drawsLevelScene` | `bool get drawsLevelScene` | View'ın şu anda level viewport'unun sahnesini çizip çizmediği (level viewport açılmadan önce ve kapandıktan sonra false; view o zaman kendi boş sahnesini çizer). |
| `cameraCandidates` | `List<EditorActorNode> get cameraCandidates` | Sekansın canlandırdığı level kamera aktörleri: kamera menüsünün sunduğu seçenekler. |
| `lockedCameraId` | `String? get lockedCameraId` | View'ın içinden baktığı kamera aktörü; editör kamerası için null. |
| `lockToCamera` | `void lockToCamera(String? actorId)` | `actorId` içinden bakar; null ise yeniden editör kamerasından. |
| `focusAnimatedActors` | `void focusAnimatedActors()` | Kamera olmayan tüm bağlı aktörleri kadraja alır (sekans hiçbirini bağlamıyorsa tüm leveli). |
| `editorCamera` | `SequencerViewportCamera get editorCamera` | Editör kamerasının gezinme durumu. |
| `viewForTest` / `cameraForTest` | `FilamentView?` / `FilamentCamera?` | Testler için Filament view'ı ve kamerası. |

## `lib/ui/features/sub_editors/models/sequencer_viewport_camera.dart`

### `class SequencerViewPose`

Level'e bakan bir view'ın bakış noktası: çalışma zamanı eksenlerinde (Y yukarı, santimetre) `eye`, `forward`, `up` ve dikey `fovDegrees`.

### `class SequencerViewportCamera`

Sequencer viewport'unun editör kamerası: level viewport'unun yörünge kamerası (saklanan Z-yukarı bir hedef etrafında yaw, pitch ve mesafe), kendi pozuyla; Sequencer view'ında gezinmek level viewport kamerasını yerinde bırakır.

| Üye | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `fromEditor` | `factory SequencerViewportCamera.fromEditor(EditorViewModel vm)` | Level viewport kamerasının olduğu yerden başlar. |
| `editorPose` | `SequencerViewPose editorPose({double fovDegrees = 45.0})` | Editör kamerasının baktığı poz. |
| `orbit` / `pan` / `dolly` | `void orbit(double dx, double dy)` … | Hedef etrafında döner, view düzleminde kayar, hedefe yaklaşır veya uzaklaşır. |
| `fly` | `void fly({required int forward, required int right, required int up, required double dt, double speed = 400.0})` | Bakış yönü, yatay sağ ve dünya yukarısı boyunca uçar. |
| `focus` | `void focus({required List<double> center, required double radius})` | Bir küreyi (saklanan eksenler, santimetre) kadraja alır. |
| `lockedPose` | `static SequencerViewPose lockedPose(EditorActorNode camera)` | Kamera kilidinin baktığı poz: aktörün konumundan ileri yönü boyunca (saklanan +Y, rotasyonuyla döndürülmüş), kamera bileşeninin `fieldOfView` / `fov` değeriyle. |
| `cameraFovDegrees` | `static double cameraFovDegrees(EditorActorNode camera)` | Kamera aktörünün dikey görüş açısı; kamera bileşeni yoksa 60° (çalışma zamanı kamera bileşeninin varsayılanı). |
| `isCamera` | `static bool isCamera(EditorActorNode actor)` | View'ın aktörün içinden bakıp bakamayacağı. |

## `lib/ui/features/sub_editors/views/sequencer/render_dialog.dart`

### `class _ResolutionPreset`

One entry of the resolution `Select`.

**Yapıcı Metotlar (Constructors):**
- `_ResolutionPreset(this.label, this.width, this.height)`: `_ResolutionPreset(this.label, this.width, this.height)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `label` | `String label` | `label` alanını (field/property) ve ilişkili veriyi saklar. |
| `width` | `int width` | `width` alanını (field/property) ve ilişkili veriyi saklar. |
| `height` | `int height` | `height` alanını (field/property) ve ilişkili veriyi saklar. |

### `class SequencerRenderDialog`

The Movie Render Queue dialog: configure an offscreen PNG-sequence export, then watch it run with a live progress bar, ETA and a working Cancel.  Honest scope — the only format this stack can write is a numbered PNG sequence (see [MovieRenderFormat]); no MP4/EXR options are offered because no encoder for them exists here.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `sequence` | `SequencerData sequence` | `sequence` alanını (field/property) ve ilişkili veriyi saklar. |
| `sequenceName` | `String sequenceName` | `sequenceName` alanını (field/property) ve ilişkili veriyi saklar. |
| `projectDirPath` | `String projectDirPath` | `projectDirPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `defaultStartFrame` | `int defaultStartFrame` | `defaultStartFrame` alanını (field/property) ve ilişkili veriyi saklar. |
| `defaultEndFrame` | `int defaultEndFrame` | `defaultEndFrame` alanını (field/property) ve ilişkili veriyi saklar. |
| `engineAvailable` | `bool engineAvailable` | False when the native offscreen render capability is missing; the Start button is then disabled with the missing symbol named. |
| `now` | `DateTime? now` | Injected clock so the default output folder name is deterministic in tests. |
| `viewModel` | `SequencerViewModel? viewModel` | Live render state. When null the dialog is a pure form (widget tests). |
| `onCancelRender` | `VoidCallback? onCancelRender` | `onCancelRender` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback? onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<SequencerRenderDialog> createState() => _SequencerRenderDialogState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _SequencerRenderDialogState`

`_SequencerRenderDialogState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |
| `openFolder` | `static Future<void> openFolder(String path)` | Reveals the finished frame folder in the platform file manager. |

## `lib/ui/features/sub_editors/views/sequencer/sequencer_sub_editor.dart`

### `class SequencerSubEditor`

`SequencerSubEditor`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | `assetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetPath` | `String? assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `asset` | `RealAssetInfo? asset` | `asset` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `SequencerViewModel? viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `levelActors` | `List<EditorActorNode>? levelActors` | `levelActors` alanını (field/property) ve ilişkili veriyi saklar. |
| `editorViewModel` | `EditorViewModel? editorViewModel` | The live level the cinematic drives. Playback and scrubbing write the evaluated samples onto its actors and notify it so the outliner, details and Filament viewport update the same frame; `stop`/close restore them. |
| `onClose` | `VoidCallback? onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `onBind` | `SubEditorBindCallback? onBind` | `onBind` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<SequencerSubEditor> createState() => _SequencerSubEditorState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _SequencerSubEditorState`

`_SequencerSubEditorState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/views/sequencer/timeline_widget.dart`

### `class SequencerTimelineWidget`

`SequencerTimelineWidget`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `SequencerViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<SequencerTimelineWidget> createState() => _SequencerTimelineWidget...` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _SequencerTimelineWidgetState`

`_SequencerTimelineWidgetState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `enum SequencerRangeBracket`

Which playback-range bracket on the ruler a drag targets.

### `class SequencerTimelinePainter`

`SequencerTimelinePainter`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `tracks` | `List<SequencerTrack> tracks` | `tracks` alanını (field/property) ve ilişkili veriyi saklar. |
| `lengthFrames` | `int lengthFrames` | `lengthFrames` alanını (field/property) ve ilişkili veriyi saklar. |
| `playheadFrame` | `int playheadFrame` | `playheadFrame` alanını (field/property) ve ilişkili veriyi saklar. |
| `fps` | `int fps` | `fps` alanını (field/property) ve ilişkili veriyi saklar. |
| `rangeStart` | `int? rangeStart` | Playback range rendered as brackets on the ruler; frames outside it are shaded. Null keeps the whole sequence. |
| `rangeEnd` | `int? rangeEnd` | `rangeEnd` alanını (field/property) ve ilişkili veriyi saklar. |
| `paint` | `void paint(Canvas canvas, Size size)` | `paint` işlemini gerçekleştirir. |
| `shouldRepaint` | `bool shouldRepaint(covariant SequencerTimelinePainter oldDelegate)` | `shouldRepaint` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/views/sequencer/track_tree_widget.dart`

### `class SequencerTrackTreeWidget`

`SequencerTrackTreeWidget`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `SequencerViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `levelActors` | `List<EditorActorNode>? levelActors` | `levelActors` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<SequencerTrackTreeWidget> createState() => _SequencerTrackTreeWidg...` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _SequencerTrackTreeWidgetState`

`_SequencerTrackTreeWidgetState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/view_models/sequencer_view_model.dart`

### `enum SequencerTimeFormat`

How the transport bar's current-time readout is formatted.

### `class SequencerViewModel`

`SequencerViewModel`: İlgili arayüz modülünün durumunu (state) yöneten, kullanıcı aksiyonlarını yürüten ve görünümü güncelleyen ChangeNotifier ViewModel sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `initialAsset` | `LuminaAsset? initialAsset` | `initialAsset` alanını (field/property) ve ilişkili veriyi saklar. |
| `transactions` | `TransactionManager transactions` | `transactions` alanını (field/property) ve ilişkili veriyi saklar. |
| `isLoading` | `bool get isLoading` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `hasError` | `bool get hasError` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isDirty` | `bool get isDirty` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `asset` | `LuminaAsset? get asset` | `asset` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `data` | `SequencerData get data` | `data` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `fps` | `int get fps` | `fps` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `lengthFrames` | `int get lengthFrames` | `lengthFrames` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `playheadFrame` | `int get playheadFrame` | `playheadFrame` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `playheadFrame` | `playheadFrame(int frame) => scrubToFrame(frame)` | `playheadFrame` işlemini gerçekleştirir. |
| `playheadPosition` | `double get playheadPosition` | `playheadPosition` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `tracks` | `List<SequencerTrack> get tracks` | `tracks` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `selectedTrackId` | `String? get selectedTrackId` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectedKey` | `SequencerKeyRef? get selectedKey` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectedKeys` | `Set<SequencerKeyRef> get selectedKeys` | İlgili aktör veya varlığı seçili duruma getirir. |
| `isPlaying` | `bool get isPlaying` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isLooping` | `bool get isLooping` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `rangeStart` | `int get rangeStart` | `rangeStart` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `rangeEnd` | `int get rangeEnd` | `rangeEnd` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `timeFormat` | `SequencerTimeFormat get timeFormat` | `timeFormat` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `hasLevelBinding` | `bool get hasLevelBinding` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isPreviewingLevel` | `bool get isPreviewingLevel` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `timeReadout` | `String get timeReadout` | Current-time readout in the selected [timeFormat]. |
| `canUndo` | `bool get canUndo` | `canUndo` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `canRedo` | `bool get canRedo` | `canRedo` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `undo` | `void undo() => transactions.undo()` | Yapılan son işlemi geri alır. |
| `redo` | `void redo() => transactions.redo()` | Geri alınan son işlemi yineler. |
| `fileBasename` | `String get fileBasename` | `fileBasename` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `timecodeStr` | `String get timecodeStr` | `timecodeStr` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `load` | `Future<void> load()` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |
| `scrubToFrame` | `void scrubToFrame(int frame)` | Moves the playhead and writes the sampled pose onto the live level immediately — no play required. |
| `setFps` | `void setFps(int newFps)` | `Fps` parametresini günceller ve sisteme uygular. |
| `setLengthFrames` | `void setLengthFrames(int len)` | `LengthFrames` parametresini günceller ve sisteme uygular. |
| `selectTrack` | `void selectTrack(String? trackId)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectKey` | `void selectKey(String trackId, String channelName, int keyIndex)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectKeys` | `void selectKeys(Iterable<SequencerKeyRef> keys)` | Box-select: replaces the selection with [keys]; the first becomes the primary [selectedKey] whose tangent handles are shown. |
| `isKeySelected` | `bool isKeySelected(String trackId, String channelName, int keyIndex)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `clearKeySelection` | `void clearKeySelection()` | Koleksiyon veya tampon içeriğini tamamen temizler. |
| `deleteSelectedKeys` | `void deleteSelectedKeys()` | Belirtilen `SelectedKeys` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `findTrack` | `SequencerTrack? findTrack(String trackId)` | Belirtilen arama kriterlerine uyan nesneleri veya aktörleri bulup listeler. |
| `findChannel` | `SequencerChannel? findChannel(String trackId, String channelName)` | Belirtilen arama kriterlerine uyan nesneleri veya aktörleri bulup listeler. |
| `deleteTrack` | `void deleteTrack(String trackId)` | Belirtilen `Track` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `renameTrack` | `void renameTrack(String trackId, String newActorName)` | `renameTrack` işlemini gerçekleştirir. |
| `moveKey` | `void moveKey(String trackId, String channelName, int keyIndex, int newFr...` | `moveKey` işlemini gerçekleştirir. |
| `deleteKey` | `void deleteKey(String trackId, String channelName, int keyIndex)` | Belirtilen `Key` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `setKeyInterpolation` | `void setKeyInterpolation(String trackId, String channelName, int keyInde...` | `KeyInterpolation` parametresini günceller ve sisteme uygular. |
| `isActorMissing` | `bool isActorMissing(String actorId, Set<String> levelActorIds)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `rebindActor` | `void rebindActor(String trackId, String newActorId, String newActorName)` | `rebindActor` işlemini gerçekleştirir. |
| `isTangentBroken` | `bool isTangentBroken(String trackId, String channelName, int keyIndex)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `setTangentBroken` | `void setTangentBroken(String trackId, String channelName, int keyIndex, ...` | `TangentBroken` parametresini günceller ve sisteme uygular. |
| `beginCurveDrag` | `void beginCurveDrag(String label, String coalesceKey)` | Opens a coalesced transaction so a whole drag lands as one undo step. |
| `endCurveDrag` | `void endCurveDrag()` | `endCurveDrag` işlemini gerçekleştirir. |
| `flattenTangents` | `void flattenTangents(String trackId, String channelName, int keyIndex)` | `flattenTangents` işlemini gerçekleştirir. |
| `setKeyInterpolationCubicAuto` | `void setKeyInterpolationCubicAuto(String trackId, String channelName, in...` | `Cubic (Auto)`: cubic interpolation with Catmull-Rom tangents computed from the neighbours, in == out (unified handles). |
| `setKeyInterpolationCubicBroken` | `void setKeyInterpolationCubicBroken(String trackId, String channelName, ...` | `Cubic (Broken)`: cubic interpolation whose two handles move independently. |
| `restoreLevel` | `void restoreLevel()` | Puts every touched actor property back to its pre-preview value and forgets the snapshot. A cinematic preview never dirties the level: the writes bypass the transaction/dirty path entirely. |
| `attachTicker` | `void attachTicker(TickerProvider vsync)` | Drives playback from the widget's frame clock. Without a ticker (unit tests) advance the clock manually with [advanceClock]. |
| `detachTicker` | `void detachTicker()` | Drops the widget-owned ticker (the widget is going away while the view model may live on, e.g. when injected by a test or a tab session). |
| `play` | `void play()` | `play` işlemini gerçekleştirir. |
| `pause` | `void pause()` | `pause` işlemini gerçekleştirir. |
| `togglePlay` | `void togglePlay() => _isPlaying ? pause() : play()` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `stop` | `void stop()` | Stops playback, returns the playhead to the range start and restores the actors' pre-preview state. |
| `advanceClock` | `void advanceClock(double dt)` | Advances playback by [dt] seconds at the sequence fps, honouring the playback range and loop mode. Fractional frames accumulate; only the displayed frame is rounded. |
| `goToFirstFrame` | `void goToFirstFrame() => scrubToFrame(_rangeStart)` | `goToFirstFrame` işlemini gerçekleştirir. |
| `nextKeyframe` | `void nextKeyframe()` | `nextKeyframe` işlemini gerçekleştirir. |
| `previousKeyframe` | `void previousKeyframe()` | `previousKeyframe` işlemini gerçekleştirir. |
| `setLooping` | `void setLooping(bool loop)` | `Looping` parametresini günceller ve sisteme uygular. |
| `setPlaybackRange` | `void setPlaybackRange(int start, int end)` | `PlaybackRange` parametresini günceller ve sisteme uygular. |
| `setRangeStart` | `void setRangeStart(int start) => setPlaybackRange(start, rangeEnd)` | `RangeStart` parametresini günceller ve sisteme uygular. |
| `setRangeEnd` | `void setRangeEnd(int end) => setPlaybackRange(_rangeStart, end)` | `RangeEnd` parametresini günceller ve sisteme uygular. |
| `setTimeFormat` | `void setTimeFormat(SequencerTimeFormat format)` | `TimeFormat` parametresini günceller ve sisteme uygular. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `projectDirPath` | `String get projectDirPath` | Root of the open project. Explicit when the shell supplies it, otherwise derived from the asset path by walking up past `contents/`. |
| `projectDirPath` | `projectDirPath(String value)` | `projectDirPath` işlemini gerçekleştirir. |
| `isRendering` | `bool get isRendering` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `renderRequiresSave` | `bool get renderRequiresSave` | True when the last [startRender] was refused because the sequence has unsaved edits — the dialog turns this into a "Save & Render" prompt. |
| `renderProgress` | `MovieRenderProgress? get renderProgress` | `renderProgress` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `renderMessage` | `String? get renderMessage` | `renderMessage` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `renderError` | `String? get renderError` | `renderError` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `lastRenderDir` | `Directory? get lastRenderDir` | `lastRenderDir` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `defaultRenderOutputName` | `String defaultRenderOutputName([DateTime? now])` | Default output folder name for the render dialog. |
| `cancelRender` | `void cancelRender()` | Cooperative cancel — the loop stops between frames, never mid-readback. |
| `save` | `Future<bool> save()` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |

### `class _ChannelSnapshot`

One animated actor property: knows how to read/write it on an [EditorActorNode] and keeps the pre-preview value for [restore]. The snapshot is per channel, never a whole-actor copy.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `actorId` | `String actorId` | `actorId` alanını (field/property) ve ilişkili veriyi saklar. |
| `id` | `String id` | `id` alanını (field/property) ve ilişkili veriyi saklar. |
| `capture` | `void capture(EditorActorNode actor) => _original = _read(actor)` | `capture` işlemini gerçekleştirir. |
| `write` | `void write(EditorActorNode actor, double value) => _write(actor, value)` | `write` işlemini gerçekleştirir. |
| `restore` | `void restore(EditorActorNode actor) => _restore(actor, _original)` | `restore` işlemini gerçekleştirir. |
| `resolve` | `static _ChannelSnapshot? resolve(EditorActorNode actor, TrackSample samp...` | `resolve` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/services/sequencer_evaluator.dart`

### `class TrackSample`

The sampled state of one [SequencerTrack] at a given frame.  [values] holds one entry per channel that has at least one key; channels without keys are omitted so the caller never overwrites an actor property the cinematic does not actually animate.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `trackId` | `String trackId` | `trackId` alanını (field/property) ve ilişkili veriyi saklar. |
| `actorId` | `String actorId` | `actorId` alanını (field/property) ve ilişkili veriyi saklar. |
| `kind` | `SequencerTrackKind kind` | `kind` alanını (field/property) ve ilişkili veriyi saklar. |
| `propertyName` | `String? propertyName` | `propertyName` alanını (field/property) ve ilişkili veriyi saklar. |
| `values` | `Map<String, double> values` | `values` alanını (field/property) ve ilişkili veriyi saklar. |

### `class SequencerEvaluator`

Pure-Dart sampler for [SequencerData].  Deliberately free of Flutter imports so the generated game runtime can reuse it later to play cinematics in shipped games.  Interpolation semantics: * the **left** key of a segment decides how the segment is interpolated; * `constant` holds the left value until the right key's frame; * `linear` lerps between the two key values; * `cubic` evaluates a 1-D cubic Hermite spline built from the key values and their tangents (`outTangent` of the left key, `inTangent` of the right key, in value units per frame), computed with de Casteljau on the equivalent bezier whose time axis is linear in the frame — so the curve is always single-valued over time; * before the first key the first value holds, after the last key the last value holds; a single key is constant everywhere; * visibility tracks always sample as a step, whatever the key says.

**Yapıcı Metotlar (Constructors):**
- `SequencerEvaluator()`: `SequencerEvaluator()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `evaluate` | `List<TrackSample> evaluate(SequencerData data, double frame)` | `evaluate` işlemini gerçekleştirir. |
| `evaluateChannel` | `static double? evaluateChannel(SequencerChannel channel, double frame)` | Samples [channel] at [frame]; `null` when the channel has no keys. |
| `evaluateStep` | `static double? evaluateStep(SequencerChannel channel, double frame)` | Step sampling: holds the value of the latest key at or before [frame]. |
| `evaluateSegment` | `static double evaluateSegment(SequencerKey a, SequencerKey b, double frame)` | Evaluates the segment `[a, b]` at [frame] using [a]'s interpolation. |
| `cubicBezier1D` | `static double cubicBezier1D(double p0, double p1, double p2, double p3, ...` | De Casteljau evaluation of a 1-D cubic bezier at parameter [t] in [0,1]. |
| `autoTangent` | `static double autoTangent(List<SequencerKey> keys, int index)` | Catmull-Rom style automatic tangent for `keys[index]`: the slope between its two neighbours (value units per frame). End keys get a flat tangent. |
| `mergedKeyFrames` | `static List<int> mergedKeyFrames(SequencerData data)` | Sorted, de-duplicated frames of every key on every channel of [data]. |

## `lib/ui/features/sub_editors/services/sequencer_movie_render_service.dart`

### `enum MovieRenderFormat`

The one output format this stack can honestly produce.  `4K MP4` and `16-bit OpenEXR` are not offered: neither has a pure-Dart encoder here and shelling out to ffmpeg would be an undeclared dependency, so the queue writes a numbered PNG sequence. A future encoder consumes the very same per-frame RGBA stream.

**Yapıcı Metotlar (Constructors):**
- `MovieRenderFormat(this.id, this.label)`: `MovieRenderFormat(this.id, this.label)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `pngSequence` | `pngSequence('png_sequence', 'PNG Sequence')` | `pngSequence` işlemini gerçekleştirir. |
| `id` | `String id` | `id` alanını (field/property) ve ilişkili veriyi saklar. |
| `label` | `String label` | `label` alanını (field/property) ve ilişkili veriyi saklar. |

### `enum MovieRenderPhase`

Lifecycle phase carried by every [MovieRenderProgress] event.

### `class MovieRenderCancellationToken`

Cooperative cancellation: the render loop checks it *between* frames so a readback is never torn down half-way and no partial PNG reaches disk.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isCancelled` | `bool get isCancelled` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `cancel` | `void cancel()` | `cancel` işlemini gerçekleştirir. |

### `class MovieRenderJob`

Everything one offscreen render run needs.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `sequence` | `SequencerData sequence` | `sequence` alanını (field/property) ve ilişkili veriyi saklar. |
| `sequenceName` | `String sequenceName` | `sequenceName` alanını (field/property) ve ilişkili veriyi saklar. |
| `width` | `int width` | `width` alanını (field/property) ve ilişkili veriyi saklar. |
| `height` | `int height` | `height` alanını (field/property) ve ilişkili veriyi saklar. |
| `fps` | `int fps` | Sampling rate of the render. Sequence keys stay authored in sequence frames; see [sequenceFrameFor]. |
| `startFrame` | `int startFrame` | Inclusive render-frame range. |
| `endFrame` | `int endFrame` | `endFrame` alanını (field/property) ve ilişkili veriyi saklar. |
| `warmupFrames` | `int warmupFrames` | Frames evaluated and drawn but never written — used to let streaming/temporal effects settle before frame 0. |
| `outputDir` | `Directory outputDir` | `outputDir` alanını (field/property) ve ilişkili veriyi saklar. |
| `format` | `MovieRenderFormat format` | `format` alanını (field/property) ve ilişkili veriyi saklar. |
| `totalFrames` | `int get totalFrames` | `totalFrames` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `sequenceFrameFor` | `double sequenceFrameFor(int renderFrame)` | Maps a render frame onto the (fractional) sequence frame to evaluate. Rounding happens nowhere: `renderFrame * (seqFps / renderFps)`. |
| `resolveOutputDir` | `static Directory resolveOutputDir(String projectDirPath, String outputName)` | `<project>/saved/movie_renders/<name>/` — project data, not an asset, so no `.lmas` wrapper and safe to git-ignore. |
| `Directory` | `Directory('$projectDirPath/saved/movie_renders/$outputName')` | `Directory` işlemini gerçekleştirir. |
| `defaultOutputName` | `static String defaultOutputName(String sequenceName, [DateTime? now])` | `defaultOutputName` işlemini gerçekleştirir. |
| `toManifestJson` | `Map<String, dynamic> toManifestJson()` | `toManifestJson` işlemini gerçekleştirir. |

### `class MovieRenderFrameRequest`

One request handed to a [MovieFrameSource].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `outputIndex` | `int outputIndex` | Zero-based index of the file this frame becomes; `-1` for warmup frames. |
| `renderFrame` | `int renderFrame` | The render-space frame (`startFrame + i`). |
| `sequenceFrame` | `double sequenceFrame` | The fractional sequence frame the samples were evaluated at. |
| `samples` | `List<TrackSample> samples` | `samples` alanını (field/property) ve ilişkili veriyi saklar. |
| `isWarmup` | `bool isWarmup` | `isWarmup` alanını (field/property) ve ilişkili veriyi saklar. |
| `width` | `int width` | `width` alanını (field/property) ve ilişkili veriyi saklar. |
| `height` | `int height` | `height` alanını (field/property) ve ilişkili veriyi saklar. |

### `class MovieFrameSource`

Produces one RGBA8 frame buffer per request.  The GPU implementation ([SequencerOffscreenFrameSource]) owns the offscreen view + RenderTarget; tests inject a CPU fake so the loop, the numbering and the IO are provable without a GPU.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `rowsAreBottomUp` | `bool get rowsAreBottomUp` | True when row 0 of the returned buffer is the *bottom* of the image, as a GL-backend `readPixels` hands it back. The service flips before encoding so exports are never upside down. |
| `prepare` | `Future<void> prepare(MovieRenderJob job)` | `prepare` işlemini gerçekleştirir. |
| `renderFrame` | `Future<Uint8List> renderFrame(MovieRenderFrameRequest request)` | `renderFrame` işlemini gerçekleştirir. |
| `dispose` | `Future<void> dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |

### `class MovieRenderProgress`

A progress tick. Carries files and counters, never pixel buffers — a 4K readback is ~33 MB and must not travel through the stream.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `phase` | `MovieRenderPhase phase` | `phase` alanını (field/property) ve ilişkili veriyi saklar. |
| `frame` | `int frame` | Zero-based index of the frame just written (`-1` for warmup/terminal). |
| `total` | `int total` | `total` alanını (field/property) ve ilişkili veriyi saklar. |
| `bytesWritten` | `int bytesWritten` | `bytesWritten` alanını (field/property) ve ilişkili veriyi saklar. |
| `file` | `File? file` | `file` alanını (field/property) ve ilişkili veriyi saklar. |
| `elapsed` | `Duration elapsed` | `elapsed` alanını (field/property) ve ilişkili veriyi saklar. |
| `framesDone` | `int get framesDone` | `framesDone` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `fraction` | `double get fraction` | `fraction` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `eta` | `Duration? get eta` | Linear estimate from the frames already written; null until one is done. |
| `fileName` | `String? get fileName` | `fileName` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `formatBytes` | `static String formatBytes(int bytes)` | `formatBytes` işlemini gerçekleştirir. |
| `formatDuration` | `static String formatDuration(Duration d)` | `formatDuration` işlemini gerçekleştirir. |

### `class MovieRenderService`

Walks a [SequencerData] frame by frame and writes a numbered PNG sequence.  One frame per event-loop turn (`Future.delayed(Duration.zero)` between frames) so the editor keeps painting and the progress UI stays live; the offscreen draw therefore never lands inside the viewport's beginFrame/endFrame.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `evaluator` | `SequencerEvaluator evaluator` | `evaluator` alanını (field/property) ve ilişkili veriyi saklar. |
| `flipRows` | `static Uint8List flipRows(Uint8List rgba, int width, int height)` | Bottom-up RGBA8 -> top-down RGBA8. |

## `lib/ui/features/sub_editors/services/sequencer_offscreen_frame_source.dart`

### `class SequencerRenderActor`

One actor the movie render queue draws: its mesh on disk plus the pose the level gave it, which the sampled channels then override per frame.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `actorId` | `String actorId` | `actorId` alanını (field/property) ve ilişkili veriyi saklar. |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `meshPath` | `String? meshPath` | Absolute path of a `.glb` to load; null renders nothing for this actor (a light or camera binding, for example). |
| `location` | `List<double> location` | `location` alanını (field/property) ve ilişkili veriyi saklar. |
| `rotation` | `List<double> rotation` | `rotation` alanını (field/property) ve ilişkili veriyi saklar. |
| `scale` | `List<double> scale` | `scale` alanını (field/property) ve ilişkili veriyi saklar. |

### `class SequencerOffscreenFrameSource`

Real Filament frame source: an offscreen View bound to its own RenderTarget, drawn with `renderStandaloneView` *outside* any beginFrame/endFrame block (so the editor viewport is never disturbed) and read back with `readPixelsFromRenderTarget`.  One RenderTarget is allocated per job and torn down in the service's `finally`; the readback buffer is reused, never copied into progress events.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `actors` | `List<SequencerRenderActor> actors` | `actors` alanını (field/property) ve ilişkili veriyi saklar. |
| `backend` | `FilamentBackend backend` | `backend` alanını (field/property) ve ilişkili veriyi saklar. |
| `rowsAreBottomUp` | `bool get rowsAreBottomUp` | `rowsAreBottomUp` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isSupported` | `static bool get isSupported` | Whether the native offscreen render capability is present in this build. Probes a trivial `@ffi.Native` symbol: resolution throws when the native asset was not built, which is exactly the "capability missing" case. |
| `prepare` | `Future<void> prepare(MovieRenderJob job)` | `prepare` işlemini gerçekleştirir. |
| `renderFrame` | `Future<Uint8List> renderFrame(MovieRenderFrameRequest request)` | `renderFrame` işlemini gerçekleştirir. |
| `dispose` | `Future<void> dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |

### `class _Pose`

`_Pose`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `location` | `List<double> location` | `location` alanını (field/property) ve ilişkili veriyi saklar. |
| `rotation` | `List<double> rotation` | `rotation` alanını (field/property) ve ilişkili veriyi saklar. |
| `scale` | `List<double> scale` | `scale` alanını (field/property) ve ilişkili veriyi saklar. |
| `visible` | `bool visible` | `visible` alanını (field/property) ve ilişkili veriyi saklar. |

---

[Önceki: Proje ayarları](project-settings.md) | [Üst: Alt editörler](index.md) | [Sonraki: Static ve skeletal mesh editörleri](meshes.md)
