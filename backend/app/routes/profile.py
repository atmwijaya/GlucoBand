from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import db_connection
import bcrypt

profile_bp = Blueprint('profile', __name__)

@profile_bp.get('/profile')
@jwt_required()
@db_connection
def get_profile(cursor):
    identity = get_jwt_identity()
    cursor.execute("SELECT * FROM users WHERE id = %s", (identity['id'],))
    user = cursor.fetchone()
    if not user:
        return jsonify({'msg': 'User tidak ditemukan'}), 404
    user.pop('password', None)
    return jsonify(user)

@profile_bp.put('/profile')
@jwt_required()
@db_connection
def update_profile(cursor):
    identity = get_jwt_identity()
    data = request.get_json()
    updates = []
    values = []
    if 'name' in data:
        updates.append("name = %s")
        values.append(data['name'])
    if 'email' in data:
        updates.append("email = %s")
        values.append(data['email'])
    if 'password' in data and data['password']:
        hashed = bcrypt.hashpw(data['password'].encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
        updates.append("password = %s")
        values.append(hashed)
    if updates:
        values.append(identity['id'])
        cursor.execute(f"UPDATE users SET {', '.join(updates)} WHERE id = %s", values)
    return jsonify({'msg': 'Profil diperbarui'})