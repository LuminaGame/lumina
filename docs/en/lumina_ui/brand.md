# Brand: the Prism L

Lumina's mark is the **Prism L**: a slanted stem with a lit top facet, a foot that tilts up to the light and a faint under-shard, in three blues. It replaced the faceted star burst in 2026-10.

## Geometry and colours

The mark lives on a 100 × 100 grid (`lumina_ui/assets/brand/prism_l.svg`):

| Facet | Points | Colour |
|---|---|---|
| stem | `26,12 46,19 46,74 26,67` | `#31A5DA` (blueDeep) |
| top facet | `26,12 46,19 54,8 34,1` | `#81C8E8` (blueLight) |
| foot | `46,74 88,60 88,46 46,60` | `#5DB8E1` (blueMid) |
| foot facet | `46,60 88,46 80,38 46,50` | `#81C8E8` (blueLight) |
| under-shard | `26,67 46,74 46,88 26,81` | `#31A5DA` at 55 % |

No spark, no highlight lines: the light is only in the three blues. The mono mark (`prism_l_mono.svg`, `LuminaMark(mono: true)`) is one colour and drops the under-shard.

## Lockup and wordmark

- **Lockup** (`LuminaLockup`): the mark at 30 px beside `LUMINA` (weight 800, 12 px, 0.12 em tracking) over `Studio` (weight 600, 10 px, muted). Used in the menu bar, the launcher header, the splash screens.
- **Compact lockup** (`compact: true`): the mark and `LUMINA` on one line, for the status bar and small headers.
- **Wordmark alone**: `LUMINA`, weight 800, 0.1 em tracking, for the about box and documents.

Clear space is half the mark's height on every side; the minimum size is 11 px (the status bar), where the facets still read.

## App icons

Every icon the project ships is rendered from the one SVG by `dart run tool/brand/render_icons.dart` (`--check` fails CI when one is stale):

| Output | Size | Notes |
|---|---|---|
| `assets/app_icon.png`, `assets/brand/icon-512-linux.png` | 512 | the mark on a `#0F1013` badge, 22 % corner radius |
| `windows/runner/resources/app_icon.ico` | 16, 24, 32, 48, 64, 128, 256 | Windows taskbar, `.exe` resource, Inno Setup |
| `assets/brand/store_logo.png` | 300 | the Microsoft Store logo (`msix_config.logo_path`), opaque |
| `macos/Runner/Assets.xcassets/AppIcon.appiconset/*` | 16–1024 | named by its `Contents.json`, rounded badge |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/*` | 20–1024 | square badge (iOS masks it); the 1024 marketing icon has no alpha |
| `assets/brand/favicon-16.png`, `favicon-32.png`, `web/favicon.png` | 16, 32 | |

The Linux package (`installer/linux/nfpm.yaml`) installs `icon-512-linux.png` as the hicolor icon.
