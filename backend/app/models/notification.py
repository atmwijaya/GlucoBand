from app.extensions import db

class Notification(db.Model):
    __tablename__ = 'notifications'

    id = db.Column(db.BigInteger(), primary_key=True, autoincrement=True, mysql_unsigned=True)
    patient_id = db.Column(db.BigInteger(), db.ForeignKey('users.id'), nullable=False, mysql_unsigned=True)
    measurement_id = db.Column(db.BigInteger(), db.ForeignKey('measurements.id'), nullable=False, mysql_unsigned=True)
    type = db.Column(db.Enum('hipoglikemia', 'hiperglikemia', 'system', 'rekomendasi', name='notif_type_enum'), nullable=False)
    glucose_value = db.Column(db.Numeric(6, 2), nullable=False)
    is_sent_patient = db.Column(db.Boolean(), default=False)
    is_sent_medis = db.Column(db.Boolean(), default=False)
    sent_at = db.Column(db.DateTime())
    created_at = db.Column(db.DateTime(), server_default=db.func.now())

    def to_dict(self):
        return {
            'id': self.id,
            'patient_id': self.patient_id,
            'type': self.type,
            'glucose_value': str(self.glucose_value),
            'created_at': self.created_at.isoformat() if self.created_at else None
        }