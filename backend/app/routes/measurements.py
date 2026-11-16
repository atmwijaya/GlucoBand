from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from db import db_connection
from app.utils.decorators import (
    get_current_user,
    can_access_patient,
    patient_owner_or_medis,
    patient_body_owner_or_medis
)

measurements_bp = Blueprint('measurements', __name__)

@measurements_bp.get('/measurements')
@jwt_required()
@db_connection
def get_all_measurements(cursor):
    """
    Mengambil data pengukuran:
    - Pasien: HANYA mengambil riwayat pengukuran milik akunnya sendiri (Anti-IDOR).
    - Tenaga Medis: Mengambil riwayat pengukuran seluruh pasien untuk dashboard monitoring.
    """
    user = get_current_user()
    if not user:
        return jsonify({'msg': 'Token otentikasi tidak valid.'}), 401

    if user.get('role') == 'pasien':
        cursor.execute("""
            SELECT m.id, m.patient_id, u.name AS patient_name,
                   m.glucose_estimated, m.status, m.ppg_heart_rate, m.ppg_spo2,
                   m.skin_temp_celsius, m.created_at
            FROM measurements m
            JOIN users u ON m.patient_id = u.id
            WHERE m.patient_id = %s
            ORDER BY m.created_at DESC
            LIMIT 100
        """, (user.get('id'),))
    else:
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
@patient_owner_or_medis('patient_id')
@db_connection
def get_patient_measurements(cursor, patient_id):
    """
    Mengambil riwayat pengukuran pasien tertentu.
    Anti-IDOR: Pasien dilarang melihat data pasien lain.
    Mendukung filter tanggal spesifik: ?date=YYYY-MM-DD
    """
    date_str = request.args.get('date')
    if date_str:
        cursor.execute("""
            SELECT id, patient_id, glucose_estimated, status, ppg_heart_rate, ppg_spo2,
                   skin_temp_celsius, created_at
            FROM measurements
            WHERE patient_id = %s AND DATE(created_at) = %s
            ORDER BY created_at ASC
        """, (patient_id, date_str))
    else:
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

@measurements_bp.get('/patients/<int:patient_id>/measurement-dates')
@patient_owner_or_medis('patient_id')
@db_connection
def get_patient_measurement_dates(cursor, patient_id):
    """
    Mengambil daftar tanggal unik (YYYY-MM-DD) yang memiliki data pengukuran untuk pasien tertentu.
    Digunakan untuk memberi indikator (dot) pada kalender dashboard.
    """
    cursor.execute("""
        SELECT DISTINCT DATE(created_at) AS date
        FROM measurements
        WHERE patient_id = %s
        ORDER BY date DESC
        LIMIT 60
    """, (patient_id,))
    rows = cursor.fetchall()
    dates = [r['date'].isoformat() if hasattr(r['date'], 'isoformat') else str(r['date']) for r in rows if r['date']]
    return jsonify(dates)

@measurements_bp.get('/patients/<int:patient_id>/latest')
@patient_owner_or_medis('patient_id')
@db_connection
def get_latest_measurement(cursor, patient_id):
    """
    Mengambil pengukuran terbaru pasien tertentu.
    Anti-IDOR: Pasien dilarang melihat data pasien lain.
    """
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
@patient_body_owner_or_medis('patient_id')
@db_connection
def add_measurement(cursor):
    """
    Endpoint untuk ESP32 atau aplikasi mobile mengirim data sensor.
    Jika request membawa token otentikasi (dari aplikasi mobile),
    sistem memastikan data hanya bisa disimpan atas nama akun pengguna sendiri.
    """
    data = request.get_json() or {}

    user = get_current_user()
    # Jika pasien terautentikasi mengirim data, selalu pastikan ID pasien sesuai akun login
    if user and user.get('role') == 'pasien':
        patient_id = user.get('id')
    else:
        patient_id = data.get('patient_id')

    if not patient_id:
        return jsonify({'msg': 'patient_id wajib disertakan'}), 400

    created_at = data.get('created_at')
    if not created_at:
        from datetime import datetime
        created_at = datetime.now().isoformat()

    if user and user.get('role') != 'tenaga_medis':
        if not can_access_patient(user, patient_id):
            return jsonify({'msg': 'Akses ditolak: Anda tidak memiliki izin mengunggah data untuk pasien lain.'}), 403

    # Sanitasi sumber data (hanya 'wifi' atau 'sdcard' sesuai enum MySQL)
    source_val = str(data.get('source', 'wifi')).lower()
    if source_val not in ('wifi', 'sdcard'):
        source_val = 'wifi'

    sql = """
        INSERT INTO measurements
        (patient_id, device_id, nir_610nm, nir_680nm, nir_730nm, nir_760nm, nir_810nm, nir_860nm,
         ppg_heart_rate, ppg_spo2, ppg_ir_value, skin_temp_celsius,
         glucose_estimated, glucose_invasive, is_calibration, created_at, source)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    cursor.execute(sql, (
        patient_id,
        data.get('device_id'),
        data.get('nir_610nm'), data.get('nir_680nm'), data.get('nir_730nm'),
        data.get('nir_760nm'), data.get('nir_810nm'), data.get('nir_860nm'),
        data.get('ppg_heart_rate'), data.get('ppg_spo2'), data.get('ppg_ir_value'),
        data.get('skin_temp_celsius'),
        data.get('glucose_estimated'), data.get('glucose_invasive'),
        data.get('is_calibration', False),
        created_at,
        source_val
    ))
    new_id = cursor.lastrowid

    try:
        from app import socketio
        glucose_val = float(data.get('glucose_estimated') or 0)
        status_calc = 'Normal'
        notif_type = None
        if glucose_val > 200:
            status_calc = 'Hiperglikemia'
            notif_type = 'hiperglikemia'
        elif glucose_val < 70 and glucose_val > 0:
            status_calc = 'Hipoglikemia'
            notif_type = 'hipoglikemia'

        # Ambil nama pasien untuk informasi realtime tenaga medis
        cursor.execute("SELECT name FROM users WHERE id = %s", (patient_id,))
        p_row = cursor.fetchone()
        patient_name = p_row['name'] if p_row else f"Pasien #{patient_id}"

        measurement_payload = {
            'id': new_id,
            'patient_id': int(patient_id),
            'patient_name': patient_name,
            'glucose_estimated': glucose_val,
            'ppg_heart_rate': int(data.get('ppg_heart_rate') or 0),
            'skin_temp_celsius': float(data.get('skin_temp_celsius') or 0),
            'ppg_spo2': int(data.get('ppg_spo2') or 98),
            'status': status_calc,
            'created_at': created_at
        }
        socketio.emit('new_measurement', measurement_payload)

        # Jika kondisi klinis kritis (Hipoglikemia / Hiperglikemia), simpan ke database notifikasi & pancarkan alert ke web tenaga medis
        if notif_type:
            try:
                cursor.execute("""
                    INSERT INTO notifications (patient_id, measurement_id, type, glucose_value, is_sent_patient, is_sent_medis, sent_at)
                    VALUES (%s, %s, %s, %s, 1, 1, NOW())
                """, (patient_id, new_id, notif_type, glucose_val))
                notif_id = cursor.lastrowid
            except Exception as dbe:
                print(f"[DB Error] Gagal insert notifications: {dbe}")
                notif_id = None

            notif_payload = {
                'id': notif_id,
                'patient_id': int(patient_id),
                'patient_name': patient_name,
                'measurement_id': new_id,
                'type': notif_type,
                'glucose_value': glucose_val,
                'message': f"Peringatan {status_calc}! Pasien {patient_name} terdeteksi kadar gula darah {glucose_val} mg/dL.",
                'created_at': created_at,
                'status': status_calc
            }
            socketio.emit('new_notification', notif_payload)
            socketio.emit('glucose_alert', notif_payload)
    except Exception as e:
        print(f"[SocketIO Error] Gagal emit new_measurement/notification: {e}")

    return jsonify({'msg': 'Data tersimpan', 'id': new_id}), 201

@measurements_bp.post('/measurements/live-stream')
@patient_body_owner_or_medis('patient_id')
def stream_sensor_data():
    """
    Endpoint untuk menerima streaming denyut jantung (BPM) dan sensor GlucoBand
    secara real-time dari aplikasi mobile pasien ke web tenaga medis via WebSocket.
    """
    data = request.get_json() or {}
    user = get_current_user()
    if user and 'patient_id' in data:
        if not can_access_patient(user, data['patient_id']):
            return jsonify({'msg': 'Akses ditolak: ID pasien tidak cocok dengan token aktif'}), 403

    try:
        from app import socketio
        socketio.emit('live_sensor_stream', data)
    except Exception as e:
        print(f"[SocketIO Error] Gagal emit live_sensor_stream: {e}")
    return jsonify({'status': 'streamed'}), 200


@measurements_bp.delete('/measurements/<int:id>')
@jwt_required()
@db_connection
def delete_measurement(cursor, id):
    """
    Menghapus satu data riwayat pengukuran berdasarkan ID.
    Pasien hanya boleh menghapus datanya sendiri (Anti-IDOR).
    """
    user = get_current_user()
    if not user:
        return jsonify({'msg': 'Token otentikasi tidak valid'}), 401

    cursor.execute("SELECT id, patient_id FROM measurements WHERE id = %s", (id,))
    meas = cursor.fetchone()
    if not meas:
        return jsonify({'msg': 'Data pengukuran tidak ditemukan'}), 404

    if user.get('role') == 'pasien':
        if int(meas['patient_id']) != int(user.get('id', 0)):
            return jsonify({'msg': 'Akses ditolak: Anda tidak memiliki izin menghapus data ini'}), 403

    cursor.execute("DELETE FROM measurements WHERE id = %s", (id,))
    return jsonify({'msg': 'Data pengukuran berhasil dihapus'}), 200
