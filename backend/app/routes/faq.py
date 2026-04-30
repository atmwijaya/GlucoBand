import json
from functools import wraps
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import get_connection

faq_bp = Blueprint('faq', __name__)

def medis_required(fn):
    @wraps(fn)
    @jwt_required()
    def wrapper(*args, **kwargs):
        identity_json = get_jwt_identity()
        if not identity_json:
            return jsonify({'msg': 'Token tidak valid'}), 422
        try:
            identity = json.loads(identity_json)
        except json.JSONDecodeError:
            return jsonify({'msg': 'Token rusak'}), 422
        if identity.get('role') != 'tenaga_medis':
            return jsonify({'msg': 'Hanya tenaga medis'}), 403
        return fn(identity, *args, **kwargs)
    return wrapper

def _get_cursor():
    conn = get_connection()
    if conn is None:
        return None, None
    return conn, conn.cursor(dictionary=True)

@faq_bp.get('/faq')
@jwt_required()
def get_faqs():
    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500
    try:
        cursor.execute("SELECT * FROM faq WHERE is_active = 1 ORDER BY order_index")
        faqs = cursor.fetchall()
        return jsonify(faqs)
    except Exception as e:
        conn.rollback()
        print("Error in get_faqs:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()

@faq_bp.post('/faq')
@medis_required
def create_faq(identity):
    data = request.get_json()
    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500
    try:
        cursor.execute(
            "INSERT INTO faq (question, answer, category, order_index, created_by) VALUES (%s, %s, %s, %s, %s)",
            (data['question'], data['answer'], data.get('category', 'umum'), data.get('order_index', 0), identity['id'])
        )
        conn.commit()
        return jsonify({'msg': 'FAQ ditambahkan', 'id': cursor.lastrowid}), 201
    except Exception as e:
        conn.rollback()
        print("Error in create_faq:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()

@faq_bp.put('/faq/<int:id>')
@medis_required
def update_faq(identity, id):
    data = request.get_json()
    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500
    try:
        cursor.execute(
            "UPDATE faq SET question=%s, answer=%s, category=%s, order_index=%s WHERE id=%s",
            (data.get('question'), data.get('answer'), data.get('category', 'umum'),
             data.get('order_index', 0), id)
        )
        conn.commit()
        return jsonify({'msg': 'FAQ diperbarui'})
    except Exception as e:
        conn.rollback()
        print("Error in update_faq:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()

@faq_bp.delete('/faq/<int:id>')
@medis_required
def delete_faq(identity, id):
    conn, cursor = _get_cursor()
    if not conn:
        return jsonify({'msg': 'Koneksi database gagal'}), 500
    try:
        cursor.execute("DELETE FROM faq WHERE id = %s", (id,))
        conn.commit()
        return jsonify({'msg': 'FAQ dihapus'})
    except Exception as e:
        conn.rollback()
        print("Error in delete_faq:", e)
        return jsonify({'msg': 'Terjadi kesalahan database'}), 500
    finally:
        cursor.close()
        conn.close()