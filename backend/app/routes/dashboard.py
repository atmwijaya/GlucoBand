from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import db_connection
from functools import wraps

dashboard_bp = Blueprint('dashboard', __name__) 

def medis_required(fn):
    @wraps(fn)
    @jwt_required()
    def wrapper(*args, **kwargs):
        identity = get_jwt_identity()
        if identity['role'] != 'tenaga_medis':
            return jsonify({'msg': 'Hanya tenaga medis'}), 403
        return fn(*args, **kwargs)
    return wrapper

@dashboard_bp.get('/dashboard/stats')
@medis_required
@db_connection
def dashboard_stats(cursor):
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