import numpy as np
import pandas as pd
import joblib
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, '..', '..', 'ml_models')

class RFService:
    def __init__(self):
        self.model = None
        self.le_gender = None
        self.le_smoking = None
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

        try:
            self.le_gender = joblib.load(os.path.join(MODEL_DIR, 'le_gender.pkl'))
        except:
            self.le_gender = None
        try:
            self.le_smoking = joblib.load(os.path.join(MODEL_DIR, 'le_smoking.pkl'))
        except:
            self.le_smoking = None

    def predict_risk(self, data: dict) -> dict:
        if self.model is None:
            raise FileNotFoundError("Model Random Forest tidak tersedia")
        if self.expected_features is None:
            raise RuntimeError("Fitur model tidak diketahui")

        # Siapkan semua fitur yang mungkin diperlukan
        features = {
            'gender': data.get('gender', 'Male'),
            'age': int(data.get('age', 0)),
            'hypertension': int(data.get('hypertension', 0)),
            'heart_disease': int(data.get('heart_disease', 0)),
            'smoking_history': data.get('smoking_history', 0),
            'bmi': float(data.get('bmi', 0)),
            'blood_glucose_level': float(data.get('blood_glucose_level', 100)),
            'HbA1c_level': float(data.get('HbA1c_level', 5.0)),
        }

        # Label encoding
        if self.le_gender and 'gender' in features:
            try:
                features['gender'] = self.le_gender.transform([features['gender']])[0]
            except:
                features['gender'] = 0
        else:
            features['gender'] = 0 if features['gender'] in (0, 'Male') else 1

        if self.le_smoking and 'smoking_history' in features:
            try:
                features['smoking_history'] = self.le_smoking.transform([features['smoking_history']])[0]
            except:
                features['smoking_history'] = 0
        else:
            features['smoking_history'] = int(features['smoking_history'])

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