[English](../../../en/lumina_ui/sub-editors/animation.md)

# Animasyon editörü

Animasyon editörü: alt editör view'i ve view model'i, oynatma controller'ı, bone track ve keyframe modelleri, notify'lar, eğriler ve blend space verisi, dope sheet ve retarget diyaloğu. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [Sıfırdan bir Animation Sequence oluşturmak](#sıfırdan-bir-animation-sequence-oluşturmak)
- [`lib/ui/features/sub_editors/views/animation_sub_editor.dart`](#libuifeaturessub_editorsviewsanimation_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/animation_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsanimation_editor_view_modeldart)
- [`lib/ui/features/sub_editors/models/anim_bone_track_info.dart`](#libuifeaturessub_editorsmodelsanim_bone_track_infodart)
- [`lib/ui/features/sub_editors/models/anim_notify_and_curves.dart`](#libuifeaturessub_editorsmodelsanim_notify_and_curvesdart)
- [`lib/ui/features/sub_editors/models/animation_playback_controller.dart`](#libuifeaturessub_editorsmodelsanimation_playback_controllerdart)
- [`lib/ui/features/sub_editors/models/selected_keyframe_details.dart`](#libuifeaturessub_editorsmodelsselected_keyframe_detailsdart)
- [`lib/ui/features/sub_editors/widgets/animation_dope_sheet_widget.dart`](#libuifeaturessub_editorswidgetsanimation_dope_sheet_widgetdart)
- [`lib/ui/features/sub_editors/widgets/animation_retarget_modal.dart`](#libuifeaturessub_editorswidgetsanimation_retarget_modaldart)
- [`lib/ui/features/sub_editors/services/anim_graph_asset_service.dart`](#libuifeaturessub_editorsservicesanim_graph_asset_servicedart)
- [`lib/ui/features/sub_editors/services/anim_preview_scene.dart`](#libuifeaturessub_editorsservicesanim_preview_scenedart)
- [`lib/ui/features/sub_editors/view_models/anim_blueprint_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsanim_blueprint_editor_view_modeldart)
- [`lib/ui/features/sub_editors/view_models/blend_space_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsblend_space_editor_view_modeldart)
- [`lib/ui/features/sub_editors/views/anim_blueprint/anim_blueprint_sub_editor.dart`](#libuifeaturessub_editorsviewsanim_blueprintanim_blueprint_sub_editordart)
- [`lib/ui/features/sub_editors/views/anim_blueprint/anim_graph_view.dart`](#libuifeaturessub_editorsviewsanim_blueprintanim_graph_viewdart)
- [`lib/ui/features/sub_editors/views/anim_blueprint/anim_preview_editor.dart`](#libuifeaturessub_editorsviewsanim_blueprintanim_preview_editordart)
- [`lib/ui/features/sub_editors/views/anim_blueprint/create_anim_asset_dialog.dart`](#libuifeaturessub_editorsviewsanim_blueprintcreate_anim_asset_dialogdart)
- [`lib/ui/features/sub_editors/views/anim_blueprint/state_machine_graph.dart`](#libuifeaturessub_editorsviewsanim_blueprintstate_machine_graphdart)
- [`lib/ui/features/sub_editors/views/anim_blueprint/state_pose_editor.dart`](#libuifeaturessub_editorsviewsanim_blueprintstate_pose_editordart)
- [`lib/ui/features/sub_editors/views/blend_space/blend_space_grid.dart`](#libuifeaturessub_editorsviewsblend_spaceblend_space_griddart)
- [`lib/ui/features/sub_editors/views/blend_space/blend_space_sub_editor.dart`](#libuifeaturessub_editorsviewsblend_spaceblend_space_sub_editordart)
- [`lib/ui/features/sub_editors/widgets/anim_blueprint_retarget_modal.dart`](#libuifeaturessub_editorswidgetsanim_blueprint_retarget_modaldart)

## Sıfırdan bir Animation Sequence oluşturmak

- **Oluşturma**: Content Browser ▸ New Asset ▸ **Animation → Animation Sequence** (ya da MCP `create_asset {type: "animation", target_mesh, length_frames | length_seconds, frame_rate}`) hedef iskelet mesh'ini, bir adı, kare ya da saniye cinsinden uzunluğu ve kare hızını (varsayılan 30) sorar. Sekans, mesh'in GLB'sine eklenen bir glTF animasyonudur (iskelet kökünün dinlenme pozu 0. karede anahtarlanır); ona işaret eden animasyon `.lmas` dosyası `contents/animations/<Mesh>/` altına yazılır (lumina'nın `AuthoredAnimationStore`'u) ve Animation editöründe açılır.
- **Pozlama**: Bone Tracks sekmesi iskeleti listeler (adla filtrelenir); oradan bir kemiğe ya da viewport'ta bir eklemin yakınına tıklamak onu seçer. Viewport iskeleti mesh'in üzerine çizer (seçili kemik kehribar renginde) ve dönüşüm gizmo'sunu kemiğe yerleştirir: her kemik için **döndürme** (E, varsayılan), iskelet kökü ve pelvis için **taşıma** (W), **ölçekleme** (R); World / Local ve snap ayarları viewport'un araç grubunda. Poz, oynatmanın kullandığı aynı eklem dönüşümleri ve skinning ile canlı görünür (`SubEditor3DViewport.jointLocalPose`).
- **Auto Key** (araç çubuğu, varsayılan açık, `editor_preferences.json` içinde `animationAutoKey` olarak hatırlanır): gizmo bırakıldığında kemiğin değişen kanalları (quaternion olarak rotation, translation, scale) oynatma kafasının karesinde, tek geri alma adımı olarak anahtarlanır; o karede bir anahtar varsa güncellenir. Auto Key kapalıyken değişiklik bir önizlemedir, bir sonraki seek ya da oynatma onu geri alır; **Key** (K) bekleyen değişiklikleri ya da seçili kemiğin tüm dönüşümünü anahtarlar.
- **Anahtarlar**: dope sheet anahtarı olan her kemiği anahtarlarıyla listeler; tıklama seçer (Shift ekler), sürükleme seçili anahtarları tam kareler halinde taşır, Delete siler. Seçili bir kemik anahtarı Key panelini açar: kare (düzenlenebilir, anahtarı taşır), kemiğin X / Y / Z eksenleri etrafında derece cinsinden yerel dönüş, translation, scale (her alan o kanalı o karede anahtarlar) ve kemiğin kanallarının interpolasyonu (Linear / Step / Cubic — glTF kanal başına interpolasyon yapar; Cubic her anahtarda yumuşak giriş ve çıkış yapar). Ctrl+Z / Ctrl+Y her düzenlemeyi geri alır ve yineler.
- **Kaydetme** klibi mesh'in GLB'sine yazar; böylece Anim Blueprint'ler, Blend Space'ler, montajlar, Play ve üretilen oyun onu adıyla, değiştirmeden oynatır; varlığı yeniden açmak anahtarları `authored_clip` içinden birebir geri yükler.
- **Pose sekmesi** (sağ panel, oluşturulmuş sekanslar; her düzenleme tek geri alma adımıdır ve aynı glTF klibinin sıradan anahtarları olarak yazılır):
  - **Onion skin** (viewport HUD anahtarı, O): oynatma kafasından önceki (turuncu) ve sonraki (mavi) en yakın anahtarlı pozların hayalet iskeletleri; önce / sonra sayıları (0–5) ve opaklık sekmededir; en yakın hayalet bu opaklıkla, uzaktakiler daha soluk çizilir.
  - **Poz**: Copy Pose (oynatma kafasındaki tüm poz, Ctrl+C) ya da Copy Selected (seçili kemik ve altındakiler), Paste (Ctrl+V) ve Paste Mirrored (Ctrl+Shift+V: kopyalanan her kemiğin pozu sol/sağ eşine, düzlem üzerindeki kemiğe kendisine), Mirror Selected (seçili uzuv diğer tarafa). Yapıştırma, gösterilen pozdan farklı ya da zaten animasyonlu kanalları anahtarlar; yapıştırılan ya da yansıtılan bir seçim tüm dönüşleri anahtarlar, böylece başka bir karedeki sonraki bir anahtar bu kareyi değiştiremez.
  - **Ayna çiftleri**: kemik adlarından (`_l`/`_r`, `Left`/`Right`, `.L`/`.R`, `l_`/`r_`) bulunur, düzlem dinlenme pozundan gelir (lumina'nın `SkeletonMirror`'ı); elle ayarlanan çiftler iskelet başına poz kütüphanesinde saklanır.
  - **Döngü**: dikiş (0. kare ile son kare arasındaki en büyük dönüş), Copy First → Last (anahtarlı her kanal), Match Selected to First ve dikişi klibin sonunda görmek için "Show frame 0 as a ghost".
  - **Poz kütüphanesi**: Save Pose (tüm poz ya da yalnızca seçili kemik ve çocukları) bir adla, ağırlıkla Apply (%0–100, gösterilen pozdan kaydedilene harmanlama), yeniden adlandırma (ad alanına), silme. İskelet mesh başına `contents/animations/<Mesh>/PoseLibrary.lmas` içinde saklanır; bu dosyayı açmak mesh'ini gösterir ve pozları listeler.
  - **İki kemikli IK** (I): iskelette bulunan kol ve bacak zincirleri; IK modunda viewport'un öteleme gizmosu zincirin uç hedefini (sarı elmas) ya da Drag Pole ile pole'unu (mor halka, dirseğe / dize kesikli çizgi) taşır. Bırakınca Auto Key açıkken zincirin dönüşleri (üst, alt ve dünya yönelimini koruyan uç) oynatma kafasında anahtarlanır; kapalıyken önizleme olarak kalır. **Pin & Bake**, bir aralığın ilk karesindeki el ya da ayağı yerinde tutar; zinciri iki uçta ve aradaki her anahtarlı karede çözüp anahtarlar (lumina'nın `TwoBoneIkSolver`'ı). Kaydedilen klip ileri kinematik kalır.
  - **Kök hareketi**: Extract from Pelvis pelvisin yatay yolunu iskelet köküne taşır (pelvis dikey hareketini korur, dünya yolu değişmez) ve Enable Root Motion'ı açar; Zero Root geri koyar ve kapatır. Draw Path: zemine viewport tıklamaları nokta ekler; Key Path kökü klip boyunca eşit dağıtılmış bu noktalardan geçirerek anahtarlar ve Enable Root Motion'ı açar.
  - Additive katmanlar sekmede yoktur: glTF bunları saklamaz, klibe gömülen bir katman da yeniden katman olarak düzenlenemez.
- **Geri alma, silme, geri getirme**: bir sekans oluşturmak tek bir geri alma adımıdır. Onu geri almak, varlığı silmek (proje çöp kutusuna) ya da klasörünü çöpe atmak, `.lmas` ile birlikte klibini mesh'in GLB'sinden ve `animation_clips` listesinden çıkarır (klibin verisi GLB'den silinir); yineleme, silmeyi geri alma ya da çöp kutusu girdisini geri getirme klibi mesh'in klip listesindeki yerine geri koyar. Aynı mesh'teki diğer sekanslar kliplerini korur.

## Pose Search Database editörü

Bir `poseSearchDatabase` asset'i için açılır (Content Browser → New → Animation → Pose Search Database, bir iskelet mesh için): `lib/ui/features/sub_editors/views/pose_search/` (`PoseSearchDatabaseSubEditor`, `PoseSearchClipTree`, `PoseSearchDatabaseClipList`, `PoseSearchDetailsPanel`), `PoseSearchDatabaseEditorViewModel` ve `PoseSearchDatabaseService` üzerinde. Üç yeniden boyutlanabilir panel: hedef mesh'in clip'leri harekete göre gruplanmış bir ağaç olarak (tıklama clip ekler ya da çıkarır, "+" bir grubu ekler, filtre ve **Add matching** metni içeren her clip'i ekler, filtre yokken **Add all clips**), veritabanının clip'leri Loop / Mirror / Use ile ve özellik önbelleğinin durumu ve istatistikleri, ve Details (clip başına etiketler, maliyet sapması ve arama aralığı; arama aralığı, sapmalar, harmanlama süresi, dışlanan son; şema: örnekleme hızı, yörünge zamanları ve ağırlıkları, kök kemik, mesh yaw ofseti, konum / hız ağırlıklı kemikler). **Build** kaydeder, sonra `.posedb`'yi arka plan isolate'inde derler ve kare, özellik, derleme süresi ve zamanlanmış örnek aramayı raporlar; her düzenleme bir geri alma adımıdır. Animation Blueprint editörünün state poz editöründe veritabanı seçicisi (ABP'nin hedef mesh'i için yapılmış veritabanları), harmanlama süresi, poz / yörünge ağırlıkları, gerekli etiketler, harekete dönme ve debug çizimi olan bir **Motion Matching** türü vardır. Bkz. [Motion matching](../../lumina/motion-matching.md).

## `lib/ui/features/sub_editors/views/animation_sub_editor.dart`

### `class AnimationSubEditor`

`AnimationSubEditor`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | `assetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetPath` | `String? assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `asset` | `RealAssetInfo? asset` | `asset` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `AnimationEditorViewModel? viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback? onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `onBind` | `SubEditorBindCallback? onBind` | `onBind` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<AnimationSubEditor> createState() => _AnimationSubEditorState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _AnimationSubEditorState`

`_AnimationSubEditorState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _BlendSpaceCanvasPainter`

`_BlendSpaceCanvasPainter`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `blendSpace` | `BlendSpaceData blendSpace` | `blendSpace` alanını (field/property) ve ilişkili veriyi saklar. |
| `paramX` | `double paramX` | `paramX` alanını (field/property) ve ilişkili veriyi saklar. |
| `paramY` | `double paramY` | `paramY` alanını (field/property) ve ilişkili veriyi saklar. |
| `weights` | `Map<String, double> weights` | `weights` alanını (field/property) ve ilişkili veriyi saklar. |
| `paint` | `void paint(Canvas canvas, Size size)` | `paint` işlemini gerçekleştirir. |
| `shouldRepaint` | `bool shouldRepaint(covariant _BlendSpaceCanvasPainter oldDelegate)` | `shouldRepaint` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/view_models/animation_editor_view_model.dart`

### `class AnimationEditorViewModel`

`AnimationEditorViewModel`: İlgili arayüz modülünün durumunu (state) yöneten, kullanıcı aksiyonlarını yürüten ve görünümü güncelleyen ChangeNotifier ViewModel sınıfıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `initialAsset` | `LuminaAsset? initialAsset` | `initialAsset` alanını (field/property) ve ilişkili veriyi saklar. |
| `isLoading` | `bool get isLoading` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `hasError` | `bool get hasError` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isDirty` | `bool get isDirty` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `asset` | `LuminaAsset? get asset` | `asset` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `glbMesh` | `GlbMeshData? get glbMesh` | `glbMesh` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `previewMeshAsset` | `RealAssetInfo? get previewMeshAsset` | `previewMeshAsset` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `previewMeshPath` | `String? get previewMeshPath` | `previewMeshPath` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `availableSkeletalMeshes` | `List<RealAssetInfo> get availableSkeletalMeshes` | `availableSkeletalMeshes` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `timelineZoom` | `double get timelineZoom` | `timelineZoom` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `snapToFrames` | `bool get snapToFrames` | `snapToFrames` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `snapInterval` | `int get snapInterval` | `snapInterval` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `selectedKeyframeIds` | `Set<String> get selectedKeyframeIds` | İlgili aktör veya varlığı seçili duruma getirir. |
| `clips` | `List<GlbAnimationClip> get clips` | `clips` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `selectedClip` | `int get selectedClip` | İlgili aktör veya varlığı seçili duruma getirir. |
| `isPlaying` | `bool get isPlaying` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isLooping` | `bool get isLooping` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `speed` | `double get speed` | `speed` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `rateScale` | `double get rateScale` | `rateScale` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `positionSeconds` | `double get positionSeconds` | `positionSeconds` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `frameRate` | `double get frameRate` | `frameRate` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `interpolation` | `String get interpolation` | `interpolation` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `additiveType` | `String get additiveType` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `notifies` | `List<EditorAnimNotify> get notifies` | `notifies` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `curves` | `List<AnimCurveData> get curves` | `curves` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `blendSpace` | `BlendSpaceData get blendSpace` | `blendSpace` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `blendParamX` | `double get blendParamX` | `blendParamX` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `blendParamY` | `double get blendParamY` | `blendParamY` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `enableRootMotion` | `bool get enableRootMotion` | `enableRootMotion` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `recentlyFiredNotifies` | `List<EditorAnimNotify> get recentlyFiredNotifies` | `recentlyFiredNotifies` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `fileBasename` | `String get fileBasename` | `fileBasename` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `activeClip` | `GlbAnimationClip? get activeClip` | `activeClip` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `duration` | `double get duration` | `duration` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `totalFrames` | `int get totalFrames` | `totalFrames` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `activeClipKeyframes` | `List<double> get activeClipKeyframes` | `activeClipKeyframes` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `allBoneTrackInfos` | `List<AnimBoneTrackInfo> get allBoneTrackInfos` | `allBoneTrackInfos` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `boneSearchQuery` | `String get boneSearchQuery` | `boneSearchQuery` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `setBoneSearchQuery` | `void setBoneSearchQuery(String query)` | `BoneSearchQuery` parametresini günceller ve sisteme uygular. |
| `animatedBoneTracks` | `List<AnimBoneTrackInfo> get animatedBoneTracks` | Returns only bones that actively vary (position/rotation/scale) over time. |
| `filteredAnimatedBoneTracks` | `List<AnimBoneTrackInfo> get filteredAnimatedBoneTracks` | Returns animated bones matching the search filter query. |
| `boneKeyframeTracks` | `Map<String, List<double>> get boneKeyframeTracks` | `boneKeyframeTracks` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `currentFrame` | `int get currentFrame` | `currentFrame` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `formattedTime` | `String get formattedTime` | `formattedTime` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `formattedTotalTime` | `String get formattedTotalTime` | `formattedTotalTime` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `activeAnimatedNodeIndices` | `Set<int> get activeAnimatedNodeIndices` | `activeAnimatedNodeIndices` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `allBones` | `List<GlbNode> get allBones` | `allBones` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `rootBones` | `List<GlbNode> get rootBones` | `rootBones` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `currentBlendWeights` | `Map<String, double> get currentBlendWeights` | `currentBlendWeights` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `dominantSample` | `EditorBlendSample? get dominantSample` | `dominantSample` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `load` | `Future<void> load()` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |
| `play` | `void play()` | `play` işlemini gerçekleştirir. |
| `pause` | `void pause()` | `pause` işlemini gerçekleştirir. |
| `togglePlay` | `void togglePlay()` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `setLooping` | `void setLooping(bool loop)` | `Looping` parametresini günceller ve sisteme uygular. |
| `setSpeed` | `void setSpeed(double s)` | `Speed` parametresini günceller ve sisteme uygular. |
| `setRateScale` | `void setRateScale(double r)` | `RateScale` parametresini günceller ve sisteme uygular. |
| `setInterpolation` | `void setInterpolation(String interp)` | `Interpolation` parametresini günceller ve sisteme uygular. |
| `setAdditiveType` | `void setAdditiveType(String type)` | `AdditiveType` parametresini günceller ve sisteme uygular. |
| `setFrameRate` | `void setFrameRate(double fps)` | `FrameRate` parametresini günceller ve sisteme uygular. |
| `selectClip` | `void selectClip(int index)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `stepFrame` | `void stepFrame(int delta)` | `stepFrame` işlemini gerçekleştirir. |
| `seek` | `void seek(double timeSeconds)` | `seek` işlemini gerçekleştirir. |
| `tickDelta` | `void tickDelta(double dt)` | `tickDelta` işlemini gerçekleştirir. |
| `moveNotify` | `void moveNotify(String id, double newTime)` | `moveNotify` işlemini gerçekleştirir. |
| `renameNotify` | `void renameNotify(String id, String newName)` | `renameNotify` işlemini gerçekleştirir. |
| `removeNotify` | `void removeNotify(String id)` | Belirtilen `Notify` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `addCurve` | `void addCurve(String name)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `removeCurve` | `void removeCurve(String name)` | Belirtilen `Curve` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `addCurveKey` | `void addCurveKey(String curveName, double time, double value)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `removeCurveKey` | `void removeCurveKey(String curveName, int keyIndex)` | Belirtilen `CurveKey` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `evaluateCurve` | `double evaluateCurve(String curveName)` | `evaluateCurve` işlemini gerçekleştirir. |
| `setTimelineZoom` | `void setTimelineZoom(double z)` | `TimelineZoom` parametresini günceller ve sisteme uygular. |
| `setSnap` | `void setSnap(bool snap)` | `Snap` parametresini günceller ve sisteme uygular. |
| `setSnapInterval` | `void setSnapInterval(int interval)` | `SnapInterval` parametresini günceller ve sisteme uygular. |
| `clearKeyframeSelection` | `void clearKeyframeSelection()` | Koleksiyon veya tampon içeriğini tamamen temizler. |
| `selectedKeyframeDetails` | `SelectedKeyframeDetails? get selectedKeyframeDetails` | İlgili aktör veya varlığı seçili duruma getirir. |
| `updateSelectedCurveKeyframeValue` | `void updateSelectedCurveKeyframeValue(double newValue)` | Mevcut verileri veya durumu günceller. |
| `deleteSelectedKeys` | `void deleteSelectedKeys()` | Belirtilen `SelectedKeys` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `setBlendSpace2D` | `void setBlendSpace2D(bool is2D)` | `BlendSpace2D` parametresini günceller ve sisteme uygular. |
| `setBlendParam` | `void setBlendParam(double x, double y)` | `BlendParam` parametresini günceller ve sisteme uygular. |
| `addBlendSample` | `void addBlendSample(String assetPath, String assetName, double x, double y)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `moveBlendSample` | `void moveBlendSample(String id, double x, double y)` | `moveBlendSample` işlemini gerçekleştirir. |
| `removeBlendSample` | `void removeBlendSample(String id)` | Belirtilen `BlendSample` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `toggleRootMotion` | `void toggleRootMotion()` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `setRootMotion` | `void setRootMotion(bool enable)` | `RootMotion` parametresini günceller ve sisteme uygular. |
| `formatTimecode` | `static String formatTimecode(double seconds)` | `formatTimecode` işlemini gerçekleştirir. |
| `save` | `Future<bool> save()` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |

**Authoring members (sequences created in the editor):**

| Member | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isAuthored` / `authoredClip` / `skeleton` | `bool get isAuthored` · `AuthoredAnimationClip? get authoredClip` · `GlbSkeleton? get skeleton` | A sequence authored here (its keys in the asset's `authored_clip`), its clip and the mesh's skeleton. |
| `transactions` / `undo` / `redo` | `TransactionManager transactions` | The editor's undo stack for authored edits (Ctrl+Z / Ctrl+Y). |
| `autoKey` / `setAutoKey` / `onAutoKeyChanged` | `bool get autoKey` · `void setAutoKey(bool value)` | Auto Key: a released gizmo keys the changed channels at the playhead; told to the preferences. |
| `selectedBone` / `selectBone` | `String? get selectedBone` · `void selectBone(String? bone)` | The bone the gizmo sits on. |
| `playheadFrame` | `int get playheadFrame` | The frame keys are written at. |
| `currentNodePose` / `jointLocalPose` | `Map<int, BoneTrs> get currentNodePose` · `Map<String, List<double>>? get jointLocalPose` | The pose shown: the clip at the playhead with pending previews over it; per joint for the viewport. |
| `boneLocal` / `boneWorldPosition` / `canTranslateBone` | `BoneTrs? boneLocal(String bone)` · `Vector3? boneWorldPosition(String bone)` · `bool canTranslateBone(String bone)` | A bone's local transform / world position now; only the root and pelvis translate. |
| `gizmoTarget` / `pickBone` | `SubEditorGizmoTarget? gizmoTarget(GizmoMode mode)` · `String? pickBone(Vector3 origin, Vector3 direction)` | The gizmo's target (authoring frame) and the joint nearest a click ray. |
| `beginBonePose` / `previewGizmoDelta` / `previewBonePose` / `endBonePose` / `cancelBonePose` | `void beginBonePose(String bone)` · `void previewGizmoDelta(SubEditorGizmoDelta delta)` · … | The gizmo drag: a world delta turned into the bone's local transform (`R_local' = R_parent⁻¹ · Δ · R_parent · R_local`); release keys it with Auto Key on, Esc restores it. |
| `hasPendingPreview` / `keyPendingOrSelected` | `bool get hasPendingPreview` · `void keyPendingOrSelected()` | The Key button: keys pending previews, or the selected bone's whole transform. |
| `parseBoneKeyId` / `boneKeyId` / `selectedBoneKeys` | `AnimBoneKeyRef? parseBoneKeyId(String id)` · `String boneKeyId(String bone, int frame)` | Dope sheet bone key ids (`bone_<bone>[_<sub-track>]_<time>`) ↔ bone and frame. |
| `setBoneKey` / `moveSelectedBoneKeysBy` / `moveSelectedBoneKeysToFrame` / `deleteSelectedBoneKeys` / `setBoneInterpolation` | `void setBoneKey(String bone, int frame, {List<double>? translation, rotation, scale})` · … | Key panel and dope sheet edits, each one undo step. |
| `authoredGlbClip` / `authoredBoneTracks` / `authoredKeyDetails` | `GlbAnimationClip? get authoredGlbClip` · … | The authored clip as the dope sheet and Key panel read clips. |

## `lib/ui/features/sub_editors/models/anim_bone_track_info.dart`

### `class AnimBoneTrackInfo`

Metadata and active animation range for a bone track.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `boneName` | `String boneName` | `boneName` alanını (field/property) ve ilişkili veriyi saklar. |
| `nodeIndex` | `int nodeIndex` | `nodeIndex` alanını (field/property) ve ilişkili veriyi saklar. |
| `keyframeTimes` | `List<double> keyframeTimes` | `keyframeTimes` alanını (field/property) ve ilişkili veriyi saklar. |
| `startTime` | `double startTime` | `startTime` alanını (field/property) ve ilişkili veriyi saklar. |
| `endTime` | `double endTime` | `endTime` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasVariation` | `bool hasVariation` | `hasVariation` alanını (field/property) ve ilişkili veriyi saklar. |
| `channels` | `List<GlbAnimationChannel> channels` | `channels` alanını (field/property) ve ilişkili veriyi saklar. |
| `duration` | `double get duration` | `duration` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `subTracks` | `List<AnimBoneSubTrack> get subTracks` | Generates the individual component sub-tracks (Location X/Y/Z, Rotation P/Y/R, Scale X/Y/Z) with per-component active variation detection and filtered keyframe lists. |

### `class _ComponentVarInfo`

`_ComponentVarInfo`: Aktörlere bağlanarak 3B uzaysal konum, görsel mesh, aydınlatma veya hareket kabiliyeti kazandıran bileşendir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `hasVariation` | `bool hasVariation` | `hasVariation` alanını (field/property) ve ilişkili veriyi saklar. |
| `startTime` | `double startTime` | `startTime` alanını (field/property) ve ilişkili veriyi saklar. |
| `endTime` | `double endTime` | `endTime` alanını (field/property) ve ilişkili veriyi saklar. |
| `keyframeTimes` | `List<double> keyframeTimes` | `keyframeTimes` alanını (field/property) ve ilişkili veriyi saklar. |
| `staticValue` | `double staticValue` | `staticValue` alanını (field/property) ve ilişkili veriyi saklar. |

### `class AnimBoneSubTrack`

An individual component sub-track (e.g. Location.X, Rotation.Pitch, Scale.Z)

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `id` | `String id` | `id` alanını (field/property) ve ilişkili veriyi saklar. |
| `label` | `String label` | `label` alanını (field/property) ve ilişkili veriyi saklar. |
| `group` | `String group` | `group` alanını (field/property) ve ilişkili veriyi saklar. |
| `color` | `Color color` | `color` alanını (field/property) ve ilişkili veriyi saklar. |
| `keyframeTimes` | `List<double> keyframeTimes` | `keyframeTimes` alanını (field/property) ve ilişkili veriyi saklar. |
| `startTime` | `double startTime` | `startTime` alanını (field/property) ve ilişkili veriyi saklar. |
| `endTime` | `double endTime` | `endTime` alanını (field/property) ve ilişkili veriyi saklar. |
| `hasVariation` | `bool hasVariation` | `hasVariation` alanını (field/property) ve ilişkili veriyi saklar. |
| `staticValue` | `double staticValue` | `staticValue` alanını (field/property) ve ilişkili veriyi saklar. |

## `lib/ui/features/sub_editors/models/anim_notify_and_curves.dart`

### `enum AnimNotifyType`

`AnimNotifyType`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class EditorAnimNotify`

`EditorAnimNotify`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `EditorAnimNotify.fromJson(Map<String, dynamic> json)`: `EditorAnimNotify.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `id` | `String id` | `id` alanını (field/property) ve ilişkili veriyi saklar. |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `time` | `double time` | `time` alanını (field/property) ve ilişkili veriyi saklar. |
| `type` | `AnimNotifyType type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |
| `isSyncMarker` | `bool isSyncMarker` | `isSyncMarker` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `class AnimCurveKey`

`AnimCurveKey`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `AnimCurveKey.fromJson(Map<String, dynamic> json)`: `AnimCurveKey.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `time` | `double time` | `time` alanını (field/property) ve ilişkili veriyi saklar. |
| `value` | `double value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `class AnimCurveData`

`AnimCurveData`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `AnimCurveData.fromJson(Map<String, dynamic> json)`: `AnimCurveData.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `keys` | `List<AnimCurveKey> keys` | `keys` alanını (field/property) ve ilişkili veriyi saklar. |
| `sortKeys` | `void sortKeys()` | `sortKeys` işlemini gerçekleştirir. |
| `evaluate` | `double evaluate(double t)` | `evaluate` işlemini gerçekleştirir. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `class BlendSpaceAxis`

`BlendSpaceAxis`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `BlendSpaceAxis.fromJson(Map<String, dynamic> json)`: `BlendSpaceAxis.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `min` | `double min` | `min` alanını (field/property) ve ilişkili veriyi saklar. |
| `max` | `double max` | `max` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `class EditorBlendSample`

`EditorBlendSample`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `EditorBlendSample.fromJson(Map<String, dynamic> json)`: `EditorBlendSample.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `id` | `String id` | `id` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetPath` | `String assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetName` | `String assetName` | `assetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `x` | `double x` | `x` alanını (field/property) ve ilişkili veriyi saklar. |
| `y` | `double y` | `y` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

### `class BlendSpaceData`

`BlendSpaceData`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `BlendSpaceData.fromJson(Map<String, dynamic> json)`: `BlendSpaceData.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `is2D` | `bool is2D` | `is2D` alanını (field/property) ve ilişkili veriyi saklar. |
| `xAxis` | `BlendSpaceAxis xAxis` | `xAxis` alanını (field/property) ve ilişkili veriyi saklar. |
| `yAxis` | `BlendSpaceAxis yAxis` | `yAxis` alanını (field/property) ve ilişkili veriyi saklar. |
| `samples` | `List<EditorBlendSample> samples` | `samples` alanını (field/property) ve ilişkili veriyi saklar. |
| `computeWeights` | `Map<String, double> computeWeights(double x, double y)` | `computeWeights` işlemini gerçekleştirir. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |

## `lib/ui/features/sub_editors/models/animation_playback_controller.dart`

### `class AnimationPlaybackController`

Manages and broadcasts frame-by-frame animation playback requests to the 3D viewport.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `callLog` | `List<String> callLog` | `callLog` alanını (field/property) ve ilişkili veriyi saklar. |
| `clipIndex` | `int get clipIndex` | `clipIndex` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `timeSeconds` | `double get timeSeconds` | `timeSeconds` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `recordCall` | `void recordCall(String methodName)` | `recordCall` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/models/selected_keyframe_details.dart`

### `class SelectedKeyframeDetails`

Detailed properties of a selected keyframe (Bone Transform, Curve Float, or Notify).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `keyId` | `String keyId` | `keyId` alanını (field/property) ve ilişkili veriyi saklar. |
| `type` | `String type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |
| `targetName` | `String targetName` | `targetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `time` | `double time` | `time` alanını (field/property) ve ilişkili veriyi saklar. |
| `frame` | `int frame` | `frame` alanını (field/property) ve ilişkili veriyi saklar. |
| `location` | `List<double>? location` | `location` alanını (field/property) ve ilişkili veriyi saklar. |
| `rotationEuler` | `List<double>? rotationEuler` | `rotationEuler` alanını (field/property) ve ilişkili veriyi saklar. |
| `rotationQuat` | `List<double>? rotationQuat` | `rotationQuat` alanını (field/property) ve ilişkili veriyi saklar. |
| `scale` | `List<double>? scale` | `scale` alanını (field/property) ve ilişkili veriyi saklar. |
| `interpolation` | `String? interpolation` | `interpolation` alanını (field/property) ve ilişkili veriyi saklar. |
| `curveValue` | `double? curveValue` | `curveValue` alanını (field/property) ve ilişkili veriyi saklar. |
| `notifyType` | `String? notifyType` | `notifyType` alanını (field/property) ve ilişkili veriyi saklar. |
| `subTrackLabel` | `String? subTrackLabel` | `subTrackLabel` alanını (field/property) ve ilişkili veriyi saklar. |
| `quaternionToEuler` | `static List<double> quaternionToEuler(double x, double y, double z, doub...` | `quaternionToEuler` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/widgets/animation_dope_sheet_widget.dart`

### `class AnimationDopeSheetWidget`

Multi-track dope sheet and animation track strip editor.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `AnimationEditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<AnimationDopeSheetWidget> createState() => _AnimationDopeSheetWidg...` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _AnimationDopeSheetWidgetState`

`_AnimationDopeSheetWidgetState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _DopeSheetRulerPainter`

`_DopeSheetRulerPainter`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `duration` | `double duration` | `duration` alanını (field/property) ve ilişkili veriyi saklar. |
| `fps` | `double fps` | `fps` alanını (field/property) ve ilişkili veriyi saklar. |
| `currentPosition` | `double currentPosition` | `currentPosition` alanını (field/property) ve ilişkili veriyi saklar. |
| `paint` | `void paint(Canvas canvas, Size size)` | `paint` işlemini gerçekleştirir. |
| `shouldRepaint` | `bool shouldRepaint(covariant _DopeSheetRulerPainter oldDelegate)` | `shouldRepaint` işlemini gerçekleştirir. |

### `class _DopeSheetGridPainter`

`_DopeSheetGridPainter`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `duration` | `double duration` | `duration` alanını (field/property) ve ilişkili veriyi saklar. |
| `fps` | `double fps` | `fps` alanını (field/property) ve ilişkili veriyi saklar. |
| `paint` | `void paint(Canvas canvas, Size size)` | `paint` işlemini gerçekleştirir. |
| `shouldRepaint` | `bool shouldRepaint(covariant _DopeSheetGridPainter oldDelegate)` | `shouldRepaint` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/widgets/animation_retarget_modal.dart`

### `class AnimationRetargetModal`

Modal dialog for retargeting an animation sequence to a different skeletal mesh character.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `AnimationEditorViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `sourceAssetName` | `String sourceAssetName` | `sourceAssetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<AnimationRetargetModal> createState() => _AnimationRetargetModalSt...` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _AnimationRetargetModalState`

`_AnimationRetargetModalState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/services/anim_graph_asset_service.dart`

### `typedef AnimPreviewMeshSource`

A skeletal mesh as a preview component loads it: a GLB path and, for a mesh whose GLB lives inside its `.lmas` payload, a provider handing those bytes over.

### `abstract final class AnimGraphAssetService`

Animation Blueprint and Blend Space assets on disk: lumina's anim graph documents as JSON in the `.lmas` `raw_payload`, next to the mesh's clips under `contents/animations/<Mesh>/`, with the target mesh kept in the metadata and as an asset reference.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `targetMeshKey` | `static const String targetMeshKey` |  |
| `baseName` | `static String baseName(String path)` |  |
| `skeletalMeshes` | `static List<RealAssetInfo> skeletalMeshes(String projectDir)` | The project's skeletal meshes. |
| `meshSource` | `static AnimPreviewMeshSource? meshSource(String projectDir, String meshRelPath)` | Where [meshRelPath]'s GLB is: the `.entity.glb` companion (template content) or the `.lmas` payload (an import). Null when neither exists. |
| `clipNames` | `static List<String> clipNames(String projectDir, String meshRelPath)` | The animation clips stored in [meshRelPath]'s GLB, in gltfio order. |
| `withPrefix` | `static String withPrefix(String name, String prefix)` |  |
| `newAnimBlueprint` | `static LuminaAnimBlueprintDocument newAnimBlueprint(String meshRelPath, List<String> clips)` | What a new Animation Blueprint for [meshRelPath] starts as: an EventGraph with Blueprint Update Animation, and an AnimGraph whose Output Pose is fed by the Locomotion state machine with one Idle state playing the mesh's first clip. |
| `newBlendSpace` | `static LuminaBlendSpaceDocument newBlendSpace()` | A new 2D Blend Space: Direction (−180…180°) × Speed (0…500 cm/s). |
| `createAnimBlueprint` | `static String createAnimBlueprint(String projectDir, {required String name, required String meshRelPath})` | Creates `ABP_<name>.lmas` for [meshRelPath] and returns its project relative path. |
| `createBlendSpace` | `static String createBlendSpace(String projectDir, {required String name, required String meshRelPath, LuminaBl...` | Creates `BS_<name>.lmas` for [meshRelPath] and returns its path; [document] is its content (a new 2D space by default). |
| `createAnimationSequence` | `static String createAnimationSequence(String projectDir, {required String name, required String meshRelPath, required int lengthFrames, double frameRate = 30.0, String? folder})` | Creates an empty Animation Sequence for [meshRelPath] (the skeleton root's rest pose keyed at frame 0), stored as a clip in the mesh's GLB; returns its project relative path. |
| `readAnimBlueprint` | `static LuminaAnimBlueprintDocument? readAnimBlueprint(String projectDir, String relPath)` |  |
| `readBlendSpace` | `static LuminaBlendSpaceDocument? readBlendSpace(String projectDir, String relPath)` |  |
| `blendSpaceTarget` | `static String? blendSpaceTarget(String projectDir, String relPath)` | The mesh a Blend Space was made for (its metadata), or null. |
| `writeAnimBlueprint` | `static void writeAnimBlueprint(String projectDir, String relPath, LuminaAnimBlueprintDocument doc)` |  |
| `writeBlendSpace` | `static void writeBlendSpace(String projectDir, String relPath, LuminaBlendSpaceDocument doc, {required String...` |  |
| `blendSpacesFor` | `static List<String> blendSpacesFor(String projectDir, String meshRelPath)` | Blend Spaces made for [meshRelPath]: named in their metadata, or (for a Blend Space written without one) whose samples all play clips the mesh has. |
| `projectDirOf` | `static String? projectDirOf(String path)` | Walks up from [path] to the project directory (the folder holding the `.lmproject`, or `contents/`). |

## `lib/ui/features/sub_editors/services/anim_preview_scene.dart`

### `class AnimPreviewOwnerMovement`

The Anim Preview's stand-in pawn movement: Get Velocity and Is Falling answer what the Anim Preview Editor's owner controls say; nothing is simulated.

**Yapıcı Metotlar (Constructors):**

- `AnimPreviewOwnerMovement()`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `standInVelocity` | `final Vector3 standInVelocity` | Velocity in runtime space (Y up), cm/s. |
| `standInFalling` | `bool standInFalling` |  |

### `class AnimPreviewScene`

A skeletal mesh on a stand-in owner, played either by an Animation Blueprint instance or by clip requests, in a lumina world: the editor world a sub-editor viewport hands over (the mesh renders through flutter_filament), or a headless world of its own (no native context: clips are requested but nothing draws — widget tests, and the editor before its viewport is up).

Editor worlds do not tick gameplay, so the scene drives the owner itself: the Animation Blueprint instance first (it picks the pose), then the mesh (it applies it), then a zero-length world tick for render prep.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `movement` | `final AnimPreviewOwnerMovement movement` |  |
| `beforeTick` | `void Function(double dt)? beforeTick` | Called before each tick (write overrides into the instance). |
| `afterTick` | `void Function()? afterTick` | Called after each tick (repaint the highlighted state). |
| `tickSeconds` | `static const double tickSeconds` |  |
| `world` | `LuminaWorld? get world` |  |
| `isAttached` | `bool get isAttached` |  |
| `hasNativeWorld` | `bool get hasNativeWorld` |  |
| `mesh` | `LuminaAnimatedMeshComponent? get mesh` |  |
| `animInstance` | `LuminaAnimBlueprintInstance? get animInstance` |  |
| `owner` | `LuminaActor? get owner` |  |
| `currentClip` | `String? get currentClip` | The clip the mesh plays now (the fade target while cross-fading). |
| `attach` | `void attach(LuminaWorld world, {bool startTicker = true})` | Binds the viewport's editor world and starts ticking at 60 Hz. |
| `attachHeadless` | `void attachHeadless({bool startTicker = true})` | A world of its own with no native context. |
| `stopTicker` | `void stopTicker()` |  |
| `setMesh` | `void setMesh(String? path, {LuminaAssetProvider? provider})` | Shows the mesh at [path] (a GLB file, or an `.lmas` read through [provider]); the same path again keeps the loaded mesh. |
| `setAnimInstance` | `void setAnimInstance(LuminaAnimBlueprintInstance? instance, {Map<String, Object?> carryVariables = const {}})` | Plays [instance] on the mesh from now on (null: none). The previous instance is removed; [carryVariables] seeds the new one's variables. |
| `crossFadeTo` | `void crossFadeTo(String clip, {double duration = 0.2})` | Blends the mesh to [clip] (a Blend Space preview's nearest sample). |
| `advance` | `void advance(double dt)` | One preview frame of [dt] seconds. |
| `detach` | `void detach()` | Releases the world: unregisters what the scene added, or cleans up its own headless world. |

## `lib/ui/features/sub_editors/view_models/anim_blueprint_editor_view_model.dart`

### `enum AnimGraphView`

Which graph of an Animation Blueprint the editor shows.

**Değerler:**

- `animGraph`
- `stateMachine`
- `state`
- `transition`
- `eventGraph`

### `class AnimGraphLocation`

A place in the Animation Blueprint's graph hierarchy: the AnimGraph, a state machine, a state's pose, a transition's rule, or the EventGraph.

**Yapıcı Metotlar (Constructors):**

- `const AnimGraphLocation.animGraph()`
- `const AnimGraphLocation.eventGraph()`
- `const AnimGraphLocation.stateMachine(String machine)`
- `const AnimGraphLocation.state(String machine, String state)`
- `const AnimGraphLocation.transition(String machine, String transition)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `view` | `final AnimGraphView view` |  |
| `machine` | `final String? machine` |  |
| `state` | `final String? state` |  |
| `transition` | `final String? transition` |  |

### `class AnimCompileRow`

One Compiler Results row, with the graph its node lives in.

**Yapıcı Metotlar (Constructors):**

- `const AnimCompileRow(this.diagnostic, this.location, this.nodeTitle)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `diagnostic` | `final LuminaBlueprintDiagnostic diagnostic` |  |
| `location` | `final AnimGraphLocation? location` |  |
| `nodeTitle` | `final String? nodeTitle` |  |

### `class AnimBlueprintEditorViewModel`

The Animation Blueprint editor's state: lumina's [LuminaAnimBlueprintDocument] from the ANIM_BLUEPRINT `.lmas`, its AnimGraph / state machine / transition rules / update event graph, compile through lumina's validator and generator, and a live preview of the Blueprint on its target mesh. Every edit is one undo step.

**Yapıcı Metotlar (Constructors):**

- `AnimBlueprintEditorViewModel({required super.assetPath})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `ruleAccepts` | `static bool ruleAccepts(LuminaBlueprintNodeSpec spec)` | A transition rule takes pure nodes and its Result only. |
| `isDirty` | `bool get isDirty` |  |
| `revision` | `int get revision` |  |
| `blendSpacePaths` | `List<String> get blendSpacePaths` |  |
| `clipAssets` | `List<RealAssetInfo> get clipAssets` | [clips] as assets for the shared asset picker: the project's animation asset of that name (with its thumbnail) where one exists, otherwise the clip inside the target mesh (`<mesh>#<clip>`). |
| `blendSpaceAssets` | `List<RealAssetInfo> get blendSpaceAssets` | [blendSpacePaths] as assets for the shared asset picker. |
| `selectedState` | `String? get selectedState` |  |
| `selectedTransition` | `String? get selectedTransition` |  |
| `selectedVariable` | `String? get selectedVariable` |  |
| `compileStatus` | `BlueprintCompileStatus get compileStatus` |  |
| `compileRows` | `List<AnimCompileRow> get compileRows` |  |
| `generatedCode` | `String get generatedCode` |  |
| `availableSkeletalMeshes` | `List<RealAssetInfo> get availableSkeletalMeshes` | Available skeletal meshes in the project for target mesh selection. |
| `undo` | `void undo()` |  |
| `redo` | `void redo()` |  |
| `className` | `static String className(String rawName)` | The Dart class the Blueprint [rawName] compiles into ([dartTypeName]: `ABP_Character` → `AbpCharacter`). |

## `lib/ui/features/sub_editors/view_models/blend_space_editor_view_model.dart`

### `class BlendSpaceEditorViewModel`

The Blend Space editor's state: lumina's [LuminaBlendSpaceDocument] from the BLEND_SPACE `.lmas`, axes, samples dropped from the target mesh's clips and snapped to the grid divisions, and a preview point whose nearest sample the preview mesh plays (lumina's nearest-sample-plus-crossfade, never a weighted blend). Every edit is one undo step.

**Yapıcı Metotlar (Constructors):**

- `BlendSpaceEditorViewModel({required this.assetPath})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `assetPath` | `final String assetPath` |  |
| `projectDir` | `late final String? projectDir` |  |
| `transactions` | `final TransactionManager transactions` |  |
| `preview` | `final AnimPreviewScene preview` |  |
| `name` | `String get name` |  |
| `relativePath` | `String get relativePath` |  |
| `document` | `LuminaBlendSpaceDocument get document` |  |
| `targetMesh` | `String get targetMesh` |  |
| `clips` | `List<String> get clips` |  |
| `divisionsX` | `int get divisionsX` |  |
| `divisionsY` | `int get divisionsY` |  |
| `selectedSample` | `int? get selectedSample` |  |
| `previewPoint` | `(double, double) get previewPoint` |  |
| `is2D` | `bool get is2D` |  |
| `isDirty` | `bool get isDirty` |  |
| `nearestSample` | `LuminaBlendSpaceSample? get nearestSample` | The sample the preview point picks. |
| `previewClip` | `String? get previewClip` | The clip the preview mesh plays now. |
| `load` | `Future<void> load() async` |  |
| `save` | `Future<bool> save() async` |  |
| `undo` | `void undo()` |  |
| `redo` | `void redo()` |  |
| `setAxis` | `bool setAxis(int index, {String? name, double? min, double? max})` |  |
| `setDivisions` | `void setDivisions({int? x, int? y})` |  |
| `setDimensions` | `bool setDimensions(int count)` | Makes the Blend Space one-dimensional (Direction only) or adds a second axis. |
| `addSample` | `int? addSample(String clip, double x, double y)` | Drops [clip] at ([x], [y]), snapped to the grid divisions. |
| `selectSample` | `void selectSample(int? index)` |  |
| `beginSampleDrag` | `void beginSampleDrag(int index)` |  |
| `dragSample` | `void dragSample(int index, double x, double y)` | Moves sample [index] to ([x], [y]) snapped to the divisions (live, during a drag). |
| `endSampleDrag` | `void endSampleDrag()` |  |
| `setSample` | `bool setSample(int index, {String? clip, double? x, double? y})` |  |
| `removeSample` | `bool removeSample(int index)` |  |
| `setPreviewPoint` | `void setPreviewPoint(double x, double y)` | Moves the preview point (not snapped); the preview mesh blends to the nearest sample. |
| `attachPreviewWorld` | `void attachPreviewWorld(LuminaWorld world)` |  |
| `detachPreviewWorld` | `void detachPreviewWorld(LuminaWorld world)` |  |
| `startHeadlessPreview` | `void startHeadlessPreview({bool ticker = true})` |  |

## `lib/ui/features/sub_editors/views/anim_blueprint/anim_blueprint_sub_editor.dart`

### `class AnimBlueprintSubEditor`

The Animation Blueprint editor: preview viewport and My Blueprint on the left, the AnimGraph / state machine / state pose / transition rule / EventGraph in the centre with breadcrumbs, Details on the right, Compiler Results and the Anim Preview Editor at the bottom.

**Yapıcı Metotlar (Constructors):**

- `const AnimBlueprintSubEditor({super.key, required this.assetName, required this.assetPath, this.onClose, this.onBind, this.viewModel, this.onAssetsModified, thi...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `assetName` | `final String assetName` |  |
| `assetPath` | `final String assetPath` |  |
| `onClose` | `final VoidCallback? onClose` |  |
| `onBind` | `final SubEditorBindCallback? onBind` |  |
| `viewModel` | `final AnimBlueprintEditorViewModel? viewModel` |  |
| `onAssetsModified` | `final VoidCallback? onAssetsModified` |  |
| `showPreviewViewport` | `final bool showPreviewViewport` | False shows the preview's state as text instead of mounting the Filament viewport; the preview still runs, in a world without a renderer (widget tests, where a native viewport never settles). |

### `class AnimBlueprintSubEditorState`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `AnimBlueprintEditorViewModel get viewModel` |  |

## `lib/ui/features/sub_editors/views/anim_blueprint/anim_graph_view.dart`

### `class AnimGraphOutputView`

The AnimGraph: the state machine node feeding Output Pose, as lumina's anim blueprint document defines it (the first state machine drives the pose). Double-clicking the state machine opens it.

**Yapıcı Metotlar (Constructors):**

- `const AnimGraphOutputView({super.key, required this.viewModel})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final AnimBlueprintEditorViewModel viewModel` |  |

## `lib/ui/features/sub_editors/views/anim_blueprint/anim_preview_editor.dart`

### `class AnimPreviewEditorPanel`

The Anim Preview Editor: the stand-in owner's speed, direction and falling state (what Get Velocity / Is Falling return to the update graph), and per-variable overrides that pin a variable (the update graph stops writing it) while the preview runs.

**Yapıcı Metotlar (Constructors):**

- `const AnimPreviewEditorPanel({super.key, required this.viewModel})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final AnimBlueprintEditorViewModel viewModel` |  |

## `lib/ui/features/sub_editors/views/anim_blueprint/create_anim_asset_dialog.dart`

### `enum AnimAssetKind`

Which animation asset the Content Browser's Animation menu creates.

**Değerler:**

- `animBlueprint`
- `blendSpace`

### `class CreateAnimAssetDialog`

**Yapıcı Metotlar (Constructors):**

- `const CreateAnimAssetDialog({super.key, required this.projectDir, required this.kind, required this.onCreated, required this.onCancel,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `projectDir` | `final String projectDir` |  |
| `kind` | `final AnimAssetKind kind` |  |
| `onCreated` | `final ValueChanged<String> onCreated` |  |
| `onCancel` | `final VoidCallback onCancel` |  |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `showCreateAnimAssetDialog` | `void showCreateAnimAssetDialog(BuildContext context, {required String projectDir, required AnimAssetKind kind,...` | Content Browser → Animation → Animation Blueprint / Blend Space: pick the target skeletal mesh and a name, then write `ABP_*.lmas` / `BS_*.lmas` next to the mesh's clips. [onCreated] gets the new asset's project relative path. |

## `lib/ui/features/sub_editors/views/anim_blueprint/state_machine_graph.dart`

### `abstract final class AnimStateLayout`

Geometry of the state machine canvas, shared by the painter, the widgets and hit-testing.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `stateSize` | `static const Size stateSize` |  |
| `entrySize` | `static const Size entrySize` |  |
| `stateRect` | `static Rect stateRect(LuminaAnimState s)` |  |
| `entryRect` | `static Rect entryRect(LuminaAnimStateMachine m)` |  |
| `arrow` | `static (Offset, Offset)? arrow(LuminaAnimStateMachine m, LuminaAnimTransition t)` | Where the arrow of [t] runs: centre to centre, shifted sideways when the opposite transition exists so both arrows show, clipped to the rects. |

### `class AnimStateMachineGraph`

A state machine graph (e.g. a "Locomotion" graph): states, the Entry node, transition arrows with rule markers, the preview's active state highlighted. Right-click adds a state; dragging from a state's handle to another state adds a transition; double-clicking a state opens its pose and a marker opens its rule.

**Yapıcı Metotlar (Constructors):**

- `const AnimStateMachineGraph({super.key, required this.viewModel})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final AnimBlueprintEditorViewModel viewModel` |  |

### `class AnimStateMachineGraphState`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `frameAll` | `void frameAll()` | Centres the Entry node and every state in the view (on open, and F). |
| `vm` | `AnimBlueprintEditorViewModel get vm` |  |
| `toScreen` | `Offset toScreen(Offset canvas)` |  |
| `stateCenter` | `Offset? stateCenter(String name)` | Screen (widget-local) centre of state [name], for tests and drags. |
| `handleCenter` | `Offset? handleCenter(String name)` | Screen position of state [name]'s transition handle. |
| `transitionMarker` | `Offset? transitionMarker(String id)` | Screen position of transition [id]'s rule marker. |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `showRenameState` | `void showRenameState(BuildContext context, AnimBlueprintEditorViewModel vm, String name)` | Renames a state from a dialog. |

## `lib/ui/features/sub_editors/views/anim_blueprint/state_pose_editor.dart`

### `class AnimStatePoseEditor`

A state's pose (a state graph, reduced to what lumina's anim blueprints play): Play Clip from the target mesh's clips, a Blend Space Player on Blend Spaces made for this mesh sampled by X / Y variables with a play rate from a speed variable, or Hold Pose.

**Yapıcı Metotlar (Constructors):**

- `const AnimStatePoseEditor({super.key, required this.viewModel, required this.state})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final AnimBlueprintEditorViewModel viewModel` |  |
| `state` | `final String state` |  |
| `shortName` | `static String shortName(String? path)` |  |

## `lib/ui/features/sub_editors/views/blend_space/blend_space_grid.dart`

### `class BlendSpaceClipDrag`

What a clip row carries when dragged onto a Blend Space grid.

**Yapıcı Metotlar (Constructors):**

- `const BlendSpaceClipDrag(this.clip)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `clip` | `final String clip` |  |

### `class BlendSpaceGridGeometry`

Axis values ↔ grid pixels for a Blend Space of one or two axes.

**Yapıcı Metotlar (Constructors):**

- `const BlendSpaceGridGeometry(this.document, this.size)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `padding` | `static const EdgeInsets padding` |  |
| `document` | `final LuminaBlendSpaceDocument document` |  |
| `size` | `final Size size` |  |
| `is2D` | `bool get is2D` |  |
| `area` | `Rect get area` |  |
| `xAxis` | `LuminaBlendSpaceAxis get xAxis` |  |
| `yAxis` | `LuminaBlendSpaceAxis get yAxis` |  |
| `toPixel` | `Offset toPixel(double x, double y)` |  |
| `toValue` | `(double, double) toValue(Offset pixel)` |  |

### `class BlendSpaceGrid`

The Blend Space grid (the Blend Space editor canvas): axes with their divisions, the samples (dragged clips) and the preview point. The sample nearest the preview point is highlighted: lumina plays the nearest sample with a crossfade, not a weighted blend.

**Yapıcı Metotlar (Constructors):**

- `const BlendSpaceGrid({super.key, required this.document, required this.point, this.highlightClip, this.readOnly = false, this.divisionsX = 4, this.divisionsY =...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `document` | `final LuminaBlendSpaceDocument document` |  |
| `point` | `final (double, double) point` |  |
| `highlightClip` | `final String? highlightClip` |  |
| `readOnly` | `final bool readOnly` |  |
| `divisionsX` | `final int divisionsX` |  |
| `divisionsY` | `final int divisionsY` |  |
| `selectedSample` | `final int? selectedSample` |  |
| `onDropClip` | `final void Function(String clip, double x, double y)? onDropClip` |  |
| `onSelectSample` | `final ValueChanged<int>? onSelectSample` |  |
| `onSampleDragStart` | `final ValueChanged<int>? onSampleDragStart` |  |
| `onSampleDrag` | `final void Function(int index, double x, double y)? onSampleDrag` |  |
| `onSampleDragEnd` | `final VoidCallback? onSampleDragEnd` |  |
| `onPointChanged` | `final void Function(double x, double y)? onPointChanged` |  |

### `class BlendSpaceGridState`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `geometry` | `BlendSpaceGridGeometry get geometry` |  |
| `globalOf` | `Offset globalOf(double x, double y)` | Global position of axis values ([x], [y]) on screen, for tests and drags. |

## `lib/ui/features/sub_editors/views/blend_space/blend_space_sub_editor.dart`

### `class BlendSpaceSubEditor`

The Blend Space editor: the target mesh's clips on the left to drag onto the grid, the grid with samples snapped to its divisions and a preview point, the preview viewport playing the nearest sample, and axis / sample details.

**Yapıcı Metotlar (Constructors):**

- `const BlendSpaceSubEditor({super.key, required this.assetName, required this.assetPath, this.onClose, this.onBind, this.viewModel, this.showPreviewViewport = tr...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `assetName` | `final String assetName` |  |
| `assetPath` | `final String assetPath` |  |
| `onClose` | `final VoidCallback? onClose` |  |
| `onBind` | `final SubEditorBindCallback? onBind` |  |
| `viewModel` | `final BlendSpaceEditorViewModel? viewModel` |  |
| `showPreviewViewport` | `final bool showPreviewViewport` | False shows the preview's clip as text instead of mounting the Filament viewport (see AnimBlueprintSubEditor.showPreviewViewport). |

### `class BlendSpaceSubEditorState`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `BlendSpaceEditorViewModel get viewModel` |  |

## `lib/ui/features/sub_editors/widgets/anim_blueprint_retarget_modal.dart`

### `class AnimBlueprintRetargetModal`

Modal dialog for retargeting an Animation Blueprint and all its linked animation clips and Blend Spaces onto another skeletal mesh character.

**Yapıcı Metotlar (Constructors):**

- `const AnimBlueprintRetargetModal({super.key, required this.viewModel, this.initialTargetMeshPath, this.onCompleted,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final AnimBlueprintEditorViewModel viewModel` |  |
| `initialTargetMeshPath` | `final String? initialTargetMeshPath` |  |
| `onCompleted` | `final VoidCallback? onCompleted` |  |

---

[Önceki: Alt editör altyapısı](framework.md) | [Üst: Alt editörler](index.md) | [Sonraki: Ses editörü](audio.md)
