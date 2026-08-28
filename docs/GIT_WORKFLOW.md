# Panduan Kolaborasi Git (Git Workflow)

Proyek Glucoband menerapkan versi sederhana dari kolaborasi **Git Flow** yang umum di industri perangkat lunak. 
Aturan ini bertujuan menjaga *repository* agar tidak kotor dan mencegah kode rusak naik ke *production*.

## 1. Strategi Percabangan (Branching Strategy)

- **`main` (atau `master`)**: Representasi lingkungan Produksi (Production). Kode yang ada di sini harus selalu berjalan mulus tanpa error.
- **`develop`**: Lingkungan Utama untuk integrasi. Semua fitur dari *developer* yang telah selesai digabungkan di sini sebelum rilis.
- **`feature/nama-fitur`**: Percabangan untuk fitur baru, ditarik dari cabang `develop`.
- **`hotfix/nama-bug`**: Percabangan darurat ketika ada bug fatal di `main`. Langsung digabungkan kembali ke `main`.

## 2. Aturan Pesan Komit (Commit Message Conventions)

Gunakan standar **Conventional Commits**. Pesan *commit* harus informatif dan mendeskripsikan secara spesifik perubahan yang terjadi.

**Format**: `<tipe>: <deskripsi singkat>`

- `feat:` Menambahkan fitur baru (contoh: `feat: add login screen for mobile`).
- `fix:` Memperbaiki celah/bug (contoh: `fix: resolved text overflow on home page`).
- `docs:` Perubahan hanya untuk dokumentasi (contoh: `docs: update README installation guide`).
- `style:` Memperbaiki tata letak UI, warna, atau spasi (tanpa ubah logika).
- `refactor:` Restrukturisasi kode tanpa mengubah perilaku fitur.
- `chore:` Pemeliharaan, pembaruan versi SDK, atau hal-hal internal alat build.

## 3. Alur Pengembangan (*Development Workflow*)

1. **Pemilihan Tugas (Issue):** 
   Ambil *Issue* atau tiket tugas dari papan kerja Anda (misal: Jira/Trello/GitHub).
2. **Checkout Branch Baru:**
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/login-page
   ```
3. **Mengerjakan Tugas & Melakukan Komit:**
   Kerjakan kodenya, pastikan tidak ada sintaks error. Lakukan *commit* dengan format yang benar.
4. **Mendorong ke Origin:**
   ```bash
   git push origin feature/login-page
   ```

## 4. Pull Request (PR) & Code Review

Sebelum perubahan masuk ke cabang `develop`, tim harus melakukan *Pull Request* (PR).
- **PR Checklist:**
  - [ ] Apakah kode telah lulus pemeriksaan struktur (linting)?
  - [ ] Apakah tidak ada UI yang tumpang tindih (*overflow*) di resolusi layar standar?
  - [ ] Apakah tidak ada perintah debug (`print()`/`console.log()`) tertinggal?
- **Code Review**: Minimal satu pengembang (*developer*) lain harus menyetujui (Approve) PR tersebut sebelum di-merge secara administratif. Jangan pernah langsung me-merge *branch* Anda sendiri.
