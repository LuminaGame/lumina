# Editör ekran kartı

Vulkan ekran kartını seçmek için **Edit → Editor Preferences → General › Graphics Device** bölümünü açın. Liste bu bilgisayarda algılanan cihazları ve **Automatic** seçeneğini içerir. Render motorunun kullandığı mevcut cihaz da gösterilir.

Seçim, launcher ile paylaşılan `launcher_settings.json` dosyasının `graphics_device` alanına hemen kaydedilir. Render oturumuna uygulamak için editörü yeniden başlatın. Proje editörleri ilk render motorunu oluşturmadan önce tercihi okur. Kaydedilen cihaz bulunamazsa otomatik seçim kullanılır.

`FILAMENT_GPU` ve sayısal `VK_DEVICE_INDEX` kayıtlı tercihten önceliklidir. Seçim bu değişkenlerle belirleniyorsa liste devre dışı kalır ve nedenini gösterir. Kayıtlı tercihi kullanmak için değişkeni kaldırıp editörü yeniden başlatın.
