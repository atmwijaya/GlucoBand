import json
from functools import wraps
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import get_connection

recommendations_bp = Blueprint('recommendations', __name__)

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
    conn = get_connection()
    if conn is None:
        return None, None
    return conn, conn.cursor(dictionary=True)

@recommendations_bp.post('/patients/<int:patient_id>/recommendations')
@medis_required
def add_recommendation(identity, patient_id):
    data = request.get_json()
    if not data or 'content' not in data:
        return jsonify({'msg': 'Konten rekomendasi diperlukan'}), 400

    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500
    try:
        cursor.execute(
            "INSERT INTO recommendations (patient_id, medis_id, content) VALUES (%s, %s, %s)",
            (patient_id, identity['id'], data['content'])
        )
        conn.commit()
        return jsonify({'msg': 'Rekomendasi terkirim'}), 201
    except Exception as e:
        conn.rollback()
        print("Error in add_recommendation:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()