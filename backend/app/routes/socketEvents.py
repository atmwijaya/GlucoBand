from flask import request
from flask_socketio import emit, join_room, leave_room
from flask_jwt_extended import decode_token
import json
import time
from app import socketio

connected_patients = {}
patient_last_seen = {}

def record_patient_heartbeat(patient_id):
    """Mencatat aktivitas online pasien dan menyiarkan pembaruan jika pasien baru online."""
    try:
        p_id = int(patient_id)
        is_new = p_id not in get_online_patient_ids()
        patient_last_seen[p_id] = time.time()
        if is_new:
            broadcast_online_patients()
    except Exception as e:
        print(f"record_patient_heartbeat error: {e}")

def get_online_patient_ids():
    """Mengembalikan daftar unik ID pasien yang sedang terhubung socket atau aktif dalam 30 detik terakhir."""
    now = time.time()
    # Bersihkan pasien yang tidak aktif lebih dari 30 detik
    expired = [p_id for p_id, last_time in list(patient_last_seen.items()) if now - last_time > 30]
    for p_id in expired:
        patient_last_seen.pop(p_id, None)

    all_online = set(connected_patients.values())
    all_online.update(patient_last_seen.keys())
    return list(all_online)

def broadcast_online_patients():
    online_ids = get_online_patient_ids()
    socketio.emit('online_patients_list', online_ids)

@socketio.on('connect')
def handle_connect():
    pass

@socketio.on('disconnect')
def handle_disconnect():
    sid = request.sid
    if sid in connected_patients:
        user_id = connected_patients.pop(sid, None)
        patient_last_seen.pop(user_id, None)
        broadcast_online_patients()

@socketio.on('join')
def on_join(data):
    token = data.get('token')
    if not token:
        return
    try:
        decoded = decode_token(token)
        identity = json.loads(decoded['sub'])
        user_id = identity['id']
        role = identity.get('role', 'pasien')
        room = f"patient_{user_id}"
        join_room(room)

        if role == 'pasien':
            connected_patients[request.sid] = user_id
            broadcast_online_patients()

        emit('status', {'msg': f'Joined room {room}'}, to=room)
    except Exception as e:
        print(f"Join error: {e}")

@socketio.on('leave')
def on_leave(data):
    sid = request.sid
    if sid in connected_patients:
        del connected_patients[sid]
        broadcast_online_patients()

@socketio.on('get_online_patients')
def handle_get_online_patients():
    emit('online_patients_list', get_online_patient_ids())

@socketio.on('sensor_stream')
def handle_sensor_stream(data):
    emit('live_sensor_stream', data, broadcast=True)
