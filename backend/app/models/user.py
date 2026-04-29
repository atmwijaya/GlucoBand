from app.extensions import db
from sqlalchemy.dialects.mysql import BIGINT, INTEGER, SMALLINT
from werkzeug.security import generate_password_hash, check_password_hash

class User(db.Model):
    __tablename__ = 'users'

    id = db.Column(BIGINT(unsigned=True), primary_key=True, autoincrement=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(150), unique=True, nullable=False)
    password = db.Column(db.String(255), nullable=False)
    role = db.Column(db.Enum('tenaga_medis', 'pasien', name='role_enum'), nullable=False)
    age = db.Column(INTEGER(unsigned=True))
    gender = db.Column(db.Enum('L', 'P', name='gender_enum'))
    weight_kg = db.Column(db.Numeric(5, 2))
    height_cm = db.Column(db.Numeric(5, 2))
    blood_pressure_sys = db.Column(SMALLINT(unsigned=True))
    blood_pressure_dia = db.Column(SMALLINT(unsigned=True))
    diabetes_history = db.Column(db.Boolean(), default=False)
    smoking_history = db.Column(db.Boolean(), default=False)
    is_active = db.Column(db.Boolean(), default=True)
    fcm_token = db.Column(db.String(255))
    created_at = db.Column(db.DateTime(), server_default=db.func.now())
    updated_at = db.Column(db.DateTime(), server_default=db.func.now(), onupdate=db.func.now())

    def set_password(self, password_text):
        self.password = generate_password_hash(password_text)

    def check_password(self, password_text):
        return check_password_hash(self.password, password_text)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'email': self.email,
            'role': self.role,
            'age': self.age,
            'gender': self.gender,
            'weight_kg': str(self.weight_kg) if self.weight_kg else None,
            'height_cm': str(self.height_cm) if self.height_cm else None,
            'blood_pressure_sys': self.blood_pressure_sys,
            'blood_pressure_dia': self.blood_pressure_dia,
            'diabetes_history': self.diabetes_history,
            'smoking_history': self.smoking_history,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }