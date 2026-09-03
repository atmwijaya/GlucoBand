from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
import json
from db import get_connection

settings_bp = Blueprint('settings', __name__)

def _get_cursor():
    conn = get_connection()
    if conn is None:
        return None, None
    return conn, conn.cursor(dictionary=True)

@settings_bp.get('/settings/<setting_key>')
def get_setting(setting_key):
    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500

    try:
        cursor.execute("SELECT setting_value FROM settings WHERE setting_key = %s", (setting_key,))
        setting = cursor.fetchone()
        if not setting:
            return jsonify({'msg': 'Pengaturan tidak ditemukan'}), 404

        return jsonify({'setting_key': setting_key, 'setting_value': setting['setting_value']})
    except Exception as e:
        print("Error in get_setting:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()

@settings_bp.put('/settings/<setting_key>')
@jwt_required()
def update_setting(setting_key):
    identity_json = get_jwt_identity()
    if not identity_json:
        return jsonify({'msg': 'Token tidak valid'}), 422
    
    # We could check if role is tenaga_medis, but assuming only admin/medis uses dashboard
    identity = json.loads(identity_json)
    if identity.get('role') != 'tenaga_medis':
         return jsonify({'msg': 'Hanya tenaga medis yang dapat mengubah pengaturan ini'}), 403

    data = request.get_json()
    if not data or 'setting_value' not in data:
        return jsonify({'msg': 'Data tidak lengkap, harap masukkan setting_value'}), 400

    new_value = data['setting_value']

    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500

    try:
        # Check if exists
        cursor.execute("SELECT id FROM settings WHERE setting_key = %s", (setting_key,))
        if cursor.fetchone():
            cursor.execute("UPDATE settings SET setting_value = %s WHERE setting_key = %s", (new_value, setting_key))
        else:
            cursor.execute("INSERT INTO settings (setting_key, setting_value) VALUES (%s, %s)", (setting_key, new_value))
            
        conn.commit()
        return jsonify({'msg': 'Pengaturan berhasil diperbarui', 'setting_key': setting_key, 'setting_value': new_value})
    except Exception as e:
        conn.rollback()
        print("Error in update_setting:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()
