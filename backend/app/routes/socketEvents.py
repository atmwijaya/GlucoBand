from flask_socketio import emit, join_room, leave_room
from flask_jwt_extended import decode_token
import json
from app import socketio

@socketio.on('connect')
def handle_connect():
    pass

@socketio.on('join')
def on_join(data):
    token = data.get('token')
    if not token:
        return
    try:
        decoded = decode_token(token)
        identity = json.loads(decoded['sub'])
        user_id = identity['id']
        room = f"patient_{user_id}"
        join_room(room)
        emit('status', {'msg': f'Joined room {room}'}, to=room)
    except Exception as e:
        print(f"Join error: {e}")

@socketio.on('leave')
def on_leave(data):
    token = data.get('token')
    if not token:
        return
    try:
        decoded = decode_token(token)
        identity = json.loads(decoded['sub'])
        user_id = identity['id']
        room = f"patient_{user_id}"
        leave_room(room)
        emit('status', {'msg': f'Left room {room}'}, to=room)
    except Exception as e:
        print(f"Leave error: {e}")