import mysql.connector
from functools import wraps
from flask import jsonify
import os
from dotenv import load_dotenv
from mysql.connector import Error

load_dotenv()

DB_HOST = os.getenv('DB_HOST')
DB_USER = os.getenv('DB_USER')
DB_PASSWORD = os.getenv('DB_PASSWORD')
DB_NAME = os.getenv('DB_NAME')

def get_connection():
    """Membuat koneksi ke database MySQL."""
    conn = None
    try:
        conn = mysql.connector.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME
        )
    except Error as e:
        print(f"Error saat menghubungkan ke database MySQL: {e}")
    return conn

def db_connection(f):
    """
    Decorator untuk menangani koneksi database secara otomatis.
    Menginjeksi cursor (dictionary=True) ke fungsi yang di-decorate.
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        conn = get_connection()
        if conn is None or not conn.is_connected():
            return jsonify({"message": "Koneksi database gagal"}), 503

        cursor = conn.cursor(dictionary=True)
        try:
            result = f(cursor, *args, **kwargs)
            conn.commit()
            return result
        except Error as e:
            conn.rollback()
            print(f"Database error: {e}")
            if hasattr(e, 'errno'):
                if e.errno == 1062:
                    return jsonify({"message": "Data dengan nilai unik yang sama sudah ada.", "error": str(e)}), 409
                if e.errno == 1451:
                    return jsonify({"message": "Tidak bisa menghapus/memperbarui data karena masih digunakan.", "error": str(e)}), 409
            return jsonify({"message": "Terjadi kesalahan pada database.", "error": str(e)}), 500
        except Exception as e:
            conn.rollback()
            print(f"An unexpected error occurred: {e}")
            return jsonify({"message": "Terjadi kesalahan tak terduga pada server.", "error": str(e)}), 500
        finally:
            cursor.close()
            conn.close()
    return decorated_function