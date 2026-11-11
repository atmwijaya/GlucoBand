import os
import joblib
import pandas as pd
import numpy as np

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, '..', '..', 'ml_models')

class RFService:
    """
    Layanan inferensi Machine Learning klasifikasi risiko diabetes mellitus
    menggunakan model Random Forest teroptimasi (rf_diabetes.pkl).
    """

    def __init__(self):
        self.model = None
        self.expected_features = [
            'gender', 'age', 'hypertension', 'heart_disease',
            'smoking_history', 'bmi', 'HbA1c_level', 'blood_glucose_level'
        ]
        self._load_assets()

    def _load_assets(self):
        try:
            model_path = os.path.join(MODEL_DIR, 'rf_diabetes.pkl')
            self.model = joblib.load(model_path)
            if hasattr(self.model, 'feature_names_in_'):
                self.expected_features = list(self.model.feature_names_in_)
            print("Random Forest Model (rf_diabetes.pkl) berhasil dimuat.")
        except Exception as e:
            print("Gagal memuat model RF:", e)
            self.model = None

    def _parse_gender(self, val) -> int:
        """Mengonversi input gender ke encoding numerik (0: Female, 1: Male, 2: Other)."""
        if isinstance(val, (int, float)):
            return int(val)
        val_str = str(val).strip().lower()
        if val_str in ['female', 'perempuan', 'f', 'p', 'wanita']:
            return 0
        if val_str in ['male', 'laki-laki', 'pria', 'm', 'l']:
            return 1
        return 2

    def _parse_smoking(self, val) -> int:
        """Mengonversi riwayat merokok ke encoding numerik (0: Never/No Info, 1: Former, 2: Current)."""
        if isinstance(val, (int, float)):
            return int(val)
        val_str = str(val).strip().lower()
        if val_str in ['current', 'merokok', 'aktif', 'ya', '2']:
            return 2
        if val_str in ['former', 'pernah', 'ever', 'not current', '1']:
            return 1
        return 0

    def _estimate_hba1c(self, glucose: float, explicit_hba1c=None) -> float:
        """
        Menghitung atau mengestimasi HbA1c jika data lab belum tersedia.
        Menggunakan Formula Klinis Nathan (ADAG): eAG = 28.7 * HbA1c - 46.7 -> HbA1c = (eAG + 46.7) / 28.7.
        """
        if explicit_hba1c is not None:
            try:
                val = float(explicit_hba1c)
                if val > 0:
                    return val
            except (ValueError, TypeError):
                pass

        # Estimasi dari kadar gula darah sewaktu (mg/dL)
        estimated = (float(glucose) + 46.7) / 28.7
        return round(float(np.clip(estimated, 4.0, 14.0)), 2)

    def predict_risk(self, data: dict) -> dict:
        """
        Memprediksi skor dan tingkat risiko diabetes berdasarkan parameter kesehatan pasien.
        """
        if self.model is None:
            raise FileNotFoundError("Model Random Forest tidak tersedia atau gagal dimuat")

        glucose = float(data.get('blood_glucose_level', 100.0))
        hba1c = self._estimate_hba1c(glucose, data.get('HbA1c_level'))

        features = {
            'gender': self._parse_gender(data.get('gender', 'Male')),
            'age': float(data.get('age', 40)),
            'hypertension': 1 if str(data.get('hypertension', 0)).strip() in ['1', 'true', 'ya', 'True'] else 0,
            'heart_disease': 1 if str(data.get('heart_disease', 0)).strip() in ['1', 'true', 'ya', 'True'] else 0,
            'smoking_history': self._parse_smoking(data.get('smoking_history', 0)),
            'bmi': float(data.get('bmi', 23.0)),
            'HbA1c_level': hba1c,
            'blood_glucose_level': glucose,
        }

        # Buat DataFrame sesuai urutan fitur yang diharapkan model
        row = {f: features.get(f, 0) for f in self.expected_features}
        df = pd.DataFrame([row], columns=self.expected_features)

        # Prediksi probabilitas kelas 1 (Diabetes)
        try:
            proba = self.model.predict_proba(df)[0]
            score = float(proba[-1])
        except AttributeError:
            pred = self.model.predict(df)[0]
            score = float(pred)

        # Interpretasi tingkat risiko klinis
        if score < 0.30:
            level = "Rendah"
        elif score < 0.60:
            level = "Sedang"
        else:
            level = "Tinggi"

        # Deteksi faktor dominan untuk rekomendasi dokter/pasien
        risk_factors = []
        if features['blood_glucose_level'] > 140:
            risk_factors.append(f"Gula darah di atas ambang normal ({features['blood_glucose_level']} mg/dL)")
        if features['bmi'] >= 25.0:
            risk_factors.append(f"Indeks massa tubuh tinggi / overweight ({features['bmi']})")
        if features['hypertension'] == 1:
            risk_factors.append("Riwayat hipertensi")
        if features['heart_disease'] == 1:
            risk_factors.append("Riwayat penyakit kardiovaskular")
        if features['smoking_history'] == 2:
            risk_factors.append("Perokok aktif")

        return {
            "risk_level": level,
            "risk_score": round(score, 4),
            "prediction": 1 if score >= 0.50 else 0,
            "model_version": "Random Forest v1.0",
            "model version": "Random Forest 1.0",
            "estimated_hba1c": hba1c,
            "risk_factors": risk_factors
        }
