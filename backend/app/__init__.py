from flask import Flask
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_socketio import SocketIO, emit
import os
from dotenv import load_dotenv

load_dotenv()
socketio = SocketIO(cors_allowed_origins="*")

def create_app():
    app = Flask(__name__)
    app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'dev-secret-key')
    app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', 'jwt-secret-key')

    CORS(app)
    JWTManager(app)
    socketio.init_app(app)

    # Register blueprints
    from app.routes.auth import auth_bp
    from app.routes.patients import patients_bp
    from app.routes.measurements import measurements_bp
    from app.routes.predictions import predictions_bp
    from app.routes.notifications import notifications_bp
    from app.routes.recommendations import recommendations_bp
    from app.routes.faq import faq_bp
    from app.routes.profile import profile_bp
    from app.routes.dashboard import dashboard_bp
    from app.routes.patientNotification import patient_notif_bp 

    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(patients_bp, url_prefix='/api')
    app.register_blueprint(measurements_bp, url_prefix='/api')
    app.register_blueprint(predictions_bp, url_prefix='/api')
    app.register_blueprint(notifications_bp, url_prefix='/api')
    app.register_blueprint(recommendations_bp, url_prefix='/api')
    app.register_blueprint(faq_bp, url_prefix='/api')
    app.register_blueprint(dashboard_bp, url_prefix='/api')
    app.register_blueprint(profile_bp, url_prefix='/api')
    app.register_blueprint(patient_notif_bp, url_prefix='/api')

    return app