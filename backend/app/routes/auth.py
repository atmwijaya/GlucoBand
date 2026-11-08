import json
from flask import Blueprint, request, jsonify
from flask_jwt_extended import create_access_token
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import timedelta
from db import db_connection
from app.utils.validators import validate_password, login_rate_limiter

auth_bp = Blueprint('auth', __name__)

@auth_bp.post('/login')
@db_connection
def login(cursor):
    data = request.get_json()
    if not data or 'email' not in data or 'password' not in data:
        return jsonify({'msg': 'Email dan kata sandi harus diisi'}), 400

    client_ip = login_rate_limiter.get_client_ip(request)
    email = str(data['email']).strip().lower()
    input_password = str(data['password'])

    # 1. Proteksi Brute-force: Cek apakah kombinasi IP/email sedang dibekukan
    is_locked, remaining_seconds = login_rate_limiter.is_locked(client_ip, email)
    if is_locked:
        minutes = max(1, (remaining_seconds + 59) // 60)
        return jsonify({
            'msg': f'Terlalu banyak percobaan login gagal. Percobaan dibekukan sementara demi keamanan. Coba lagi dalam {minutes} menit.',
            'retry_after_seconds': remaining_seconds
        }), 429

    cursor.execute("SELECT id, name, email, password, role FROM users WHERE LOWER(email) = %s", (email,))
    user = cursor.fetchone()

    if not user:
        # Catat kegagalan jika user tidak ditemukan (mencegah enumerasi akun secara massal)
        is_now_locked, lockout_dur, remaining = login_rate_limiter.record_failure(client_ip, email)
        if is_now_locked:
            return jsonify({
                'msg': 'Terlalu banyak percobaan login gagal. Percobaan dibekukan sementara selama 5 menit.',
                'retry_after_seconds': lockout_dur
            }), 429
        return jsonify({
            'msg': f'Email atau kata sandi salah. Sisa percobaan: {remaining} kali.'
        }), 401

    stored_password = str(user['password'])
    is_valid = False
    needs_upgrade = False

    if stored_password.startswith(('scrypt:', 'pbkdf2:', 'sha256:', '$2b$', '$2a$')):
        try:
            is_valid = check_password_hash(stored_password, input_password)
        except Exception:
            is_valid = False
    else:
        if stored_password == input_password:
            is_valid = True
            needs_upgrade = True

    if not is_valid:
        # Catat kegagalan jika kata sandi tidak cocok
        is_now_locked, lockout_dur, remaining = login_rate_limiter.record_failure(client_ip, email)
        if is_now_locked:
            return jsonify({
                'msg': 'Terlalu banyak percobaan login gagal. Akun dibekukan sementara selama 5 menit demi keamanan.',
                'retry_after_seconds': lockout_dur
            }), 429
        return jsonify({
            'msg': f'Email atau kata sandi salah. Sisa percobaan: {remaining} kali.'
        }), 401

    # 2. Login Berhasil -> Reset counter kegagalan
    login_rate_limiter.record_success(client_ip, email)

    # 3. Upgrade otomatis akun lama ke hash scrypt
    if needs_upgrade:
        try:
            new_hash = generate_password_hash(input_password)
            cursor.execute("UPDATE users SET password = %s WHERE id = %s", (new_hash, user['id']))
        except Exception as e:
            print("Peringatan: Gagal meng-upgrade password hash user:", e)

    identity_string = json.dumps({'id': user['id'], 'role': user['role']})
    token = create_access_token(
        identity=identity_string,
        expires_delta=timedelta(days=30)
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

    email = str(data['email']).strip().lower()
    password = str(data['password']).strip()

    # Validasi kekuatan kata sandi: minimal 8 karakter, harus ada huruf dan angka
    is_valid_pw, pw_err_msg = validate_password(password)
    if not is_valid_pw:
        return jsonify({'msg': pw_err_msg}), 400

    cursor.execute("SELECT id FROM users WHERE LOWER(email) = %s", (email,))
    if cursor.fetchone():
        return jsonify({'msg': 'Email sudah terdaftar'}), 409

    hashed_password = generate_password_hash(password)

    sql = """
        INSERT INTO users (name, email, password, role, age, gender, weight_kg, height_cm,
                          blood_pressure_sys, blood_pressure_dia, diabetes_history, smoking_history)
        VALUES (%s, %s, %s, 'pasien', %s, %s, %s, %s, %s, %s, %s, %s)
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
        data.get('smoking_history', 0)
    ))
    return jsonify({'msg': 'Registrasi berhasil'}), 201
