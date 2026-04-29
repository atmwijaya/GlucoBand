import bcrypt
from db import get_connection

email = 'glucoband@home.id'
new_password = 'admingluband'      

# Buat hash bcrypt
hashed = bcrypt.hashpw(new_password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
print("Hash baru:", hashed)

conn = get_connection()
if conn:
    cursor = conn.cursor()
    try:
        cursor.execute("UPDATE users SET password = %s WHERE email = %s AND role = 'tenaga_medis'", (hashed, email))
        conn.commit()
        if cursor.rowcount > 0:
            print(f"✅ Password untuk {email} berhasil diperbarui.")
        else:
            print("❌ User tenaga medis tidak ditemukan.")
    except Exception as e:
        print("Error:", e)
    finally:
        cursor.close()
        conn.close()
else:
    print("❌ Koneksi database gagal.")