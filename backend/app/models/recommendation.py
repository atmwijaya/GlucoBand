from app.extensions import db

class Recommendation(db.Model):
    __tablename__ = 'recommendations'

    id = db.Column(db.BigInteger(), primary_key=True, autoincrement=True, mysql_unsigned=True)
    patient_id = db.Column(db.BigInteger(), db.ForeignKey('users.id'), nullable=False, mysql_unsigned=True)
    medis_id = db.Column(db.BigInteger(), db.ForeignKey('users.id'), nullable=False, mysql_unsigned=True)
    content = db.Column(db.Text(), nullable=False)
    is_read = db.Column(db.Boolean(), default=False)
    created_at = db.Column(db.DateTime(), server_default=db.func.now())