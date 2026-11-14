from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity, verify_jwt_in_request
import json
from db import get_connection

settings_bp = Blueprint('settings', __name__)

def _get_cursor():
    conn = get_connection()
    if conn is None:
        return None, None
    return conn, conn.cursor(dictionary=True)

@settings_bp.get('/app-version')
def get_app_version():
    """
    Endpoint publik untuk pemeriksaan versi aplikasi mobile (In-App Update).
    Mengembalikan informasi versi terbaru, URL unduh APK, changelog, dan status force_update.
    """
    version_info = {
        'latest_version': '1.0.1',
        'latest_build_number': 2,
        'download_url': 'https://glucobandpro.id/download/glucoband.apk',
        'changelog': '• Pembaruan performa dan stabilitas koneksi sensor\n• Fitur update otomatis terintegrasi\n• Peningkatan kenyamanan antarmuka pengguna',
        'force_update': False
    }

    conn, cursor = _get_cursor()
    if not conn:
        return jsonify(version_info), 200

    try:
        cursor.execute("""
            SELECT setting_key, setting_value 
            FROM settings 
            WHERE setting_key IN ('app_version', 'app_build_number', 'app_download_url', 'app_changelog', 'app_force_update')
        """)
        rows = cursor.fetchall()
        for r in rows:
            k = r.get('setting_key')
            v = r.get('setting_value')
            if not v:
                continue
            if k == 'app_version':
                version_info['latest_version'] = str(v).strip()
            elif k == 'app_build_number':
                try:
                    version_info['latest_build_number'] = int(v)
                except ValueError:
                    pass
            elif k == 'app_download_url':
                version_info['download_url'] = str(v).strip()
            elif k == 'app_changelog':
                version_info['changelog'] = str(v).strip()
            elif k == 'app_force_update':
                version_info['force_update'] = str(v).strip().lower() in ('true', '1', 'yes')

        return jsonify(version_info), 200
    except Exception as e:
        print("Error fetching app version:", e)
        return jsonify(version_info), 200
    finally:
        cursor.close()
        conn.close()

@settings_bp.get('/settings/<setting_key>')
def get_setting(setting_key):
    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500

    try:
        # Jika request nomor kontak darurat dan ada identitas pasien, prioritaskan nomor tenaga medis pasien
        if setting_key == 'emergency_contact':
            try:
                verify_jwt_in_request(optional=True)
                identity_json = get_jwt_identity()
                if identity_json:
                    user_identity = json.loads(identity_json) if isinstance(identity_json, str) else identity_json
                    user_id = user_identity.get('id')
                    cursor.execute("""
                        SELECT tm.name, tm.phone_number, tm.specialization
                        FROM users u
                        JOIN tenaga_medis tm ON u.tenaga_medis_id = tm.id
                        WHERE u.id = %s AND tm.is_active = 1
                    """, (user_id,))
                    doc = cursor.fetchone()
                    if doc and doc.get('phone_number'):
                        return jsonify({
                            'setting_key': 'emergency_contact',
                            'setting_value': doc['phone_number'],
                            'tenaga_medis_name': doc['name'],
                            'doctor_name': doc['name'],
                            'specialization': doc['specialization'],
                            'assigned': True
                        }), 200
            except Exception:
                pass  # Fallback ke nomor umum jika token tidak disertakan atau belum ada penugasan

        cursor.execute("SELECT setting_value FROM settings WHERE setting_key = %s", (setting_key,))
        setting = cursor.fetchone()
        if not setting:
            return jsonify({'msg': 'Pengaturan tidak ditemukan'}), 404

        return jsonify({
            'setting_key': setting_key,
            'setting_value': setting['setting_value'],
            'tenaga_medis_name': 'Layanan Darurat Medis',
            'doctor_name': 'Layanan Darurat Medis',
            'specialization': 'Pusat Bantuan 119',
            'assigned': False
        })
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
