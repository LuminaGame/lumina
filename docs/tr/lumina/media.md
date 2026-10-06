[English](../../en/lumina/media.md)

# Medya Alt Sistemi (Video & Ses Oynatıcı)

Medya alt sistemi, `media-kit` (libmpv donanım kod çözümü) ile desteklenen, Lumina runtime'ı, UMG widget'ları, Blueprint görsel programlama sistemi ve Lumina Studio arayüzü ile sorunsuz entegre edilmiş yüksek performanslı video ve ses oynatma özellikleri sunar.

Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

- [Mimari & Başlatma](#mimari--başlatma)
- [`lib/src/media/lumina_media.dart`](#libsrcmedialumina_mediadart)
- [`lib/src/media/video/lumina_video_controller.dart`](#libsrcmediavideolumina_video_controllerdart)
- [`lib/src/media/video/lumina_video_player.dart`](#libsrcmediavideolumina_video_playerdart)
- [`lib/src/media/audio/lumina_audio_controller.dart`](#libsrcmediaaudiolumina_audio_controllerdart)
- [`lib/src/media/audio/lumina_audio_player.dart`](#libsrcmediaaudiolumina_audio_playerdart)
- [`lib/src/umg/umg_media_widgets.dart`](#libsrcumgumg_media_widgetsdart)
- [Blueprint Video Node'ları](#blueprint-video-nodeları)
- [Lumina Studio Arayüz Widget'ları](#lumina-studio-arayüz-widgetları)

---

## Mimari & Başlatma

Medya alt sistemi, `media_kit`, `media_kit_video` ve `media_kit_libs_video` üzerine kuruludur:

1. **Donanım Hızlandırma**: Masaüstü (Windows, Linux, macOS) ve mobil platformlarda medya çözme ve video çıktısı yerel libmpv kütüphaneleriyle donanım hızlandırmalı çalışır.
2. **Headless & Test Simülasyonu**: Yerel paylaşımlı kütüphanelerin bulunmadığı headless birim testlerinde veya ortamlarda, `LuminaVideoController` ve `LuminaAudioController` yerel kütüphane mevcudiyetini (`LuminaMedia.isNativeAvailable`) otomatik olarak algılar ve deterministik bir dahili oynatma simülatörüne geçer. Bu sayede test paketleri ve CI hatları mock gerektirmeden çökme yaşamadan çalışır.
3. **Eklenti Uyumluluğu**: Eklentiler (örneğin `gem_x_plugin`), Flutter'ın standart `video_player`'ından doğrudan `LuminaVideoController` ve `LuminaVideoPlayer`'a tam API uyumluluğu (`ValueNotifier<LuminaVideoPlayerValue>`) ile geçiş yapabilir.

---

## `lib/src/media/lumina_media.dart`

### `class LuminaMedia`

Lumina ve Lumina Studio genelinde alt sistem başlatmasını koordine eder.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `ensureInitialized` | `static void ensureInitialized()` | Yerel binding'leri ve medya oynatma kancalarını başlatır. Birden çok kez çağrılması güvenlidir. |
| `isNativeAvailable` | `static bool get isNativeAvailable` | Yerel libmpv çalışma ortamının başarıyla yüklenip yüklenmediğini ve kullanılabilir olup olmadığını döner. |

---

## `lib/src/media/video/lumina_video_controller.dart`

### `class LuminaVideoPlayerValue`

Bir video oynatıcının anlık oynatma durumunun değişmez (immutable) anlık görüntüsüdür.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `isInitialized` | `final bool isInitialized` | Video kaynağının yüklenip başlatıldığını belirtir. |
| `isPlaying` | `final bool isPlaying` | Oynatmanın aktif olarak devam edip etmediği. |
| `isBuffering` | `final bool isBuffering` | Medya akışının arabelleğe alınıp alınmadığı. |
| `isCompleted` | `final bool isCompleted` | Oynatmanın medya sonuna ulaşıp ulaşmadığı. |
| `isLooping` | `final bool isLooping` | Sona ulaşıldığında videonun başa sarıp sarmayacağı. |
| `position` | `final Duration position` | Geçerli oynatma konumu zaman damgası. |
| `duration` | `final Duration duration` | Toplam medya süresi. |
| `size` | `final Size size` | Piksel cinsinden video kare çözünürlüğü. |
| `aspectRatio` | `double get aspectRatio` | Video akışının en/boy oranı (`genişlik / yükseklik`). |
| `volume` | `final double volume` | `0.0` ile `1.0` arasındaki geçerli ses seviyesi. |
| `playbackRate` | `final double playbackRate` | Geçerli oynatma hızı çarpanı (ör. `1.0`, `1.5`, `2.0`). |
| `hasError` | `bool get hasError` | Medya yükleme veya oynatma sırasında hata oluşup oluşmadığı. |
| `errorDescription` | `final String? errorDescription` | Bir hata oluştuysa hata mesajı metni. |

### `class LuminaVideoController`

Video yüklemeyi, donanım hızlandırmalı oynatmayı, zaman çizelgesinde gezinmeyi ve durum bildirimlerini (`ValueNotifier<LuminaVideoPlayerValue>`) yöneten denetleyicidir.

**Yapıcı Metotlar (Constructors):**

- `LuminaVideoController.file(File file, {bool autoPlay = false, bool looping = false, double volume = 1.0, double playbackRate = 1.0, bool preferHeadless = false})`
- `LuminaVideoController.asset(String assetPath, {bool autoPlay = false, bool looping = false, double volume = 1.0, double playbackRate = 1.0, bool preferHeadless = false})`
- `LuminaVideoController.network(String uri, {bool autoPlay = false, bool looping = false, double volume = 1.0, double playbackRate = 1.0, bool preferHeadless = false})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `initialize` | `Future<void> initialize()` | Video kaynağını açar, video akışlarını yapılandırır ve başlatmayı bildirir. |
| `play` | `Future<void> play()` | Video oynatmayı başlatır veya devam ettirir. |
| `pause` | `Future<void> pause()` | Video oynatmayı duraklatır. |
| `stop` | `Future<void> stop()` | Oynatmayı durdurur ve başa (`Duration.zero`) sarar. |
| `seekTo` | `Future<void> seekTo(Duration position)` | Oynatmayı belirtilen hedef zaman konumuna atlatır. |
| `setVolume` | `Future<void> setVolume(double volume)` | Ses seviyesini `0.0` (sessiz) ile `1.0` (maksimum) arasında ayarlar. |
| `setPlaybackRate` | `Future<void> setPlaybackRate(double rate)` | Oynatma hızını ayarlar (`0.25` ile `4.0` arasına sınırlandırılır). |
| `setLooping` | `Future<void> setLooping(bool looping)` | Sürekli döngü halinde oynatmayı açar/kapatır. |
| `dispose` | `Future<void> dispose()` | Yerel oynatıcı tanıtıcılarını, dokuları ve abonelikleri temizler. |

---

## `lib/src/media/video/lumina_video_player.dart`

### `class LuminaVideoPlayer`

Bir `LuminaVideoController` için yerel donanım hızlandırmalı video render yüzeyini yerleştiren Flutter widget'ıdır.

**Yapıcı Metotlar (Constructors):**

- `const LuminaVideoPlayer({super.key, required this.controller, this.fit = BoxFit.contain, this.alignment = Alignment.center, this.filterQuality = FilterQuality.low, this.controls})`

---

## `lib/src/media/audio/lumina_audio_controller.dart`

### `class LuminaAudioPlayerValue`

Konumsal olmayan arka plan müziği, seslendirme veya arayüz ses akışlarının oynatma durumunu temsil eden değişmez durum görüntüsü.

### `class LuminaAudioController`

Görüntü render yükü olmaksızın bağımsız ses akışlarına tahsis edilmiş hafif medya denetleyicisi.

**Yapıcı Metotlar (Constructors):**

- `LuminaAudioController.file(File file, {bool autoPlay = false, bool looping = false, double volume = 1.0, double playbackRate = 1.0, bool preferHeadless = false})`
- `LuminaAudioController.asset(String assetPath, {bool autoPlay = false, bool looping = false, double volume = 1.0, double playbackRate = 1.0, bool preferHeadless = false})`
- `LuminaAudioController.network(String uri, {bool autoPlay = false, bool looping = false, double volume = 1.0, double playbackRate = 1.0, bool preferHeadless = false})`

---

## `lib/src/media/audio/lumina_audio_player.dart`

### `class LuminaAudioPlayer`

Bir ses denetleyicisi için görsel oynatma durumunu ve denetimlerini sağlayan widget.

---

## `lib/src/umg/umg_media_widgets.dart`

Oyun geliştiricilerinin oyun içi UI yerleşimlerinde ve HUD'larında video ve ses oynatıcıları kullanmasını sağlayan UMG runtime widget'ları.

### `class LuminaUmgVideoPlayer`

Oyun içi video oynatma için UMG widget'ı. Dosya/asset/ağ yollarını, otomatik oynatmayı, döngüyü, ses seviyesini, boyut sığdırmayı ve otomatik bellek temizliğini destekler.

### `class LuminaUmgAudioPlayer`

Oyun içi ses ve müzik yönetimi için UMG widget'ı.

---

## Blueprint Video Node'ları

Lumina Blueprint kütüphanesi, `Media` kategorisi altında 11 standart medya node'u içerir:

| Node Adı | Tür | Açıklama |
| :--- | :--- | :--- |
| `Open Video` | Impure | Verilen dosya, asset veya URL yoluna göre isteğe bağlı otomatik oynatma ve döngü bayraklarıyla bir video denetleyicisi oluşturur ya da yeniden açar. |
| `Play Video` | Impure | Hedef denetleyicide video oynatmayı başlatır veya devam ettirir. |
| `Pause Video` | Impure | Hedef denetleyicide video oynatmayı duraklatır. |
| `Stop Video` | Impure | Oynatmayı durdurur ve başa sarar. |
| `Seek Video` | Impure | Oynatmayı milisaniye cinsinden belirli bir zamana atlatır. |
| `Set Video Volume` | Impure | Ses seviyesini `0.0` ile `1.0` arasında ayarlar. |
| `Set Video Rate` | Impure | Oynatma hız çarpanını ayarlar (`0.25` - `4.0`). |
| `Set Video Looping` | Impure | Döngü durumunu değiştirir. |
| `Is Video Playing` | Pure | Videonun şu anda oynatılıp oynatılmadığını belirten mantıksal değer döner. |
| `Get Video Position` | Pure | Geçerli oynatma konumunu milisaniye cinsinden döner. |
| `Get Video Duration` | Pure | Toplam video süresini milisaniye cinsinden döner. |

---

## Lumina Studio Arayüz Widget'ları

`lumina_ui` paketinden export edilen arayüz bileşenleri (`package:lumina_ui/lumina_ui.dart` ve `lib/ui/core/widgets/media/editor_media_widgets.dart`):

1. **`LuminaVideoPlayerWidget`**: `shadcn_flutter` kullanılarak oluşturulmuş kapsamlı video oynatıcı:
   - Donanım video yüzeyi ekranı.
   - Oynat/Duraklat geçişi ve Durdur butonları.
   - Konum ve toplam süre zaman kodları (`00:12 / 01:45`).
   - Etkileşimli ilerleme çubuğu (slider scrubber).
   - Sessize alma geçişi ve dikey ses slider'ı içeren ses popover menüsü.
   - Döngü butonu.
   - Oynatma hızı açılır menüsü (`0.5x`, `1.0x`, `1.25x`, `1.5x`, `2.0x`).
2. **`LuminaAudioPlayerWidget`**: Oynatma çubuğu, zaman kodu, ses seviyesi ve döngü seçenekleri içeren hafif `shadcn_flutter` ses oynatıcı bileşeni.
