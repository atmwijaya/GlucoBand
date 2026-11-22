import json
from flask import Blueprint, request, jsonify
from flask_jwt_extended import (
    create_access_token,
    create_refresh_token,
    jwt_required,
    get_jwt_identity
)
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
    input_password = str(data['password']).strip()

    is_locked, remaining_seconds = login_rate_limiter.is_locked(client_ip, email)
    if is_locked:
        minutes = max(1, (remaining_seconds + 59) // 60)
        time_desc = f"{minutes} menit" if remaining_seconds >= 60 else f"{remaining_seconds} detik"
        return jsonify({
            'msg': f'Terlalu banyak percobaan login gagal. Akun dibekukan sementara. Coba lagi dalam {time_desc}.',
            'retry_after_seconds': remaining_seconds
        }), 429

    cursor.execute("SELECT id, name, email, password, role FROM users WHERE LOWER(email) = %s", (email,))
    user = cursor.fetchone()

    if not user:
        is_now_locked, lockout_dur, remaining = login_rate_limiter.record_failure(client_ip, email)
        if is_now_locked:
            minutes = max(1, (lockout_dur + 59) // 60)
            time_desc = f"{minutes} menit" if lockout_dur >= 60 else f"{lockout_dur} detik"
            return jsonify({
                'msg': f'Batas percobaan login tercapai. Akun dibekukan sementara selama {time_desc}.',
                'retry_after_seconds': lockout_dur
            }), 429
        return jsonify({
            'msg': f'Email atau kata sandi salah. Sisa percobaan: {remaining} kali.'
        }), 401

    stored_password = str(user['password']).strip()
    is_valid = False
    needs_upgrade = False

    try:
        is_valid = check_password_hash(stored_password, input_password)
    except Exception:
        is_valid = False

    # Fallback jika password di database masih berupa plain-text (belum di-hash)
    if not is_valid and stored_password == input_password:
        is_valid = True
        needs_upgrade = True

    if not is_valid:
        is_now_locked, lockout_dur, remaining = login_rate_limiter.record_failure(client_ip, email)
        if is_now_locked:
            minutes = max(1, (lockout_dur + 59) // 60)
            time_desc = f"{minutes} menit" if lockout_dur >= 60 else f"{lockout_dur} detik"
            return jsonify({
                'msg': f'Batas percobaan login tercapai. Akun dibekukan sementara selama {time_desc}.',
                'retry_after_seconds': lockout_dur
            }), 429
        return jsonify({
            'msg': f'Email atau kata sandi salah. Sisa percobaan: {remaining} kali.'
        }), 401

    login_rate_limiter.record_success(client_ip, email)

    if needs_upgrade:
        try:
            new_hash = generate_password_hash(input_password)
            cursor.execute("UPDATE users SET password = %s WHERE id = %s", (new_hash, user['id']))
        except Exception as e:
            print("Peringatan: Gagal meng-upgrade password hash user:", e)

    identity_string = json.dumps({'id': user['id'], 'role': user['role']})
    access_token = create_access_token(
        identity=identity_string,
        expires_delta=timedelta(days=1)
    )
    refresh_token = create_refresh_token(
        identity=identity_string,
        expires_delta=timedelta(days=30)
    )

    return jsonify({
        'token': access_token,            
        'access_token': access_token,       
        'refresh_token': refresh_token,     
        'user': {
            'id': user['id'],
            'name': user['name'],
            'email': user['email'],
            'role': user['role']
        }
    })

@auth_bp.post('/refresh')
@jwt_required(refresh=True)
def refresh_token_endpoint():
    """
    Endpoint pembaruan token (JWT Refresh).
    Klien mengirimkan Refresh Token di header 'Authorization: Bearer <REFRESH_TOKEN>'
    untuk mendapatkan Access Token baru tanpa meminta kata sandi pengguna kembali.
    """
    identity = get_jwt_identity()
    new_access_token = create_access_token(
        identity=identity,
        expires_delta=timedelta(days=1)
    )
    return jsonify({
        'token': new_access_token,
        'access_token': new_access_token
    }), 200

@auth_bp.post('/register/pasien')
@db_connection
def register_pasien(cursor):
    data = request.get_json()
    if not data or 'email' not in data or 'password' not in data:
        return jsonify({'msg': 'Data tidak lengkap'}), 400

    email = str(data['email']).strip().lower()
    password = str(data['password'])

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

@auth_bp.post('/change-password')
@jwt_required()
@db_connection
def change_password(cursor):
    """Mengubah kata sandi akun pengguna (Pasien / Tenaga Medis)."""
    from app.utils.decorators import get_current_user
    user = get_current_user()
    if not user:
        return jsonify({'msg': 'Token otentikasi tidak valid'}), 401

    data = request.get_json()
    if not data:
        return jsonify({'msg': 'Data tidak lengkap'}), 400

    old_password = str(data.get('old_password', '')).strip()
    new_password = str(data.get('new_password', '')).strip()

    if not old_password or not new_password:
        return jsonify({'msg': 'Kata sandi lama dan baru wajib diisi'}), 400

    cursor.execute("SELECT id, password FROM users WHERE id = %s", (user['id'],))
    row = cursor.fetchone()
    if not row:
        return jsonify({'msg': 'Pengguna tidak ditemukan'}), 404

    stored_password = str(row['password']).strip()
    is_valid = False
    try:
        is_valid = check_password_hash(stored_password, old_password)
    except Exception:
        is_valid = False

    if not is_valid and stored_password == old_password:
        is_valid = True

    if not is_valid:
        return jsonify({'msg': 'Kata sandi saat ini (lama) tidak cocok'}), 400

    is_valid_pw, pw_err = validate_password(new_password)
    if not is_valid_pw:
        return jsonify({'msg': pw_err}), 400

    new_hash = generate_password_hash(new_password)
    cursor.execute("UPDATE users SET password = %s WHERE id = %s", (new_hash, user['id']))
    return jsonify({'msg': 'Kata sandi berhasil diperbarui'}), 200
