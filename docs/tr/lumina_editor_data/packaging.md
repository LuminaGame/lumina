[English](../../en/lumina_editor_data/packaging.md)

# Paketleme (Android)

`lib/src/packaging/` bir oyunu Android derlemesine hazırlar: manifest, Gradle ayarları ve etkin eklentilerin runtime modülleri. Lumina Studio'nun Build Manager'ı, Project Settings'i ve Play on Device'ı bunu `AndroidPackagingHooks` (lumina_ui) üzerinden çağırır. İş akışı [Android ve Meta Quest paketleme](../lumina_ui/android-quest-packaging.md) sayfasında anlatılır.

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
