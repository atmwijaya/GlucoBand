# MANUAL PENGGUNAAN PROGRAM KOMPUTER
## SISTEM APLIKASI MOBILE DAN WEB FULL STACK GLUCOBAND UNTUK PEMANTAUAN KADAR GLUKOSA NON-INVASIF BERBASIS WEARABLE

---

### IDENTITAS CIPTAAN
- **Judul Ciptaan**: Sistem Aplikasi Mobile dan Web Full Stack GlucoBand untuk Pemantauan Kadar Glukosa Non-Invasif Berbasis Wearable
- **Jenis Ciptaan**: Program Komputer
- **Sub-Jenis Ciptaan**: Program Komputer (Aplikasi Mobile, Web Dashboard, Back-End Service, dan Firmware IoT)
- **Tahun Pembuatan**: 2026
- **Versi Sistem**: Versi 1.0.0

---

## DAFTAR ISI
1. [BAB I: DESKRIPSI UMUM SISTEM](#bab-i-deskripsi-umum-sistem)
2. [BAB II: SPESIFIKASI KEBUTUHAN SISTEM](#bab-ii-spesifikasi-kebutuhan-sistem)
3. [BAB III: PANDUAN PENGOPERASIAN APLIKASI MOBILE PASIEN](#bab-iii-panduan-pengoperasian-aplikasi-mobile-pasien)
4. [BAB IV: PANDUAN PENGOPERASIAN PORTAL WEB TENAGA MEDIS](#bab-iv-panduan-pengoperasian-portal-web-tenaga-medis)
5. [BAB V: PEMECAHAN MASALAH (TROUBLESHOOTING)](#bab-v-pemecahan-masalah-troubleshooting)

---

## BAB I: DESKRIPSI UMUM SISTEM

### 1.1 Latar Belakang dan Tujuan
Sistem **GlucoBand** adalah solusi teknologi kesehatan terpadu (*integrated healthcare technology*) yang dirancang untuk memantau kadar glukosa darah secara non-invasif tanpa tusukan jarum (*finger-prick free*). Sistem ini mengintegrasikan perangkat keras *wearable* gelang cerdas, aplikasi ponsel pintar (*mobile app*) berbasis Flutter untuk pasien, layanan pemrosesan *cloud back-end* berbasis Python Flask dengan model inferensi *Machine Learning* XGBoost Regressor, serta dasbor web berbasis React.js bagi tenaga medis (dokter dan perawat) yang dilengkapi dengan sistem peringatan dini otomatis (*Early Warning System*).

### 1.2 Arsitektur Sistem Terintegrasi
Sistem GlucoBand terdiri dari 4 (empat) lapisan utama:
1. **Lapisan Perangkat Keras Wearable (ESP32-C3)**: Berfungsi membaca data biometrik secara langsung dari pergelangan tangan pengguna, meliputi spektrum optik *Near-Infrared* (NIR) 6-kanal (sensor AS726X), fotopletismografi (PPG detak jantung sensor MAX30105), dan suhu kulit (sensor MLX90614).
2. **Lapisan Aplikasi Mobile Pasien (Flutter)**: Bertindak sebagai antarmuka pengguna awam untuk memandu proses pengukuran, mengontrol perangkat keras, menyajikan estimasi kadar glukosa, dan menyimpan riwayat harian.
3. **Lapisan Cloud & AI Service (Flask & XGBoost)**: Menerima data panjang gelombang NIR (kanal R, S, T, U, V, W), melakukan standarisasi fitur, dan mengeksekusi model *XGBoost Regressor* untuk memprediksi kadar gula darah dalam satuan mg/dL, serta mengklasifikasikan status glukosa (Normal, Pradiabetes, Hipoglikemia, atau Hiperglikemia).
4. **Lapisan Portal Web Tenaga Medis (React.js)**: Menyajikan data riwayat rekam medis pasien, visualisasi tren glukosa, serta notifikasi peringatan darurat seketika (*real-time WebSocket*) saat terdeteksi kondisi darurat glukosa darah.

================================================================================
[TEMPATKAN GAMBAR 1: Diagram Arsitektur dan Alur Kerja Sistem Terintegrasi GlucoBand]
Keterangan Gambar 1: Diagram Arsitektur Sistem GlucoBand (Hardware Wearable, Mobile App, Cloud AI XGBoost, dan Web Dashboard Medis).
Ukuran yang Disarankan: Lebar 12 - 14 cm, Tengah (Center).
================================================================================

---

## BAB II: SPESIFIKASI KEBUTUHAN SISTEM

### 2.1 Kebutuhan Perangkat Keras (Hardware Requirements)
1. **Perangkat Wearable Gelang GlucoBand**:
   - Mikrokontroler: ESP32-C3 RISC-V 32-bit (dukungan Wi-Fi 2.4 GHz dan BLE).
   - Sensor Spektrum Optik: AS726X NIR Spectrometer (6 kanal: R, S, T, U, V, W).
   - Sensor Fotopletismografi (PPG): MAX30105 Heart Rate & Pulse Oximeter.
   - Sensor Suhu Tubuh: MLX90614 Contactless Infrared Body Temperature Sensor.
   - Layar Tampilan Mini: OLED 0.91 inci I2C (128x32 piksel).
   - Sumber Daya: Baterai Lithium Polymer 3.7V / 500 mAh dengan modul proteksi pengisian daya TP4056.
2. **Perangkat Pengguna (Smartphone Pasien)**:
   - Sistem Operasi: Android 8.0 (Oreo) ke atas atau iOS 12.0 ke atas.
   - Konektivitas: Wi-Fi 802.11 b/g/n dan/atau Data Seluler.
   - RAM Minimal: 2 GB.
3. **Perangkat Komputer Tenaga Medis (PC / Laptop)**:
   - Processor: Intel Core i3 / AMD Ryzen 3 atau setara.
   - RAM Minimal: 4 GB.
   - Peramban Web (Browser): Google Chrome, Mozilla Firefox, atau Microsoft Edge versi terbaru.

### 2.2 Kebutuhan Perangkat Lunak (Software Stack)
1. **Firmware**: Arduino IDE / ESP-IDF (C++).
2. **Aplikasi Mobile**: Framework Flutter 3.x, Dart SDK.
3. **Back-End API**: Python 3.10+, Flask, Flask-JWT-Extended, Flask-SocketIO.
4. **Machine Learning Model**: XGBoost 1.7+, Scikit-Learn (StandardScaler), Joblib, Pandas, NumPy.
5. **Basis Data**: MySQL 8.0 / MariaDB.
6. **Web Portal**: React 18, Vite, Tailwind CSS, Lucide Icons, Socket.IO Client.

---

## BAB III: PANDUAN PENGOPERASIAN APLIKASI MOBILE PASIEN

### 3.1 Registrasi dan Masuk Akun (Login)
1. Buka aplikasi **GlucoBand** pada perangkat smartphone.
2. Jika pengguna belum memiliki akun, pilih menu **"Daftar Akun Baru"**, lengkapi data nama lengkap, alamat email, kata sandi, tanggal lahir, dan jenis kelamin, lalu tekan tombol **"Daftar"**.
3. Jika sudah memiliki akun, masukkan email dan kata sandi yang terdaftar pada form login, kemudian tekan tombol **"Masuk"**.

================================================================================
[TEMPATKAN GAMBAR 2: Antarmuka Halaman Login dan Registrasi Aplikasi Mobile]
Keterangan Gambar 2: Tampilan Halaman Masuk (Login) dan Halaman Pendaftaran Akun Pasien pada Aplikasi Mobile GlucoBand.
Ukuran yang Disarankan: Lebar 12 - 13 cm, format 2 kolom/berdampingan, Tengah (Center).
================================================================================

### 3.2 Halaman Beranda dan Pemantauan Status Gelang
1. Setelah login berhasil, pengguna akan diarahkan ke halaman **Beranda**.
2. Pada bagian atas layar, terdapat kartu **"Perangkat GlucoBand"** yang menampilkan:
   - Status Keterhubungan: **Terhubung** (badge hijau) atau **Terputus** (badge merah).
   - Indikator Daya Baterai: Menampilkan status daya baterai gelang (misal: *Optimal*).
   - Alamat Jaringan Perangkat yang sedang aktif.
3. Kartu **"Estimasi Kadar Glukosa Terakhir"** menyajikan angka hasil pengukuran terkini beserta kategori kesehatannya.

================================================================================
[TEMPATKAN GAMBAR 3: Antarmuka Beranda Aplikasi Mobile Pasien]
Keterangan Gambar 3: Tampilan Halaman Beranda Aplikasi Mobile Menampilkan Kartu Status Perangkat GlucoBand dan Ringkasan Glukosa Terakhir.
Ukuran yang Disarankan: Lebar 8 - 9 cm, Tengah (Center).
================================================================================

### 3.3 Konfigurasi Jaringan Wi-Fi Perangkat Wearable
Jika gelang belum terhubung dengan jaringan:
1. Tekan kartu **"Konfigurasi Perangkat"** atau badge koneksi pada aplikasi.
2. Dialog **Konfigurasi Gelang GlucoBand** akan muncul.
3. Sistem secara otomatis mencari sinyal Wi-Fi dari gelang (*GlucoBand-Setup* / IP `192.168.4.1`).
4. Pilih menu **"Hubungkan ke Wi-Fi Rumah / Kantor"**, pilih nama SSID Wi-Fi yang tersedia, masukkan kata sandi Wi-Fi, lalu tekan tombol **"Simpan & Hubungkan"**.
5. Gelang akan mendapatkan alamat IP lokal baru dan indikator pada aplikasi akan berubah menjadi **"Terhubung"**.

================================================================================
[TEMPATKAN GAMBAR 4: Dialog Konfigurasi Jaringan Perangkat (Device Config Dialog)]
Keterangan Gambar 4: Dialog Konfigurasi Jaringan Wi-Fi untuk Menghubungkan Gelang GlucoBand ke Jaringan Lokal.
Ukuran yang Disarankan: Lebar 8 - 9 cm, Tengah (Center).
================================================================================

### 3.4 Prosedur Pelaksanaan Pengukuran Kadar Glukosa Non-Invasif
1. Posisikan gelang GlucoBand pada pergelangan tangan, tepat di atas area **Arteri Radialis** (sisi pergelangan tangan bagian dalam sejajar jempol).
2. Pastikan sensor optik NIR, sensor PPG, dan sensor suhu menempel dengan pas pada permukaan kulit (tidak terlalu longgar dan tidak menekan terlalu kencang).
3. Buka menu tab **"Ukur"** di navigasi bawah aplikasi.
4. Perhatikan 4 (empat) kartu indikator kesiapan pada bagian bawah:
   - **BATERAI**: Menampilkan status daya gelang (*Optimal*).
   - **STATUS ALAT**: Menampilkan kesiapan hardware (*Siap Digunakan*).
   - **DENYUT NADI**: Menampilkan deteksi denyut nadi awal (*-- BPM*).
   - **SUHU TUBUH**: Menampilkan pembacaan suhu kulit (*-- °C*).
5. Tekan tombol lingkaran besar bertuliskan **"Mulai"**.
6. Sistem akan memandu pengguna melalui teks instruksi:
   - Tahap 1: *"Menghubungi GlucoBand..."*
   - Tahap 2: *"Inisiasi Hardware Sensor..."*
   - Tahap 3: *"Tempelkan pergelangan tangan Anda pada sensor..."*
   - Tahap 4: *"Membaca sinyal PPG & spektrum NIR (Mohon tidak bergerak)..."*
7. Proses akuisisi data berlangsung selama kurang lebih 10 – 15 detik.

================================================================================
[TEMPATKAN GAMBAR 5: Antarmuka Halaman Pengukuran Glukosa Darah]
Keterangan Gambar 5: Tampilan Halaman Pengukuran Menampilkan Tombol Utama "Mulai" dan 4 Kartu Indikator Kesiapan (Baterai, Status Alat, Denyut Nadi, Suhu Tubuh).
Ukuran yang Disarankan: Lebar 8 - 9 cm, Tengah (Center).
================================================================================

### 3.5 Pembacaan Hasil Estimasi Glukosa Darah (Model XGBoost)
1. Setelah sensor selesai membaca sinyal optik, data 6 panjang gelombang NIR dikirimkan ke model **XGBoost Regressor** di backend.
2. Aplikasi secara otomatis mengalihkan layar ke **Halaman Hasil Pengukuran**:
   - Nilai estimasi kadar gula darah ditampilkan dalam satuan **mg/dL**.
   - Indikator visual status glukosa:
     - **Normal (Hijau)**: Rentang 70 – 140 mg/dL.
     - **Pradiabetes (Kuning)**: Rentang 141 – 199 mg/dL.
     - **Hiperglikemia (Merah)**: Kadar glukosa >= 200 mg/dL.
     - **Hipoglikemia (Biru/Oranye Gelap)**: Kadar glukosa < 70 mg/dL.
   - Disertai informasi pendukung: **Denyut Nadi (BPM)** dan **Suhu Tubuh (°C)**.
3. Tekan tombol **"Simpan & Sinkronkan"** untuk menyimpan hasil ke riwayat cloud dan meneruskannya ke portal tenaga medis.

================================================================================
[TEMPATKAN GAMBAR 6: Antarmuka Halaman Hasil Pengukuran Glukosa]
Keterangan Gambar 6: Tampilan Halaman Hasil Pengukuran Menampilkan Nilai Estimasi Glukosa AI XGBoost, Klasifikasi Status Klinis, Denyut Nadi, dan Suhu Tubuh.
Ukuran yang Disarankan: Lebar 8 - 9 cm, Tengah (Center).
================================================================================

### 3.6 Melihat Riwayat Pengukuran dan Grafik Tren
1. Tekan tab menu **"Riwayat"** atau tekan ikon jam (*history*) di sudut atas halaman pengukuran.
2. Pengguna dapat melihat daftar seluruh pengukuran terdahulu yang diurutkan dari yang terbaru, lengkap dengan tanggal, jam, nilai glukosa, dan status klinis.
3. Halaman ini juga menyajikan visualisasi grafik fluktuasi kadar gula darah harian/mingguan untuk mempermudah evaluasi gaya hidup.

================================================================================
[TEMPATKAN GAMBAR 7: Antarmuka Halaman Riwayat Pengukuran Glukosa]
Keterangan Gambar 7: Tampilan Halaman Riwayat Menampilkan Rekapitulasi Pengukuran Glukosa Darah Pasien Secara Kronologis.
Ukuran yang Disarankan: Lebar 8 - 9 cm, Tengah (Center).
================================================================================

### 3.7 Manajemen Profil Kesehatan Pasien
1. Masuk ke tab menu **"Profil"**.
2. Pengguna dapat melengkapi dan memperbarui profil fisiologis:
   - Usia, Berat Badan (kg), Tinggi Badan (cm) untuk kalkulasi Indeks Massa Tubuh (BMI).
   - Tekanan Darah Sistolik & Diastolik.
   - Riwayat merokok dan riwayat penyakit kardiovaskular.
3. Data ini digunakan oleh model kecerdasan buatan untuk analisis risiko kesehatan komprehensif.

================================================================================
[TEMPATKAN GAMBAR 8: Antarmuka Halaman Profil Kesehatan Pasien]
Keterangan Gambar 8: Tampilan Halaman Pengaturan Profil Pasien dan Parameter Fisiologis Tubuh.
Ukuran yang Disarankan: Lebar 8 - 9 cm, Tengah (Center).
================================================================================

---

## BAB IV: PANDUAN PENGOPERASIAN PORTAL WEB TENAGA MEDIS

### 4.1 Masuk ke Portal Tenaga Medis (Login Medis)
1. Buka peramban (*web browser*) pada komputer/laptop tenaga medis dan akses URL sistem web GlucoBand.
2. Masukkan **Email Resmi / NIP Tenaga Medis** dan kata sandi yang telah didaftarkan oleh administrator rumah sakit / klinik.
3. Tekan tombol **"Masuk ke Portal Medis"**.

================================================================================
[TEMPATKAN GAMBAR 9: Antarmuka Halaman Login Portal Web Tenaga Medis]
Keterangan Gambar 9: Tampilan Form Login Tenaga Medis pada Portal Web Pemantauan GlucoBand.
Ukuran yang Disarankan: Lebar 12 - 14 cm, Tengah (Center).
================================================================================

### 4.2 Dashboard Utama Pemantauan Pasien
1. Setelah login berhasil, tenaga medis disajikan halaman **Dashboard Utama**.
2. Dashboard menyajikan ringkasan statistik klinis:
   - Total Pasien Terdaftar.
   - Pasien dalam Kondisi Normal.
   - Pasien dalam Perhatian Khusus (Kondisi Hipoglikemia / Hiperglikemia).
3. Tabel daftar pasien menampilkan nama pasien, usia, jenis kelamin, pembacaan glukosa darah terakhir, waktu pengukuran, serta status kesehatan terkini.

================================================================================
[TEMPATKAN GAMBAR 10: Antarmuka Dashboard Utama Tenaga Medis]
Keterangan Gambar 10: Tampilan Dashboard Portal Web Tenaga Medis Menampilkan Ringkasan Statistik Pasien dan Tabel Monitoring Aktif.
Ukuran yang Disarankan: Lebar 13 - 15 cm, Tengah (Center).
================================================================================

### 4.3 Detail Rekam Medis Pasien dan Grafik Analisis
1. Klik nama pasien atau tombol **"Lihat Detail"** pada tabel pasien.
2. Halaman detail menyajikan rekam medis elektronik (*Electronic Health Record*):
   - Grafik interaktif fluktuasi glukosa darah dari waktu ke waktu.
   - Korelasi antara suhu tubuh, detak jantung, dan kadar glukosa.
   - Catatan riwayat obat dan jadwal kontrol pasien.

================================================================================
[TEMPATKAN GAMBAR 11: Antarmuka Detail Rekam Medis dan Grafik Glukosa Pasien]
Keterangan Gambar 11: Tampilan Halaman Rekam Medis Pasien Lengkap dengan Visualisasi Grafik Tren Glukosa Darah.
Ukuran yang Disarankan: Lebar 13 - 15 cm, Tengah (Center).
================================================================================

### 4.4 Sistem Peringatan Dini (Early Warning System / Notifikasi Kritis)
1. Klik menu **"Notifikasi"** pada bilah navigasi atas/samping.
2. Sistem secara otomatis memfilter pasien-pasien yang membutuhkan tindakan darurat:
   - **Kartu Merah (Hiperglikemia Berat)**: Pasien dengan kadar gula darah >= 200 mg/dL (atau > 300 mg/dL kondisi krisis).
   - **Kartu Biru Gelap (Hipoglikemia Akut)**: Pasien dengan kadar gula darah < 70 mg/dL (atau < 54 mg/dL risiko syok hipoglikemik).
3. Setiap kartu notifikasi memuat nama pasien, nilai glukosa yang terdeteksi secara real-time, waktu kejadian, arahan tindakan medis awal, dan tombol langsung **"Buka Rekam Medis"**.
4. Apabila terjadi kondisi kritis saat portal web sedang dibuka, sistem memberikan pemberitahuan visual instan melalui koneksi *WebSocket*.

================================================================================
[TEMPATKAN GAMBAR 12: Antarmuka Halaman Notifikasi Peringatan Dini Tenaga Medis]
Keterangan Gambar 12: Tampilan Halaman Peringatan Dini (*Early Warning System*) Portal Web Menampilkan Daftar Notifikasi Klinis Darurat Pasien.
Ukuran yang Disarankan: Lebar 13 - 15 cm, Tengah (Center).
================================================================================

### 4.5 Pemberian Rekomendasi Medis Dokter ke Pasien
1. Pada halaman detail pasien, buka bagian **"Form Rekomendasi Medis"**.
2. Dokter dapat mengetikkan instruksi klinis, anjuran penyesuaian dosis insulin/obat oral, atau saran pola makan dan aktivitas fisik.
3. Tekan tombol **"Kirim Rekomendasi"**.
4. Rekomendasi tersebut akan langsung tersinkronisasi dan muncul pada aplikasi mobile milik pasien secara otomatis.

================================================================================
[TEMPATKAN GAMBAR 13: Antarmuka Form Input Rekomendasi Dokter]
Keterangan Gambar 13: Tampilan Form Input Rekomendasi Medis Dokter untuk Pengiriman Arahan Klinis Langsung ke Smartphone Pasien.
Ukuran yang Disarankan: Lebar 11 - 13 cm, Tengah (Center).
================================================================================

---

## BAB V: PEMECAHAN MASALAH (TROUBLESHOOTING)

| Gejala Masalah | Kemungkinan Penyebab | Tindakan Solusi |
| :--- | :--- | :--- |
| Status alat pada aplikasi bertuliskan *"Belum Terhubung"* atau *"Terputus"*. | Gelang berada di luar jangkauan Wi-Fi atau belum terhubung ke router. | Pastikan gelang menyala. Buka dialog konfigurasi perangkat, hubungkan kembali ke Wi-Fi rumah atau hidupkan *Personal Hotspot* HP. |
| Pengukuran gagal dengan pesan *"Sensor Tidak Terdeteksi"*. | Gangguan komunikasi pada bus I2C hardware. | Matikan daya gelang selama 5 detik, kemudian nyalakan kembali. Periksa apakah sensor optik NIR dan MAX30105 menyala merah/cahaya sensor. |
| Nilai estimasi glukosa berfluktuasi tidak stabil. | Artefak gerak (*motion artifacts*) saat pengukuran berlangsung. | Pastikan pergelangan tangan menempel stabil pada sensor, tidak berbicara atau menggerakkan tangan selama 15 detik proses pembacaan data. |
| Notifikasi darurat tidak muncul di portal web medis. | Koneksi jaringan terputus atau server backend offline. | Pastikan server Flask dan layanan Socket.IO berjalan normal. Lakukan penyegaran (*refresh*) peramban web pada komputer tenaga medis. |

---

### RINGKASAN DAFTAR GAMBAR YANG HARUS DISIAPKAN UNTUK HKI

Untuk mempermudah penyusunan dokumen di Microsoft Word sebelum diekspor ke PDF, berikut adalah daftar periksa (*checklist*) 13 tangkapan layar yang perlu Anda siapkan:

1. [ ] **Gambar 1**: Diagram Arsitektur & Alur Kerja Sistem GlucoBand (Bisa berupa diagram blok dari proposal/skripsi Anda).
2. [ ] **Gambar 2**: Tangkapan layar Halaman Login & Registrasi Aplikasi Mobile Pasien.
3. [ ] **Gambar 3**: Tangkapan layar Halaman Beranda Mobile (Kartu Perangkat GlucoBand & Status Koneksi).
4. [ ] **Gambar 4**: Tangkapan layar Dialog Konfigurasi Wi-Fi Gelang (`deviceConfigDialog`).
5. [ ] **Gambar 5**: Tangkapan layar Halaman Pengukuran Mobile (Tombol "Mulai" & 4 Kartu: Baterai, Status Alat, Nadi, Suhu).
6. [ ] **Gambar 6**: Tangkapan layar Halaman Hasil Pengukuran Glukosa (Nilai mg/dL, Status Medis, BPM, Suhu).
7. [ ] **Gambar 7**: Tangkapan layar Halaman Riwayat Pengukuran Glukosa Pasien.
8. [ ] **Gambar 8**: Tangkapan layar Halaman Profil Kesehatan Pasien.
9. [ ] **Gambar 9**: Tangkapan layar Halaman Login Portal Web Tenaga Medis.
10. [ ] **Gambar 10**: Tangkapan layar Dashboard Utama Tenaga Medis (Tabel Monitoring Pasien).
11. [ ] **Gambar 11**: Tangkapan layar Detail Rekam Medis Pasien & Grafik Glukosa Web.
12. [ ] **Gambar 12**: Tangkapan layar Halaman Notifikasi Peringatan Dini Tenaga Medis (`notificationPage.jsx`).
13. [ ] **Gambar 13**: Tangkapan layar Form Input Rekomendasi Dokter.
