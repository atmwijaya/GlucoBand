import json
import bcrypt
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

    # Verifikasi password dengan bcrypt
    stored_hash = user['password'].encode('utf-8')
    if not bcrypt.checkpw(data['password'].encode('utf-8'), stored_hash):
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