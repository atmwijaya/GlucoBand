from app.extensions import db

class Measurement(db.Model):
    __tablename__ = 'measurements'

    id = db.Column(db.BigInteger(), primary_key=True, autoincrement=True, mysql_unsigned=True)
    patient_id = db.Column(db.BigInteger(), db.ForeignKey('users.id'), nullable=False, mysql_unsigned=True)
    device_id = db.Column(db.BigInteger(), db.ForeignKey('devices.id'), mysql_unsigned=True)
    nir_610nm = db.Column(db.Float())
    nir_680nm = db.Column(db.Float())
    nir_730nm = db.Column(db.Float())
    nir_760nm = db.Column(db.Float())
    nir_810nm = db.Column(db.Float())
    nir_860nm = db.Column(db.Float())
    ppg_heart_rate = db.Column(db.Float())
    ppg_spo2 = db.Column(db.Float())
    ppg_ir_value = db.Column(db.Float())
    skin_temp_celsius = db.Column(db.Numeric(5, 2))
    glucose_estimated = db.Column(db.Numeric(6, 2))
    glucose_invasive = db.Column(db.Numeric(6, 2))
    is_calibration = db.Column(db.Boolean(), default=False)
    created_at = db.Column(db.DateTime(), nullable=False)
    synced_at = db.Column(db.DateTime(), server_default=db.func.now())
    source = db.Column(db.Enum('wifi', 'sdcard', name='source_enum'), default='wifi')

    def to_dict(self):
        return {
            'id': self.id,
            'patient_id': self.patient_id,
            'glucose_estimated': str(self.glucose_estimated) if self.glucose_estimated else None,
            'ppg_heart_rate': self.ppg_heart_rate,
            'ppg_spo2': self.ppg_spo2,
            'skin_temp_celsius': str(self.skin_temp_celsius) if self.skin_temp_celsius else None,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }