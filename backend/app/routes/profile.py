from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from db import get_connection
from app.utils.decorators import get_current_user

profile_bp = Blueprint('profile', __name__)

def _get_cursor():
    conn = get_connection()
    if conn is None:
        return None, None
    return conn, conn.cursor(dictionary=True)

@profile_bp.get('/profile')
@jwt_required()
def get_profile():
    user = get_current_user()
    if not user:
        return jsonify({'msg': 'Token otentikasi tidak valid'}), 401
    user_id = user['id']

    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500

    try:
        from app.routes.tenagaMedis import ensure_tenaga_medis_schema
        ensure_tenaga_medis_schema(cursor)

        cursor.execute("""
            SELECT u.id, u.name, u.email, u.role, u.age, u.gender, u.weight_kg, u.height_cm, u.bmi,
                   u.blood_pressure_sys, u.blood_pressure_dia, u.diabetes_history, u.smoking_history,
                   u.tenaga_medis_id,
                   tm.name AS tenaga_medis_name,
                   tm.phone_number AS tenaga_medis_phone,
                   tm.specialization AS tenaga_medis_specialization,
                   tm.name AS medical_staff_name,
                   tm.phone_number AS medical_staff_phone,
                   tm.specialization AS medical_staff_specialization
            FROM users u
            LEFT JOIN tenaga_medis tm ON u.tenaga_medis_id = tm.id
            WHERE u.id = %s
        """, (user_id,))
        user_row = cursor.fetchone()
        if not user_row:
            return jsonify({'msg': 'User tidak ditemukan'}), 404

        # Konversi Decimal ke float/string
        for key in ['weight_kg', 'height_cm', 'bmi']:
            if user_row.get(key) is not None:
                user_row[key] = float(user_row[key])
        return jsonify(user_row)
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
    user = get_current_user()
    if not user:
        return jsonify({'msg': 'Token otentikasi tidak valid'}), 401
    user_id = user['id']

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
