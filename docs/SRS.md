# Software Requirements Specification (SRS)

## Peran Pengguna (User Roles)

Sistem Glucoband dirancang untuk melayani beberapa peran pengguna dengan hak akses yang berbeda:

1. **Pasien (Patient)**
   Pengguna utama yang memakai perangkat pintar Glucoband untuk memantau kadar gula darah harian mereka.
2. **Dokter/Admin (Doctor/Admin)**
   Tenaga medis atau pengelola klinik yang memantau data pasien, mengelola perangkat, serta mengelola basis pengetahuan (FAQ).

## Hak Akses & Kemampuan (Capabilities & Use Cases)

### 1. Pasien
- **Registrasi & Login**: Mendaftar akun baru dan masuk ke dalam sistem aplikasi *mobile*.
- **Pemantauan (Monitoring)**: Melihat grafik gula darah dan hasil pengukuran secara *real-time* maupun riwayat pengukuran sebelumnya.
- **Profil**: Memperbarui informasi data diri (nama, berat badan, tinggi badan, dsb).
- **FAQ/Bantuan**: Mengakses daftar pertanyaan umum (FAQ) mengenai kesehatan dan penggunaan alat.
- **Notifikasi**: Menerima peringatan otomatis jika gula darah melewati ambang batas normal.

### 2. Dokter/Admin
- **Login Web**: Masuk ke *dashboard web* khusus pengelola.
- **Manajemen Pasien**: Melihat daftar pasien terdaftar, melihat riwayat pengukuran gula darah dari setiap pasien secara detil.
- **Manajemen FAQ**: Menambah, mengubah, dan menghapus (CRUD) konten FAQ yang akan muncul di aplikasi *mobile*.
- **Notifikasi Darurat**: Menerima peringatan ringkas terkait pasien yang mengalami kondisi kritis (hipoglikemia/hiperglikemia).

## Persyaratan Fungsional Utama (Key Functional Requirements)

1. **Integrasi Perangkat (Hardware Integration)**
   - Sistem harus mampu menerima transmisi data dari gelang pintar ESP32 (misal, via MQTT/REST API) secara berkala dan menyimpannya ke database.
2. **Autentikasi & Otorisasi**
   - Sistem wajib menggunakan token (JWT) untuk mengamankan komunikasi API antara *frontend* (Web/Mobile) dengan *backend*. Token otomatis hangus (kedaluwarsa) dalam 30 hari.
3. **Penyajian Data Berbasis Grafik**
   - Aplikasi *mobile* dan *web* harus menampilkan data glukosa dalam bentuk diagram garis (*line chart*) untuk memperlihatkan tren harian, mingguan, atau bulanan.
4. **Respon Waktu Nyata (Near Real-Time)**
   - Data yang baru dikirimkan oleh gelang pintar harus segera terlihat (*refresh*) di aplikasi seluler tanpa *delay* yang mengganggu pengawasan pasien.
