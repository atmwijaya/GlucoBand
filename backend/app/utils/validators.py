import time
from threading import Lock

def validate_password(password: str):
    """
    Validasi kekuatan kata sandi:
    - Minimal 8 karakter
    - Mengandung minimal 1 huruf
    - Mengandung minimal 1 angka
    Mengembalikan (is_valid: bool, msg: str)
    """
    if not password or len(password) < 8:
        return False, "Kata sandi minimal 8 karakter"
    if not any(c.isalpha() for c in password):
        return False, "Kata sandi harus mengandung minimal 1 huruf"
    if not any(c.isdigit() for c in password):
        return False, "Kata sandi harus mengandung minimal 1 angka"
    return True, ""


class LoginRateLimiter:
    """
    In-memory rate limiter & brute-force protector thread-safe.
    Membatasi percobaan login gagal maksimal 5 kali.
    Tahapan durasi blokir (incremental lockout):
    - Blokir ke-1: 1 menit (60 detik)
    - Blokir ke-2 (jika gagal lagi setelah blokir berakhir): 2 menit (120 detik)
    - Blokir ke-3+ (jika gagal lagi): 5 menit (300 detik, batas maksimum)
    Selama periode blokir, sekalipun password benar, request tetap ditolak (429).
    Setelah login berhasil, counter dan seluruh riwayat blokir di-reset total.
    """
    def __init__(self, max_attempts=5):
        self.max_attempts = max_attempts
        self.records = {}
        self.lock = Lock()

    @staticmethod
    def get_client_ip(request):
        """Mendapatkan alamat IP klien yang sebenarnya, mendukung reverse proxy (Nginx)."""
        forwarded_for = request.headers.get('X-Forwarded-For')
        if forwarded_for:
            # Mengambil IP pertama di X-Forwarded-For jika ada beberapa proxy
            return forwarded_for.split(',')[0].strip()
        return request.remote_addr or '127.0.0.1'

    def _get_key(self, ip: str, email: str) -> str:
        clean_ip = ip.strip()
        clean_email = email.strip().lower()
        return f"{clean_ip}:{clean_email}"

    def is_locked(self, ip: str, email: str):
        """
        Mengecek apakah kunci IP + email sedang dibekukan.
        Mengembalikan (is_locked: bool, remaining_seconds: int)
        """
        now = time.time()
        key = self._get_key(ip, email)
        with self.lock:
            record = self.records.get(key)
            if not record:
                return False, 0

            locked_until = record.get('locked_until', 0)
            if now < locked_until:
                remaining = int(locked_until - now)
                return True, max(1, remaining)

            # Jika waktu penguncian sudah selesai lewat, kosongkan waktu lock tapi pertahankan level
            # agar jika langsung gagal lagi, penalti durasi blokir naik ke tingkat berikutnya
            if record.get('locked_until', 0) > 0 and now >= locked_until:
                record['locked_until'] = 0
                record['attempts'] = 0

            return False, 0

    def record_failure(self, ip: str, email: str):
        """
        Mencatat percobaan login gagal.
        Mengembalikan (is_now_locked: bool, lockout_duration: int, remaining_attempts: int)
        """
        now = time.time()
        key = self._get_key(ip, email)
        with self.lock:
            # Bersihkan riwayat yang sudah tidak aktif (> 2 jam)
            for k in list(self.records.keys()):
                if now - self.records[k].get('last_attempt', 0) > 7200:
                    del self.records[k]

            record = self.records.setdefault(key, {
                'attempts': 0,
                'locked_until': 0,
                'lockout_level': 0,
                'last_attempt': now
            })

            record['last_attempt'] = now
            record['attempts'] += 1

            # Tentukan apakah akun harus diblokir:
            # 1. Jika sudah pernah diblokir sebelumnya (lockout_level > 0), 1 kali gagal lagi langsung kena blokir tier berikutnya
            # 2. Atau jika baru pertama kali, blokir aktif setelah mencapai max_attempts (5 kali)
            should_lock = False
            if record['lockout_level'] > 0:
                record['lockout_level'] += 1
                should_lock = True
            elif record['attempts'] >= self.max_attempts:
                record['lockout_level'] = 1
                should_lock = True

            if should_lock:
                level = record['lockout_level']
                if level == 1:
                    lockout_duration = 60    # 1 menit
                elif level == 2:
                    lockout_duration = 120   # 2 menit
                else:
                    lockout_duration = 300   # 5 menit (maksimum)

                record['locked_until'] = now + lockout_duration
                return True, lockout_duration, 0

            remaining = self.max_attempts - record['attempts']
            return False, 0, max(0, remaining)

    def record_success(self, ip: str, email: str):
        """Mereset counter percobaan login setelah login berhasil."""
        key = self._get_key(ip, email)
        with self.lock:
            if key in self.records:
                del self.records[key]

# Singleton instance untuk aplikasi
login_rate_limiter = LoginRateLimiter(max_attempts=5)

