# Manajemen Basis Data (Data Migration & Seeding)

Dokumen ini menjelaskan alur pembuatan versi tabel (*migrations*) dan penyisipan data awal (*seeding*) pada Glucoband, menggunakan lingkungan *backend* Python.

## 1. Migrasi Database (Database Migrations)

Proyek ini menggunakan pustaka **Alembic** (jika *backend* menggunakan SQLAlchemy) atau *script SQL murni* (apabila *raw connector*).

### Membuat Migrasi Baru
Jika Anda menambahkan model baru di backend, selalu hasilkan file migrasi terlebih dahulu.
```bash
# Jalankan di folder backend
flask db migrate -m "Menambahkan tabel FAQ"
```
*Pastikan Anda telah me-review file Python yang ter-generate di folder `migrations/versions/` sebelum menerapkannya.*

### Menjalankan Migrasi (*Upgrade*)
Untuk mengaplikasikan semua perubahan skema terbaru ke database lokal atau produksi:
```bash
flask db upgrade
```

### Mengembalikan Versi Migrasi (*Rollback*)
Jika terjadi kesalahan desain kolom dan Anda ingin mundur 1 versi:
```bash
flask db downgrade
```

## 2. Penyisipan Data Awal (Seed Data)

*Seed data* diperlukan agar aplikasi langsung bisa dites (memiliki akun admin/dummy pasien) di lingkungan dev.

1. **Syarat Seeding**:
   - Akun Admin statis untuk mengakses Web Dashboard.
   - Minimal 1 Akun Pasien uji coba lengkap dengan data rekam *measurements* secara acak (opsional, untuk visualisasi grafik).
   - 3-5 Data referensi statis di tabel `faqs`.

2. **Eksekusi Seed**:
   Jalankan *script* penyemai yang telah disediakan.
   ```bash
   python seed.py
   # atau perintah kustom flask
   flask seed-db
   ```

## 3. Pencadangan dan Pemulihan (Backup & Restore)

Untuk memastikan data rekam medis pasien tidak hilang, lakukan pencadangan (*dump*) secara rutin (contoh menggunakan MySQL bawaan).

**Pencadangan (*Backup*):**
```bash
mysqldump -u root -p glucoband_db > backup_glucoband_2026.sql
```

**Pemulihan (*Restore*):**
```bash
mysql -u root -p glucoband_db < backup_glucoband_2026.sql
```
