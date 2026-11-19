from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required
from db import get_connection
from app.utils.decorators import get_current_user

patient_notif_bp = Blueprint('patient_notifications', __name__)

def _get_cursor():
    conn = get_connection()
    if conn is None:
        return None, None
    return conn, conn.cursor(dictionary=True)

def _ensure_notif_is_read_col(cursor, conn):
    """Memastikan kolom is_read tersedia di tabel notifications."""
    try:
        cursor.execute("SHOW COLUMNS FROM notifications LIKE 'is_read'")
        if not cursor.fetchone():
            cursor.execute("ALTER TABLE notifications ADD COLUMN is_read TINYINT(1) NOT NULL DEFAULT 0")
            conn.commit()
    except Exception as e:
        print("[DB Notice] Gagal memeriksa/menambahkan kolom is_read:", e)

@patient_notif_bp.get('/patient/notifications')
@jwt_required()
def get_patient_notifications():
    user = get_current_user()
    if not user:
        return jsonify({'msg': 'Token otentikasi tidak valid'}), 401
    patient_id = user['id']

    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500

    try:
        _ensure_notif_is_read_col(cursor, conn)
        cursor.execute("""
            SELECT id, type, glucose_value, created_at, is_read
            FROM notifications
            WHERE patient_id = %s
            ORDER BY created_at DESC
            LIMIT 50
        """, (patient_id,))
        alerts = cursor.fetchall()

        cursor.execute("""
            SELECT id, content, created_at, is_read
            FROM recommendations
            WHERE patient_id = %s
            ORDER BY created_at DESC
            LIMIT 50
        """, (patient_id,))
        recommendations = cursor.fetchall()

        notifications = []
        for alert in alerts:
            notifications.append({
                'id': alert['id'],
                'type': 'alert',
                'subtype': alert['type'], 
                'message': f"Kadar gula {alert['glucose_value']} mg/dL ({alert['type']})",
                'glucose_value': float(alert['glucose_value']) if alert.get('glucose_value') is not None else None,
                'created_at': alert['created_at'].isoformat() if alert['created_at'] else None,
                'is_read': bool(alert.get('is_read', 0))
            })

        for rec in recommendations:
            notifications.append({
                'id': rec['id'],
                'type': 'recommendation',
                'subtype': None,
                'message': rec['content'],
                'created_at': rec['created_at'].isoformat() if rec['created_at'] else None,
                'is_read': bool(rec.get('is_read', 0))
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

@patient_notif_bp.put('/patient/notifications/<int:id>/read')
@jwt_required()
def mark_notification_read(id):
    user = get_current_user()
    if not user:
        return jsonify({'msg': 'Token otentikasi tidak valid'}), 401
    patient_id = user['id']

    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500

    try:
        _ensure_notif_is_read_col(cursor, conn)
        # Tandai dibaca di tabel notifications (alert)
        cursor.execute(
            "UPDATE notifications SET is_read = 1 WHERE id = %s AND patient_id = %s",
            (id, patient_id)
        )
        affected = cursor.rowcount
        # Jika bukan di tabel notifications, coba update di tabel recommendations
        if affected == 0:
            cursor.execute(
                "UPDATE recommendations SET is_read = 1 WHERE id = %s AND patient_id = %s",
                (id, patient_id)
            )
        conn.commit()
        return jsonify({'msg': 'Notifikasi berhasil ditandai telah dibaca'})
    except Exception as e:
        conn.rollback()
        print("Error in mark_notification_read:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()

@patient_notif_bp.put('/patient/notifications/read-all')
@jwt_required()
def mark_all_notifications_read():
    user = get_current_user()
    if not user:
        return jsonify({'msg': 'Token otentikasi tidak valid'}), 401
    patient_id = user['id']

    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500

    try:
        _ensure_notif_is_read_col(cursor, conn)
        cursor.execute("UPDATE notifications SET is_read = 1 WHERE patient_id = %s", (patient_id,))
        cursor.execute("UPDATE recommendations SET is_read = 1 WHERE patient_id = %s", (patient_id,))
        conn.commit()
        return jsonify({'msg': 'Semua notifikasi berhasil ditandai telah dibaca'})
    except Exception as e:
        conn.rollback()
        print("Error in mark_all_notifications_read:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()

@patient_notif_bp.put('/patient/recommendations/<int:id>/read')
@jwt_required()
def mark_recommendation_read(id):
    return mark_notification_read(id)
