import json
from functools import wraps
from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import get_connection

notifications_bp = Blueprint('notifications', __name__)

def _get_cursor():
    conn = get_connection()
    if conn is None:
        return None, None
    return conn, conn.cursor(dictionary=True)

@notifications_bp.get('/notifications')
@jwt_required()
def get_notifications():
    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500
    try:
        cursor.execute("""
            SELECT n.id, n.patient_id, u.name AS patient_name, n.type, n.glucose_value, n.created_at
            FROM notifications n
            JOIN users u ON n.patient_id = u.id
            ORDER BY n.created_at DESC
            LIMIT 50
        """)
        notifs = cursor.fetchall()
        for n in notifs:
            n['glucose_value'] = str(n['glucose_value']) if n['glucose_value'] else None
            n['created_at'] = n['created_at'].isoformat() if n['created_at'] else None
        return jsonify(notifs)
    except Exception as e:
        conn.rollback()
        print("Error in get_notifications:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()