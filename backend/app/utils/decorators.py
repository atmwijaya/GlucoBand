import json
from functools import wraps
from flask import request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity

def get_current_user():
    """
    Mengambil dan mem-parsing data identitas dari JWT token aktif.
    Format yang diharapkan: {'id': int, 'role': str}
    """
    raw_identity = get_jwt_identity()
    if not raw_identity:
        return None
    if isinstance(raw_identity, dict):
        return raw_identity
    try:
        return json.loads(raw_identity)
    except Exception:
        return {'id': raw_identity, 'role': 'pasien'}

def can_access_patient(user_identity, target_patient_id):
    """
    Validasi otorisasi data rekam medis pasien (Anti-IDOR):
    - Tenaga Medis: Boleh mengakses rekam medis seluruh pasien.
    - Pasien: HANYA boleh mengakses data milik dirinya sendiri.
    """
    if not user_identity:
        return False
    role = user_identity.get('role')
    if role == 'tenaga_medis':
        return True
    if role == 'pasien':
        try:
            return int(user_identity.get('id', 0)) == int(target_patient_id)
        except (ValueError, TypeError):
            return False
    return False

def medis_only(fn):
    """Decorator: Hanya mengizinkan akses untuk akun dengan role 'tenaga_medis'."""
    @wraps(fn)
    @jwt_required()
    def wrapper(*args, **kwargs):
        user = get_current_user()
        if not user or user.get('role') != 'tenaga_medis':
            return jsonify({'msg': 'Akses ditolak: Hanya tenaga medis yang memiliki wewenang.'}), 403
        return fn(*args, **kwargs)
    return wrapper

def patient_owner_or_medis(patient_id_arg_name='patient_id'):
    """
    Decorator URL param: Memastikan pemanggil adalah tenaga medis ATAU pasien pemilik data itu sendiri.
    Mencegah kebocoran rekam medis antar-pasien (Anti-IDOR).
    Dijalankan sebelum koneksi database dibuka untuk menghemat resource.
    """
    def decorator(fn):
        @wraps(fn)
        @jwt_required()
        def wrapper(*args, **kwargs):
            user = get_current_user()
            if not user:
                return jsonify({'msg': 'Token otentikasi tidak valid.'}), 401

            target_id = kwargs.get(patient_id_arg_name)
            if target_id is not None and not can_access_patient(user, target_id):
                return jsonify({'msg': 'Akses ditolak: Anda tidak memiliki izin untuk melihat atau mengubah rekam medis pasien lain.'}), 403

            return fn(*args, **kwargs)
        return wrapper
    return decorator

def patient_body_owner_or_medis(patient_id_field='patient_id'):
    """
    Decorator JSON body: Memastikan data JSON yang diunggah cocok dengan ID pasien di JWT token.
    Mencegah pemalsuan identitas pasien pada request payload (Anti-IDOR).
    Dijalankan sebelum koneksi database dibuka untuk menghemat resource.
    """
    def decorator(fn):
        @wraps(fn)
        @jwt_required(optional=True)
        def wrapper(*args, **kwargs):
            user = get_current_user()
            if user:
                data = request.get_json(silent=True)
                if data and patient_id_field in data:
                    if not can_access_patient(user, data[patient_id_field]):
                        return jsonify({'msg': 'Akses ditolak: Anda tidak memiliki izin mengunggah data untuk pasien lain.'}), 403
            return fn(*args, **kwargs)
        return wrapper
    return decorator
