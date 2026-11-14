import os
import joblib
import pandas as pd
import numpy as np

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, '..', '..', 'ml_models')

class RFService:
    """
    Layanan inferensi Machine Learning klasifikasi risiko diabetes mellitus
    menggunakan model Random Forest biner teroptimasi (glucoband_rf_model.joblib)
    dan StandardScaler (scaler_rf.joblib) berbasis spesifikasi Dokumen C300.
    """

    def __init__(self):
        self.model = None
        self.scaler = None
        # 7 Fitur Masukan Sesuai Spesifikasi Dokumen C300 & Model Latih Biner
        self.expected_features = [
            'age', 'gender', 'bmi', 'hypertension', 'heart_disease',
            'smoking_history', 'blood_glucose_level'
        ]
        self._load_assets()

    def _load_assets(self):
        try:
            model_path = os.path.join(MODEL_DIR, 'glucoband_rf_model.joblib')
            scaler_path = os.path.join(MODEL_DIR, 'scaler_rf.joblib')

            if os.path.exists(model_path) and os.path.exists(scaler_path):
                self.model = joblib.load(model_path)
                self.scaler = joblib.load(scaler_path)
                print("✅ Random Forest Model (glucoband_rf_model.joblib) & Scaler (scaler_rf.joblib) berhasil dimuat.")
            else:
                # Fallback ke model lama jika model baru belum tersedia
                legacy_model_path = os.path.join(MODEL_DIR, 'rf_diabetes.pkl')
                if os.path.exists(legacy_model_path):
                    self.model = joblib.load(legacy_model_path)
                    print("⚠️ Menggunakan fallback model Random Forest lama (rf_diabetes.pkl).")
        except Exception as e:
            print("Gagal memuat model RF:", e)
            self.model = None
            self.scaler = None

    def _parse_gender(self, val) -> int:
        """
        Mengonversi gender sesuai mapping notebook:
        {'Female': 0, 'Male': 1, 'Other': 0}
        """
        if isinstance(val, (int, float)):
            return 1 if int(val) == 1 else 0
        val_str = str(val).strip().lower()
        if val_str in ['male', 'laki-laki', 'pria', 'm', 'l', '1']:
            return 1
        return 0

    def _parse_smoking(self, val) -> int:
        """
        Mengonversi riwayat merokok sesuai mapping notebook:
        {'never': 0, 'No Info': 0, 'current': 1, 'former': 2, 'not current': 1, 'ever': 1}
        """
        if isinstance(val, (int, float)):
            return int(val)
        val_str = str(val).strip().lower()
        if val_str in ['former', 'pernah', '2']:
            return 2
        if val_str in ['current', 'merokok', 'aktif', 'ya', 'not current', 'ever', '1']:
            return 1
        return 0

    def predict_risk(self, data: dict) -> dict:
        """
        Memprediksi skor dan tingkat risiko diabetes berdasarkan parameter profil pasien
        dan kadar glukosa hasil estimasi sensor.
        Menerapkan stratifikasi probabilitas klinis 3 tingkat (Rendah, Sedang, Tinggi)
        dari luaran model klasifikasi biner Random Forest.
        """
        if self.model is None:
            raise FileNotFoundError("Model Random Forest tidak tersedia atau gagal dimuat")

        glucose = float(data.get('blood_glucose_level', 100.0))
        age = float(data.get('age', 40))
        gender = self._parse_gender(data.get('gender', 'Male'))
        bmi = float(data.get('bmi', 23.0))
        hypertension = 1 if str(data.get('hypertension', 0)).strip() in ['1', 'true', 'ya', 'True'] else 0
        heart_disease = 1 if str(data.get('heart_disease', 0)).strip() in ['1', 'true', 'ya', 'True'] else 0
        smoking = self._parse_smoking(data.get('smoking_history', 0))

        # Dataframe dengan 7 fitur masukan
        features_dict = {
            'age': age,
            'gender': gender,
            'bmi': bmi,
            'hypertension': hypertension,
            'heart_disease': heart_disease,
            'smoking_history': smoking,
            'blood_glucose_level': glucose
        }

        df_input = pd.DataFrame([features_dict], columns=self.expected_features)

        # Normalisasi fitur jika scaler tersedia
        if self.scaler is not None:
            input_scaled = self.scaler.transform(df_input)
        else:
            input_scaled = df_input

        # Prediksi Probabilitas
        try:
            pred_proba = self.model.predict_proba(input_scaled)[0]
            prob_non_diabetes = float(pred_proba[0] * 100)
            prob_diabetes = float(pred_proba[1] * 100)
            score = float(pred_proba[1])
        except AttributeError:
            pred = self.model.predict(input_scaled)[0]
            score = float(pred)
            prob_diabetes = score * 100
            prob_non_diabetes = 100.0 - prob_diabetes

        prediction_class = 1 if score >= 0.50 else 0

        # Stratifikasi 3 Tingkat Risiko Medis (GlucoBand EWS System Dokumen C300)
        if prob_diabetes < 30.0:
            level = "Rendah"
            risk_label = "RENDAH"
            class_name = "Non-diabetes (Normal)"
            badge = "🟢 LOW RISK"
            recommendation = (
                "Kondisi metabolisme tubuh baik. Pertahankan pola hidup sehat, "
                "olahraga teratur, dan pemantauan rutin."
            )
        elif prob_diabetes < 60.0:
            level = "Sedang"
            risk_label = "SEDANG"
            class_name = "Risiko Sedang (Waspada)"
            badge = "🟡 MODERATE RISK"
            recommendation = (
                "Terdeteksi indikasi risiko sedang diabetes. Disarankan menjaga asupan gizi seimbang, "
                "kurangi konsumsi gula berlebih, dan konsultasi berkala."
            )
        else:
            level = "Tinggi"
            risk_label = "TINGGI"
            class_name = "Diabetes"
            badge = "🔴 HIGH RISK"
            recommendation = (
                "Terdeteksi risiko tinggi diabetes. Disarankan untuk segera melakukan konsultasi "
                "dengan dokter spesialis penyakit dalam untuk evaluasi klinis."
            )

        # Deteksi faktor risiko dominan
        risk_factors = []
        if glucose > 140:
            risk_factors.append(f"Gula darah di atas ambang normal ({glucose:.1f} mg/dL)")
        if bmi >= 25.0:
            risk_factors.append(f"Indeks massa tubuh tinggi / overweight ({bmi:.1f})")
        if hypertension == 1:
            risk_factors.append("Riwayat hipertensi")
        if heart_disease == 1:
            risk_factors.append("Riwayat penyakit kardiovaskular")
        if smoking in [1, 2]:
            risk_factors.append("Riwayat merokok aktif/pernah")

        return {
            "risk_level": level,
            "risk_label": risk_label,
            "class_name": class_name,
            "risk_score": round(score, 4),
            "prob_diabetes": round(prob_diabetes, 2),
            "prob_non_diabetes": round(prob_non_diabetes, 2),
            "prediction": prediction_class,
            "badge": badge,
            "recommendation": recommendation,
            "model_version": "Random Forest Biner v2.0 (C300)",
            "model version": "Random Forest Biner v2.0 (C300)",
            "risk_factors": risk_factors
        }
