[English](../../en/lumina_editor_data/index.md)

# lumina_editor_data (editör veri katmanı)

`lumina_editor_data`, Lumina Studio'nun araç veri katmanıdır: editörün okuduğu, yazdığı, içe aktardığı ve ürettiği her şey. Engine'in dışında durur; böylece `lumina`'yı import eden bir oyun bunların hiçbirini taşımaz ve engine editörden bağımsız olarak ele alınabilir.

## Mimarideki yeri

`lumina_editor_data`, engine ile editör arasında durur. `lumina_core`'a (formatlar, yollar, logger), `lumina`'ya (engine: şablonlar, Blueprint tipleri ve kod üreteçlerinin hedefleri), `flutter_filament`'e (ekran dışı thumbnail render'ları), `flutter_assimp`'e (model içe aktarma), `flutter_riglogic`'e (MetaHuman DNA rig'leri), analyzer'a (Blueprint fonksiyon tarayıcısı) ve `package:image`'a bağımlıdır. `lumina_ui` ve editör eklentileri onun üzerine kurulur. Engine onu hiçbir zaman import etmez: `lumina/test/architecture/engine_without_editor_data_test.dart`, `lumina.dart` ve `lumina_runtime.dart`'ın ulaştığı her kütüphaneyi gezer; bunlardan biri `lumina_editor_data`, analyzer, Assimp, RigLogic ya da bir editör repository'si ise başarısız olur. Bkz. [Katmanlı mimari](../overview/layers.md).

Paket widget içermez: `test/architecture/no_widgets_test.dart`, paketin `package:flutter/widgets.dart`, `material.dart`, `cupertino.dart` ya da `shadcn_flutter` import eden herhangi bir kütüphanesinde başarısız olur. Kendi import döngüleri iki dosya çiftiyle sınırlıdır (`test/architecture/import_cycles_test.dart`).

## Kütüphaneler

- `package:lumina_editor_data/lumina_editor_data.dart`: yalnızca editör veri katmanı (bölünmeden önce `lumina.dart`'ın `lib/data` ve `lib/domain`'den export ettikleri).
- `package:lumina_editor_data/lumina_editor.dart`: editör kodu (Lumina Studio, editör eklentileri) için şemsiye kütüphane. `lumina_core`, `lumina`, `lumina_widgets`, `lumina_editor_data`, `flutter_assimp` ve `flutter_riglogic`'i export eder: bölünmeden önce `package:lumina/lumina.dart`'ın export ettiklerini.

```dart
import 'package:lumina_editor_data/lumina_editor.dart';
```

Üretilen oyunlar `package:lumina_widgets/lumina_game.dart`'ı (`kLuminaGameLibrary`) import eder: launcher (`LuminaGameHost` gösteren ve `LuminaWidgets.ensureInitialized()` çağıran `main.dart`), level'lar, `input/project_input.g.dart`, karakter ve game mode ile UMG widget sınıfları. Derlenmiş Blueprint sınıfları ve kayıtları yalnızca motoru kullanır ve `package:lumina/lumina_runtime.dart`'ı import eder.

## Neleri barındırır

| Alan | İçerik | Referans |
| :--- | :--- | :--- |
| Repository'ler | `AssetRepository` (tarama, içe aktarma, aileler, thumbnail'lar, dosya işlemleri), `ProjectRepository` (oluşturma, açma, son projeler, şablonlar), `CollectionsRepository` | [Repository'ler](repositories.md), [Repository'ler (devamı)](repositories-continued.md) |
| İçe aktarıcılar | `AssimpImportService`, `FbxImportService`, `ObjImportService`, `ObjParserService`, `GlbParserService` (içe aktarma temizleyicisi: TGA'dan PNG'ye, doku bütçesi, dört skin etkisi), `ImportQueue`, `ImportFolderScanner`, görüntü dönüştürme, mesh çarpışması, mesh fiziği | [Use case'ler ve servisler](services.md), [bölüm 2](services-continued-2.md), [bölüm 3](services-continued-3.md) |
| Thumbnail'lar | `ThumbnailService`, `FilamentThumbnailRenderer`, thumbnail sidecar geçişi, `ModelFileThumbnailer` / `ModelThumbnailCommand` (projesiz model dosyalarının dosya yöneticisi thumbnail'ları) | [Use case'ler ve servisler](services.md), [bölüm 2](services-continued-2.md), [bölüm 3](services-continued-3.md) |
| Kod üretimi | `DartCodeGeneratorService`, `BlueprintDartGenerator`, `BlueprintFunctionScanner`, `BlueprintFunctionManifest`, `LuminaBlueprintClassRegistry`, `LuminaProjectBlueprintAssets`, base eye height geçişi, uygulama ikonları ve web yükleme ekranı | [Use case'ler ve servisler](services.md), [bölüm 1](services-continued.md), [bölüm 3](services-continued-3.md) |
| Proje editörü build'leri | `EditorHostGeneratorService`, `EditorBuildService` | [Use case'ler ve servisler, bölüm 2](services-continued-2.md) |
| Eklentiler | `PluginRegistryService`, `PluginTemplateGeneratorService` | [Use case'ler ve servisler](services.md) |
| Türetilmiş veri | `DerivedDataCache`, `AssetReferenceGraph` | [Use case'ler ve servisler](services.md), [bölüm 1](services-continued.md) |
| Rig'ler | `RigLogicEvaluator` (MetaHuman DNA yüz rig'leri) | [Use case'ler ve servisler, bölüm 3](services-continued-3.md) |
| Use case'ler | `SaveLevelUseCase`, `GenerateDartCodeUseCase`, `ImportAssetUseCase` ve sonuçları | [Use case'ler ve servisler](services.md) |

Dosyalar `lib/src/repositories/`, `lib/src/services/` ve `lib/src/domain/` altındadır.

## Engine'de kalanlar

Eski `lumina/lib/data` dosyalarının bazıları çalışan bir oyunun ya da Play-In-Editor'ün ihtiyaç duyduklarıdır. Bunlar `lumina`'da kaldı:

- GLB yükleyici (`LuminaGlbLoader`, `lib/src/assets/glb_loader.dart`): lumina_core'un saf `GlbReader`'ı, Filament'in Draco çözücüsü ve platform görüntü codec'iyle. Landscape'in foliage mesh'leri bununla okunur. Buradaki `GlbParserService.parseGlb` aynı okuyucu ile içe aktarma temizleyicisidir;
- kodlanmış görüntü çözücü, level asset manifestosu ve level mesh materyal araması (`lib/src/assets/`);
- proje input binder'ı (`lib/src/input/project_input_binder.dart`).

Bkz. [Yardımcılar](../lumina/utilities.md) ve [Girdi](../lumina/input.md).

## Editör kodunu taşımak

Eski `package:lumina/data/...` ve `package:lumina/domain/...` yolları kaldırıldı. Editör kodu ve eklentiler şemsiye kütüphaneyi, yalnızca onu kullanıyorlarsa daha dar bir paketi import eder:

| Önce | Sonra |
| :--- | :--- |
| `package:lumina/lumina.dart` (editör kodu) | `package:lumina_editor_data/lumina_editor.dart` |
| `package:lumina/data/repositories/asset_repository.dart`, `project_repository.dart` | `package:lumina_editor_data/lumina_editor.dart` |
| `package:lumina/data/services/<servis>.dart` | `package:lumina_editor_data/lumina_editor.dart` |
| `package:lumina/domain/...` | `package:lumina_editor_data/lumina_editor.dart` |

Bunu yapan bir paket `lumina_editor_data`'yı bağımlılıklarına ekler. Yalnızca engine kullanan kod `package:lumina/lumina.dart`'ta kalır; yalnızca formatları (`LuminaAsset`, `LuminaProject`, level'lar, eklenti tanımlayıcıları) okuyan ya da yazan kod `package:lumina_core/lumina_core.dart`'ı ([kaldırılan import yolları](../lumina_core/index.md#kaldırılan-import-yolları)), bir eklentinin süreç bölümü ise `package:lumina_plugin_process/lumina_plugin_process.dart`'ı import eder.

## Testler ve smoke

Veri katmanı testleri `lumina_editor_data/test/` altındadır ve `lumina/test/`'teki düzenlerini korur. Bazıları engine'in kendi test fixture'larını (`lumina/test/blueprint/` altındaki Blueprint belgeleri ve üretilen kod golden'ları) göreli yolla okur. Editör ile engine'i birlikte çalıştıran smoke dosyaları (animasyon, Blueprint, çarpışma, fizik, girdi, türetilmiş veri, domain, paketleme, web) `test/smoke/` altındadır ve her paketin smoke raporu gibi paketin `tool/smoke_report.dart`'ı ile çalışır.

---

[Önceki: Yardımcılar, matematik ve test](../lumina/utilities.md) | [Üst: Lumina dokümantasyonu](../../README.tr.md) | [Sonraki: Veri katmanı: use case'ler ve servisler](services.md)
