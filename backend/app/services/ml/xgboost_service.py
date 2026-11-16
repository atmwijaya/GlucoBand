import os
import joblib
import pandas as pd
import numpy as np

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, '..', '..', 'ml_models')

class XGBoostService:
    """
    Layanan inferensi Machine Learning estimasi kadar gula darah non-invasif
    berbasis sensor spektrum NIR (AS7265x / AS726x) 6-kanal (R, S, T, U, V, W)
    menggunakan model XGBoost Regressor (xgboost_model.joblib) dan StandardScaler (scaler_xgb.joblib).
    """

    _instance = None

    def __new__(cls, *args, **kwargs):
        if cls._instance is None:
            cls._instance = super(XGBoostService, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if getattr(self, '_initialized', False):
            return
        self.model = None
        self.scaler = None
        self.expected_features = ['R', 'S', 'T', 'U', 'V', 'W']
        self._load_assets()
        self._initialized = True

    def _load_assets(self):
        try:
            model_path = os.path.join(MODEL_DIR, 'xgboost_model.joblib')
            scaler_path = os.path.join(MODEL_DIR, 'scaler_xgb.joblib')

            if os.path.exists(model_path) and os.path.exists(scaler_path):
                self.model = joblib.load(model_path)
                self.scaler = joblib.load(scaler_path)
                print("XGBoost Model (xgboost_model.joblib) & Scaler (scaler_xgb.joblib) berhasil dimuat.")
            elif os.path.exists(model_path):
                self.model = joblib.load(model_path)
                print("Scaler_xgb.joblib tidak ditemukan, menggunakan model XGBoost.")
            else:
                print("File model xgboost_model.joblib tidak ditemukan di", MODEL_DIR)
        except Exception as e:
            print("Gagal memuat model XGBoost:", e)
            self.model = None
            self.scaler = None

    def predict_glucose(self, data: dict) -> dict:
        """
        Memprediksi estimasi kadar gula darah (mg/dL) dari 6 panjang gelombang NIR.
        Parameter input:
        data: dict berisi R, S, T, U, V, W (case-insensitive)
        """
        if self.model is None:
            # Re-attempt loading in case assets were just created
            self._load_assets()
            if self.model is None:
                raise FileNotFoundError("Model XGBoost tidak tersedia atau gagal dimuat.")

        # Ambil nilai kanal (mendukung huruf besar maupun huruf kecil)
        r = float(data.get('R') if data.get('R') is not None else data.get('r', 0.0))
        s = float(data.get('S') if data.get('S') is not None else data.get('s', 0.0))
        t = float(data.get('T') if data.get('T') is not None else data.get('t', 0.0))
        u = float(data.get('U') if data.get('U') is not None else data.get('u', 0.0))
        v = float(data.get('V') if data.get('V') is not None else data.get('v', 0.0))
        w = float(data.get('W') if data.get('W') is not None else data.get('w', 0.0))

        # Buat DataFrame dengan 6 fitur
        input_df = pd.DataFrame([[r, s, t, u, v, w]], columns=self.expected_features)

        # Standarisasi fitur jika scaler tersedia
        if self.scaler is not None:
            features_transformed = self.scaler.transform(input_df)
        else:
            features_transformed = input_df.values

        # Lakukan inferensi regresi
        raw_pred = float(self.model.predict(features_transformed)[0])

        # Batasi estimasi ke rentang klinis wajar non-invasif (40.0 - 450.0 mg/dL)
        estimated_glucose = round(float(np.clip(raw_pred, 40.0, 450.0)), 1)

        # Klasifikasi status kadar gula darah
        if estimated_glucose < 70.0:
            status = "Hipoglikemia"
            status_desc = "Kadar gula darah di bawah batas normal (< 70 mg/dL)"
        elif estimated_glucose <= 140.0:
            status = "Normal"
            status_desc = "Kadar gula darah dalam batas normal (70 - 140 mg/dL)"
        elif estimated_glucose <= 199.0:
            status = "Pradiabetes"
            status_desc = "Kadar gula darah toleransi terganggu (141 - 199 mg/dL)"
        else:
            status = "Hiperglikemia"
            status_desc = "Kadar gula darah tinggi (>= 200 mg/dL)"

        return {
            "success": True,
            "Glucose": estimated_glucose,
            "glucose": estimated_glucose,
            "status": status,
            "status_desc": status_desc,
            "unit": "mg/dL",
            "features": {
                "R": r, "S": s, "T": t, "U": u, "V": v, "W": w
            }
        }
