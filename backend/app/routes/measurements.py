from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import db_connection
from datetime import datetime

measurements_bp = Blueprint('measurements', __name__)

@measurements_bp.get('/measurements')
@jwt_required()
@db_connection
def get_all_measurements(cursor):
    cursor.execute("""
        SELECT m.id, m.patient_id, u.name AS patient_name,
               m.glucose_estimated, m.status, m.ppg_heart_rate, m.ppg_spo2,
               m.skin_temp_celsius, m.created_at
        FROM measurements m
        JOIN users u ON m.patient_id = u.id
        ORDER BY m.created_at DESC
        LIMIT 100
    """)
    measurements = cursor.fetchall()
    for m in measurements:
        m['glucose_estimated'] = str(m['glucose_estimated']) if m['glucose_estimated'] else None
        m['skin_temp_celsius'] = str(m['skin_temp_celsius']) if m['skin_temp_celsius'] else None
        m['created_at'] = m['created_at'].isoformat() if m['created_at'] else None
    return jsonify(measurements)

@measurements_bp.get('/patients/<int:patient_id>/measurements')
@jwt_required()
@db_connection
def get_patient_measurements(cursor, patient_id):
    limit = request.args.get('limit', 20, type=int)
    cursor.execute("""
        SELECT id, patient_id, glucose_estimated, status, ppg_heart_rate, ppg_spo2,
               skin_temp_celsius, created_at
        FROM measurements
        WHERE patient_id = %s
        ORDER BY created_at DESC
        LIMIT %s
    """, (patient_id, limit))
    measurements = cursor.fetchall()
    for m in measurements:
        m['glucose_estimated'] = str(m['glucose_estimated']) if m['glucose_estimated'] else None
        m['skin_temp_celsius'] = str(m['skin_temp_celsius']) if m['skin_temp_celsius'] else None
        m['created_at'] = m['created_at'].isoformat() if m['created_at'] else None
    return jsonify(measurements)

@measurements_bp.get('/patients/<int:patient_id>/latest')
@jwt_required()
@db_connection
def get_latest_measurement(cursor, patient_id):
    cursor.execute("""
        SELECT id, patient_id, glucose_estimated, status, ppg_heart_rate, ppg_spo2,
               skin_temp_celsius, created_at
        FROM measurements
        WHERE patient_id = %s
        ORDER BY created_at DESC
        LIMIT 1
    """, (patient_id,))
    m = cursor.fetchone()
    if not m:
        return jsonify({'msg': 'Belum ada pengukuran'}), 404
    m['glucose_estimated'] = str(m['glucose_estimated']) if m['glucose_estimated'] else None
    m['skin_temp_celsius'] = str(m['skin_temp_celsius']) if m['skin_temp_celsius'] else None
    m['created_at'] = m['created_at'].isoformat() if m['created_at'] else None
    return jsonify(m)

@measurements_bp.post('/measurements')
@db_connection
def add_measurement(cursor):
    """Endpoint untuk ESP32 mengirim data sensor."""
    data = request.get_json()
    required = ['patient_id', 'created_at']
    if not all(k in data for k in required):
        return jsonify({'msg': 'Data tidak lengkap'}), 400

    sql = """
        INSERT INTO measurements
        (patient_id, device_id, nir_610nm, nir_680nm, nir_730nm, nir_760nm, nir_810nm, nir_860nm,
         ppg_heart_rate, ppg_spo2, ppg_ir_value, skin_temp_celsius,
         glucose_estimated, glucose_invasive, is_calibration, created_at, source)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    cursor.execute(sql, (
        data['patient_id'],
        data.get('device_id'),
        data.get('nir_610nm'), data.get('nir_680nm'), data.get('nir_730nm'),
        data.get('nir_760nm'), data.get('nir_810nm'), data.get('nir_860nm'),
        data.get('ppg_heart_rate'), data.get('ppg_spo2'), data.get('ppg_ir_value'),
        data.get('skin_temp_celsius'),
        data.get('glucose_estimated'), data.get('glucose_invasive'),
        data.get('is_calibration', False),
        data['created_at'],
        data.get('source', 'wifi')
    ))
    return jsonify({'msg': 'Data tersimpan', 'id': cursor.lastrowid}), 201