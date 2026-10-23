# Marka: Prism L

Lumina'nın işareti **Prism L**: eğik bir gövde, ışık alan bir üst yüz, ışığa doğru kalkan bir ayak ve soluk bir alt kıymık, üç mavide. 2026-10'da çok yüzlü yıldız patlamasının yerini aldı.

## Geometri ve renkler

İşaret 100 × 100 ızgarada yaşar (`lumina_ui/assets/brand/prism_l.svg`):

| Yüz | Noktalar | Renk |
|---|---|---|
| gövde | `26,12 46,19 46,74 26,67` | `#31A5DA` (blueDeep) |
| üst yüz | `26,12 46,19 54,8 34,1` | `#81C8E8` (blueLight) |
| ayak | `46,74 88,60 88,46 46,60` | `#5DB8E1` (blueMid) |
| ayak yüzü | `46,60 88,46 80,38 46,50` | `#81C8E8` (blueLight) |
| alt kıymık | `26,67 46,74 46,88 26,81` | `#31A5DA`, % 55 |

Parıltı ve vurgu çizgisi yok: ışık yalnızca üç mavide. Tek renkli işaret (`prism_l_mono.svg`, `LuminaMark(mono: true)`) tek renktir ve alt kıymığı bırakır.

## Kilit ve yazı markası

- **Kilit** (`LuminaLockup`): 30 px işaretin yanında `LUMINA` (ağırlık 800, 12 px, 0.12 em aralık), altında `Studio` (ağırlık 600, 10 px, soluk). Menü çubuğunda, launcher başlığında ve splash ekranlarında.
- **Sıkışık kilit** (`compact: true`): işaret ve `LUMINA` tek satırda; durum çubuğu ve küçük başlıklar için.
- **Yalnız yazı markası**: `LUMINA`, ağırlık 800, 0.1 em aralık; hakkında kutusu ve belgeler için.

Boş alan her yanda işaret yüksekliğinin yarısı; en küçük boyut 11 px (durum çubuğu), yüzler burada hâlâ okunur.

## Uygulama ikonları

Projenin dağıttığı her ikon tek SVG'den `dart run tool/brand/render_icons.dart` ile üretilir (`--check` biri eskiyse CI'ı düşürür):

| Çıktı | Boyut | Not |
|---|---|---|
| `assets/app_icon.png`, `assets/brand/icon-512-linux.png` | 512 | `#0F1013` rozet üstünde işaret, % 22 köşe yarıçapı |
| `windows/runner/resources/app_icon.ico` | 16, 24, 32, 48, 64, 128, 256 | Windows görev çubuğu, `.exe` kaynağı, Inno Setup |
| `assets/brand/store_logo.png` | 300 | Microsoft Store logosu (`msix_config.logo_path`), opak |
| `macos/Runner/Assets.xcassets/AppIcon.appiconset/*` | 16–1024 | `Contents.json`'ın adlandırdığı dosyalar, yuvarlatılmış rozet |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/*` | 20–1024 | kare rozet (iOS maskeler); 1024 pazarlama ikonunda alfa yok |
| `assets/brand/favicon-16.png`, `favicon-32.png`, `web/favicon.png` | 16, 32 | |

Linux paketi (`installer/linux/nfpm.yaml`) hicolor ikonu olarak `icon-512-linux.png`'yi kurar.
