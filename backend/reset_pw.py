from db import get_connection

conn = get_connection()
if conn:
    cursor = conn.cursor()
    cursor.execute("UPDATE users SET password = 'admingluband' WHERE email = 'glucoband@home.id' AND role = 'tenaga_medis'")
    conn.commit()
    cursor.close()
    conn.close()
    print("Password diubah menjadi plain text.")
else:
    print("Koneksi gagal.")