from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import db_connection

predictions_bp = Blueprint('predictions', __name__)

@predictions_bp.get('/predictions/trend/<int:patient_id>')
@jwt_required()
@db_connection
def get_trend(cursor, patient_id):
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
@jwt_required()
@db_connection
def get_risk(cursor, patient_id):
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