import pandas as pd
from sklearn.ensemble import RandomForestClassifier
import joblib
import os
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BASE_DIR = os.path.join(SCRIPT_DIR, 'app', 'ml_models')

print("Loading dataset...")
df = pd.read_csv(os.path.join(BASE_DIR, 'diabetes_prediction_dataset.csv'))

gender_map = {'Female': 0, 'Male': 1, 'Other': 2}
df['gender'] = df['gender'].map(gender_map)
smoking_map = {
    'No Info': 0,
    'never': 0,
    'former': 1,
    'ever': 1,
    'not current': 1,
    'current': 2
}
df['smoking_history'] = df['smoking_history'].map(smoking_map)
df = df.dropna()

features = ['gender', 'age', 'hypertension', 'heart_disease', 'smoking_history', 'bmi', 'HbA1c_level', 'blood_glucose_level']
X = df[features]
y = df['diabetes']

print("Training model...")
model = RandomForestClassifier(n_estimators=50, random_state=42)
model.fit(X, y)

joblib.dump(model, os.path.join(BASE_DIR, 'rf_diabetes.pkl'))

print("Training completed. Only rf_diabetes.pkl is saved.")
