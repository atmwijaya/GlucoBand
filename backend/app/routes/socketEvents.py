from flask import request
from flask_socketio import emit, join_room, leave_room
from flask_jwt_extended import decode_token
import json
from app import socketio

connected_patients = {}

def get_online_patient_ids():
    return list(set(connected_patients.values()))

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
        del connected_patients[sid]
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
