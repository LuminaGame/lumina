[English](../../en/lumina/character-slots.md)

# Karakter slotları

Birkaç skinned mesh'ten oluşan bir karakter — gövde, yüz, saç, kaşlar, sakal, giysiler — tek seferde animasyonlanır ve parçaları adlarıyla değiştirilir. Bunu üç parça sağlar:

- **Poz takibi**: bir skeletal mesh her karede liderinin pozunu kemik adına göre alır (`LuminaAnimatedMeshComponent.poseLeader`, Blueprint özelliği `poseFrom`; bkz. [Bileşenler: mesh'ler](components-mesh-and-particles.md)).
- **Slotlar**: `slot` adı taşıyan bileşenler çalışma anında listelenir, doldurulur ve boşaltılır (`LuminaCharacterSlots`, *Character|Slots* Blueprint düğümleri).
- **Gövde maskeleri**: bir giysi slotu altındaki gövde üçgenlerini gizler; ten giysinin içinden çıkmaz.

| Parça | Yer |
| :--- | :--- |
| Slotlar | `lib/src/components/mesh/character_slots.dart` |
| Gövde maskeleri (motor tarafı) | `lib/src/components/mesh/character_slots/body_masks.dart` |
| Maske hesabı, skinned GLB geometrisi, en yakın nokta sorguları | `lumina_core/lib/src/garment/` (`LuminaBodyMask`, `LuminaSkinnedMeshData`, `LuminaTriangleGrid`) |
| Blueprint düğümleri | `lib/src/blueprint/node_library/character_slots.dart`, `lib/src/blueprint/blueprint_function_library/character_slots.dart` |

## Slotlu bir Blueprint

Her parça, aktör Blueprint'inin iki özellikli bir bileşenidir:

| Özellik | Anlamı |
| :--- | :--- |
| `slot` | Slot adı (`Body`, `Face`, `Hair`, `Torso`, …). Boş: slot değil. |
| `poseFrom` | Bu bileşenin pozunu takip ettiği skeletal mesh bileşeninin id'si (yoksa adı); bir Skinned Cloth'ta giyildiği mesh. |
| `masksBody` | İsteğe bağlı: bu slottaki giysi altındaki gövdeyi gizler mi (varsayılan: `Torso`, `Legs`, `Feet` için evet). |

Mesh'i boş bir slot boş bir sahne bileşeni olarak kurulur ve sonra doldurulabilir. MetaHuman eklentisinin bölünmüş dışa aktarımı böyle bir Blueprint yazar: `Root` > `Body` > `Face` > `Eyelashes`, `Eyebrows`, `Beard`, `Fuzz`, `Hair`, `Mustache`, ve `Body` altında `Torso`, `Legs`, `Feet`. Blueprint düzenleyicisinde Details paneli Skeletal Mesh ve Skinned Cloth bileşenlerinde *CHARACTER* altında **Slot** ve **Pose From** gösterir (Blueprint'in diğer skeletal mesh'leri arasından bir seçici; bileşenin kendisi ya da onu zaten takip eden biri asla listelenmez).

`LuminaBlueprintComponents.construct` (Blueprint önizlemesi, PIE'nin VM'i ve üretilen oyun kodu aynı şekilde kullanır) poz liderlerini bağlar ve slotları kaydeder; oyun, düzenleyicinin gösterdiği gibi davranır.

## `class LuminaCharacterSlots`

`LuminaCharacterSlots.of(actor)` (ya da `maybeOf`) aktörün slotlarını verir.

| Üye | Açıklama |
| :--- | :--- |
| `names` | Slot adları, kayıt sırasıyla. |
| `slot(name)` / `component(name)` / `meshOf(name)` | Slot, şu anki bileşeni, kayıtlı mesh referansı (boşsa '', bilinmiyorsa null). |
| `setMesh(name, mesh)` | Slotu doldurur (Blueprint'inki gibi çözülen kayıtlı bir mesh yolu). Bir skeletal mesh mesh'ini **yerinde** değiştirir (`LuminaStaticMeshComponent.setMeshAsset`): animasyonu, Animation Blueprint'i, takipçileri ve çocukları kalır. Boş bir slot, slotun liderini takip eden yeni bir skeletal mesh alır; bir Skinned Cloth slotu yeni giysiyle yeniden kurulur. Yüklenince tamamlanır; bilinmeyen slot için false. |
| `clear(name)` | Slotu boşaltır (çocuklar boş bir bileşenin altında kalır). |
| `register(name, component, {mesh, leaderSlot, properties})` | Dart'ta kurulmuş bir slotu kaydeder. |
| `refreshBodyMask(bodySlot)` | Gövdeyi takip eden giysi slotlarından gövde maskesini yeniden hesaplar. |
| `changes` | Bir slotun bileşeni her değiştiğinde slot adlarının akışı. |

## Gövde maskeleri

Bir giysi slotu (`masksBody`) doldurulunca ya da boşaltılınca, ya da gövdenin kendisi değişince gövde maskesi bir worker isolate'ta yeniden hesaplanır: `LuminaBodyMask.compute`, dışında 4 cm içinde bir giysi yüzeyi olan ve o giysi noktası giysinin açık kenarlarından en az 3 cm uzakta olan gövde köşesini örtülü sayar (yakalar, manşetler ve etekler altındaki ten çizilmeye devam eder); üç köşesi örtülü olan üçgen örtülüdür. `LuminaBodyMask.applyDegenerate`, örtülü üçgenleri dejenere (çizilmeyen) gövde GLB'sinin bir kopyasını yazar ve gövde bileşeni bu kopyayı yerinde çizer (`<gövde yolu>#masked-<özet>`). Kayıtlı mesh maskesiz gövde olarak kalır; giysileri boşaltmak onu geri getirir. Draco ile sıkıştırılmış bir gövde yamalanamaz ve bütün kalır.

## Blueprint düğümleri (*Character|Slots*)

| Düğüm | Pinler |
| :--- | :--- |
| **Set Slot Mesh** | `slot`, `mesh` (asset yolu; '' boşaltır) → sahibin o slotu varsa true; mesh arka planda yüklenir. |
| **Clear Slot** | `slot` → sahibin o slotu varsa true. |
| **Get Slot Mesh** | `slot` → içindeki mesh (boşsa ya da bilinmiyorsa ''). |
| **Get Slots** | → sahibin slot adları. |

Düğümler grafı çalıştıran aktör üzerinde çalışır. VM ve üretilen Dart aynı sonuçları verir (`blueprint_codegen_parity_test.dart`).
