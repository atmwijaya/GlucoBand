# Panduan Pengembangan (Development Guide)

## Struktur Direktori Proyek

Proyek Glucoband menerapkan arsitektur *monorepo-style* (kumpulan folder untuk tiap komponen utama):

```text
glucoband/
├── backend/            # Python Flask backend API
│   ├── app/            # Source code utama backend
│   │   ├── routes/     # Endpoint/Controller API
│   │   ├── models/     # Model Database (SQLAlchemy/sejenisnya)
│   │   └── services/   # Business logic
│   └── app.py          # Entry point backend
├── mobile/             # Flutter Mobile App
│   └── glucobandapp/   # Root proyek Flutter
│       └── lib/
│           ├── data/         # Models dan Repositories
│           ├── presentation/ # Pages/Screens & UI Components
│           ├── providers/    # State management logic
│           └── services/     # API request handlers
├── web/                # React Vite Dashboard Web
│   └── src/
│       ├── api/        # Fungsi pemanggilan endpoint (axios)
│       ├── components/ # Reusable UI components
│       └── pages/      # Halaman utama (Views)
└── docs/               # Berkas Dokumentasi
```

## Prinsip Pengembangan (Development Principles)

1. **Separation of Concerns (Pemisahan Tanggung Jawab)**
   - Logika bisnis (perhitungan, validasi kompleks) diletakkan di bagian *services/providers*, bukan tergabung pada *controller/routes* atau langsung di komponen antarmuka UI.
2. **Single Responsibility Principle**
   - Setiap fungsi, kelas, atau komponen hanya boleh memiliki satu tugas/fokus. Jika *file* mencapai ratusan baris dengan beragam tanggung jawab, pisahkan.
3. **DRY (Don't Repeat Yourself)**
   - Gunakan komponen berulang (*reusable components*) untuk UI yang identik seperti tombol, *cards*, atau *modals*.

## Standar Pengodean (Coding Standards & Naming Conventions)

- **Penamaan Folder/File:**
  - *Flutter*: Gunakan `camelCase` (misal: `berandaPage.dart`) atau `snake_case` (disesuaikan dengan konsensus awal tim). 
  - *React/JS*: Gunakan `PascalCase` untuk komponen (e.g., `Header.jsx`) dan `camelCase` untuk fungsi/api (e.g., `authApi.js`).
  - *Python*: Gunakan `snake_case` untuk *file* dan direktori.
- **Penamaan Kelas & Fungsi:**
  - Kelas: `PascalCase` (`class UserProfile`).
  - Fungsi & Variabel: `camelCase` di Dart/JS (`fetchUserData()`), `snake_case` di Python (`def get_user()`).

## Praktik Keamanan, Penanganan Error & Kinerja

- **Error Handling:** 
  - Selalu gunakan blok *Try-Catch* saat melakukan pemanggilan API (REST). Tampilkan *feedback* visual yang ramah kepada pengguna (misal: *Snackbar* atau *Toast*).
- **Logging:**
  - Hindari `print()` / `console.log()` yang tertinggal di produksi. Gunakan sistem *logging* terpusat (contoh: *library logger* di Dart/Python) untuk kemudahan *debugging* di *production*.
- **Security:**
  - Simpan rahasia (kunci JWT, kredensial DB) secara eksklusif di dalam file `.env`. JANGAN PERNAH men-commit `.env` ke Git repository.
- **Performance:**
  - Minimalkan pemanggilan ulang ke API. Gunakan *state management* (seperti `Provider` di Flutter) untuk menyematkan dan memanfaatkan data secara persisten di memori selama diperlukan.
