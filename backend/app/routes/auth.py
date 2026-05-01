import json
from flask import Blueprint, request, jsonify
from flask_jwt_extended import create_access_token
from datetime import timedelta
from db import db_connection

auth_bp = Blueprint('auth', __name__)

@auth_bp.post('/login')
@db_connection
def login(cursor):
    data = request.get_json()
    if not data or 'email' not in data or 'password' not in data:
        return jsonify({'msg': 'Email dan password harus diisi'}), 400

    cursor.execute("SELECT id, name, email, password, role FROM users WHERE email = %s", (data['email'],))
    user = cursor.fetchone()

    if not user:
        return jsonify({'msg': 'Email atau password salah'}), 401

    if user['password'] != data['password']:
        return jsonify({'msg': 'Email atau password salah'}), 401

    identity_string = json.dumps({'id': user['id'], 'role': user['role']})
    token = create_access_token(
        identity=identity_string,
        expires_delta=timedelta(hours=24)
    )
    return jsonify(token=token, user={
        'id': user['id'],
        'name': user['name'],
        'email': user['email'],
        'role': user['role']
    })

@auth_bp.post('/register/pasien')
@db_connection
def register_pasien(cursor):
    data = request.get_json()
    if not data or 'email' not in data or 'password' not in data:
        return jsonify({'msg': 'Data tidak lengkap'}), 400

    # Cek apakah email sudah terdaftar
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
        data['password'],
        data.get('age'),
        data.get('gender'),
        data.get('weight_kg'),
        data.get('height_cm'),
        data.get('blood_pressure_sys'),
        data.get('blood_pressure_dia'),
        data.get('diabetes_history', 0),
        data.get('smoking_history', 0)
    ))
    return jsonify({'msg': 'Registrasi berhasil'}), 201