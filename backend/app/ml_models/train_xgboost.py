"""
Skrip Otomatis Pelatihan Model AI XGBoost Estimasi Glukosa Non-Invasif
GlucoBand Project - AS726X NIR Spectrometry
"""

import os
import pandas as pd
import numpy as np
import joblib
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
from xgboost import XGBRegressor

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.join(BASE_DIR, 'nir_glucose.csv')
MODEL_PATH = os.path.join(BASE_DIR, 'xgboost_model.joblib')
SCALER_PATH = os.path.join(BASE_DIR, 'scaler_xgb.joblib')
JSON_PATH = os.path.join(BASE_DIR, 'xgboost_model.json')

def train():
    print("=" * 60)
    print("🔄 Memulai Pelatihan Model XGBoost GlucoBand")
    print("=" * 60)

    if not os.path.exists(CSV_PATH):
        print(f"❌ Error: File dataset tidak ditemukan di: {CSV_PATH}")
        return

    print(f"📂 Membaca dataset dari: {CSV_PATH}")
    df = pd.read_csv(CSV_PATH)
    print(f"📊 Jumlah total sampel data: {len(df)} baris")

    features = ['R', 'S', 'T', 'U', 'V', 'W']
    target = 'Glucose'

    # Validasi kelengkapan kolom
    for col in features + [target]:
        if col not in df.columns:
            # Cek case-insensitive
            matched = [c for c in df.columns if c.lower() == col.lower()]
            if matched:
                df.rename(columns={matched[0]: col}, inplace=True)
            else:
                print(f"❌ Error: Kolom '{col}' tidak ditemukan di dataset.")
                return

    # Bersihkan NaN jika ada
    df_clean = df.dropna(subset=features + [target])
    X = df_clean[features].values
    y = df_clean[target].values

    # Pembagian Train-Test Split (80% Train, 20% Test)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    print(f"📈 Ukuran Data Latih : {len(X_train)} sampel")
    print(f"🧪 Ukuran Data Uji   : {len(X_test)} sampel")

    # Standardisasi Fitur
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    # Inisialisasi dan Pelatihan Model XGBoost
    print("⚙️  Melatih model XGBRegressor...")
    model = XGBRegressor(
        n_estimators=300,
        learning_rate=0.05,
        max_depth=4,
        subsample=0.8,
        colsample_bytree=0.8,
        objective='reg:squarederror',
        random_state=42
    )
    model.fit(X_train_scaled, y_train)

    # Evaluasi Metrik
    y_pred = model.predict(X_test_scaled)
    r2 = r2_score(y_test, y_pred)
    mae = mean_absolute_error(y_test, y_pred)
    rmse = np.sqrt(mean_squared_error(y_test, y_pred))

    print("\n" + "=" * 60)
    print("🎯 HASIL EVALUASI MODEL:")
    print("=" * 60)
    print(f"  • R² Score (Akurasi Tren) : {r2:.4f} ({r2 * 100:.2f}%)")
    print(f"  • MAE (Rata-rata Margin)  : {mae:.2f} mg/dL")
    print(f"  • RMSE                    : {rmse:.2f} mg/dL")
    print("=" * 60)

    # Simpan Artefak Model
    joblib.dump(model, MODEL_PATH)
    joblib.dump(scaler, SCALER_PATH)
    model.save_model(JSON_PATH)

    print(f"✅ Model baru berhasil disimpan ke:")
    print(f"   1. {MODEL_PATH}")
    print(f"   2. {SCALER_PATH}")
    print(f"   3. {JSON_PATH}")
    print("\n🎉 Pelatihan selesai! File .joblib siap diunggah ke VPS.")

if __name__ == '__main__':
    train()
