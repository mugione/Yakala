# Güvenlik Politikası

## Desteklenen sürümler

Güvenlik düzeltmeleri yalnızca en son sürüme yapılır. Lütfen her zaman
[son sürümü](https://github.com/mugione/Yakala/releases/latest) kullanın.

| Sürüm | Destek |
|---|---|
| 1.5 | ✅ |
| 1.0 – 1.4.1 | ❌ (1.5'e güncelleyin) |

## Güvenlik açığı bildirmek

**Lütfen güvenlik açıklarını herkese açık Issues bölümüne yazmayın.**

1. Depo sayfasında **Security › Report a vulnerability** ile gizli bir bildirim gönderin.
2. Bu seçenek görünmüyorsa, ayrıntı vermeden "Güvenlik: iletişim" başlıklı bir issue açın;
   size gizli bir iletişim yolu bildirilir.

Bildirime şunları eklemeniz işi hızlandırır: Yakala ve macOS sürümü, sorunu tekrar oluşturma
adımları, beklenen ve gerçekleşen davranış. Düzeltme yayımlandığında, isterseniz adınız sürüm
notlarında teşekkürle anılır.

## Yakala'nın güvenlik modeli

- **App Sandbox:** Yakala macOS'un sandbox'ında çalışır. İzinleri
  [`Support/Yakala.entitlements`](Support/Yakala.entitlements) dosyasında; **ağ izni yoktur**, yani
  macOS Yakala'nın internete bağlanmasını engeller.
- **Dosya erişimi:** Yalnızca Resimler klasörü (varsayılan kayıt klasörü `~/Pictures/Yakala`) ve
  kaydetme / klasör seçme pencerelerinde kullanıcının seçtiği konumlar.
- **Ekran kaydı:** Yalnızca kullanıcı ⇧⌘2'ye bastığında ya da menü çubuğu simgesine tıkladığında
  ([`ScreenCapturer.swift`](Sources/Yakala/ScreenCapturer.swift)).
- **Veri toplama:** Yok. Analiz, çökme raporu ya da kullanım verisi gönderilmez.
- **Bağımlılıklar:** Yok. Yalnızca Apple'ın sistem çerçeveleri kullanılır.
- **Kod imzası:** 1.4.1'den itibaren uygulama ve DMG Apple Developer ID ile imzalanır (Team ID
  `H86X88P8FK`) ve Apple tarafından noterlenir. Her sürümün DMG'si için bir SHA-256 özeti de yayımlanır.

---

## Security Policy (English)

Only the latest release receives security fixes. Please **do not** report vulnerabilities in public
issues: use **Security › Report a vulnerability** on the repository page, or open an issue titled
"Security: contact" without details and we will reach out privately.

Yakala runs in the macOS **App Sandbox without any network entitlement**, has no third-party
dependencies and collects no data. Since 1.4.1 releases are signed with a Developer ID (Team ID
`H86X88P8FK`) and notarized by Apple. See [`Support/Yakala.entitlements`](Support/Yakala.entitlements).
