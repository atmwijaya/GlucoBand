from app.extensions import db

class Device(db.Model):
    __tablename__ = 'devices'

    id = db.Column(db.BigInteger(), primary_key=True, autoincrement=True, mysql_unsigned=True)
    patient_id = db.Column(db.BigInteger(), db.ForeignKey('users.id'), nullable=False, mysql_unsigned=True)
    device_code = db.Column(db.String(64), unique=True, nullable=False)
    firmware_ver = db.Column(db.String(20))
    is_active = db.Column(db.Boolean(), default=True)
    registered_at = db.Column(db.DateTime(), server_default=db.func.now())