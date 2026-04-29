from app.extensions import db

class PredictionTrend(db.Model):
    __tablename__ = 'predictions_trend'

    id = db.Column(db.BigInteger(), primary_key=True, autoincrement=True, mysql_unsigned=True)
    patient_id = db.Column(db.BigInteger(), db.ForeignKey('users.id'), nullable=False, mysql_unsigned=True)
    input_measurement_ids = db.Column(db.JSON(), nullable=False)
    health_snapshot = db.Column(db.JSON(), nullable=False)
    predicted_values = db.Column(db.JSON(), nullable=False)
    horizon_hours = db.Column(db.SmallInteger(), default=6)
    model_version = db.Column(db.String(20), default='1.0')
    gen_ai_recommendation = db.Column(db.Text())
    created_at = db.Column(db.DateTime(), server_default=db.func.now())

class PredictionRisk(db.Model):
    __tablename__ = 'predictions_risk'

    id = db.Column(db.BigInteger(), primary_key=True, autoincrement=True, mysql_unsigned=True)
    patient_id = db.Column(db.BigInteger(), db.ForeignKey('users.id'), nullable=False, mysql_unsigned=True)
    feature_vector = db.Column(db.JSON(), nullable=False)
    risk_level = db.Column(db.Enum('rendah', 'sedang', 'tinggi', name='risk_level_enum'), nullable=False)
    risk_score = db.Column(db.Numeric(5, 4), nullable=False)
    model_version = db.Column(db.String(20), default='1.0')
    created_at = db.Column(db.DateTime(), server_default=db.func.now())