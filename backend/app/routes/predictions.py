import json
from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required
from db import db_connection
from app.utils.decorators import get_current_user, can_access_patient, patient_owner_or_medis

predictions_bp = Blueprint('predictions', __name__)

@predictions_bp.get('/predictions/trend/<int:patient_id>')
@patient_owner_or_medis('patient_id')
@db_connection
def get_trend(cursor, patient_id):
    """
    Mengambil data tren prediksi glukosa terbaru pasien.
    Anti-IDOR: Pasien hanya bisa melihat prediksi miliknya sendiri.
    """
    cursor.execute("""
        SELECT * FROM predictions_trend
        WHERE patient_id = %s
        ORDER BY created_at DESC
        LIMIT 1
    """, (patient_id,))
    trend = cursor.fetchone()
    if not trend:
        return jsonify([])
    return jsonify(trend['predicted_values'])

@predictions_bp.get('/predictions/risk/<int:patient_id>')
@patient_owner_or_medis('patient_id')
@db_connection
def get_risk(cursor, patient_id):
    """
    Mengambil level risiko diabetes terbaru pasien.
    Anti-IDOR: Pasien hanya bisa melihat prediksi miliknya sendiri.
    """
    cursor.execute("""
        SELECT risk_level, risk_score FROM predictions_risk
        WHERE patient_id = %s
        ORDER BY created_at DESC
        LIMIT 1
    """, (patient_id,))
    risk = cursor.fetchone()
    if not risk:
        return jsonify({'risk_level': 'unknown', 'risk_score': 0})
    return jsonify(risk)

@predictions_bp.get('/predictions/trend/<int:patient_id>/history')
@patient_owner_or_medis('patient_id')
@db_connection
def get_trend_history(cursor, patient_id):
    """
    Mengambil seluruh riwayat tren prediksi glukosa pasien.
    Anti-IDOR: Pasien hanya bisa melihat riwayat miliknya sendiri.
    """
    cursor.execute("""
        SELECT * FROM predictions_trend
        WHERE patient_id = %s
        ORDER BY created_at DESC
    """, (patient_id,))
    trends = cursor.fetchall()

    for trend in trends:
        if 'created_at' in trend and hasattr(trend['created_at'], 'isoformat'):
            trend['created_at'] = trend['created_at'].isoformat()
        # Parse JSON fields before sending
        if isinstance(trend.get('health_snapshot'), str):
            try:
                trend['health_snapshot'] = json.loads(trend['health_snapshot'])
            except Exception:
                pass
        if isinstance(trend.get('predicted_values'), str):
            try:
                trend['predicted_values'] = json.loads(trend['predicted_values'])
            except Exception:
                pass

    return jsonify(trends)

@predictions_bp.delete('/predictions/trend/<int:prediction_id>')
@jwt_required()
@db_connection
def delete_trend_history(cursor, prediction_id):
    """
    Menghapus satu catatan riwayat prediksi glukosa.
    Anti-IDOR: Tenaga medis atau pasien pemilik catatan tersebut.
    """
    user = get_current_user()
    if not user:
        return jsonify({'msg': 'Token otentikasi tidak valid.'}), 401

    cursor.execute("SELECT id, patient_id FROM predictions_trend WHERE id = %s", (prediction_id,))
    trend = cursor.fetchone()
    if not trend:
        return jsonify({'message': 'Data tidak ditemukan'}), 404

    if not can_access_patient(user, trend['patient_id']):
        return jsonify({'message': 'Akses ditolak: Anda tidak memiliki izin menghapus prediksi ini'}), 403

    cursor.execute("""
        DELETE FROM predictions_trend
        WHERE id = %s
    """, (prediction_id,))

    return jsonify({'message': 'Riwayat prediksi berhasil dihapus'})
