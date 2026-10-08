[English](../../en/lumina_core/index.md)

# lumina_core (saf Dart temeli)

`lumina_core`, Lumina'nın engine'i, Lumina Studio ve eklenti süreçlerinin paylaştığı temeldir. Matematik kurallarını, Lumina'nın dosya formatlarını ve bunları okuyup yazan repository'leri, engine logger'ı, çalışma alanı ve veri yollarını ve renderer gerektirmeyen araç servislerini içerir. Flutter, `dart:ui` ya da FFI bağımlılığı yoktur. Bu yüzden düz bir Dart programı (bir eklenti süreci, bir komut satırı aracı, bir sunucu) bir `.lmproject`, bir level ya da bir `.lmplugin` dosyasını `dart run` ile okuyabilir.

## Mimarideki yeri

`lumina_core`, `lumina`'nın altındadır. Bağımlılıkları yalnızca saf Dart paketleridir: `path`, `crypto`, `yaml`, `pub_semver`, `vector_math` ve `meta`. `lumina` ona bağımlıdır ve onu yeniden dışa aktarır. `package:lumina/lumina.dart` ve `package:lumina/lumina_runtime.dart` önceki kütüphanelerin aynısını dışa aktarır, bu yüzden engine ve oyun kodu değişmez. `lumina_editor_api`, `lumina_ui` ve eklentiler onu doğrudan import eder:

```dart
import 'package:lumina_core/lumina_core.dart';
```

Paket lumina deposunda (`lumina_core/`) durur ve deponun pub workspace'inin bir üyesidir. Bkz. [Katmanlı mimari](../overview/layers.md).

## İçindekiler

| Alan | İçerik | Referans |
| :--- | :--- | :--- |
| Değişim bildirimi | `ChangeSignal`, `Observable<T>`, `ChangeEmitter`, `ObservableValue<T>`: Flutter'sız dinleyiciler, aşağıya bakın | bu sayfa |
| Matematik | `LuminaUnits` (1 birim = 1 cm), `LuminaAxes` (saklanan Z-yukarı, runtime Y-yukarı), Euler ve control-rotation yardımcıları, interpolasyon, `LuminaTransformSnapshot` | [Matematik](math.md) |
| Dosya formatları | `.lmas` asset'leri (`LuminaAsset`, `LuminaAssetSummary`), `.lmproject` manifest'i (`LuminaProject` ve ayarları), level dokümanları (`LuminaLevelDocument`), landscape ve sequencer verisi, `.lmplugin` tanımları (`LuminaPluginDescriptor`, `PluginIsolation`), tema dokümanları, son projeler | [Dosya formatları ve repository'ler](formats.md) |
| Repository'ler | `LuminaLevelRepository` (level `.lmas` dosyaları), `PluginRepository` (eklenti keşfi ve `.lmplugin` doğrulaması) | [Dosya formatları ve repository'ler](formats.md) |
| Servisler | `EngineLoggerService`, `LuminaWorkspace`, `LuminaDataDir`, `LuminaConfigDir`, config JSON dosyaları, asset indeksi, proje editörü build parmak izi ve önbelleği, engine kurulumu ve kaynak kopyalama, glTF paketleyici, primitive GLB fabrikası, TGA çözücü, GLB animasyon birleştirme ve retargeting, oyun ve level şablonları, eklenti paketleme, sürüm asset'leri | [Servisler](services.md), [Servisler (devamı)](services-continued.md) |
| Physics asset'ler | `LuminaPhysicsAssetData` (gövdeler, kısıtlar, devre dışı çiftler; Physics Asset editörünün JSON'u), `LuminaPhysicsAssetGenerator` / `LuminaSkeletonRest` (skinned bir GLB'nin iskeletinden insansı physics asset) | [Ragdoll](../lumina/ragdoll.md) |
| Motion matching | Pose search database'ler: `LuminaPoseSearchDatabaseDocument` / şema / clip'ler, `LuminaGlbAnimationSampler` (CPU'da glTF clip örnekleme ve FK), `LuminaPoseSearchBuilder` (özellikler, normalizasyon, aynalama, arka planda derleme, parmak izi), `LuminaPoseSearchIndex` (budanmış arama, `.posedb` codec'i), `LuminaPoseSearchPoser` (kök hareketi çıkarılmış, aynalı pozlar); testler için `package:lumina_core/testing.dart` içinde `LuminaSyntheticLocomotionRig` | [Motion matching](../lumina/motion-matching.md) |

Kütüphane tek bir barrel'dır: `package:lumina_core/lumina_core.dart`. Dosyalar `lib/src/foundation/`, `lib/src/math/`, `lib/src/formats/`, `lib/src/repositories/` ve `lib/src/services/` altındadır.

## Flutter'sız değişim bildirimi

`lib/src/foundation/observable.dart`, Flutter'ın `Listenable`, `ValueListenable`, `ChangeNotifier` ve `ValueNotifier` tiplerinin aynı üye adlarına sahip saf karşılıklarını tutar:

| Tip | Rolü |
| :--- | :--- |
| `ChangeSignal` | `addListener` / `removeListener`: dinleyicilerine değiştiğini söyleyen bir şey. |
| `Observable<T>` | Güncel bir `value`'su olan bir `ChangeSignal`. |
| `ChangeEmitter` | Olağan `ChangeSignal`: `notifyListeners()` o anda kayıtlı her dinleyiciyi sırayla çağırır (hata fırlatan biri diğerlerini durdurmaz; ilk hata sonra yeniden fırlatılır); `hasListeners`, `dispose()` (ardından dinleyici eklemek bir `StateError`'dır). |
| `ObservableValue<T>` | `value`'su atanabilen bir `Observable`; eşit bir değer atamak kimseyi bilgilendirmez. |

Eklenti süreci API'si (`lumina_plugin_process`) canlı değerleri için bunları kullanır: `PluginProcessContext.pluginSettings`, bir slot butonunun `state`'i, bir menü öğesinin `checked`'i, level'ın `changes`'i. Motor da onlarla haber verir (`LuminaGameInstance`, bir player controller'ın `cursorState`'i, widget alt sisteminin `activeWidgets`'ı, kullanılan GPU). `lumina_widgets` onları Flutter'ın tiplerine ve tiplerinden dönüştürür (`asValueListenable()`, `asListenable()`, `asObservable()`, `asChangeSignal()`); `lumina_editor_api` bu görünümleri yeniden export eder.

## Engine'de kalanlar

`lumina_core` paylaşılan temeldir, engine mantığı değildir. World, actor'ler, component'ler, çarpışma, fizik, AI, animasyon, Blueprint'ler ve kayıt oyunları `lumina`'da kalır. Flutter, renderer, Assimp ya da analyzer gerektiren editör veri katmanı dosyaları (asset ve proje repository'leri, GLB içe aktarma servisi, içe aktarıcılar, küçük resimler, kod üreteçleri) [lumina_editor_data](../lumina_editor_data/index.md) paketindedir. GLB okuyucusunun kendisi buradadır (`GlbReader`, saf Dart); engine Filament'in Draco çözücüsünü ve platform görüntü codec'ini `LuminaGlbLoader` ile ekler.

İki `lumina_core` tipinin `lumina`'da engine tarafı eklemeleri vardır; bunları `package:lumina/lumina.dart` dışa aktarır:

- **Level Blueprint'leri.** Bir level dokümanı Level Blueprint'ini JSON olarak saklar: `LuminaLevelDocument.levelBlueprintJson`, `hasLevelBlueprint` ve `LuminaLevelDocument.levelBlueprintKey` (`'levelBlueprint'`). Engine'in `lib/src/blueprint/level_blueprint_storage.dart` dosyası onu kendi graf tipine okur. `LuminaLevelDocument` üzerine `levelBlueprint` getter ve setter'ını ve `levelActorRefs`'i, `LuminaLevelRepository` üzerine `loadLevelBlueprint` / `saveLevelBlueprint`'i ekler. Boş bir Blueprint atamak, önceden olduğu gibi anahtarı siler.
- **Tema renkleri.** Bir tema dokümanı renkleri ARGB int (`0xAARRGGBB`) olarak saklar; `colorInt(token)` bir rengi okur. Engine'in `lib/src/umg/theme_document_colors.dart` dosyası Flutter `Color` görünümlerini ekler: `LuminaThemeDocument` üzerinde `colorOf(token)`, `LuminaComponentStyle` üzerinde `bgColor` / `fgColor` / `bColor`.

## Kaldırılan import yolları

Eski yolları bir sürüm boyunca çalışır tutan `@Deprecated` tek satırlık yeniden dışa aktarımlar kaldırıldı; `package:lumina/data/` de artık yok. Bunun yerine barrel'ı import edin:

| Eski yol | Şimdi |
| :--- | :--- |
| `package:lumina/data/models/*.dart` (asset, proje, level, eklenti tanımlayıcısı, landscape, sequencer, tema formatları) | `package:lumina_core/lumina_core.dart` |
| `package:lumina/data/repositories/level_repository.dart`, `plugin_repository.dart` | `package:lumina_core/lumina_core.dart` |
| `package:lumina/data/services/<saf servis>.dart` (workspace yolları, veri/config klasörleri, logger, glTF packer, TGA decoder, …) | `package:lumina_core/lumina_core.dart` |
| `package:lumina/src/math/*.dart`, `package:lumina/src/components/camera/camera_math.dart` | `package:lumina_core/lumina_core.dart` (`lumina.dart` / `lumina_runtime.dart` de yeniden dışa aktarır) |

Level dokümanının ve repository'sinin Level Blueprint extension'ı ile tema dokümanının renk extension'ı `package:lumina/lumina.dart` ve `package:lumina_widgets/lumina_widgets.dart` ile gelir. Lumina Studio'nun `test/architecture/no_deprecated_lumina_paths_test.dart` testi kaldırılmış, derin ya da `@Deprecated` bir Lumina yolunun her import'unda ve engine'de kalmış `@Deprecated` bir kütüphanede başarısız olur.

## Saf bir Dart programından kullanım

```dart
import 'dart:convert';
import 'dart:io';

import 'package:lumina_core/lumina_core.dart';

Future<void> main(List<String> args) async {
  final dir = args.single;
  final manifest = Directory(dir).listSync().whereType<File>().firstWhere((f) => f.path.endsWith('.lmproject'));
  final project = LuminaProject.fromMap(jsonDecode(await manifest.readAsString()) as Map<String, dynamic>);

  final level = LuminaLevelRepository(dir).load(project.activeLevel);
  print('${project.projectName}: ${level?.actors.length ?? 0} actors in ${level?.name}');

  final plugins = await PluginRepository(
    roots: [PluginScanRoot(dir: Directory('$dir/plugins'), origin: PluginOrigin.project)],
  ).scanAll();
  for (final p in plugins.plugins) {
    print('${p.name} ${p.version} runs ${p.effectiveIsolation(project).manifestValue}');
  }
}
```

## Testler

`lumina_core` testleri paket dizininden `flutter test` ile değil, `dart test` ile çalışır:

```bash
cd lumina_core
dart test test/architecture/pure_dart_test.dart test/formats_round_trip_test.dart
```

- `test/architecture/pure_dart_test.dart` paketteki her kütüphanenin import grafını, import ettikleri paketler dahil, dolaşır. `package:flutter`, herhangi bir `flutter_*` paketi, `dart:ui`, `dart:ffi`, `package:ffi` ya da `package:lumina` bulursa başarısız olur. Testin `dart test` altında çalışması kanıtın bir parçasıdır.
- `test/formats_round_trip_test.dart` bir `.lmproject`, actor'leri, world partition'ı ve bir Level Blueprint'i olan bir level ve `isolation` ile `process_class` taşıyan bir `.lmplugin` dosyasını geçici bir klasöre yazar. Her birini okur, geri yazar ve yeniden okur. Ayrıca birimlerin ve eksenlerin engine'in beklediği gibi dönüştüğünü denetler.
- Taşınan dosyaların testleri (modeller, proje ayarları, eklenti izolasyon manifest'i, build önbelleği, kaynak kopyalama, engine kurulumu, çalışma alanı yolları, TGA çözücü, GLB retargeter ve diğerleri) `test/` altında önceki düzenle durur.

---

[Üst: Dokümantasyon dizini](../../README.tr.md) | [Sonraki: Matematik: birimler, eksenler ve dönüşler](math.md)
