from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.services.ml.rf_service import RFService
from app.services.ml.lstm_service import LSTMService
from db import db_connection
import json
import traceback

patient_pred_bp = Blueprint('patient_predictions', __name__)
rf_service = RFService()
lstm_service = LSTMService()

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
        "blood_glucose_level": float(data.get("blood_glucose_level", 100.0))
    }
    try:
        result = rf_service.predict_risk(features)
        
        identity_raw = get_jwt_identity()
        try:
            patient_id = json.loads(identity_raw).get('id')
        except:
            patient_id = identity_raw
        risk_level = result.get("risk_level", "rendah").lower()
        risk_score = result.get("risk_score", 0)
        model_version = result.get("model version", "1.0")

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

    try:
        result = lstm_service.predict_trend(
            history, 
            horizon,
            age=age,
            bmi=bmi,
            hypertension=hypertension,
            heart_disease=heart_disease,
            gender=gender,
            smoking_history=smoking
        )
        identity_raw = get_jwt_identity()
        try:
            patient_id = json.loads(identity_raw).get('id')
        except:
            patient_id = identity_raw
        health_snapshot = {
            "age": age,
            "bmi": bmi,
            "hypertension": hypertension,
            "heart_disease": heart_disease,
            "gender": gender,
            "smoking_history": smoking,
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
        
        return jsonify(result)
    except Exception as e:
        print("=== ERROR in predict_trend ===")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500