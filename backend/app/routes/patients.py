import json
from functools import wraps
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from werkzeug.security import generate_password_hash
from db import get_connection
from app.utils.validators import validate_password       

patients_bp = Blueprint('patients', __name__)

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


@patients_bp.get('/patients')
@medis_required
def get_patients(identity):
    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500
    try:
        from app.routes.tenagaMedis import ensure_tenaga_medis_schema
        ensure_tenaga_medis_schema(cursor)

        cursor.execute("""
            SELECT u.id, u.name, u.email, u.age, u.gender, u.weight_kg, u.height_cm,
                   u.bmi, u.blood_pressure_sys, u.blood_pressure_dia,
                   u.diabetes_history, u.smoking_history, u.created_at,
                   u.tenaga_medis_id, tm.name AS tenaga_medis_name, tm.phone_number AS tenaga_medis_phone,
                   tm.specialization AS tenaga_medis_specialization,
                   tm.name AS medical_staff_name, tm.phone_number AS medical_staff_phone,
                   tm.specialization AS medical_staff_specialization
            FROM users u
            LEFT JOIN tenaga_medis tm ON u.tenaga_medis_id = tm.id
            WHERE u.role = 'pasien'
            ORDER BY u.created_at DESC
        """)
        patients = cursor.fetchall()
        for p in patients:
            p['bmi'] = str(p['bmi']) if p['bmi'] is not None else None
            p['weight_kg'] = str(p['weight_kg']) if p['weight_kg'] is not None else None
            p['height_cm'] = str(p['height_cm']) if p['height_cm'] is not None else None
            p['created_at'] = p['created_at'].isoformat() if p['created_at'] else None
        return jsonify(patients)
    except Exception as e:
        conn.rollback()
        print("Error in get_patients:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()


@patients_bp.get('/patients/online')
@jwt_required()
def get_online_patients():
    try:
        from app.routes.socketEvents import get_online_patient_ids
        return jsonify(get_online_patient_ids()), 200
    except Exception as e:
        print("Error in get_online_patients:", e)
        return jsonify([]), 200


@patients_bp.get('/patients/<int:id>')
@medis_required
def get_patient(identity, id):
    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500
    try:
        from app.routes.tenagaMedis import ensure_tenaga_medis_schema
        ensure_tenaga_medis_schema(cursor)

        cursor.execute("""
            SELECT u.id, u.name, u.email, u.age, u.gender, u.weight_kg, u.height_cm,
                   u.bmi, u.blood_pressure_sys, u.blood_pressure_dia,
                   u.diabetes_history, u.smoking_history, u.created_at,
                   u.tenaga_medis_id, tm.name AS tenaga_medis_name, tm.phone_number AS tenaga_medis_phone,
                   tm.specialization AS tenaga_medis_specialization,
                   tm.name AS medical_staff_name, tm.phone_number AS medical_staff_phone,
                   tm.specialization AS medical_staff_specialization
            FROM users u
            LEFT JOIN tenaga_medis tm ON u.tenaga_medis_id = tm.id
            WHERE u.id = %s AND u.role = 'pasien'
        """, (id,))
        patient = cursor.fetchone()
        if not patient:
            return jsonify({'msg': 'Pasien tidak ditemukan'}), 404
        patient['bmi'] = str(patient['bmi']) if patient['bmi'] is not None else None
        patient['weight_kg'] = str(patient['weight_kg']) if patient['weight_kg'] is not None else None
        patient['height_cm'] = str(patient['height_cm']) if patient['height_cm'] is not None else None
        patient['created_at'] = patient['created_at'].isoformat() if patient['created_at'] else None
        return jsonify(patient)
    except Exception as e:
        conn.rollback()
        print("Error in get_patient:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()


@patients_bp.post('/patients')
@medis_required
def add_patient(identity):
    data = request.get_json()
    if not data or 'email' not in data or 'password' not in data:
        return jsonify({'msg': 'Data tidak lengkap'}), 400

    email = str(data['email']).strip().lower()
    password = str(data['password']).strip()

    is_valid_pw, pw_err = validate_password(password)
    if not is_valid_pw:
        return jsonify({'msg': pw_err}), 400

    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500
    try:
        from app.routes.tenagaMedis import ensure_tenaga_medis_schema
        ensure_tenaga_medis_schema(cursor)

        cursor.execute("SELECT id FROM users WHERE LOWER(email) = %s", (email,))
        if cursor.fetchone():
            return jsonify({'msg': 'Email sudah terdaftar'}), 409

        # Enkripsi / Hashing kata sandi pasien
        hashed_password = generate_password_hash(password)

        sql = """
            INSERT INTO users (name, email, password, role, age, gender, weight_kg, height_cm,
                              blood_pressure_sys, blood_pressure_dia, diabetes_history, smoking_history, tenaga_medis_id)
            VALUES (%s, %s, %s, 'pasien', %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        cursor.execute(sql, (
            data.get('name'),
            email,
            hashed_password,
            data.get('age'),
            data.get('gender'),
            data.get('weight_kg'),
            data.get('height_cm'),
            data.get('blood_pressure_sys'),
            data.get('blood_pressure_dia'),
            data.get('diabetes_history', 0),
            data.get('smoking_history', 0),
            data.get('tenaga_medis_id') or data.get('medical_staff_id')
        ))
        conn.commit()
        return jsonify({'msg': 'Pasien berhasil ditambahkan', 'id': cursor.lastrowid or 0}), 201
    except Exception as e:
        conn.rollback()
        print("Error in add_patient:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()


@patients_bp.put('/patients/<int:id>')
@medis_required
def update_patient(identity, id):
    data = request.get_json()
    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500
    try:
        from app.routes.tenagaMedis import ensure_tenaga_medis_schema
        ensure_tenaga_medis_schema(cursor)

        cursor.execute("SELECT id FROM users WHERE id = %s AND role = 'pasien'", (id,))
        if not cursor.fetchone():
            return jsonify({'msg': 'Pasien tidak ditemukan'}), 404

        fields = []
        values = []
        for key in ['name', 'email', 'age', 'gender', 'weight_kg', 'height_cm',
                    'blood_pressure_sys', 'blood_pressure_dia', 'diabetes_history', 'smoking_history', 'tenaga_medis_id']:
            if key in data:
                val = data[key]
                if key == 'email' and val:
                    val = str(val).strip().lower()
                fields.append(f"{key} = %s")
                values.append(val)
        if 'medical_staff_id' in data and 'tenaga_medis_id' not in data:
            fields.append("tenaga_medis_id = %s")
            values.append(data['medical_staff_id'])

        if 'password' in data and data['password']:
            new_password = str(data['password']).strip()
            is_valid_pw, pw_err = validate_password(new_password)
            if not is_valid_pw:
                return jsonify({'msg': f"Kata sandi baru: {pw_err}"}), 400
            fields.append("password = %s")
            values.append(generate_password_hash(new_password))

        if not fields:
            return jsonify({'msg': 'Tidak ada data yang diubah'}), 400

        values.append(id)
        sql = f"UPDATE users SET {', '.join(fields)} WHERE id = %s"
        cursor.execute(sql, values)
        conn.commit()
        return jsonify({'msg': 'Data pasien diperbarui'})
    except Exception as e:
        conn.rollback()
        print("Error in update_patient:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()


@patients_bp.delete('/patients/<int:id>')
@medis_required
def delete_patient(identity, id):
    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500
    try:
        cursor.execute("SELECT id FROM users WHERE id = %s AND role = 'pasien'", (id,))
        if not cursor.fetchone():
            return jsonify({'msg': 'Pasien tidak ditemukan'}), 404
        cursor.execute("DELETE FROM users WHERE id = %s", (id,))
        conn.commit()
        return jsonify({'msg': 'Pasien dihapus'})
    except Exception as e:
        conn.rollback()
        print("Error in delete_patient:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()