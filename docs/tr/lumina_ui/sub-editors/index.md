[English](../../../en/lumina_ui/sub-editors/index.md)

# Alt editörler

Lumina Studio'da her asset tipi kendine ait bir alt editör sekmesinde açılır. Alt editörler aynı MVVM düzenini izler: bir view, bir view model, önizleme ve işleme servisleri ve asset belgesi için modeller.

## Bir alt editör nasıl kurulur

Content browser'dan bir asset açmak, onun alt editörünü ana editörde bir sekme olarak açar. Tüm alt editör kodu `lib/ui/features/sub_editors/` altındadır:

- `views/`: widget'lar. Aynı alana ait view'ler kendi klasörlerinde durur (`views/blueprint/`, `views/landscape/`, `views/material/`, `views/particle/`, `views/sequencer/`, `views/skeletal_mesh/`, `views/umg/`, ...).
- `view_models/`: her alt editör için, asset'i `.lmas` dosyasından yükleyip geri kaydeden bir ChangeNotifier view model.
- `services/`: önizleme sahneleri, decoder'lar, kod üreteçleri ve pipeline'lar.
- `models/`: asset belgesi ve editör durumu tipleri.
- `widgets/`: animasyon dope sheet'i gibi daha büyük, yeniden kullanılabilir widget'lar.

Önizlemeler gerçektir: her 3D önizleme, genellikle bir `LuminaWorld` üzerinden yönetilen canlı bir Filament sahnesidir ve bir editörün gösterdiği değerler oyunun çalıştırdığı engine tiplerinin kendisinden gelir.

### Çalışma alanı düzeni, panel bütünlüğü ve Content Browser çekmecesi

Alt editörler ve eklentiler sekmeler arasında görsel ve davranışsal uyumu garanti eden `SubEditorWorkspaceShell` içerisinde çalışır:
- **Panel ve Ağaç Bütünlüğü**: Sol ve sağ yan paneller Level Editör stilini izler (`EditorColors.sidebar`, `EditorColors.card`, `EditorColors.cardHeader`, `EditorColors.border`). Hiyerarşi, outliner ve varlık ağaçları 22–24 px satır yüksekliği, standart açma/kapama okları ve 10–11 px tipografi belirteçlerine uyar.
- **Yeniden Boyutlandırılabilir Düzenler**: Paneller her zaman `ResizablePanel` ve sürükleyiciler ile yeniden boyutlandırılabilir ve minimum boyut sınırlarına (`minSize: 120-200 px`) sahiptir.
- **Content Browser Etkileşimi**:
  - `contentDroppable`: Etkinleştirildiğinde çalışma alanı kanvası `DragTarget<RealAssetInfo>` olarak çalışır ve sürüklenen mesh, materyal, doku veya Blueprint varlıklarını kabul eder.
  - `contentBrowserOpened`: `true` olduğunda Content Browser sekmenin altında dikey bir `ResizablePanel` olarak kenetlenmiş gelir. `false` olduğunda sol alt köşede klasör çekmece butonu (`LucideIcons.folder`) yer alır; kullanıcı buna tıklayarak alttaki Content Drawer'ı açabilir ve iğne butonuyla sekmeye sabitleyebilir.

## Alt editörler

| Sayfa | Kapsam |
|---|---|
| [Alt editör altyapısı](framework.md) | Ortak 3D önizleme viewport'u, hiyerarşi widget'ı, çalışma alanı modalı, önizleme mesh'leri. |
| [Animasyon editörü](animation.md) | Animasyon alt editörü, dope sheet, retargeting, notify'lar ve eğriler. |
| [Ses editörü](audio.md) | Dalga formu, transport, attenuation eğrisi, WAV decode. |
| [Blueprint editörü](blueprint.md) | Blueprint alt editörü, component ağacı, event graph, component registry'si. |
| [Blueprint editörü (devamı, bölüm 1)](blueprint-continued.md) | `lib/ui/features/sub_editors/models/`, `lib/ui/features/sub_editors/services/`, `lib/ui/features/sub_editors/view_models/`, `lib/ui/features/sub_editors/views/blueprint/` altındaki diğer dosyalar. |
| [Blueprint editörü (devamı, bölüm 2)](blueprint-continued-2.md) | `lib/ui/features/sub_editors/views/blueprint/`, `lib/ui/features/sub_editors/views/blueprint/graph_canvas/`, `lib/ui/features/sub_editors/views/blueprint/timeline/`, `lib/ui/features/sub_editors/views/blueprint_enum/`, `lib/ui/features/sub_editors/views/blueprint_interface/` altındaki diğer dosyalar. |
| [Build yöneticisi](build-manager.md) | Build adımları, doğrulama ve `flutter build` ile Cook & Package. |
| [Çevre ışıklandırması](environment-lighting.md) | Güneş ve günün saati, sky ve IBL, sis ve post-process kontrolleri. |
| [Landscape ve foliage](landscape.md) | Şekillendirme fırçaları, foliage boyama, heightmap asset'leri, arazi önizlemesi. |
| [Materyal editörü](material.md) | GLSL materyal kaynağı, parametreler, derleme ve önizleme. |
| [Navigasyon editörü](navigation.md) | Nav sınır volume'ları, grid bake, yol testi. |
| [Parçacık editörü](particle.md) | Emitter yığını, eğri ve gradient editörleri, canlı önizleme. |
| [Fizik asset editörü](physics-asset.md) | Gövdeler, kısıtlar, çakışma kontrolleri ve fizik önizlemesi. |
| [Proje ayarları](project-settings.md) | `.lmproject` manifest'ini kategori bazında düzenleme. |
| [Sequencer](sequencer.md) | Timeline, track ağacı, eğri editörü, değerlendirme ve film render'ı. |
| [Static ve skeletal mesh editörleri](meshes.md) | Mesh önizlemesi, LOD'lar, çarpışma, materyal slot'ları, socket'ler. |
| [Texture editörü](texture.md) | Texture önizlemesi, mip seviyeleri ve texture ayarları. |
| [Tema editörü](theme.md) | Kullanıcı arayüzü teması oluşturma, renk belirteçleri, bileşen stilleri, özel stiller ve canlı önizleme vitrini. |
| [Widget (UMG) tasarımcısı](umg.md) | Tasarım kanvası, palet, hiyerarşi, slot inspector'ı, widget kod üretimi. |

---

[Önceki: Windows paketleme](../windows-packaging.md) | [Üst: lumina_ui (Lumina Studio)](../index.md) | [Sonraki: Alt editör altyapısı](framework.md)
