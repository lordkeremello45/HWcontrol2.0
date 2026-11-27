# HWcontrol2.0 — All-in-One Kurulum, Tanıtım ve Başlangıç Rehberi

> **Belgenin kapsamı:** Bu rehber yalnızca üç ana bölümden oluşur: **Tanıtım**, **Kurulum** ve **Başlangıç**. Mimari ayrıntılar, mühendislik durum raporları, güvenlik politikaları ve geliştirme süreçleri bu rehbere taşınmaz; kendi teknik belgelerinde kalır.
>
> **Ürün kanalı:** Beta · **Hedefler:** Windows 10/11 x64, Debian/Ubuntu ailesi Linux x64, macOS 14+ Apple Silicon.
>
> Donanım desteği cihaz, sürücü, işletim sistemi ve izinlere bağlıdır. Bir platformun hedeflenmesi, o platformdaki her sensörün veya kontrol özelliğinin çalıştığı anlamına gelmez.

## 1. Tanıtım

### HWcontrol2.0 nedir?

HWcontrol2.0; bilgisayar donanımını izlemek, sistem durumunu incelemek ve desteklenen donanımlarda güvenlik sınırları içinde kontrol sağlamak amacıyla geliştirilen açık kaynaklı, çok platformlu bir masaüstü uygulamasıdır.

Başlıca amaçları:

- CPU ve GPU sıcaklıklarını ve erişilebilen sensör verilerini görüntülemek.
- Bellek, depolama, fan devri ve sistem bilgilerini takip etmek.
- Desteklenen donanımlarda fan eğrileri ve kontrol profilleri kullanmak.
- Performance, Balanced ve Quiet gibi performans profillerini yönetmek.
- Game Mode ve donanım tanılama gibi yardımcı özellikler sunmak.
- Telemetri geçmişini ve grafikleri incelemek, gerektiğinde dışa aktarmak.

### Nasıl çalışır?

Uygulamanın mevcut donanım iletişim yolu şöyledir:

```text
Flutter / Dart masaüstü arayüzü
          ↓ HMAC doğrulamalı localhost iletişimi
Go Bridge — donanım verisi ve desteklenen kontrol işlemleri
          ↓
Windows / Linux / macOS donanım API'leri ve sürücüleri
```

Go Bridge, mevcut donanım toplama ve desteklenen kontrol işlemlerinin aktif sınırıdır. C++/CMake tabanlı AI ve ses bileşenleri ayrı yardımcı bileşenlerdir; mevcut donanım kontrol motoru olarak değerlendirilmemelidir.

### Platform ve özellik sınırları

| Platform | Mevcut genel durum |
|---|---|
| Windows 10/11 x64 | Donanım kimliği ve izleme kısmi; fan yazma kontrolü mevcut değil. |
| Debian/Ubuntu ailesi Linux x64 | İzleme ve keşif kısmi; fan PWM kontrolü yalnızca uygun hwmon kanalı, izinler ve güvenlik önkoşulları sağlandığında kullanılabilir. |
| macOS 14+ Apple Silicon | Donanım kimliği kısmi; fan yazma kontrolü ve otomatik işletim sistemi güç modu değiştirme mevcut değil. |

Önemli notlar:

- Sensör verisinin okunabilmesi, aynı donanımın kontrol edilebildiği anlamına gelmez.
- Linux fan kontrolü tüm anakartlarda veya fan denetleyicilerinde garanti edilmez.
- Sıvı soğutma entegrasyonu mevcut durumda isteğe bağlı ve salt okunur telemetri kapsamındadır.
- RGB/ARGB, pompa yazma kontrolü, GPU güç limiti, saat hızı ve voltaj ayarları genel desteklenen özellikler olarak sunulmaz.
- Fiziksel donanım doğrulaması yapılmamış özellikler doğrulanmış gibi kabul edilmemelidir.

### Resmî bağlantılar

- [GitHub deposu](https://github.com/lordkeremello45/HWcontrol2.0)
- [GitHub Releases — indirmeler](https://github.com/lordkeremello45/HWcontrol2.0/releases)
- [Proje web sitesi](https://lordkeremello45.github.io/HWcontrol2.0/)
- [GitHub Wiki](https://github.com/lordkeremello45/HWcontrol2.0/wiki)
- [Discord topluluğu](https://discord.gg/nVF6The3Nu)

## 2. Kurulum

### 2.1 Doğru sürümü indirme

1. [GitHub Releases](https://github.com/lordkeremello45/HWcontrol2.0/releases) sayfasını aç.
2. En güncel **Pre-release / Beta** sürümünü seç.
3. İşletim sistemine ve işlemci mimarine uygun paketi indir.
4. İndirme sayfasında beklenen kurulum dosyası bulunmuyorsa o platform için paketin yayımlandığını varsayma.

Mevcut paket hedefleri:

| Platform | Hedef paketler |
|---|---|
| Windows x64 | Setup EXE, MSI, ZIP ve 7Z; yapılandırıldığı durumlarda imzasız MSIX önizlemesi |
| Linux x64 | DEB, TAR.GZ, TAR.ZST ve ZIP |
| macOS arm64 | PKG, DMG ve `HWControl.app` içeren uygulama paketi ZIP'i |

Paketin listelenmesi tek başına güvenilir yayıncı imzası veya fiziksel donanım uyumluluğu kanıtı değildir.

### 2.2 Windows 10/11

1. Releases sayfasından Windows x64 **Setup EXE** paketini indir.
2. İndirdiğin dosyanın SHA-256 değerini, sürümle birlikte yayımlanmış manifest varsa onunla karşılaştır.
3. Kurulum dosyasını çalıştır ve kurulum sihirbazındaki adımları izle.
4. Kurulum tamamlandığında HWcontrol2.0 uygulamasını Başlat menüsünden aç.

MSI, yönetilen kurulum senaryoları içindir. ZIP/7Z paketleri taşınabilir arşivlerdir; arşivi çıkarmak klasik kurulumla aynı değildir. MSIX beta önizlemesi imzasız olabilir ve üretim yayıncı güveni sağlamaz.

### 2.3 Debian / Ubuntu Linux

1. Releases sayfasından Linux x64 için DEB paketini indir.
2. İndirme sayfasındaki checksum manifesti varsa dosyayı doğrula.
3. Terminalde paketin bulunduğu dizine geç.
4. Aşağıdaki komutla paketi kur:

```bash
sudo apt install ./hwcontrol*.deb
```

Bağımlılık çözümlemesi başarısız olursa:

```bash
sudo apt --fix-broken install
```

Fan kontrolü gibi ayrıcalık gerektiren işlemler yalnızca desteklenen hwmon aygıtlarında ve gerekli izinler sağlandığında kullanılabilir. Uygulama izin hatası bildirirse izin denetimini atlatmaya veya rastgele sistem dosyalarını değiştirmeye çalışma.

**APT deposu notu:** Otomatik APT deposu, kararlı DEB sürümü ve imzalı depo yayını gerçekten hazır olduğunda kullanılabilir. Depo kaydının yapılabilmesi, paketin yayımlanmış olduğunu garanti etmez. Güncel kullanılabilirliği Releases ve depo yayınından doğrula.

### 2.4 macOS 14+ Apple Silicon

1. Releases sayfasından Apple Silicon / arm64 için PKG veya DMG paketini indir.
2. Yayımlanmış SHA-256 manifesti varsa dosyanın bütünlüğünü doğrula.
3. DMG içindeki kurulum yönergelerini izle veya PKG yükleyicisini çalıştır.
4. Kurulumdan sonra HWControl uygulamasını Applications klasöründen aç.

macOS paketi ve uygulama imzası/notarizasyon durumu sürüme göre doğrulanmalıdır. İmza uyarılarını güvenlik denetimlerini devre dışı bırakarak geçiştirme.

### 2.5 Kurulum güvenliği

- Kurulum dosyalarını yalnızca resmî GitHub Releases veya resmî proje dağıtım bağlantılarından edin.
- SHA-256 checksum dosyası varsa indirdiğin dosyayla karşılaştır.
- Checksum, dosyanın yayımlanan baytlarla aynı olduğunu kontrol eder; yayıncı kimliğini tek başına kanıtlamaz.
- GitHub artifact attestation, build provenance bilgisidir; işletim sistemi yayıncı imzasının yerine geçmez.
- Windows Authenticode ve Apple Developer ID/notarization yalnızca ilgili imza gerçekten mevcut ve doğrulanmışsa var kabul edilmelidir.
- Bridge anahtarını, API anahtarlarını veya imzalama kimlik bilgilerini kimseyle paylaşma.

## 3. Başlangıç

### 3.1 İlk açılış

1. HWcontrol2.0 uygulamasını başlat.
2. İlk ekranda donanım taramasının tamamlanmasını bekle.
3. Dashboard üzerinde listelenen CPU, GPU, bellek, depolama ve sensör verilerini kontrol et.
4. Bir alan boşsa veya desteklenmiyor olarak görünüyorsa bunu sıfır değer ya da donanım arızası olarak yorumlama; işletim sistemi veya sürücü o veriyi sağlamıyor olabilir.
5. Uygulamanın bridge bağlantı/sağlık durumunu kontrol et. Veri gelmiyorsa kontrol işlemlerini denemek yerine önce bağlantı sorununu çöz.

### 3.2 Dashboard'u tanıma

- **Sistem izleme:** CPU/GPU sıcaklığı, bellek, depolama ve erişilebilen sensörler.
- **Fan izleme:** Donanımın sunduğu fan RPM değerleri.
- **Grafikler ve geçmiş:** Desteklenen telemetri alanlarının zaman içindeki değişimi.
- **Profiller:** Uygulamada sunulan Performance, Balanced ve Quiet seçenekleri. Bir profilin görünmesi, tüm donanım parametrelerinin değiştirildiği anlamına gelmez.
- **Game Mode:** Desteklenen süreç algılama ve profil ilişkilendirme davranışı. Donanım saat hızı veya voltaj ayarı yaptığı varsayılmamalıdır.
- **Tanılama:** Uygulamanın topladığı yerel durum ve hata bilgileri.

### 3.3 Güvenli kullanım

1. İlk kullanımda önce yalnızca izleme özelliklerini incele.
2. Fan kontrolü görünüyorsa yalnızca uygulamanın ilgili cihaz için açıkça desteklediği kanalları kullan.
3. Bilinmeyen PWM kanallarını elle değiştirme; firmware veya BIOS güvenlik davranışını devre dışı bırakma.
4. Sıcaklık, RPM veya sensör verisi geçersiz ya da güncelliğini yitirmiş görünüyorsa kontrol işlemi yapma.
5. Donanımın fiziksel tepkisini gözlemle. Yazılımın komut değerini geri okuması fanın gerçekten o hızda döndüğünü kanıtlamaz.
6. Anormal sıcaklık, gürültü veya davranış fark edersen kontrol işlemini durdur ve sistemin üretici varsayılanlarına dön.

### 3.4 Sorun giderme

| Belirti | İlk kontrol |
|---|---|
| Dashboard'da veri görünmüyor | Bridge bağlantısını, uygulama günlüklerini ve işletim sistemi sensör erişimini kontrol et. |
| CPU/GPU sensörü listelenmiyor | Sürücü ve donanım API'sinin ilgili sensörü sağlayıp sağlamadığını kontrol et. |
| Fan RPM görünmüyor | Fan denetleyicisinin ve işletim sistemi sürücüsünün RPM bilgisini sunup sunmadığını kontrol et. |
| Fan kontrolü kullanılamıyor | Platformun, fan kanalının, izinlerin ve manuel mod önkoşulunun desteklenip desteklenmediğini kontrol et. |
| Kurulum başarısız | Doğru mimari paketini, dosya bütünlüğünü, işletim sistemi sürümünü ve bağımlılıkları kontrol et. |
| Uygulama açılmıyor | Günlükleri incele; gizli anahtarları ve kişisel verileri paylaşmadan hata kaydı oluştur. |

### 3.5 Destek isteme ve hata bildirme

Sorun bildirirken şu bilgileri ekle:

- İşletim sistemi ve sürümü.
- İşlemci ve ekran kartı modeli.
- İlgili sürücü sürümleri.
- Hatanın hangi adımda oluştuğu.
- Varsa hata mesajı ve gizli bilgilerden arındırılmış günlük kaydı.

[GitHub Issues](https://github.com/lordkeremello45/HWcontrol2.0/issues) üzerinden hata bildirebilir veya [Beta Feedback Form](https://docs.google.com/forms/d/e/1FAIpQLSdxSKZIdg6terWsT_k8hbv8yhM-AAx6Begr2wV4JuarU3y9Rw/viewform?usp=dialog) formunu kullanabilirsin.

**Asla** bridge anahtarı, parola, API tokenı, özel imzalama anahtarı, sertifika parolası veya kişisel cihaz seri numarası paylaşma.

---

> **Bu rehberin sınırı:** Bu dosya yalnızca Tanıtım, Kurulum ve Başlangıç konularını kapsar. Ayrıntılı teknik mimari, güvenlik politikaları, geliştirici talimatları, test prosedürleri ve sürüm mühendisliği kendi uzmanlık belgelerinde tutulur.
