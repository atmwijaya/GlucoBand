# Desain dan Struktur Database (Database Design)

## Prinsip Desain (Design Principles)
- **Engine Relasional**: Menggunakan MySQL karena tingginya tingkat relasi antar tabel (Pasien -> Pengukuran).
- **Penamaan Tabel**: Gunakan `snake_case` dalam bentuk jamak (*plural*), contoh: `users`, `measurements`, `faqs`.
- **Primary Key (PK)**: Selalu gunakan tipe data INTEGER dengan mode *Auto Increment* sebagai ID internal. Hindari penggabungan (*composite key*) jika tidak benar-benar diperlukan.
- **Foreign Key (FK)**: Selalu akhiri kolom referensi dengan `_id`, contoh: `user_id`. Terapkan klausul aturan relasi *ON DELETE CASCADE* apabila penghapusan data induk harus menghapus data anaknya (misal: menghapus user akan menghapus pengukuran terkait).
- **Kolom Audit TImestamp**: Sertakan kolom `created_at` dan `updated_at` di hampir semua tabel untuk tujuan rekam jejak.

---

## Arsitektur Tabel Inti (Core Tables Architecture)

### 1. Tabel `users`
Menyimpan data pengguna, baik Pasien maupun Dokter/Admin.

| Kolom       | Tipe Data      | Keterangan |
|-------------|----------------|------------|
| `id`        | INT (PK)       | Auto increment |
| `name`      | VARCHAR(100)   | Nama Lengkap |
| `email`     | VARCHAR(100)   | Unique |
| `password`  | VARCHAR(255)   | Hashed password |
| `role`      | ENUM           | 'pasien', 'admin', 'dokter' |
| `created_at`| TIMESTAMP      | Waktu pendaftaran |

### 2. Tabel `measurements`
Menyimpan riwayat bacaan sensor (kadar glukosa) yang dikirim oleh ESP32.

| Kolom          | Tipe Data      | Keterangan |
|----------------|----------------|------------|
| `id`           | INT (PK)       | Auto increment |
| `user_id`      | INT (FK)       | Merujuk ke `users.id` |
| `glucose_level`| DECIMAL(5,2)   | Nilai glukosa (misal: 120.50) |
| `status`       | VARCHAR(50)    | 'Normal', 'Tinggi', 'Rendah' |
| `recorded_at`  | TIMESTAMP      | Waktu perekaman dari device |

### 3. Tabel `faqs`
Menyimpan kumpulan pertanyaan dan jawaban yang tampil di menu *Help/FAQ* aplikasi.

| Kolom       | Tipe Data      | Keterangan |
|-------------|----------------|------------|
| `id`        | INT (PK)       | Auto increment |
| `question`  | VARCHAR(255)   | Teks Pertanyaan |
| `answer`    | TEXT           | Teks Jawaban lengkap |
| `is_active` | BOOLEAN        | 1 (Tampil), 0 (Sembunyikan) |
| `created_at`| TIMESTAMP      | Waktu pembuatan data |
