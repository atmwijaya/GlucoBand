import json
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import get_connection

profile_bp = Blueprint('profile', __name__)

def _get_cursor():
    conn = get_connection()
    if conn is None:
        return None, None
    return conn, conn.cursor(dictionary=True)

@profile_bp.get('/profile')
@jwt_required()
def get_profile():
    identity_json = get_jwt_identity()
    if not identity_json:
        return jsonify({'msg': 'Token tidak valid'}), 422
    identity = json.loads(identity_json)
    user_id = identity['id']

    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500

    try:
        cursor.execute("""
            SELECT id, name, email, role, age, gender, weight_kg, height_cm, bmi,
                   blood_pressure_sys, blood_pressure_dia, diabetes_history, smoking_history
            FROM users WHERE id = %s
        """, (user_id,))
        user = cursor.fetchone()
        if not user:
            return jsonify({'msg': 'User tidak ditemukan'}), 404

        # Konversi Decimal ke float/string
        for key in ['weight_kg', 'height_cm', 'bmi']:
            if user.get(key) is not None:
                user[key] = float(user[key])
        return jsonify(user)
    except Exception as e:
        conn.rollback()
        print("Error in get_profile:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()

@profile_bp.put('/profile')
@jwt_required()
def update_profile():
    identity_json = get_jwt_identity()
    if not identity_json:
        return jsonify({'msg': 'Token tidak valid'}), 422
    identity = json.loads(identity_json)
    user_id = identity['id']

    data = request.get_json()
    if not data:
        return jsonify({'msg': 'Data tidak lengkap'}), 400

    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500

    try:
        allowed_fields = ['age', 'gender', 'weight_kg', 'height_cm',
                          'blood_pressure_sys', 'blood_pressure_dia',
                          'diabetes_history', 'smoking_history']
        updates = []
        values = []
        for field in allowed_fields:
            if field in data:
                updates.append(f"{field} = %s")
                values.append(data[field])

        if not updates:
            return jsonify({'msg': 'Tidak ada data yang diubah'}), 400

        values.append(user_id)
        sql = f"UPDATE users SET {', '.join(updates)} WHERE id = %s"
        cursor.execute(sql, values)
        conn.commit()
        return jsonify({'msg': 'Profil diperbarui'})
    except Exception as e:
        conn.rollback()
        print("Error in update_profile:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()