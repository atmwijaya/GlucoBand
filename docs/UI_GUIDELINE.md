# Panduan Antarmuka Pengguna (UI Guideline)

## Prinsip Desain & Tata Letak (Design Principles & Layout)

Tujuan utama dari antarmuka Glucoband adalah **kebersihan (cleanliness), fungsionalitas, dan kemodernan**.
Desain harus memberikan kemudahan navigasi dengan jarak/ruang kosong (*white-space*) yang cukup, menghindari kesan padat, serta menonjolkan data-data krusial (seperti angka gula darah).

- **Mobile:** *Mobile-first*, navigasi bawah (*Bottom Navigation Bar*), header minimalis (bukan *AppBar* bawaan kaku), serta menggunakan *border radius* bulat pada setiap elemen.
- **Web:** Mengadopsi tata letak dua kolom (Sidebar Navigasi di kiri, Konten di kanan).

## Tipografi, Warna, dan Spasi

### Tipografi
Proyek ini standar menggunakan keluarga *font*: **Plus Jakarta Sans**.
- *Heading 1/Title*: Bold (700), ukuran proporsional besar (24px - 32px).
- *Subtitle*: Semi-Bold (600), 16px - 18px.
- *Body Text*: Regular (400) / Medium (500), 13px - 14px.

### Palet Warna (Color Palette)
- **Primary Brand Color**: `#613EEA` (Ungu) - Digunakan untuk tombol utama, *active states*, ikon penting, dan latar belakang khusus.
- **Success Color**: `#10B981` (Hijau Emerald) - Status normal, baterai penuh.
- **Warning/Error Color**: `#EF4444` (Merah) - Status gula darah berbahaya, peringatan notifikasi.
- **Background Color**: `#F5F7FA` (Abu-abu kebiruan terang) - Untuk warna dasar layar *body scaffold*.
- **Card Color**: `#FFFFFF` (Putih) - Latar elemen *card* melayang.
- **Text Primary**: `#1E293B` - Teks judul/kepala.
- **Text Secondary**: `#64748B` / `#94A3B8` - Teks deskripsi/label.

### Spasi (Spacing)
- Terapkan standar kelipatan 4 atau 8. (misal: `padding` 8, 12, 16, 20, 24).
- Batas pinggir (*margin horizontal*) utama layar aplikasi biasanya `20px`.

## Komponen Inti UI (Core UI Components)

1. **Tombol (Buttons)**
   - Wajib berbentuk bundar ujung (*pill shape*) menggunakan `borderRadius: BorderRadius.circular(30)`.
   - Tombol aktif (*Primary*): Background `#613EEA`, Teks Putih.
   - Tombol sekunder: Background `#F1F5F9`, Teks/Ikon `#613EEA`.
2. **Cards**
   - Harus memiliki *box shadow* yang sangat halus (opacity 3% - 5%) agar melayang alami tanpa bayangan tajam.
   - `borderRadius` umumnya `16` atau `20`.
3. **Formulir & Inputs**
   - Kolom isian (*TextField*) tidak menggunakan garis batas (border) tegas. Sebaliknya, gunakan latar belakang abu-abu pudar (`#F1F5F9`) dengan bentuk membulat (`borderRadius: 16`).

## Desain Responsif (Responsive Design)
- Pada versi *mobile*, gunakan `Flexible`, `Expanded`, atau persentase `MediaQuery` jika elemen dibagi ke dalam grid horizontal (seperti menu navigasi baris bawah) untuk mencegah *overflow*.
- Pada layar web (lebar > 768px), sidebar harus statis dan tidak lagi menggunakan mode menu *hamburger*.
