# Glucoband - Sistem Pemantauan Gula Darah Terintegrasi

## Gambaran Umum Proyek
Glucoband adalah sebuah solusi terintegrasi untuk pemantauan kadar gula darah secara *real-time*. Sistem ini menghubungkan perangkat keras berupa gelang pintar (berbasis ESP32) dengan aplikasi *mobile* untuk pasien (dibangun menggunakan Flutter) dan *dashboard* berbasis *web* untuk tenaga medis/admin (dibangun menggunakan React & Vite), serta didukung oleh *backend* Python (Flask) dengan database MySQL.

Tujuan utama dari Glucoband adalah memberikan kemudahan bagi pasien diabetes dalam memantau gula darah mereka tanpa metode invasif yang menyakitkan, serta memudahkan dokter dalam memantau rekam medis harian pasien dari jarak jauh.

## Prasyarat (Prerequisites)
Sebelum menjalankan proyek ini, pastikan Anda telah menginstal:
- **Node.js** (v18 atau lebih baru) & **npm** (untuk *Web Dashboard*)
- **Python** (v3.9 atau lebih baru) & **pip** (untuk *Backend API*)
- **Flutter SDK** (v3.19 atau lebih baru) & **Dart** (untuk *Mobile App*)
- **MySQL Server** (v8.0 atau lebih baru)
- **Arduino IDE / PlatformIO** (untuk *ESP32 Firmware*)

## Instalasi dan Konfigurasi

### 1. Database Setup
1. Buat database baru di MySQL dengan nama `glucoband_db`.
2. Jalankan skrip migrasi atau *import* file `schema.sql` (jika ada) ke dalam database tersebut.

### 2. Backend (Python/Flask)
```bash
cd backend
python -m venv venv
# Windows: venv\Scripts\activate | Mac/Linux: source venv/bin/activate
pip install -r requirements.txt
```
Buat file `.env` dan sesuaikan koneksi database Anda (contoh: `DATABASE_URL=mysql+pymysql://user:password@localhost/glucoband_db`).

### 3. Web Dashboard (React/Vite)
```bash
cd web
npm install
```
Buat file `.env` (contoh: `VITE_API_BASE_URL=http://localhost:5000/api`).

### 4. Mobile App (Flutter)
```bash
cd mobile/glucobandapp
flutter pub get
```

## Cara Menjalankan Proyek (Lokal)

### Menjalankan Backend
```bash
cd backend
python app.py
```
Backend akan berjalan secara *default* di `http://localhost:5000`.

### Menjalankan Web Dashboard
```bash
cd web
npm run dev
```
Web akan berjalan secara *default* di `http://localhost:5173`.

### Menjalankan Mobile App
Pastikan emulator (Android/iOS) sudah berjalan atau perangkat asli sudah terhubung via *debugging*.
```bash
cd mobile/glucobandapp
flutter run
```

## Lingkungan Produksi (Production)
- **Backend:** Gunakan Gunicorn atau uWSGI yang di-proxy oleh Nginx.
- **Web:** Jalankan `npm run build` dan sajikan folder `dist/` menggunakan Nginx/Apache.
- **Mobile:** Build APK/AAB (`flutter build apk` / `flutter build appbundle`) atau rilis ke App Store (`flutter build ipa`).
- **Database:** Gunakan *Managed Database Service* (misal: AWS RDS, Google Cloud SQL) untuk ketersediaan tinggi dan *backup* otomatis.
