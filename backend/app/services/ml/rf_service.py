import numpy as np
import pandas as pd
import joblib
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, '..', '..', 'ml_models')

class RFService:
    def __init__(self):
        self.model = None
        self.expected_features = None
        self._load_assets()

    def _load_assets(self):
        try:
            self.model = joblib.load(os.path.join(MODEL_DIR, 'rf_diabetes.pkl'))
            if hasattr(self.model, 'feature_names_in_'):
                self.expected_features = list(self.model.feature_names_in_)
            else:
                # fallback manual
                self.expected_features = [
                    'gender', 'age', 'hypertension', 'heart_disease',
                    'smoking_history', 'bmi', 'blood_glucose_level'
                ]
        except Exception as e:
            print("Gagal memuat model RF:", e)
            self.model = None

    def predict_risk(self, data: dict) -> dict:
        if self.model is None:
            raise FileNotFoundError("Model Random Forest tidak tersedia")
        if self.expected_features is None:
            raise RuntimeError("Fitur model tidak diketahui")

        gender_map = {'Female': 0, 'Male': 1, 'Other': 2}
        
        # Siapkan semua fitur yang mungkin diperlukan
        features = {
            'gender': gender_map.get(data.get('gender', 'Male'), 1),
            'age': int(data.get('age', 0)),
            'hypertension': int(data.get('hypertension', 0)),
            'heart_disease': int(data.get('heart_disease', 0)),
            'smoking_history': int(data.get('smoking_history', 0)),
            'bmi': float(data.get('bmi', 0)),
            'blood_glucose_level': float(data.get('blood_glucose_level', 100)),
            'HbA1c_level': float(data.get('HbA1c_level', 5.0)),
        }

        # Buat DataFrame sesuai expected_features (hilangkan warning)
        row = {f: features.get(f, 0) for f in self.expected_features}
        df = pd.DataFrame([row], columns=self.expected_features)

        # Prediksi
        try:
            proba = self.model.predict_proba(df)[0]
            score = float(proba[-1])
        except AttributeError:
            pred = self.model.predict(df)[0]
            score = float(pred)

        # Interpretasi
        if score < 0.3:
            level = "Rendah"
        elif score < 0.6:
            level = "Sedang"
        else:
            level = "Tinggi"

        return {"risk_level": level, "risk_score": round(score, 4), "model version": "Random Forest 1.0"}