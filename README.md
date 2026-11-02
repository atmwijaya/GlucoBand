# 🩺 Glucoband - Sistem Pemantauan Gula Darah Non-Invasif

Glucoband adalah platform ekosistem kesehatan IoT dan AI untuk pemantauan kadar gula darah secara **non-invasif**. Sistem mengintegrasikan gelang pintar (ESP32 dengan sensor NIR multi-spektral & PPG), aplikasi mobile pasien (Flutter), web dashboard dokter (React), serta backend (Flask) yang dilengkapi model Machine Learning (Random Forest & LSTM).

---

## 🏛 Arsitektur Sistem

```mermaid
flowchart LR
    ESP[Smartband ESP32<br>NIR & PPG] -->|HTTP POST| NGINX[Nginx Reverse Proxy]
    NGINX -->|/api/*| FLASK[Flask Backend API<br>JWT & SocketIO]
    NGINX -->|/| WEB_BUILD[Web Dashboard<br>React/Vite]
    FLASK --> DB[(MySQL 8.0)]
    FLASK --> ML[AI Models<br>RF & LSTM]
    
    WEB[Web Medis<br>React] <-->|REST & WSS| NGINX
    APP[Mobile Pasien<br>Flutter] <-->|REST & WSS| NGINX
```

### Komponen Utama
- **IoT Smartband (ESP32):** Membaca data sensor optik spektrometri NIR (610–860nm), denyut nadi (PPG), SpO2, dan suhu kulit.
- **Backend (Python Flask):** REST API, autentikasi JWT, WebSocket (Socket.IO), dan orkestrasi model AI.
- **AI Models:** 
  - *Random Forest* (`rf_diabetes.pkl`): Klasifikasi tingkat risiko diabetes.
  - *LSTM Neural Network* (`glucoband_lstm_model.h5`): Peramalan (*forecasting*) tren glukosa multi-jam.
- **Web Dashboard (React 19 + Vite):** Monitoring real-time pasien, grafik riwayat, dan input rekomendasi klinis dokter.
- **Mobile App (Flutter):** Tampilan status glukosa pasien, tren harian, notifikasi bahaya, dan tanya jawab kesehatan via Gemini AI.
- **Database (MySQL 8.0):** Penyimpanan data pengguna, telemetri sensor, riwayat prediksi, dan rekomendasi.

---

## ⚙️ Konfigurasi Environment

### 1. Backend (`backend/.env`)
```env
FLASK_ENV=production
SECRET_KEY=kunci-rahasia-server-anda
JWT_SECRET_KEY=kunci-jwt-anda
DATABASE_URL=mysql+pymysql://glucoband_user:PasswordKuat123!@127.0.0.1:3306/glucoband_db
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=glucoband_db
DB_USER=glucoband_user
DB_PASSWORD=PasswordKuat123!
```

### 2. Web Dashboard (`web/.env`)
```env
VITE_API_BASE_URL=/api
```

### 3. Mobile App (`mobile/glucobandapp/.env` & `apiConstant.dart`)
- **`.env`:** `GEMINI_API_KEY=AIzaSy...`
- **`lib/core/constants/apiConstant.dart`:** Atur `baseUrl` ke domain server Anda:
  ```dart
  static const String baseUrl = 'https://yourdomain.com/api';
  ```

---

## 🚀 Panduan Ringkas Deployment VPS (Ubuntu 22.04 / 24.04)

### 1. Instalasi Kebutuhan Sistem
```bash
sudo apt update && sudo apt install -y python3-venv python3-pip nginx mysql-server certbot python3-certbot-nginx nodejs npm
```

### 2. Setup Database MySQL
```sql
CREATE DATABASE glucoband_db;
CREATE USER 'glucoband_user'@'localhost' IDENTIFIED WITH mysql_native_password BY 'PasswordKuat123!';
GRANT ALL PRIVILEGES ON glucoband_db.* TO 'glucoband_user'@'localhost';
FLUSH PRIVILEGES;
```
Import data awal:
```bash
mysql -u glucoband_user -p glucoband_db < backend/backup/glucoband_backup.sql
```

### 3. Setup Backend Flask
```bash
cd /var/www/glucoband/backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirement.txt gunicorn eventlet
```

### 4. Systemd Service (`/etc/systemd/system/glucoband-backend.service`)
```ini
[Unit]
Description=Glucoband Backend Service
After=network.target

[Service]
User=www-data
WorkingDirectory=/var/www/glucoband/backend
Environment="PATH=/var/www/glucoband/backend/venv/bin"
EnvironmentFile=/var/www/glucoband/backend/.env
ExecStart=/var/www/glucoband/backend/venv/bin/gunicorn --worker-class eventlet -w 1 --bind 127.0.0.1:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
```
Jalankan service:
```bash
sudo systemctl daemon-reload && sudo systemctl enable --now glucoband-backend
```

### 5. Build Web Dashboard
```bash
cd /var/www/glucoband/web
npm install && npm run build
```

### 6. Konfigurasi Nginx (`/etc/nginx/sites-available/glucoband`)
```nginx
server {
    listen 80;
    server_name yourdomain.com;
    root /var/www/glucoband/web/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:5000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /socket.io/ {
        proxy_pass http://127.0.0.1:5000/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
    }
}
```
Aktifkan dan pasang SSL:
```bash
sudo ln -s /etc/nginx/sites-available/glucoband /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d yourdomain.com
```

---

## 📖 Ringkasan Alur Penggunaan (Manual Book)

- **Tenaga Medis (Web Dashboard):**
  1. Login menggunakan akun dengan role `tenaga_medis`.
  2. Buka menu **Data Pasien** untuk mendaftarkan atau memantau rekam medis pasien.
  3. Akses **Realtime Monitoring** untuk melihat kadar glukosa live (status: Normal, Rendah/Hipoglikemia, atau Tinggi/Hiperglikemia).
  4. Analisis grafik prediksi tren AI (LSTM) dan kirim **Rekomendasi Medis** langsung ke aplikasi pasien.
- **Pasien (Mobile App):**
  1. Login atau register akun pasien.
  2. Kenakan gelang Glucoband (pastikan gelang terhubung ke Wi-Fi).
  3. Cek kadar gula terkini pada kartu beranda, grafik tren harian, pesan peringatan, rekomendasi dokter, serta konsultasi FAQ/Gemini AI.

---

## 📡 Daftar Endpoint API

Semua request privat wajib menyertakan header: `Authorization: Bearer <JWT_TOKEN>`.

### 1. Autentikasi (`/api/auth`)
| Method | Endpoint | Deskripsi |
| :--- | :--- | :--- |
| `POST` | `/auth/login` | Login (Email & Password), mengembalikan JWT token & info user |
| `POST` | `/auth/register/pasien` | Pendaftaran akun baru pasien |

### 2. Manajemen Pasien (`/api/patients`)
| Method | Endpoint | Role | Deskripsi |
| :--- | :--- | :--- | :--- |
| `GET` | `/patients` | Medis | Mengambil daftar semua pasien |
| `GET` | `/patients/<id>` | Medis | Detail data & parameter klinis pasien |
| `POST` | `/patients` | Medis | Menambahkan data pasien baru |
| `PUT` | `/patients/<id>` | Medis | Memperbarui profil medis pasien |
| `DELETE`| `/patients/<id>` | Medis | Menghapus data pasien |

### 3. Pengukuran Sensor & Glukosa (`/api/measurements`)
| Method | Endpoint | Deskripsi |
| :--- | :--- | :--- |
| `POST` | `/measurements` | **Ingest Data IoT ESP32** (NIR 6-ch, PPG HR/SpO2/IR, suhu, estimasi glukosa) |
| `GET` | `/measurements` | 100 riwayat pengukuran terakhir |
| `GET` | `/patients/<id>/measurements` | Riwayat pengukuran pasien tertentu (`?limit=20`) |
| `GET` | `/patients/<id>/latest` | Data pengukuran paling mutakhir pasien |

### 4. Prediksi AI & Machine Learning
| Method | Endpoint | Model | Deskripsi |
| :--- | :--- | :--- | :--- |
| `POST` | `/predict/risk` | Random Forest | Input: data klinis + glukosa. Output: level & skor risiko |
| `POST` | `/predict/trend` | LSTM | Input: `glucose_history` (min 3 titik). Output: ramalan glukosa 3–6 jam ke depan |
| `GET` | `/predictions/risk/<patient_id>` | - | Mengambil status risiko terakhir pasien |
| `GET` | `/predictions/trend/<patient_id>` | - | Mengambil ramalan tren glukosa terakhir |
| `GET` | `/predictions/trend/<patient_id>/history` | - | Riwayat prediksi tren glukosa pasien |

### 5. Rekomendasi, Notifikasi, & Lainnya
| Method | Endpoint | Role | Deskripsi |
| :--- | :--- | :--- | :--- |
| `POST` | `/patients/<id>/recommendations` | Medis | Kirim rekomendasi klinis dokter ke pasien |
| `GET` | `/patient/notifications` | Pasien | Notifikasi peringatan & rekomendasi milik pasien |
| `PUT` | `/patient/recommendations/<id>/read` | Pasien | Menandai rekomendasi telah dibaca |
| `GET` | `/notifications` | Medis | Daftar seluruh peringatan darurat pasien |
| `GET/PUT`| `/profile` | User | Mengambil atau memperbarui profil pengguna |
| `GET/POST`| `/faq` | User/Medis | Mengambil atau mengelola artikel FAQ |
| `GET` | `/dashboard/stats` | Medis | Statistik total pasien, alert hari ini, dan bacaan |

---

## 📂 Struktur Direktori Proyek

```text
glucoband/
├── backend/                  # REST API Flask & Machine Learning
│   ├── app/
│   │   ├── ml_models/        # Bobot Model (rf_diabetes.pkl, lstm_model.h5)
│   │   ├── routes/           # Controller Blueprint (auth, patients, measurements, dll)
│   │   ├── services/ml/      # Service Inferensi ML (LSTM & Random Forest)
│   │   └── __init__.py       # Factory App & Socket.IO
│   ├── backup/               # Dump SQL Database Awal
│   ├── app.py                # Entrypoint Backend Server
│   ├── db.py                 # Koneksi & Decorator Database MySQL
│   └── requirement.txt       # Dependensi Python
├── web/                      # Frontend Dashboard Tenaga Medis (React 19 + Vite)
│   ├── src/
│   │   ├── pages/            # Halaman Dashboard, Pasien, Realtime Monitoring, FAQ
│   │   ├── components/       # Komponen UI (Navbar, Sidebar, Charts)
│   │   └── api/              # Axios API Client
│   └── package.json
├── mobile/glucobandapp/      # Aplikasi Pasien (Flutter)
│   ├── lib/
│   │   ├── core/constants/   # apiConstant.dart (Base URL Server)
│   │   ├── presentation/     # UI Pages (Beranda, Monitoring, Profile, FAQ)
│   │   └── services/         # API Service, Socket, Secure Storage, Gemini AI
│   └── pubspec.yaml
├── docker-compose.yml        # Setup Kontainer MySQL
└── README.md                 # Dokumentasi Proyek
```

---

## 📄 Lisensi
MIT License © 2026 Tim Glucoband.
