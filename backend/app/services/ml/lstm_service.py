import numpy as np
import tensorflow as tf
import joblib
import os
from datetime import datetime, timedelta

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, '..', '..', 'ml_models')

class LSTMService:
    def __init__(self):
        self.model = None
        self.scaler = None
        self.n_features = 7
        self.feature_order = [
            'age', 'bmi', 'blood_glucose_level', 
            'hypertension', 'heart_disease', 'gender', 'smoking_history'
        ]
        self._load_assets()

    def _load_assets(self):
        try:
            self.model = tf.keras.models.load_model(
                os.path.join(MODEL_DIR, 'lstm_glucose_trend.keras')
            )
            print("LSTM Model loaded successfully")
        except Exception as e:
            print("❌ Gagal memuat LSTM model:", e)
            self.model = None

        try:
            self.scaler = joblib.load(os.path.join(MODEL_DIR, 'scaler.pkl'))
            print("Scaler loaded successfully")
        except Exception as e:
            print("Gagal memuat scaler:", e)
            self.scaler = None

    def predict_trend(self, glucose_history: list, horizon_hours: int = 6, 
                     age: int = 40, bmi: float = 25.0, hypertension: int = 0,
                     heart_disease: int = 0, gender: str = "Male", 
                     smoking_history: int = 0) -> list:
        
        if self.model is None:
            raise FileNotFoundError("Model LSTM tidak tersedia")

        if len(glucose_history) < 3:
            raise ValueError("Minimal 3 data glukosa historis diperlukan")

        glucose_values = np.array(glucose_history[-3:], dtype=np.float32)

        dummy_features = np.array([
            [age, bmi, g, hypertension, heart_disease, 
             0 if gender == "Male" else 1, smoking_history]
            for g in glucose_values
        ])

        X = np.concatenate([
            glucose_values.reshape(-1, 1),
            dummy_features[:, 0:6]  
        ], axis=1)

        # Scaling
        if self.scaler:
            X_scaled = self.scaler.transform(X)
        else:
            X_scaled = X / 400.0  

        X_input = X_scaled.reshape(1, 3, self.n_features)

        predictions = []
        current_input = X_input.copy()
        now = datetime.utcnow()

        for i in range(horizon_hours):
            y_pred_scaled = self.model.predict(current_input, verbose=0)[0, 0]

            if self.scaler:
                dummy_row = np.zeros((1, self.n_features))
                dummy_row[0, 2] = y_pred_scaled  
                y_pred = self.scaler.inverse_transform(dummy_row)[0, 2]
            else:
                y_pred = y_pred_scaled * 400.0

            y_pred = max(40.0, min(400.0, float(y_pred)))

            predictions.append({
                "timestamp": (now + timedelta(hours=i + 1)).isoformat(),
                "glucose": round(y_pred, 2)
            })
            new_row = X_input[0, -1, :].copy()
            new_row[2] = y_pred_scaled if self.scaler is None else y_pred_scaled
            current_input = np.roll(current_input, -1, axis=1)
            current_input[0, -1, :] = new_row

        return predictions