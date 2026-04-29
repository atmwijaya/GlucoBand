from app.extensions import db

class FAQ(db.Model):
    __tablename__ = 'faq'

    id = db.Column(db.BigInteger(), primary_key=True, autoincrement=True, mysql_unsigned=True)
    question = db.Column(db.String(300), nullable=False)
    answer = db.Column(db.Text(), nullable=False)
    category = db.Column(db.String(60), default='umum')
    order_index = db.Column(db.SmallInteger(), default=0)
    is_active = db.Column(db.Boolean(), default=True)
    created_by = db.Column(db.BigInteger(), db.ForeignKey('users.id'), nullable=False, mysql_unsigned=True)
    created_at = db.Column(db.DateTime(), server_default=db.func.now())
    updated_at = db.Column(db.DateTime(), server_default=db.func.now(), onupdate=db.func.now())

    def to_dict(self):
        return {
            'id': self.id,
            'question': self.question,
            'answer': self.answer,
            'category': self.category
        }