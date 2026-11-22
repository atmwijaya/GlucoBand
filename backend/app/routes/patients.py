import json
from functools import wraps
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from werkzeug.security import generate_password_hash
from db import get_connection
from app.utils.validators import validate_password       
from app.utils.decorators import get_current_user       

patients_bp = Blueprint('patients', __name__)

def medis_required(fn):
    @wraps(fn)
    @jwt_required()
    def wrapper(*args, **kwargs):
        identity = get_current_user()
        if not identity:
            return jsonify({'msg': 'Token tidak valid'}), 422
        if identity.get('role') != 'tenaga_medis':
            return jsonify({'msg': 'Hanya tenaga medis yang dapat mengakses'}), 403
        return fn(identity, *args, **kwargs)
    return wrapper


def _get_cursor():
    conn = get_connection()
    if conn is None:
        return None, None
    return conn, conn.cursor(dictionary=True)


def _clean_num(val, cast_type=float):
    """Membersihkan nilai numerik: string kosong atau None diubah menjadi None (NULL di SQL)."""
    if val is None or str(val).strip() == '':
        return None
    try:
        return cast_type(val)
    except (ValueError, TypeError):
        return None


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
                   tm.specialization AS medical_staff_specialization,
                   (
                       SELECT m.glucose_estimated 
                       FROM measurements m 
                       WHERE m.patient_id = u.id 
                       ORDER BY m.created_at DESC 
                       LIMIT 1
                   ) AS latest_glucose,
                   (
                       SELECT m.created_at 
                       FROM measurements m 
                       WHERE m.patient_id = u.id 
                       ORDER BY m.created_at DESC 
                       LIMIT 1
                   ) AS latest_measurement_at,
                   (
                       SELECT pr.risk_level 
                       FROM predictions_risk pr 
                       WHERE pr.patient_id = u.id 
                       ORDER BY pr.created_at DESC 
                       LIMIT 1
                   ) AS risk_level
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
            p['latest_glucose'] = float(p['latest_glucose']) if p.get('latest_glucose') is not None else None
            p['latest_measurement_at'] = p['latest_measurement_at'].isoformat() if p.get('latest_measurement_at') else None
            p['created_at'] = p['created_at'].isoformat() if p['created_at'] else None
            p['risk_level'] = str(p['risk_level']).lower() if p.get('risk_level') is not None else None
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


@patients_bp.post('/patients/heartbeat')
@jwt_required()
def patient_heartbeat():
    """Endpoint heartbeat berkala dari background service aplikasi mobile pasien."""
    try:
        user = get_current_user()
        patient_id = None
        if user:
            patient_id = user.get('id')
        if not patient_id:
            req_data = request.get_json(silent=True) or {}
            patient_id = req_data.get('patient_id')

        if patient_id:
            from app.routes.socketEvents import record_patient_heartbeat
            record_patient_heartbeat(patient_id)
            return jsonify({'status': 'ok', 'patient_id': int(patient_id)}), 200
        return jsonify({'msg': 'patient_id tidak terdeteksi'}), 400
    except Exception as e:
        print("Error in patient_heartbeat:", e)
        return jsonify({'status': 'error', 'detail': str(e)}), 500


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
                   tm.specialization AS medical_staff_specialization,
                   (
                       SELECT m.glucose_estimated 
                       FROM measurements m 
                       WHERE m.patient_id = u.id 
                       ORDER BY m.created_at DESC 
                       LIMIT 1
                   ) AS latest_glucose,
                   (
                       SELECT m.created_at 
                       FROM measurements m 
                       WHERE m.patient_id = u.id 
                       ORDER BY m.created_at DESC 
                       LIMIT 1
                   ) AS latest_measurement_at,
                   (
                       SELECT pr.risk_level 
                       FROM predictions_risk pr 
                       WHERE pr.patient_id = u.id 
                       ORDER BY pr.created_at DESC 
                       LIMIT 1
                   ) AS risk_level
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
        patient['latest_glucose'] = float(patient['latest_glucose']) if patient.get('latest_glucose') is not None else None
        patient['latest_measurement_at'] = patient['latest_measurement_at'].isoformat() if patient.get('latest_measurement_at') else None
        patient['created_at'] = patient['created_at'].isoformat() if patient['created_at'] else None
        patient['risk_level'] = str(patient['risk_level']).lower() if patient.get('risk_level') is not None else None
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
    if not data:
        return jsonify({'msg': 'Data tidak ditemukan dalam request (harus berformat JSON)'}), 400

    name = str(data.get('name', '')).strip()
    if not name:
        return jsonify({'msg': 'Nama lengkap wajib diisi'}), 400

    raw_email = str(data.get('email', '')).strip().lower()
    if not raw_email:
        return jsonify({'msg': 'Email wajib diisi'}), 400
    if '@' not in raw_email or '.' not in raw_email:
        return jsonify({'msg': 'Format email tidak valid'}), 400
    email = raw_email

    password = str(data.get('password', '')).strip()
    if not password:
        return jsonify({'msg': 'Password wajib diisi'}), 400

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

        age = _clean_num(data.get('age'), int)
        weight_kg = _clean_num(data.get('weight_kg'), float)
        height_cm = _clean_num(data.get('height_cm'), float)
        bp_sys = _clean_num(data.get('blood_pressure_sys'), int)
        bp_dia = _clean_num(data.get('blood_pressure_dia'), int)
        diabetes_history = int(data.get('diabetes_history') or 0)
        smoking_history = int(data.get('smoking_history') or 0)
        tenaga_medis_id = _clean_num(data.get('tenaga_medis_id') or data.get('medical_staff_id'), int)

        sql = """
            INSERT INTO users (name, email, password, role, age, gender, weight_kg, height_cm,
                              blood_pressure_sys, blood_pressure_dia, diabetes_history, smoking_history, tenaga_medis_id)
            VALUES (%s, %s, %s, 'pasien', %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        cursor.execute(sql, (
            name,
            email,
            hashed_password,
            age,
            data.get('gender') or 'L',
            weight_kg,
            height_cm,
            bp_sys,
            bp_dia,
            diabetes_history,
            smoking_history,
            tenaga_medis_id
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
    if not data:
        return jsonify({'msg': 'Data tidak ditemukan dalam request'}), 400

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

        num_int_fields = {'age', 'blood_pressure_sys', 'blood_pressure_dia', 'diabetes_history', 'smoking_history', 'tenaga_medis_id'}
        num_float_fields = {'weight_kg', 'height_cm'}

        for key in ['name', 'email', 'age', 'gender', 'weight_kg', 'height_cm',
                    'blood_pressure_sys', 'blood_pressure_dia', 'diabetes_history', 'smoking_history', 'tenaga_medis_id']:
            if key in data:
                val = data[key]
                if key == 'email' and val:
                    val = str(val).strip().lower()
                    if '@' not in val or '.' not in val:
                        return jsonify({'msg': 'Format email tidak valid'}), 400
                elif key == 'name' and val:
                    val = str(val).strip()
                elif key in num_int_fields:
                    val = _clean_num(val, int)
                elif key in num_float_fields:
                    val = _clean_num(val, float)

                fields.append(f"{key} = %s")
                values.append(val)

        if 'medical_staff_id' in data and 'tenaga_medis_id' not in data:
            fields.append("tenaga_medis_id = %s")
            values.append(_clean_num(data['medical_staff_id'], int))

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