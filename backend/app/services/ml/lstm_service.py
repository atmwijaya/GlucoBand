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
        self.scaler_features = None
        self.scaler_target = None
        self.n_features = 7
        self.feature_order = [
            'blood_glucose_level', 'age', 'bmi', 'HbA1c_level',
            'hypertension', 'heart_disease', 'smoking_history'
        ]
        self._load_assets()

    def _load_assets(self):
        try:
            self.model = tf.keras.models.load_model(
                os.path.join(MODEL_DIR, 'glucoband_lstm_model.h5')
            )
            print("LSTM Model loaded successfully")
        except Exception as e:
            print("❌ Gagal memuat LSTM model:", e)
            self.model = None

        try:
            self.scaler_features = joblib.load(os.path.join(MODEL_DIR, 'scaler_features.pkl'))
            print("Scaler features loaded successfully")
        except Exception as e:
            print("Gagal memuat scaler features:", e)
            self.scaler_features = None

        try:
            self.scaler_target = joblib.load(os.path.join(MODEL_DIR, 'scaler_target.pkl'))
            print("Scaler target loaded successfully")
        except Exception as e:
            print("Gagal memuat scaler target:", e)
            self.scaler_target = None

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
            [g, age, bmi, 5.5, hypertension, heart_disease, smoking_history]
            for g in glucose_values
        ])

        X = dummy_features

        # Scaling
        if self.scaler_features:
            import pandas as pd
            X_df = pd.DataFrame(X, columns=self.feature_order)
            X_scaled = self.scaler_features.transform(X_df)
        else:
            X_scaled = X / 400.0  

        X_input = X_scaled.reshape(1, 3, self.n_features)

        predictions = []
        current_input = X_input.copy()
        now = datetime.now()
        base_time = now.replace(minute=0, second=0, microsecond=0)

        for i in range(horizon_hours):
            y_pred_scaled = self.model.predict(current_input, verbose=0)[0, 0]

            if self.scaler_target:
                y_pred = self.scaler_target.inverse_transform([[y_pred_scaled]])[0, 0]
            else:
                y_pred = y_pred_scaled * 400.0

            y_pred = max(40.0, min(400.0, float(y_pred)))

            # Gunakan astimezone() agar offset zona waktu (+07:00) ikut disertakan
            predictions.append({
                "timestamp": (base_time + timedelta(hours=i + 1)).astimezone().isoformat(),
                "glucose": round(y_pred, 2)
            })
            
            if self.scaler_features and self.scaler_target:
                next_raw = np.array([[y_pred, age, bmi, 5.5, hypertension, heart_disease, smoking_history]])
                import pandas as pd
                next_df = pd.DataFrame(next_raw, columns=self.feature_order)
                new_row = self.scaler_features.transform(next_df)[0]
            else:
                new_row = current_input[0, -1, :].copy()
                new_row[0] = y_pred_scaled
                
            current_input = np.roll(current_input, -1, axis=1)
            current_input[0, -1, :] = new_row

        return predictions