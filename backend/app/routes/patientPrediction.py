from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from app.services.ml.rf_service import RFService
from app.services.ml.lstm_service import LSTMService
import traceback

patient_pred_bp = Blueprint('patient_predictions', __name__)
rf_service = RFService()
lstm_service = LSTMService()

@patient_pred_bp.post('/predict/risk')
@jwt_required()
def predict_risk():
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
        return jsonify(result)
    except FileNotFoundError as e:
        return jsonify({"error": str(e)}), 503
    except Exception as e:
        print("=== ERROR in predict_risk ===")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@patient_pred_bp.post('/predict/trend')
@jwt_required()
def predict_trend():
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
        return jsonify(result)
    except Exception as e:
        print("=== ERROR in predict_trend ===")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500