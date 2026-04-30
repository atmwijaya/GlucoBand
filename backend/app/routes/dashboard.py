import json
from functools import wraps
from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import get_connection      

dashboard_bp = Blueprint('dashboard', __name__)

def medis_required(fn):
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
            return jsonify({'msg': 'Hanya tenaga medis'}), 403
        return fn(identity, *args, **kwargs)
    return wrapper

def _get_cursor():
    """Helper: dapatkan koneksi dan cursor (dictionary=True)."""
    conn = get_connection()
    if conn is None:
        return None, None
    return conn, conn.cursor(dictionary=True)

@dashboard_bp.get('/dashboard/stats')
@medis_required
def dashboard_stats(identity):
    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500
    try:
        cursor.execute("SELECT COUNT(*) AS total FROM users WHERE role = 'pasien'")
        total_patients = cursor.fetchone()['total']

        cursor.execute("SELECT COUNT(*) AS total FROM notifications WHERE DATE(created_at) = CURDATE()")
        alerts_today = cursor.fetchone()['total']

        cursor.execute("SELECT COUNT(*) AS total FROM measurements")
        total_measurements = cursor.fetchone()['total']

        return jsonify({
            'total_patients': total_patients,
            'alerts_today': alerts_today,
            'total_measurements': total_measurements
        })
    except Exception as e:
        conn.rollback()
        print("Error in dashboard_stats:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()