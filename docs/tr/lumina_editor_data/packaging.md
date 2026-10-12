[English](../../en/lumina_editor_data/packaging.md)

# Paketleme (Android, NVIDIA DLSS çalışma zamanı)

`lib/src/packaging/` bir oyunu Android derlemesine hazırlar: manifest, Gradle ayarları ve etkin eklentilerin runtime modülleri. Bir proje isterse NVIDIA'nın DLSS çalışma zamanını Windows ve Linux paketlerine de koyar ([aşağıda](#nvidia-dlss-çalışma-zamanı)). Lumina Studio'nun Build Manager'ı, Project Settings'i ve Play on Device'ı bunu `AndroidPackagingHooks` (lumina_ui) üzerinden çağırır. İş akışı [Android ve Meta Quest paketleme](../lumina_ui/android-quest-packaging.md) sayfasında anlatılır.

## `lib/src/packaging/android/android_manifest_composer.dart`

| Üye | Amaç |
| :--- | :--- |
| `AndroidManifestComposer.compose({template, settings, plugins, usedClasses})` | Flutter şablonu + `ProjectAndroidSettings` + her eklentinin `PluginAndroidContributions`'ı → `ComposedAndroidManifest`. Eklenenler her yer için bir blok olarak `begin` / `end` işaretleri arasına yazılır. Yeniden oluştururken önce eski bloklar silinir (`withoutGenerated`). Çıktı sıralanır ve tekrarlar birleştirilir: güçlü olan `required` ve en yüksek `version` kazanır. Aktivite öznitelikleri ana aktiviteye yazılır, `configChanges` birleştirilir. `refusedProperties` (Android XR'ın başlangıç modu) çıkarılır. |
| `ComposedAndroidManifest` | `xml`, `lines` (her biri `source` alanıyla bir `ComposedManifestLine`: `template`, `project` ya da eklenti adı), `summary`. |

## `lib/src/packaging/android/android_gradle_configurator.dart`

`AndroidGradleConfigurator.configure(gradle, settings, projectName)`, `android/app/build.gradle.kts` dosyasını yeniden yazar. Namespace ile application id'yi (tek değer), `minSdk`, `targetSdk`, `versionCode`, `versionName` değerlerini, bir `abiFilters` bloğunu ve imzayı yazar. Keystore varsa imza, parolaları `LUMINA_ANDROID_KEYSTORE_PASSWORD` / `LUMINA_ANDROID_KEY_PASSWORD` ortam değişkenlerinden okuyan bir `luminaRelease` yapılandırmasıyla atılır; yoksa Flutter'ın debug anahtarı kullanılır. `apply(projectDir, settings, projectName)` ayrıca `MainActivity`'yi yeni pakete taşır.

## `lib/src/packaging/runtime_module_dependencies.dart`

| Üye | Amaç |
| :--- | :--- |
| `RuntimeModuleDependencies.resolve(enabled)` | Etkin eklentilerin runtime modülleri, `RuntimeModuleDependency` olarak: paket, kütüphane, kayıt sınıfı, eklenti klasörü bir git checkout'uysa git kaynağı (URL, depodaki yol, HEAD) ve eklentinin kendi `pubspec_overrides.yaml`'ının sabitlediği yerel paketler. |
| `apply(projectDir, deps, {settings})` | Pubspec bloğunu (`pubspecBegin` / `pubspecEnd`), override bloğunu (`ProjectEngineLink.pluginOverridesBegin`; motor bağlantısının zaten sabitlediği paketler atlanır) ve `lib/plugin_runtime_modules.g.dart` dosyasını (`registerPluginRuntimeModules()`, `kPluginRuntimeSettings`) yazar. Boş `deps` üçünü de kaldırır. |

`DartCodeGeneratorService.generateMainDart(pluginRuntimeModules: true)` kayıt dosyasını import eder ve `main()` içinde ilk iş olarak çağırır. `GenerateDartCodeUseCase` bu bayrağı dosya oluştuğunda açar.

## `lib/src/packaging/android/android_packaging.dart`

| Üye | Amaç |
| :--- | :--- |
| `AndroidPackaging.prepare(projectDir, project, plugins)` | Manifesti oluşturur (eklenti koşullarının adlandırdığı bileşen sınıflarını `usedClasses` UI isolate'i dışında tarar), Gradle ayarlarını yazar ve runtime modüllerini uygular. `AndroidPreparation` döndürür; onun `manifestDiff` alanı derleme günlüğü için değişen satırları tutar. |
| `preview(projectDir, project, plugins)` | Bir derlemenin oluşturacağı manifest; hiçbir şey yazılmaz. |
| `applyRuntimeModules(...)` | Yalnızca runtime modülleri; her hedefin derlemesi bunu çalıştırır. |
| `runtimeSettings(project)` | Kayıtlara giden `project_name` ve Android ayarları. |
| `targetPlatforms(settings)` | ABI'lerin `--target-platform` değerleri. |
| `finishPackage(packageDir, projectName, versionName)` | APK'yı `<proje>-<sürüm>.apk` olarak adlandırır, `.sha256` yazar, `storeLimitBytes` (1 GB) üstünde uyarır. |

Gerçek cook çalıştırıcısı `tool/android_quest/cook_android_quest_test.dart` dosyasıdır (`LUMINA_ANDROID_COOK=1`).

---

[Yukarı: lumina_editor_data](index.md)

## NVIDIA DLSS çalışma zamanı

`lib/src/packaging/dlss/`, projenin `packaging.bundle_dlss_runtime` ayarı açıkken NVIDIA'nın DLSS çalışma zamanını paketlenmiş bir Windows ya da Linux oyununa koyar. Lumina Studio bunu Project Settings'in Package Project'i ve Build Manager'ın Cook & Package'ı içinde `DlssPackagingHooks` (lumina_ui) üzerinden çağırır.

| Üye | Amaç |
| :--- | :--- |
| `DlssSdk.locate(projectDir, {fallbackPackageRoots})` | Oyunun derlendiği flutter_filament'in DLSS SDK'sı: projenin `.dart_tool/package_config.json` dosyasının çözdüğü paket (native derlemesi DLSS'i yalnızca o paketin `build/dlss-sdk/` klasörü varsa içerir), yoksa `tool/dlss/` içeren ilk yedek (varsayılan: editörün kaynak checkout'u). Arka plan isolate'ında çalışır. |
| `DlssSdk` | `packageRoot`, `version` (`tool/dlss/VERSION`), `manifest` (`DlssManifestEntry`: SHA-256, boyut, yol), `missing`, `isFetched`, `missingReason` (`dart run tool/dlss/fetch_sdk.dart` ile), `runtimeEntriesFor(target)` (`lib/Windows_x86_64/rel/*` ya da `lib/Linux_x86_64/rel/*`), `verify(entries)` (isolate'ta boyut + SHA-256), `refresh()`. `supportsTarget` yalnızca `windows` ve `linux` için true döner. |
| `DlssRuntimeBundle.bundleInto(sdk, target:, packageDir:)` | Önce hedefin çalışma zamanı kütüphanelerini ve `LICENSE.txt` dosyasını manifeste göre doğrular; uyuşmazlık ya da eksik dosya `DlssBundleRefused` fırlatır ve hiçbir şey kopyalanmaz. Sonra kütüphaneleri düz biçimde çalıştırılabilir dosyanın yanına kopyalar (çalışma zamanı araması `lib/` değil, çalıştırılabilir dosyanın klasörüne bakar), lisansı `NVIDIA_DLSS_LICENSE.txt` olarak koyar ve `NVIDIA_DLSS_NOTICE.txt` yazar (dosyalar, SHA-256'ları, tabi oldukları lisans). Diğer hedefler `skippedReason` içeren bir `DlssBundleReport` döner ve hiçbir şey almaz. `describe(report)` günlük satırlarını verir. |
| `DlssSdkFetcher(baseUrl:).fetch(sdk, onProgress:)` | Manifestteki dosyaları sabitlenmiş etiketten (`https://raw.githubusercontent.com/NVIDIA/DLSS/<tag>/<path>`) `build/dlss-sdk/` içine indirir, `tool/dlss/fetch_sdk.dart` gibi: zaten olan ve eşleşen dosyalar tutulur, her indirme `<file>.part` dosyasına gider, doğrulanır ve yeniden adlandırılır; uyuşmazlık hata fırlatır ve yarım dosya bırakmaz. `DlssSdkFetchProgress` dosya ve bayt ilerlemesini taşır. |

Dosyalar NVIDIA'nındır ve NVIDIA RTX SDKs lisansıyla yeniden dağıtılır (§1c bir uygulamaya katılmış olarak §2 koşullarıyla dağıtıma izin verir; §4b tek başına dağıtımı yasaklar; §4e SDK'yı açık kaynak lisansına tabi kılmayı yasaklar). Bir oyunun bunları dağıtıp dağıtamayacağı geliştiricinin kararıdır; Lumina'nın kendi sürümleri bunları asla içermez.
