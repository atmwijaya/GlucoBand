import os
import joblib
import numpy as np
import tensorflow as tf
from datetime import datetime, timedelta

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, '..', '..', 'ml_models')

# Konstanta Fisiologis & Konversi Medis Dokumen C200 & C300
MMOL_TO_MGDL = 18.0
MIN_SAFE_MGDL = 40.0
MAX_SAFE_MGDL = 400.0
MAX_DELTA_PER_HOUR_MMOL = 5.0  # ~90 mg/dL per jam (batas fisiologis maksimum)
DEFAULT_RESTING_HR = 75.0      # Detak jantung rata-rata normal (bpm)

class LSTMService:
    """
    Layanan inferensi Machine Learning GlucoBand berbasis arsitektur 2-layer LSTM
    dengan target residual delta (perubahan glukosa 1 jam ke depan) menggunakan
    scaler_features.pkl (MinMaxScaler 6 fitur) dan scaler_delta.pkl (StandardScaler).
    """

    def __init__(self):
        self.model = None
        self.scaler_features = None
        self.scaler_delta = None
        self.timesteps = 72       # 72 titik waktu (interval 5 menit = 6 jam riwayat)
        self.n_features = 6       # ['bg', 'insulin', 'carbs', 'hr', 'steps', 'cals']
        self.feature_names = ['bg', 'insulin', 'carbs', 'hr', 'steps', 'cals']
        self._load_assets()

    def _load_assets(self):
        """Memuat berkas model H5 dan scaler pickle."""
        model_path = os.path.join(MODEL_DIR, 'glucoband_lstm_model.h5')
        scaler_feat_path = os.path.join(MODEL_DIR, 'scaler_features.pkl')
        scaler_delta_path = os.path.join(MODEL_DIR, 'scaler_delta.pkl')

        try:
            self.model = tf.keras.models.load_model(model_path)
            print("LSTM Model (glucoband_lstm_model.h5) berhasil dimuat.")
        except Exception as e:
            print("Gagal memuat LSTM model:", e)
            self.model = None

        try:
            self.scaler_features = joblib.load(scaler_feat_path)
            print("Scaler features (scaler_features.pkl) berhasil dimuat.")
        except Exception as e:
            print("Gagal memuat scaler features:", e)
            self.scaler_features = None

        try:
            self.scaler_delta = joblib.load(scaler_delta_path)
            print("Scaler delta (scaler_delta.pkl) berhasil dimuat.")
        except Exception as e:
            print("Gagal memuat scaler delta:", e)
            self.scaler_delta = None

    def _build_72x6_sequence(self, glucose_history_mgdl: list, hr: float = DEFAULT_RESTING_HR,
                             insulin: float = 0.0, carbs: float = 0.0,
                             steps: float = 0.0, cals: float = 0.0) -> np.ndarray:
        """
        Mengonstruksi matriks 2D (72, 6) dari riwayat glukosa (mg/dL) dan sinyal penunjang.
        Menggunakan interpolasi linear jika titik riwayat kurang dari 72.
        """
        # Konversi mg/dL ke mmol/L sesuai dataset pelatihan BrisT1D
        history_mmol = [float(v) / MMOL_TO_MGDL for v in glucose_history_mgdl if float(v) > 0]
        if not history_mmol:
            history_mmol = [100.0 / MMOL_TO_MGDL]

        # Jika data kurang dari 72 titik, lakukan interpolasi sepanjang sumbu waktu 6 jam
        if len(history_mmol) < self.timesteps:
            x_old = np.linspace(0, 1, len(history_mmol))
            x_new = np.linspace(0, 1, self.timesteps)
            bg_series = np.interp(x_new, x_old, history_mmol)
        else:
            bg_series = np.array(history_mmol[-self.timesteps:], dtype=np.float32)

        # Penyesuaian Asumsi Fisiologis Insulin Basal (Pankreas Endogen):
        # Model dilatih pada dataset T1D (tanpa insulin alami). Pada pengguna umum/form
        # yang tidak menginput insulin, gunakan estimasi laju sekresi basal endogen
        # agar glukosa normal tidak mengalami distorsi lonjakan palsu akibat ketiadaan sinyal insulin.
        current_mgdl = float(bg_series[-1]) * MMOL_TO_MGDL
        if float(insulin) <= 0.0:
            if current_mgdl < 75.0:
                effective_insulin = 0.0      # Hipoglikemia: sekresi insulin ditekan oleh tubuh
            elif current_mgdl <= 130.0:
                effective_insulin = 0.35     # Homeostasis basal normal individu sehat
            elif current_mgdl <= 180.0:
                effective_insulin = 0.20     # Regulasi parsial pada gula darah meningkat
            else:
                effective_insulin = 0.10     # Hiperglikemia persisten tanpa insulin
        else:
            effective_insulin = max(0.0, float(insulin))

        # Susun matriks berdimensi (72, 6)
        seq = np.zeros((self.timesteps, self.n_features), dtype=np.float32)
        seq[:, 0] = bg_series                                    # bg (mmol/L)
        seq[:, 1] = effective_insulin                            # insulin (units)
        seq[:, 2] = max(0.0, float(carbs))                       # carbs (grams)
        seq[:, 3] = max(30.0, min(220.0, float(hr)))             # hr (bpm)
        seq[:, 4] = max(0.0, float(steps))                       # steps
        seq[:, 5] = max(0.0, float(cals))                        # calories

        return seq

    def predict_trend(self, glucose_history: list, horizon_hours: int = 6,
                      age: int = 40, bmi: float = 25.0, hypertension: int = 0,
                      heart_disease: int = 0, gender: str = "Male",
                      smoking_history: int = 0, heart_rate: float = DEFAULT_RESTING_HR,
                      insulin: float = 0.0, carbs: float = 0.0,
                      steps: float = 0.0, calories: float = 0.0) -> list:
        """
        Memprediksi tren kadar gula darah beberapa jam ke depan (default 6 jam).
        Mengembalikan daftar titik dengan format:
        [{"timestamp": "ISO-8601", "glucose": float}, ...]
        """
        if self.model is None:
            raise FileNotFoundError("Model LSTM tidak tersedia atau gagal dimuat")
        if self.scaler_features is None or self.scaler_delta is None:
            raise FileNotFoundError("Scaler LSTM (features/delta) tidak lengkap")

        if len(glucose_history) < 1:
            raise ValueError("Minimal 1 data glukosa historis diperlukan")

        # Bangun deret 72x6 awal
        current_seq = self._build_72x6_sequence(
            glucose_history_mgdl=glucose_history,
            hr=heart_rate,
            insulin=insulin,
            carbs=carbs,
            steps=steps,
            cals=calories
        )

        current_bg_mmol = float(current_seq[-1, 0])
        now = datetime.now()
        base_time = now.replace(minute=0, second=0, microsecond=0)
        predictions = []

        for h in range(max(1, horizon_hours)):
            # 1. Normalisasi fitur (72, 6)
            seq_scaled = self.scaler_features.transform(current_seq)
            input_3d = np.expand_dims(seq_scaled, axis=0) # (1, 72, 6)

            # 2. Inferensi model LSTM -> menghasilkan delta skalar terstandarisasi
            pred_delta_scaled = self.model.predict(input_3d, verbose=0)

            # 3. Denormalisasi delta glukosa (mmol/L)
            pred_delta_mmol = float(self.scaler_delta.inverse_transform(pred_delta_scaled)[0, 0])

            # 4. Medical Safety Guardrail & Filter Lonjakan Fisiologis
            # Batasi laju perubahan glukosa per jam agar tidak melampaui batas anatomis
            pred_delta_mmol = float(np.clip(pred_delta_mmol, -MAX_DELTA_PER_HOUR_MMOL, MAX_DELTA_PER_HOUR_MMOL))

            # 5. Rekonstruksi nilai glukosa 1 jam berikutnya (mmol/L)
            next_bg_mmol = current_bg_mmol + pred_delta_mmol
            next_bg_mmol = float(np.clip(next_bg_mmol, MIN_SAFE_MGDL / MMOL_TO_MGDL, MAX_SAFE_MGDL / MMOL_TO_MGDL))

            # 6. Konversi ke mg/dL dan terapkan bobot inersia fisiologis (Dokumen C200 hal 41)
            raw_pred_mgdl = next_bg_mmol * MMOL_TO_MGDL
            curr_mgdl = current_bg_mmol * MMOL_TO_MGDL
            final_pred_mgdl = 0.92 * raw_pred_mgdl + 0.08 * curr_mgdl
            final_pred_mgdl = float(np.clip(final_pred_mgdl, MIN_SAFE_MGDL, MAX_SAFE_MGDL))

            target_time = (base_time + timedelta(hours=h + 1)).astimezone()
            predictions.append({
                "timestamp": target_time.isoformat(),
                "glucose": round(final_pred_mgdl, 2)
            })

            # 7. Pembaruan autoregressive: Geser deret waktu maju 1 jam (12 titik 5-menit)
            final_mmol = final_pred_mgdl / MMOL_TO_MGDL
            transition_bg = np.linspace(current_bg_mmol, final_mmol, 13)[1:]
            
            # Perbarui estimasi insulin basal sesuai glukosa baru
            if float(insulin) <= 0.0:
                if final_pred_mgdl < 75.0:
                    step_insulin = 0.0
                elif final_pred_mgdl <= 130.0:
                    step_insulin = 0.35
                elif final_pred_mgdl <= 180.0:
                    step_insulin = 0.20
                else:
                    step_insulin = 0.10
            else:
                step_insulin = max(0.0, float(insulin))

            new_steps = np.zeros((12, self.n_features), dtype=np.float32)
            new_steps[:, 0] = transition_bg
            new_steps[:, 1] = step_insulin
            new_steps[:, 2] = current_seq[-1, 2]
            new_steps[:, 3] = current_seq[-1, 3]
            new_steps[:, 4] = current_seq[-1, 4]
            new_steps[:, 5] = current_seq[-1, 5]

            current_seq = np.vstack([current_seq[12:], new_steps])
            current_bg_mmol = final_mmol

        return predictions

    def predict_detailed(self, glucose_history: list, horizon_hours: int = 6, **kwargs) -> dict:
        """
        Metode komprehensif yang mengembalikan titik proyeksi beserta diagnosis klinis,
        arah pergerakan tren, dan rekomendasi medis GlucoBand.
        """
        points = self.predict_trend(glucose_history, horizon_hours=horizon_hours, **kwargs)
        if not points:
            return {}

        current_glucose = float(glucose_history[-1])
        first_hour_pred = points[0]["glucose"]
        delta_mgdl = first_hour_pred - current_glucose

        # Penentuan arah tren
        if delta_mgdl > 5.0:
            trend_direction = "Tren Naik (Rising)"
            trend_code = "rising"
        elif delta_mgdl < -5.0:
            trend_direction = "Tren Turun (Falling)"
            trend_code = "falling"
        else:
            trend_direction = "Tren Stabil (Stable)"
            trend_code = "stable"

        # Penentuan status klinis & rekomendasi
        if first_hour_pred < 70.0:
            clinical_status = "DANGER: RISIKO HIPOGLIKEMIA (< 70 mg/dL)"
            recommendation = (
                "Segera konsumsi 15-20g karbohidrat sederhana (jus buah, tablet glukosa, "
                "atau teh manis) dan pantau ulang dalam 15 menit."
            )
            is_abnormal = True
        elif first_hour_pred > 200.0:
            clinical_status = "WARNING: RISIKO HIPERGLIKEMIA (> 200 mg/dL)"
            recommendation = (
                "Lakukan hidrasi air mineral, batasi asupan karbohidrat, dan konsultasikan "
                "penyesuaian dosis insulin/obat dengan dokter atau tenaga medis Anda."
            )
            is_abnormal = True
        elif first_hour_pred > 140.0:
            clinical_status = "PERINGATAN: GULA DARAH MENINGKAT (140 - 200 mg/dL)"
            recommendation = (
                "Kadar gula darah berada di atas rentang optimal. Kurangi camilan manis "
                "dan lakukan aktivitas fisik ringan."
            )
            is_abnormal = False
        else:
            clinical_status = "NORMAL (70 - 140 mg/dL)"
            recommendation = "Kondisi glikemik stabil. Pertahankan pola makan sehat, hidrasi, dan istirahat teratur."
            is_abnormal = False

        return {
            "current_glucose": round(current_glucose, 2),
            "predicted_1h_glucose": round(first_hour_pred, 2),
            "delta_mgdl": round(delta_mgdl, 2),
            "trend_direction": trend_direction,
            "trend_code": trend_code,
            "clinical_status": clinical_status,
            "medical_recommendation": recommendation,
            "is_abnormal": is_abnormal,
            "predictions": points,
            "model_version": "LSTM Delta BrisT1D v2.0"
        }
