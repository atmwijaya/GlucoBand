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
    Membatasi percobaan login gagal maksimal 5 kali dalam jendela waktu tertentu.
    Jika melampaui batas, akun/IP dibekukan sementara selama 5 menit.
    """
    def __init__(self, max_attempts=5, lockout_seconds=300):
        self.max_attempts = max_attempts
        self.lockout_seconds = lockout_seconds
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

            # Jika waktu penguncian sudah lewat, bersihkan status penguncian
            if record.get('locked_until', 0) > 0 and now >= locked_until:
                del self.records[key]

            return False, 0

    def record_failure(self, ip: str, email: str):
        """
        Mencatat percobaan login gagal.
        Mengembalikan (is_now_locked: bool, lockout_duration: int, remaining_attempts: int)
        """
        now = time.time()
        key = self._get_key(ip, email)
        with self.lock:
            # Bersihkan riwayat yang sudah usang (> 1 jam) agar memori tetap bersih
            for k in list(self.records.keys()):
                if now - self.records[k].get('last_attempt', 0) > 3600:
                    del self.records[k]

            record = self.records.setdefault(key, {
                'attempts': 0,
                'locked_until': 0,
                'last_attempt': now
            })

            record['attempts'] += 1
            record['last_attempt'] = now

            if record['attempts'] >= self.max_attempts:
                record['locked_until'] = now + self.lockout_seconds
                return True, self.lockout_seconds, 0

            remaining = self.max_attempts - record['attempts']
            return False, 0, remaining

    def record_success(self, ip: str, email: str):
        """Mereset counter percobaan login setelah login berhasil."""
        key = self._get_key(ip, email)
        with self.lock:
            if key in self.records:
                del self.records[key]

# Singleton instance untuk aplikasi
login_rate_limiter = LoginRateLimiter(max_attempts=5, lockout_seconds=300)

