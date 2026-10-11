[English](../../en/lumina_ui/android-quest-packaging.md)

# Android ve Meta Quest paketleme

Bir proje Android APK'sı üretir. **Meta Quest** XR profiliyle bu APK, açıldığında immersive başlayan bağımsız bir gözlük uygulamasıdır. Bu sayfa Android hedefini Project Settings'ten gözlüğe kadar anlatır: ayarlar, derlemenin oluşturduğu manifest, etkin eklentilerin oyun bağımlılığı olan runtime modülleri, imzalama, cook ve bir Quest ile Play on Device.

## Project Settings → Packaging → Android

Target Platforms altında **Android** işaretlenince bir **Android** bölümü çıkar (`.lmproject` `packaging.android`, `lumina_core` içinde `ProjectAndroidSettings`):

| Ayar | Anahtar | Varsayılan |
|---|---|---|
| XR Profile | `xr` | `none` (telefon / tablet); gözlük için `quest` |
| Application Id | `application_id` | boş: `com.lumina.<proje_snake>` |
| Version | `version_name`, `version_code` | `1.0.0`, `1` |
| SDK Levels | `min_sdk`, `target_sdk` | `24` / `34`; Quest: `32` / `34` |
| ABI'ler | `abis` | `arm64-v8a` |
| Refresh Rate (Quest) | `refresh_rate` | `72` (90 ve 120 seçilebilir) |
| Multiview (Quest) | `multiview` | açık |
| Impeller | `impeller` | açık; Quest'te kapalı |
| Signing | `keystore_path`, `key_alias` | boş: Flutter'ın debug anahtarı |

Quest alt sınırları Meta'nın Horizon Store gereksinimlerinden alındı (okuma tarihi 2026-10-11). Yaşam döngüsündeki tüm Quest'ler için minSdk 32 ve targetSdk 34 öneriliyor. 2026-03-01'den sonra Developer Dashboard'da oluşturulan uygulamalar API 34'ü hedeflemek zorunda. Quest profilini seçmek SDK seviyelerini bu sınırlara yükseltir, yalnızca arm64'ü bırakır ve Impeller'ı kapatır.

Keystore parolaları projeye asla yazılmaz. Gradle bunları `LUMINA_ANDROID_KEYSTORE_PASSWORD` ve `LUMINA_ANDROID_KEY_PASSWORD` ortam değişkenlerinden okur; anahtar parolası verilmezse store parolası kullanılır.

**Manifest Preview**, bir sonraki derlemenin oluşturacağı `AndroidManifest.xml`'i salt okunur gösterir. Her satır kaynağını taşır: `template` (Flutter'ın manifesti ve sizin ona yaptığınız düzenlemeler), `project` (projenin ayarları) ya da o satırı ekleyen eklentinin adı.

## Oluşturulan manifest

`AndroidManifestComposer` (`lumina_editor_data/lib/src/packaging/android/`), oyunun `android/app/src/main/AndroidManifest.xml` dosyasını üç girdiden yazar:

1. Flutter'ın şablonu ve sizin onda yaptığınız düzenlemeler;
2. projenin Android ayarları: Impeller kapalıysa bu `io.flutter.embedding.android.EnableImpeller=false` meta-data'sına dönüşür;
3. etkin eklentilerin `android` katkıları (aşağıda).

Eklediği her şey `<!-- BEGIN LUMINA (generated) -->` ile `<!-- END LUMINA (generated) -->` işaretleri arasında durur. Her yer için bir blok vardır: `<manifest>`'ten sonra özellikler ve izinler, queries, launcher aktivitesinin MAIN intent filtresi ve `<application>` meta-data'ları. Yeniden oluştururken önce bu bloklar silinir. Böylece blokların dışındaki düzenlemeleriniz kalır ve dosya büyümez. Bir eklentiyi kapatınca onun eklediği satırlar da gider.

Aktivite öznitelikleri bir yorumun içine konamaz. Bu yüzden doğrudan ana aktivitenin açılış etiketine yazılır. `configChanges` bayrak kümesi olarak birleştirilir. Bir eklentinin yazdığı öznitelik, eklenti kapatıldıktan sonra da kalır.

Çıktı belirlenimcidir: girdiler ada göre sıralanır, tekrarlar birleştirilir. Herhangi bir katkı sahibinin zorunlu kıldığı özellik zorunludur, en yüksek `version` kazanır. Android XR'ın `android.window.PROPERTY_XR_ACTIVITY_START_MODE` özelliği, elle kopyalanmış bir manifestte bile her zaman çıkarılır, çünkü Horizon OS onu yok sayar.

## Bir eklentinin `android` bölümü

Bir eklenti manifest ihtiyaçlarını kendi `.lmplugin` dosyasında bildirir (`lumina_core` içinde `PluginAndroidContributions`):

```json
"android": {
  "uses_features": [
    {"name": "android.hardware.vr.headtracking", "required": true, "version": 1},
    {"name": "com.oculus.feature.PASSTHROUGH", "required": false, "required_when_used": "LuminaMetaPassthroughComponent"},
    {"name": "oculus.software.handtracking", "required": false, "when_used": "LuminaMetaHandTrackingComponent"}
  ],
  "permissions": ["org.khronos.openxr.permission.OPENXR", {"name": "com.oculus.permission.HAND_TRACKING", "when_used": "LuminaMetaHandTrackingComponent"}],
  "intent_categories": ["com.oculus.intent.category.VR", "org.khronos.openxr.intent.category.IMMERSIVE_HMD"],
  "meta_data": [{"name": "com.oculus.supportedDevices", "value": "quest3|quest3s|quest2|questpro"}],
  "queries": ["<provider android:authorities=\"org.khronos.openxr.runtime_broker;org.khronos.openxr.system_runtime_broker\" />"],
  "activity_attributes": {"launchMode": "singleTask", "screenOrientation": "landscape"}
}
```

- `when_used` bir bileşen sınıfı adıdır: girdi yalnızca projenin bir level'ı ya da Blueprint'i o sınıfı kullanıyorsa eklenir.
- `required_when_used`, o sınıf kullanıldığında özelliği zorunlu yapar.
- `queries` girdilerinin her biri tek bir `<provider …/>` ya da `<intent>…</intent>` elemanı olmalıdır.
- Bilinmeyen anahtarlar yoluyla birlikte reddedilir (ör. `android.uses_features[0].requird`), değerler XML kaçışlıdır.

OpenXR eklentisi head tracking'i, VR ve IMMERSIVE_HMD launcher kategorilerini, loader'ın broker izinleri ile queries girdilerini ve immersive bir uygulamanın aktivite özniteliklerini ekler. MetaXR eklentisi `com.oculus.supportedDevices`'ı, passthrough'u (bir level `LuminaMetaPassthroughComponent` kullanıyorsa zorunlu) ve yalnızca kullanıldığında el takibini ekler.

## Runtime modülleri oyun bağımlılığı olur

`"type": "runtime"` modülü olan her etkin eklenti, elle düzenleme gerekmeden oyunun bağımlılığı olur (`RuntimeModuleDependencies`):

- `pubspec.yaml`, eklenti paketlerini `dependencies:` altında `# BEGIN LUMINA PLUGINS (generated)` ile `# END LUMINA PLUGINS` arasında listeler. Remote'u olan bir git checkout'undaki eklenti klasörü URL ve commit ile, diğer klasörler yol ile yazılır.
- Yerelde checkout'u olan bir git eklentisi, gitignore'lu `pubspec_overrides.yaml` içinde o checkout'a sabitlenir. Eklentinin kendi override'larındaki yerel paketler de buraya eklenir. Motor bağlantısı yenilense de bu blok korunur.
- `lib/plugin_runtime_modules.g.dart` her modülün kütüphanesini import eder ve `<registration_class>.register(kPluginRuntimeSettings)` çağırır. Üretilen `main()` önce `registerPluginRuntimeModules()` çalıştırır. Ayar haritası `project_name` ile projenin Android ayarlarını (`xr`, `refresh_rate`, `multiview`, …) taşır.

Bu adımlar her hedefin derlemesinden önce çalışır. Bir eklentiyi kapatıp yeniden derleyince onun bağımlılığı, sabitlemeleri ve kaydı kaldırılır.

## Cook & Package

Motor tarafında Android, Android araç zinciri hazır olduğunda (`flutter doctor`) ve Filament Android arşivleri diskte bulunduğunda derlenebilir. `HostBuildTargets.androidArchivesReason`, `<filament>/out/android-release/filament/lib/arm64-v8a/libfilament.a` dosyasını önce `LUMINA_FILAMENT_DIR` altında, sonra motorun `flutter_filament.filament_dir` hook ayarında arar. Arşivler yoksa gerekçe `dart run tool/filament/fetch_prebuilt.dart --android` komutunu adıyla verir.

Bir Android cook'u şunları yapar:

1. manifesti oluşturur ve Gradle ayarlarını yazar. Application id aynı zamanda namespace olduğu için `MainActivity` o pakete taşınır. SDK seviyeleri, sürümler, bir `abiFilters` bloğu ve keystore varsa release imzası da yazılır. Build Manager günlüğü manifestin değişen satırlarını gösterir;
2. oyun kodunu yeniden üretir;
3. `flutter build apk --release|--debug --target-platform android-arm64` çalıştırır;
4. APK'yı `build/package/android/<proje>-<sürüm>.apk` olarak kopyalar, yanına `.sha256` yazar ve boyutunu bildirir. Mağazanın genişletme dosyası olmadan izin verdiği 1 GB sınırının üstündeki APK'lar için uyarı verilir.

`lumina_editor_data/tool/android_quest/cook_android_quest_test.dart` akışın tamamını bu makinede çalıştırır. Boş bir proje oluşturur, OpenXR ve MetaXR'ı etkinleştirir, bir Quest APK'sı derler ve `aapt2 dump xmltree` ile composer'ın ürettiği her girdinin paketlenmiş manifestte olduğunu doğrular. `LUMINA_ANDROID_COOK=1` ile çalışır, Android SDK yoksa atlanır.

## Meta Quest ile Play on Device

Play açılır menüsü bağlı bir gözlüğü model, Horizon OS sürümü (`ro.hzos.build.display_name`) ve batarya ile listeler. Örneğin `Android 14.0 ("UpsideDownCake") | arm64 | battery 93 %` satırının üstünde `Quest 3S · Horizon OS 2.7.0` yazar. Seçilince şunları yapar:

1. Android uygulamasını projenin Meta Quest profiliyle hazırlar. Proje Quest profilini seçmemişse, profilin varsayılanları yalnızca bu çalıştırma için kullanılır;
2. oyun kodunu yeniden üretir, böylece `main()` eklentilerin runtime modüllerini kaydeder;
3. `flutter build apk --debug --target-platform android-arm64`, ardından `adb -s <seri> install -r …` çalıştırır;
4. uygulamayı `adb -s <seri> shell am start -n <application id>/.MainActivity` ile başlatır;
5. `adb logcat --pid` çıktısını Output Log'a akıtır.

Oyun çalışırken araç çubuğunda **Stop** (`am force-stop`) ve iki yakalama düğmesi vardır:

- kamera düğmesi `adb exec-out screencap -p` ile ekran görüntüsü alır;
- video düğmesi `adb shell screenrecord --time-limit` ile 15 sn kaydeder, dosyayı çeker ve cihazdan siler.

İki yakalama da projenin `Saved/Captures/` klasörüne kaydedilir. Gözlüğü takan biri yokken yakalamalar runtime'ın oluşturduğu görüntüyü gösterir; immersive bir uygulamanın passthrough katmanı orada karanlık görünebilir.

---

[Yukarı: lumina_ui](index.md)
