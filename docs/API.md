# Dokumentasi API (API Reference)

Semua layanan *backend* API disajikan di bawah:
**Base URL:** `http://<domain_atau_ip>:5000/api` atau `/api` (Tergantung lingkungan *deploy*)

## Metode Autentikasi (Authentication)

Setiap endpoint API tertutup memerlukan autentikasi melalui format **Bearer Token**.
Tambahkan header berikut pada setiap permintaan HTTP:
`Authorization: Bearer <JWT_TOKEN_ANDA>`

Respon standar kegagalan autentikasi (401):
```json
{
  "status": "error",
  "message": "Token is missing or invalid!"
}
```

---

## 1. Otentikasi Pengguna (Login)
Berfungsi untuk mendapatkan akses token.

**Endpoint:** `POST /auth/login`
**Auth Required:** `No`

**Request Body (JSON):**
```json
{
  "email": "user@example.com",
  "password": "yourpassword"
}
```

**Success Response (200 OK):**
```json
{
  "status": "success",
  "token": "eyJhbGc...",
  "user": {
    "id": 1,
    "name": "Arrasyid",
    "email": "user@example.com",
    "role": "pasien"
  }
}
```

---

## 2. Mendapatkan Profil Pengguna Saat Ini
Berfungsi untuk mengambil informasi pengguna yang terautentikasi (Profil/Settings).

**Endpoint:** `GET /user/profile`
**Auth Required:** `Yes`

**Success Response (200 OK):**
```json
{
  "status": "success",
  "data": {
    "id": 1,
    "name": "Arrasyid Atma Wijaya",
    "email": "arrasyid@example.com",
    "role": "pasien",
    "phone": "08123456789",
    "created_at": "2026-08-11T12:00:00"
  }
}
```

---

## 3. Sinkronisasi/Mengambil Pengukuran Gula Darah Terkini
Mendapatkan data pengukuran glukosa ter-update milik pengguna.

**Endpoint:** `GET /measurements/latest`
**Auth Required:** `Yes`

**Query Parameters:** (Optional)
- `limit`: (int) Jumlah rekaman terakhir (Default 1).

**Success Response (200 OK):**
```json
{
  "status": "success",
  "data": {
    "id": 204,
    "user_id": 1,
    "glucose_level": 120.5,
    "status": "Normal",
    "recorded_at": "2026-08-11T10:45:12"
  }
}
```
