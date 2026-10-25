# Değişiklik Günlüğü

Yakala'daki tüm önemli değişiklikler bu dosyada, en yeni sürüm en üstte olacak şekilde listelenir.
Biçim [Keep a Changelog](https://keepachangelog.com/tr-TR/1.1.0/) düzenine, sürüm numaraları
[Anlamsal Sürümleme](https://semver.org/lang/tr/) kurallarına dayanır.

İndirmek için: [Releases](https://github.com/mugione/Yakala/releases)

## [Yayınlanmamış]

### Düzeltilenler
- Aynı anda yalnızca bir Yakala çalışır: başka bir kopya (ör. DMG'deki) açılırsa menü çubuğunda ikinci simge
  belirmez, yeni açılan kendini kapatır.

## [1.4.1] - 2026-10-25

### Güvenlik
- Yakala artık **Apple Developer ID ile imzalı ve Apple tarafından noterlenmiş** olarak dağıtılır
  (Team ID `H86X88P8FK`). İlk açılıştaki "Yakala açılamadı" uyarısı ve "Yine de Aç" adımı kalktı.
- DMG de imzalı; noter onayı DMG'ye iliştirildiği için internet olmadan da doğrulanır.

### Değişenler
- Uygulamanın içeriği 1.4 ile aynı. İmza değiştiği için güncellemeden sonra ekran kaydı izni bir kez daha
  verilmeli; sonraki imzalı sürümlerde izin korunur.

## [1.4] - 2026-10-24

### Eklenenler
- **Güzelleştir:** Düzenleyicinin altındaki ✨ düğmesi sağda bir panel açar ve görüntüyü renkli bir
  arka planın ortasına yerleştirir. Kopyala ve Kaydet sonucu bu hâliyle çıkarır.
  - 8 hazır arka plan: Yakala, Gün batımı, Okyanus, Nane, Şeftali, Gece, Açık gri ve Saydam.
  - Boşluk, köşe yuvarlaklığı ve gölge kaydırıcıları.
  - Oranlar: Otomatik, 16:9, 4:3, 1:1; görüntü hep ortada kalır.
  - İsteğe bağlı macOS pencere çerçevesi (●●●). Pencere yakalamalarında pencerenin kendi şekli kullanılır.
  - Son seçilen ayarlar hatırlanır.

## [1.3] - 2026-10-24

### Eklenenler
- **Etiket aracı (`L`):** Yazıyı renkli, yuvarlak köşeli bir kutunun içine koyar; yazı rengi kutuya göre
  kendiliğinden beyaz ya da siyah olur. Karmaşık ekranlarda da okunur kalır.
- **Büyüteç (`M`):** Bir bölgeyi yuvarlak bir mercekte 2 kat büyütür. Bulanıklaştırılan ya da
  pikselleştirilen bölgeler mercekte de gizli kalır.
- **Damga (`D`):** ✓ ✗ ? ! işaretleri. Tür, düğmenin yanındaki küçük oktan seçilir; renk işarete göre
  kendiliğinden ayarlanır.
- **Hızlı mod:** Ayarlar › Yakaladıktan sonra: *Düzenleyiciyi aç*, *Hemen panoya kopyala* ya da
  *Hemen kayıt klasörüne kaydet*. Hızlı modda son görüntü menüden yine düzenlenebilir.
- **Kısayolları değiştirme:** Ayarlar › Kısayollar'dan alan ve pencere seçiminin kısayolları
  değiştirilebilir; çakışan ya da başka uygulamanın kullandığı kısayollar için uyarı gösterilir.

### Değişenler
- Düzenleyici penceresinin en küçük genişliği, 13 aracın tek satıra sığması için artırıldı.
- Menüdeki ve menü çubuğu simgesinin ipucundaki kısayollar ayarlara göre gösterilir.

## [1.2] - 2026-10-24

### Eklenenler
- **Pencere yakalama:** **⇧⌘1**'e bas ve bir pencereye tıkla; alan seçerken **Boşluk** tuşu da pencere
  seçimine geçer. Pencerenin yuvarlak köşeleri saydam olarak alınır.
- **Vurgulayıcı (`H`):** Yarı saydam fosforlu kalem; hep diğer şekillerin altında çizilir.
  Shift ile düz çizgi.
- **Numara aracı (`N`):** Her tıklamada sıradaki numarayı (①②③) koyar.
- Menüye **Pencere Seç** eklendi.

### Değişenler
- **Kaydet (⌘S)** ve **Farklı Kaydet (⇧⌘S)** de Kopyala gibi pencereyi kapatır, "Kaydedildi"
  bildirimi gösterir ve önceki uygulamaya döner. Kaydetme penceresinde vazgeçilirse düzenleyici açık kalır.

## [1.1] - 2026-10-24

### Güvenlik
- Yakala artık macOS **App Sandbox**'ında, **ağ izni olmadan** çalışır: internete bağlanamaz.
  İzinler [`Support/Yakala.entitlements`](Support/Yakala.entitlements) dosyasında.
- Uygulama, notarization için gereken sertleştirilmiş çalışma ortamıyla (hardened runtime) imzalanır.
- Her sürümün DMG'si için bir **SHA-256 özeti** (`.sha256`) yayımlanır.
- [SECURITY.md](SECURITY.md) eklendi: güvenlik açığı bildirme yolu ve güvenlik modeli.

### Değişenler
- Varsayılan kayıt klasörü gerçek `~/Pictures/Yakala` klasörüdür; seçilen başka bir klasör sandbox'ta
  güvenli yer imiyle hatırlanır.
- 1.0'dan güncellerken ekran kaydı izni bir kez daha verilmeli; ayarlar varsayılana döner.

## [1.0] - 2026-10-24

İlk sürüm.

### Eklenenler
- Menü çubuğunda çalışan, Dock'ta görünmeyen ekran görüntüsü aracı.
- **⇧⌘2** ile dondurulmuş ekran üzerinde alan seçimi; tek tıkla tüm ekran; birden fazla ekran desteği.
- Düzenleyici: ok, dikdörtgen, yuvarlak, kalem, metin, bulanıklaştırma ve pikselleştirme; 7 renk,
  3 kalınlık; şekilleri seçme, taşıma ve silme; geri al / yinele.
- **Kopyala (⌘C)** panoya kopyalar, pencereyi kapatır ve önceki uygulamaya döner.
- **Kaydet** ve **Farklı Kaydet**; isteğe bağlı otomatik kayıt ve kayıt klasörü seçimi.
- Ayarlar: Mac açılınca başlatma, kayıt klasörü, otomatik kayıt.
- Hakkında paneli, uygulama simgesi ve tek dosyalık DMG kurulumu.

[Yayınlanmamış]: https://github.com/mugione/Yakala/compare/v1.4.1...HEAD
[1.4.1]: https://github.com/mugione/Yakala/releases/tag/v1.4.1
[1.4]: https://github.com/mugione/Yakala/releases/tag/v1.4
[1.3]: https://github.com/mugione/Yakala/releases/tag/v1.3
[1.2]: https://github.com/mugione/Yakala/releases/tag/v1.2
[1.1]: https://github.com/mugione/Yakala/releases/tag/v1.1
[1.0]: https://github.com/mugione/Yakala/releases/tag/v1.0
