from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from db import db_connection
from functools import wraps

faq_bp = Blueprint('faq', __name__)

def medis_required(fn):
    @wraps(fn)
    @jwt_required()
    def wrapper(*args, **kwargs):
        identity = get_jwt_identity()
        if identity['role'] != 'tenaga_medis':
            return jsonify({'msg': 'Hanya tenaga medis'}), 403
        return fn(*args, **kwargs)
    return wrapper

@faq_bp.get('/faq')
@jwt_required()
@db_connection
def get_faqs(cursor):
    cursor.execute("SELECT * FROM faq WHERE is_active = 1 ORDER BY order_index")
    faqs = cursor.fetchall()
    return jsonify(faqs)

@faq_bp.post('/faq')
@medis_required
@db_connection
def create_faq(cursor):
    identity = get_jwt_identity()
    data = request.get_json()
    cursor.execute(
        "INSERT INTO faq (question, answer, category, order_index, created_by) VALUES (%s, %s, %s, %s, %s)",
        (data['question'], data['answer'], data.get('category', 'umum'), data.get('order_index', 0), identity['id'])
    )
    return jsonify({'msg': 'FAQ ditambahkan', 'id': cursor.lastrowid}), 201

@faq_bp.put('/faq/<int:id>')
@medis_required
@db_connection
def update_faq(cursor, id):
    data = request.get_json()
    cursor.execute("UPDATE faq SET question=%s, answer=%s, category=%s, order_index=%s WHERE id=%s",
                   (data.get('question'), data.get('answer'), data.get('category', 'umum'),
                    data.get('order_index', 0), id))
    return jsonify({'msg': 'FAQ diperbarui'})

@faq_bp.delete('/faq/<int:id>')
@medis_required
@db_connection
def delete_faq(cursor, id):
    cursor.execute("DELETE FROM faq WHERE id = %s", (id,))
    return jsonify({'msg': 'FAQ dihapus'})