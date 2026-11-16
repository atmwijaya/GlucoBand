from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from app.services.ml.rf_service import RFService
from app.services.ml.lstm_service import LSTMService
from app.services.ml.xgboost_service import XGBoostService
from db import db_connection
from app import socketio
from app.utils.decorators import get_current_user
import json
import traceback

patient_pred_bp = Blueprint('patient_predictions', __name__)
rf_service = RFService()
lstm_service = LSTMService()
xgboost_service = XGBoostService()

@patient_pred_bp.post('/predict/risk')
@jwt_required()
@db_connection
def predict_risk(cursor):
    data = request.get_json()
    if not data:
        return jsonify({"error": "Data tidak lengkap"}), 400
    features = {
        "age": int(data.get("age", 0)),
        "gender": data.get("gender", "Male"),
        "bmi": float(data.get("bmi", 0)),
        "blood_pressure_sys": int(data.get("blood_pressure_sys", 0)),
        "blood_pressure_dia": int(data.get("blood_pressure_dia", 0)),
        "smoking_history": data.get("smoking_history", 0),
        "hypertension": int(data.get("hypertension", 0)),
        "heart_disease": int(data.get("heart_disease", 0)),
        "blood_glucose_level": float(data.get("blood_glucose_level", 100.0)),
        "HbA1c_level": data.get("HbA1c_level")
    }
    try:
        result = rf_service.predict_risk(features)
        
        user = get_current_user()
        if not user:
            return jsonify({'error': 'Token otentikasi tidak valid'}), 401
        
        # Anti-IDOR: Pasien hanya bisa membuat data prediksi untuk dirinya sendiri
        if user.get('role') == 'pasien':
            patient_id = user['id']
        else:
            patient_id = data.get('patient_id', user['id'])
        risk_level = result.get("risk_level", "rendah").lower()
        risk_score = result.get("risk_score", 0)
        model_version = str(result.get("model_version") or result.get("model version") or "1.0")[:20]

        cursor.execute("""
            INSERT INTO predictions_risk (patient_id, feature_vector, risk_level, risk_score, model_version)
            VALUES (%s, %s, %s, %s, %s)
        """, (patient_id, json.dumps(features), risk_level, risk_score, model_version))
        
        return jsonify(result)
    except FileNotFoundError as e:
        return jsonify({"error": str(e)}), 503
    except Exception as e:
        print("=== ERROR in predict_risk ===")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@patient_pred_bp.post('/predict/trend')
@jwt_required()
@db_connection
def predict_trend(cursor):
    data = request.get_json()
    if not data or 'glucose_history' not in data:
        return jsonify({"error": "glucose_history diperlukan"}), 400

    history = data.get('glucose_history', [])
    try:
        history = [float(x) for x in history if float(x) > 0]
    except:
        return jsonify({"error": "Format glucose_history tidak valid"}), 400

    if len(history) < 3:
        return jsonify({"error": "Minimal 3 data glukosa historis diperlukan"}), 400

    horizon = int(data.get('horizon_hours', 6))

    age = int(data.get('age', 40))
    bmi = float(data.get('bmi', 25.0))
    hypertension = int(data.get('hypertension', 0))
    heart_disease = int(data.get('heart_disease', 0))
    gender = data.get('gender', 'Male')
    smoking = int(data.get('smoking_history', 0))
    heart_rate = float(data.get('heart_rate') or data.get('hr') or 75.0)
    insulin = float(data.get('insulin', 0.0))
    carbs = float(data.get('carbs', 0.0))
    steps = float(data.get('steps', 0.0))
    calories = float(data.get('calories') or data.get('cals') or 0.0)

    try:
        result = lstm_service.predict_trend(
            history, 
            horizon,
            age=age,
            bmi=bmi,
            hypertension=hypertension,
            heart_disease=heart_disease,
            gender=gender,
            smoking_history=smoking,
            heart_rate=heart_rate,
            insulin=insulin,
            carbs=carbs,
            steps=steps,
            calories=calories
        )
        user = get_current_user()
        if not user:
            return jsonify({'error': 'Token otentikasi tidak valid'}), 401
        
        # Anti-IDOR: Pasien hanya bisa membuat data prediksi untuk dirinya sendiri
        if user.get('role') == 'pasien':
            patient_id = user['id']
        else:
            patient_id = data.get('patient_id', user['id'])
        health_snapshot = {
            "age": age,
            "bmi": bmi,
            "hypertension": hypertension,
            "heart_disease": heart_disease,
            "gender": gender,
            "smoking_history": smoking,
            "heart_rate": heart_rate,
            "glucose_history": history
        }

        cursor.execute("""
            INSERT INTO predictions_trend (patient_id, input_measurement_ids, health_snapshot, predicted_values, horizon_hours, model_version)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (
            patient_id,
            json.dumps([]),
            json.dumps(health_snapshot),
            json.dumps(result),
            horizon,
            "1.0"
        ))
        
        cursor.execute("SELECT LAST_INSERT_ID() AS id")
        new_id = cursor.fetchone()['id']
        import datetime
        
        new_prediction_event = {
            "id": new_id,
            "patient_id": patient_id,
            "created_at": datetime.datetime.now().isoformat(),
            "predicted_values": result,
            "horizon_hours": horizon
        }
        socketio.emit('new_prediction_trend', new_prediction_event)
        
        return jsonify(result)
    except Exception as e:
        print("=== ERROR in predict_trend ===")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@patient_pred_bp.post('/xgb/predict')
@patient_pred_bp.post('/predict/xgb')
def predict_xgb():
    """
    Endpoint publik untuk estimasi kadar glukosa non-invasif menggunakan model XGBoost.
    Digunakan langsung oleh alat ESP32 (tanpa JWT) dan aplikasi mobile.
    Menerima parameter 6 panjang gelombang NIR: R, S, T, U, V, W.
    Mengembalikan estimasi kadar glukosa dalam satuan mg/dL dan status glukosa.
    """
    data = request.get_json(silent=True) or {}
    if not data:
        data = request.values.to_dict()

    try:
        result = xgboost_service.predict_glucose(data)

        # Opsi integrasi live streaming ke web tenaga medis jika patient_id disertakan
        patient_id = data.get('patient_id')
        if patient_id:
            try:
                from db import get_connection
                patient_name = f"Pasien #{patient_id}"
                c_conn = get_connection()
                if c_conn:
                    with c_conn.cursor(dictionary=True) as c_cur:
                        c_cur.execute("SELECT name FROM users WHERE id = %s", (patient_id,))
                        u_row = c_cur.fetchone()
                        if u_row:
                            patient_name = u_row['name']
                    c_conn.close()

                live_payload = {
                    'patient_id': int(patient_id),
                    'patient_name': patient_name,
                    'glucose': result['glucose'],
                    'glucose_estimated': result['glucose'],
                    'status': result['status'],
                    'unit': 'mg/dL',
                    'features': result.get('features', {})
                }
                socketio.emit('live_glucose_estimate', live_payload)

                # Jika kritis, kirim alert langsung ke portal medis
                if result['status'] in ('Hipoglikemia', 'Hiperglikemia'):
                    alert_payload = {
                        'patient_id': int(patient_id),
                        'patient_name': patient_name,
                        'type': result['status'].lower(),
                        'glucose_value': result['glucose'],
                        'message': f"Peringatan Realtime: Pasien {patient_name} terdeteksi {result['status']} ({result['glucose']} mg/dL).",
                        'status': result['status']
                    }
                    socketio.emit('new_notification', alert_payload)
                    socketio.emit('glucose_alert', alert_payload)
            except Exception as se:
                print(f"[SocketIO Error] Gagal emit live_glucose_estimate: {se}")

        return jsonify(result), 200
    except FileNotFoundError as e:
        return jsonify({"error": str(e)}), 503
    except Exception as e:
        print("=== ERROR in predict_xgb ===")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500