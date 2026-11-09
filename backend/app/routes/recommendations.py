from flask import Blueprint, request, jsonify
from db import get_connection
from app import socketio
from app.utils.decorators import medis_only, get_current_user

recommendations_bp = Blueprint('recommendations', __name__)

def _get_cursor():
    conn = get_connection()
    if conn is None:
        return None, None
    return conn, conn.cursor(dictionary=True)

@recommendations_bp.post('/patients/<int:patient_id>/recommendations')
@medis_only
def add_recommendation(patient_id):
    """
    Menambahkan pesan rekomendasi medis untuk pasien tertentu.
    Hanya bisa dilakukan oleh Tenaga Medis terverifikasi.
    """
    user = get_current_user()
    data = request.get_json()
    if not data or 'content' not in data:
        return jsonify({'msg': 'Konten rekomendasi diperlukan'}), 400

    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500
    try:
        cursor.execute(
            "INSERT INTO recommendations (patient_id, medis_id, content) VALUES (%s, %s, %s)",
            (patient_id, user['id'], data['content'])
        )
        conn.commit()
        socketio.emit('new_recommendation', {
            'message': data['content'],
            'created_at': 'now'
        }, to=f'patient_{patient_id}')

        return jsonify({'msg': 'Rekomendasi terkirim'}), 201
    except Exception as e:
        conn.rollback()
        print("Error in add_recommendation:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()
