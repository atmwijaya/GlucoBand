import json
from functools import wraps
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import get_connection
from app.utils.decorators import get_current_user

tenaga_medis_bp = Blueprint('tenaga_medis', __name__)

def medis_required(fn):
    @wraps(fn)
    @jwt_required()
    def wrapper(*args, **kwargs):
        identity_json = get_jwt_identity()
        if not identity_json:
            return jsonify({'msg': 'Token tidak valid'}), 422
        try:
            identity = json.loads(identity_json)
        except json.JSONDecodeError:
            return jsonify({'msg': 'Token rusak'}), 422
        if identity.get('role') != 'tenaga_medis':
            return jsonify({'msg': 'Hanya tenaga medis yang dapat mengakses'}), 403
        return fn(identity, *args, **kwargs)
    return wrapper

def _get_cursor():
    conn = get_connection()
    if conn is None:
        return None, None
    return conn, conn.cursor(dictionary=True)

def ensure_tenaga_medis_schema(cursor):
    """Memastikan tabel tenaga_medis dan kolom relasi tenaga_medis_id pada users tersedia."""
    try:
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS tenaga_medis (
                id              BIGINT UNSIGNED    NOT NULL AUTO_INCREMENT,
                name            VARCHAR(100)       NOT NULL,
                phone_number    VARCHAR(30)        NOT NULL,
                specialization  VARCHAR(100)       NOT NULL DEFAULT 'Dokter Umum',
                is_active       TINYINT(1)         NOT NULL DEFAULT 1,
                created_at      TIMESTAMP          NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at      TIMESTAMP          NOT NULL DEFAULT CURRENT_TIMESTAMP
                                                   ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                KEY idx_tenaga_medis_active (is_active)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        """)

        # Cek apakah kolom tenaga_medis_id sudah ada di tabel users
        cursor.execute("""
            SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'tenaga_medis_id'
        """)
        if not cursor.fetchone():
            cursor.execute("""
                ALTER TABLE users ADD COLUMN tenaga_medis_id BIGINT UNSIGNED NULL;
            """)
    except Exception as e:
        print("Schema verification note:", e)

@tenaga_medis_bp.get('/tenaga-medis')
@medis_required
def get_all_tenaga_medis(identity):
    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500

    try:
        ensure_tenaga_medis_schema(cursor)

        # Ambil daftar tenaga medis aktif
        cursor.execute("""
            SELECT id, name, phone_number, specialization, is_active, created_at
            FROM tenaga_medis
            WHERE is_active = 1
            ORDER BY name ASC
        """)
        tenaga_medis_list = cursor.fetchall()

        # Ambil daftar pasien yang dilayani oleh masing-masing tenaga medis
        for tm in tenaga_medis_list:
            if tm.get('created_at'):
                tm['created_at'] = tm['created_at'].isoformat()

            cursor.execute("""
                SELECT id, name, email, age, gender, bmi
                FROM users
                WHERE tenaga_medis_id = %s AND role = 'pasien'
                ORDER BY name ASC
            """, (tm['id'],))
            patients = cursor.fetchall()
            for p in patients:
                if p.get('bmi') is not None:
                    p['bmi'] = str(p['bmi'])

            tm['patients'] = patients
            tm['patient_count'] = len(patients)

        return jsonify(tenaga_medis_list), 200
    except Exception as e:
        print("Error in get_all_tenaga_medis:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()

@tenaga_medis_bp.post('/tenaga-medis')
@medis_required
def create_tenaga_medis(identity):
    data = request.get_json()
    if not data or not data.get('name') or not data.get('phone_number'):
        return jsonify({'msg': 'Nama dan nomor telepon wajib diisi'}), 400

    name = str(data['name']).strip()
    phone_number = str(data['phone_number']).strip()
    specialization = str(data.get('specialization', 'Dokter Umum')).strip()
    patient_ids = data.get('patient_ids', [])

    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500

    try:
        ensure_tenaga_medis_schema(cursor)

        cursor.execute("""
            INSERT INTO tenaga_medis (name, phone_number, specialization)
            VALUES (%s, %s, %s)
        """, (name, phone_number, specialization))
        new_tm_id = cursor.lastrowid

        # Tetapkan pasien yang dilayani jika ada
        if patient_ids and isinstance(patient_ids, list):
            for pid in patient_ids:
                cursor.execute("""
                    UPDATE users SET tenaga_medis_id = %s WHERE id = %s AND role = 'pasien'
                """, (new_tm_id, pid))

        conn.commit()
        return jsonify({
            'msg': 'Tenaga medis berhasil ditambahkan',
            'id': new_tm_id
        }), 201
    except Exception as e:
        conn.rollback()
        print("Error in create_tenaga_medis:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()

@tenaga_medis_bp.put('/tenaga-medis/<int:id>')
@medis_required
def update_tenaga_medis(identity, id):
    data = request.get_json()
    if not data:
        return jsonify({'msg': 'Data tidak boleh kosong'}), 400

    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500

    try:
        ensure_tenaga_medis_schema(cursor)

        cursor.execute("SELECT id FROM tenaga_medis WHERE id = %s AND is_active = 1", (id,))
        if not cursor.fetchone():
            return jsonify({'msg': 'Tenaga medis tidak ditemukan'}), 404

        fields = []
        values = []
        if 'name' in data and data['name']:
            fields.append("name = %s")
            values.append(str(data['name']).strip())
        if 'phone_number' in data and data['phone_number']:
            fields.append("phone_number = %s")
            values.append(str(data['phone_number']).strip())
        if 'specialization' in data and data['specialization']:
            fields.append("specialization = %s")
            values.append(str(data['specialization']).strip())

        if fields:
            values.append(id)
            cursor.execute(f"UPDATE tenaga_medis SET {', '.join(fields)} WHERE id = %s", values)

        # Jika menyertakan daftar pasien yang dilayani
        if 'patient_ids' in data and isinstance(data['patient_ids'], list):
            patient_ids = data['patient_ids']
            # Lepas pasien lama yang ditugaskan ke tenaga medis ini
            cursor.execute("UPDATE users SET tenaga_medis_id = NULL WHERE tenaga_medis_id = %s", (id,))
            # Tetapkan pasien baru
            for pid in patient_ids:
                cursor.execute("UPDATE users SET tenaga_medis_id = %s WHERE id = %s AND role = 'pasien'", (id, pid))

        conn.commit()
        return jsonify({'msg': 'Data tenaga medis berhasil diperbarui'}), 200
    except Exception as e:
        conn.rollback()
        print("Error in update_tenaga_medis:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()

@tenaga_medis_bp.delete('/tenaga-medis/<int:id>')
@medis_required
def delete_tenaga_medis(identity, id):
    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500

    try:
        ensure_tenaga_medis_schema(cursor)

        cursor.execute("SELECT id FROM tenaga_medis WHERE id = %s", (id,))
        if not cursor.fetchone():
            return jsonify({'msg': 'Tenaga medis tidak ditemukan'}), 404

        # Lepaskan relasi pada semua pasien terlebih dahulu
        cursor.execute("UPDATE users SET tenaga_medis_id = NULL WHERE tenaga_medis_id = %s", (id,))

        # Hapus data tenaga medis
        cursor.execute("DELETE FROM tenaga_medis WHERE id = %s", (id,))
        conn.commit()
        return jsonify({'msg': 'Tenaga medis berhasil dihapus'}), 200
    except Exception as e:
        conn.rollback()
        print("Error in delete_tenaga_medis:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()

@tenaga_medis_bp.post('/tenaga-medis/assign')
@medis_required
def assign_patient_to_tenaga_medis(identity):
    """
    Menetapkan satu atau banyak pasien ke seorang tenaga medis.
    Payload: {"tenaga_medis_id": int, "patient_ids": [int, ...]}
             atau {"tenaga_medis_id": int, "patient_id": int}
    """
    data = request.get_json()
    if not data or 'tenaga_medis_id' not in data:
        return jsonify({'msg': 'tenaga_medis_id wajib disertakan'}), 400

    tm_id = data.get('tenaga_medis_id')
    patient_ids = data.get('patient_ids')
    if patient_ids is None and 'patient_id' in data:
        patient_ids = [data['patient_id']]

    if not patient_ids or not isinstance(patient_ids, list):
        return jsonify({'msg': 'patient_ids harus berupa daftar ID pasien'}), 400

    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500

    try:
        ensure_tenaga_medis_schema(cursor)

        if tm_id is not None:
            cursor.execute("SELECT id, name FROM tenaga_medis WHERE id = %s AND is_active = 1", (tm_id,))
            staff = cursor.fetchone()
            if not staff:
                return jsonify({'msg': 'Tenaga medis tidak ditemukan'}), 404

        for pid in patient_ids:
            cursor.execute("""
                UPDATE users SET tenaga_medis_id = %s WHERE id = %s AND role = 'pasien'
            """, (tm_id, pid))

        conn.commit()
        return jsonify({'msg': 'Penugasan tenaga medis pasien berhasil diperbarui'}), 200
    except Exception as e:
        conn.rollback()
        print("Error in assign_patient_to_tenaga_medis:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()

@tenaga_medis_bp.get('/tenaga-medis/my-doctor')
@jwt_required()
def get_my_doctor():
    """
    Mengambil data dokter/tenaga medis penanggung jawab pasien yang sedang login (untuk aplikasi mobile).
    Jika belum ditetapkan tenaga medis, akan mengembalikan nomor darurat default (119).
    """
    user = get_current_user()
    if not user:
        return jsonify({'msg': 'Token tidak valid'}), 401

    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500

    try:
        ensure_tenaga_medis_schema(cursor)

        cursor.execute("""
            SELECT tm.id, tm.name, tm.phone_number, tm.specialization
            FROM users u
            JOIN tenaga_medis tm ON u.tenaga_medis_id = tm.id
            WHERE u.id = %s AND tm.is_active = 1
        """, (user['id'],))
        doc = cursor.fetchone()

        if doc:
            return jsonify({
                'assigned': True,
                'id': doc['id'],
                'tenaga_medis_name': doc['name'],
                'phone_number': doc['phone_number'],
                'specialization': doc['specialization'],
                'emergency_contact': doc['phone_number']
            }), 200

        # Jika pasien belum ditentukan tenaga medisnya, ambil dari setting emergency_contact default
        cursor.execute("SELECT setting_value FROM settings WHERE setting_key = 'emergency_contact'")
        row = cursor.fetchone()
        default_number = row['setting_value'] if row else '119'

        return jsonify({
            'assigned': False,
            'id': None,
            'tenaga_medis_name': 'Layanan Darurat Medis',
            'phone_number': default_number,
            'specialization': 'Pusat Bantuan 119',
            'emergency_contact': default_number
        }), 200
    except Exception as e:
        print("Error in get_my_doctor:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()
