from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import db_connection
from functools import wraps

recommendations_bp = Blueprint('recommendations', __name__)

def medis_required(fn):
    @wraps(fn)
    @jwt_required()
    def wrapper(*args, **kwargs):
        identity = get_jwt_identity()
        if identity['role'] != 'tenaga_medis':
            return jsonify({'msg': 'Hanya tenaga medis'}), 403
        return fn(*args, **kwargs)
    return wrapper

@recommendations_bp.post('/patients/<int:patient_id>/recommendations')
@medis_required
@db_connection
def add_recommendation(cursor, patient_id):
    identity = get_jwt_identity()
    data = request.get_json()
    if not data or 'content' not in data:
        return jsonify({'msg': 'Konten rekomendasi diperlukan'}), 400

    cursor.execute(
        "INSERT INTO recommendations (patient_id, medis_id, content) VALUES (%s, %s, %s)",
        (patient_id, identity['id'], data['content'])
    )
    return jsonify({'msg': 'Rekomendasi terkirim'}), 201