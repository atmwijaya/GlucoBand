import json
from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import get_connection

patient_notif_bp = Blueprint('patient_notifications', __name__)

def _get_cursor():
    conn = get_connection()
    if conn is None:
        return None, None
    return conn, conn.cursor(dictionary=True)

@patient_notif_bp.get('/patient/notifications')
@jwt_required()
def get_patient_notifications():
    identity_json = get_jwt_identity()
    if not identity_json:
        return jsonify({'msg': 'Token tidak valid'}), 422
    identity = json.loads(identity_json)
    patient_id = identity['id']

    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500

    try:
        # Ambil notifikasi alert (tanpa is_read)
        cursor.execute("""
            SELECT id, type, glucose_value, created_at
            FROM notifications
            WHERE patient_id = %s
            ORDER BY created_at DESC
            LIMIT 50
        """, (patient_id,))
        alerts = cursor.fetchall()

        # Ambil rekomendasi (dengan is_read)
        cursor.execute("""
            SELECT id, content, created_at, is_read
            FROM recommendations
            WHERE patient_id = %s
            ORDER BY created_at DESC
            LIMIT 50
        """, (patient_id,))
        recommendations = cursor.fetchall()

        # Gabungkan
        notifications = []
        for alert in alerts:
            notifications.append({
                'id': alert['id'],
                'type': 'alert',
                'subtype': alert['type'],          # 'hipoglikemia' atau 'hiperglikemia'
                'message': f"Kadar gula {alert['glucose_value']} mg/dL ({alert['type']})",
                'created_at': alert['created_at'].isoformat() if alert['created_at'] else None,
                'is_read': False                   # notifikasi alert selalu belum dibaca (default)
            })

        for rec in recommendations:
            notifications.append({
                'id': rec['id'],
                'type': 'recommendation',
                'subtype': None,
                'message': rec['content'],
                'created_at': rec['created_at'].isoformat() if rec['created_at'] else None,
                'is_read': rec['is_read'] if rec['is_read'] is not None else False
            })

        # Urutkan berdasarkan waktu terbaru
        notifications.sort(key=lambda x: x['created_at'] or '', reverse=True)

        return jsonify(notifications)
    except Exception as e:
        conn.rollback()
        print("Error in get_patient_notifications:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()
        
@patient_notif_bp.put('/patient/recommendations/<int:id>/read')
@jwt_required()
def mark_recommendation_read(id):
    identity_json = get_jwt_identity()
    if not identity_json:
        return jsonify({'msg': 'Token tidak valid'}), 422
    identity = json.loads(identity_json)
    patient_id = identity['id']

    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500

    try:
        # Pastikan rekomendasi milik pasien ini
        cursor.execute(
            "UPDATE recommendations SET is_read = 1 WHERE id = %s AND patient_id = %s",
            (id, patient_id)
        )
        conn.commit()
        if cursor.rowcount > 0:
            return jsonify({'msg': 'Notifikasi ditandai telah dibaca'})
        else:
            return jsonify({'msg': 'Notifikasi tidak ditemukan'}), 404
    except Exception as e:
        conn.rollback()
        print("Error in mark_recommendation_read:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()