from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import db_connection

notifications_bp = Blueprint('notifications', __name__)

@notifications_bp.get('/notifications')
@jwt_required()
@db_connection
def get_notifications(cursor):
    cursor.execute("""
        SELECT n.id, n.patient_id, u.name AS patient_name, n.type, n.glucose_value, n.created_at
        FROM notifications n
        JOIN users u ON n.patient_id = u.id
        ORDER BY n.created_at DESC
        LIMIT 50
    """)
    notifs = cursor.fetchall()
    for n in notifs:
        n['glucose_value'] = str(n['glucose_value']) if n['glucose_value'] else None
        n['created_at'] = n['created_at'].isoformat() if n['created_at'] else None
    return jsonify(notifs)