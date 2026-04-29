import json
from functools import wraps
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import db_connection

patients_bp = Blueprint('patients', __name__)

def medis_required(fn):
    """Decorator untuk memvalidasi JWT dan role tenaga medis."""
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
        # Teruskan identity sebagai argumen posisi pertama
        return fn(identity, *args, **kwargs)
    return wrapper


# ---------------------------------------------------------------------
# GET /patients
@patients_bp.get('/patients')
@medis_required
@db_connection
def get_patients(identity, cursor):
    cursor.execute("""
        SELECT id, name, email, age, gender, weight_kg, height_cm,
               bmi, blood_pressure_sys, blood_pressure_dia,
               diabetes_history, smoking_history, created_at
        FROM users WHERE role = 'pasien'
        ORDER BY created_at DESC
    """)
    patients = cursor.fetchall()
    for p in patients:
        p['bmi'] = str(p['bmi']) if p['bmi'] is not None else None
        p['weight_kg'] = str(p['weight_kg']) if p['weight_kg'] is not None else None
        p['height_cm'] = str(p['height_cm']) if p['height_cm'] is not None else None
        p['created_at'] = p['created_at'].isoformat() if p['created_at'] else None
    return jsonify(patients)


# GET /patients/<id>
@patients_bp.get('/patients/<int:id>')
@medis_required
@db_connection
def get_patient(identity, cursor, id):
    cursor.execute("""
        SELECT id, name, email, age, gender, weight_kg, height_cm,
               bmi, blood_pressure_sys, blood_pressure_dia,
               diabetes_history, smoking_history, created_at
        FROM users WHERE id = %s AND role = 'pasien'
    """, (id,))
    patient = cursor.fetchone()
    if not patient:
        return jsonify({'msg': 'Pasien tidak ditemukan'}), 404
    patient['bmi'] = str(patient['bmi']) if patient['bmi'] is not None else None
    patient['weight_kg'] = str(patient['weight_kg']) if patient['weight_kg'] is not None else None
    patient['height_cm'] = str(patient['height_cm']) if patient['height_cm'] is not None else None
    patient['created_at'] = patient['created_at'].isoformat() if patient['created_at'] else None
    return jsonify(patient)


# POST /patients
@patients_bp.post('/patients')
@medis_required
@db_connection
def add_patient(identity, cursor):
    data = request.get_json()
    if not data or 'email' not in data or 'password' not in data:
        return jsonify({'msg': 'Data tidak lengkap'}), 400

    cursor.execute("SELECT id FROM users WHERE email = %s", (data['email'],))
    if cursor.fetchone():
        return jsonify({'msg': 'Email sudah terdaftar'}), 409

    sql = """
        INSERT INTO users (name, email, password, role, age, gender, weight_kg, height_cm,
                          blood_pressure_sys, blood_pressure_dia, diabetes_history, smoking_history)
        VALUES (%s, %s, %s, 'pasien', %s, %s, %s, %s, %s, %s, %s, %s)
    """
    cursor.execute(sql, (
        data.get('name'),
        data['email'],
        data['password'],          # plaintext sesuai permintaan
        data.get('age'),
        data.get('gender'),
        data.get('weight_kg'),
        data.get('height_cm'),
        data.get('blood_pressure_sys'),
        data.get('blood_pressure_dia'),
        data.get('diabetes_history', 0),
        data.get('smoking_history', 0)
    ))
    return jsonify({'msg': 'Pasien berhasil ditambahkan', 'id': cursor.lastrowid or 0}), 201


# PUT /patients/<id>
@patients_bp.put('/patients/<int:id>')
@medis_required
@db_connection
def update_patient(identity, cursor, id):
    data = request.get_json()
    cursor.execute("SELECT id FROM users WHERE id = %s AND role = 'pasien'", (id,))
    if not cursor.fetchone():
        return jsonify({'msg': 'Pasien tidak ditemukan'}), 404

    fields = []
    values = []
    for key in ['name', 'email', 'age', 'gender', 'weight_kg', 'height_cm',
                'blood_pressure_sys', 'blood_pressure_dia', 'diabetes_history', 'smoking_history']:
        if key in data:
            fields.append(f"{key} = %s")
            values.append(data[key])

    if 'password' in data and data['password']:
        fields.append("password = %s")
        values.append(data['password'])   # plaintext

    if not fields:
        return jsonify({'msg': 'Tidak ada data yang diubah'}), 400

    values.append(id)
    sql = f"UPDATE users SET {', '.join(fields)} WHERE id = %s"
    cursor.execute(sql, values)
    return jsonify({'msg': 'Data pasien diperbarui'})


# DELETE /patients/<id>
@patients_bp.delete('/patients/<int:id>')
@medis_required
@db_connection
def delete_patient(identity, cursor, id):
    cursor.execute("SELECT id FROM users WHERE id = %s AND role = 'pasien'", (id,))
    if not cursor.fetchone():
        return jsonify({'msg': 'Pasien tidak ditemukan'}), 404
    cursor.execute("DELETE FROM users WHERE id = %s", (id,))
    return jsonify({'msg': 'Pasien dihapus'})