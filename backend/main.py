from flask import Flask, request, jsonify
from flask_caching import Cache
from flask_cors import CORS
from waitress import serve
import argparse

from database.sql_models import db
from database.schemas import ma
from routes.dataset_routes import dataset_routes_bp
from routes.module_routes import module_routes_bp
from routes.processing_routes import processing_routes_bp
from routes.management_routes import management_routes_bp
from utility.auth import require_auth
from utility.init_db import initialize_database
from utility.dataset_helper import initialize_datasets
from utility.paths import DB_PATH
from utility.error_handlers import register_error_handlers
from celery_app import celery_init_app


DEMO_MODE = False


def create_app(db_uri: str = "sqlite:///" + DB_PATH, auth_password: str = "da46d0ec15764ea5e9c79f8506f8e97a"):
    app = Flask("CATS Backend")
    CORS(app)

    app.config["SQLALCHEMY_DATABASE_URI"] = db_uri
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    app.config["AUTH_PASSWORD"] = auth_password
    app.config["CACHE_TYPE"] = "SimpleCache"
    app.config["CACHE_DEFAULT_TIMEOUT"] = 3600  # 1 hour

    # Celery config
    app.config["CELERY"] = {
        "broker_url": "redis://localhost:6379/0",
        "result_backend": "redis://localhost:6379/0",
        "task_ignore_result": False,
        "result_expires": 3600,  # 1 hour
    }
    celery_init_app(app)

    app.cache = Cache(app)  # type: ignore

    db.init_app(app)
    ma.init_app(app)

    app.register_blueprint(dataset_routes_bp)
    app.register_blueprint(module_routes_bp)
    app.register_blueprint(processing_routes_bp)
    app.register_blueprint(management_routes_bp)

    register_error_handlers(app)

    @app.before_request
    def before_request():
        if request.method == "OPTIONS":
            response = app.make_default_options_response()
            headers = response.headers

            headers["Access-Control-Allow-Origin"] = "*"
            headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
            headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type"

            return response
        elif auth_response := require_auth():
            return auth_response

        if DEMO_MODE:
            if request.method in {"POST", "PUT", "DELETE", "PATCH"} and request.path != "/api/process":
                return jsonify({"error": "Demo mode", "message": "Write operations are disabled in demo mode"}), 403

    return app


def run():
    parser = argparse.ArgumentParser(description="Run the CATS backend server.")
    parser.add_argument(
        "--password",
        type=str,
        default="da46d0ec15764ea5e9c79f8506f8e97a",
        help="Password for authentication, defaults to da46d0ec15764ea5e9c79f8506f8e97a",
    )
    parser.add_argument("--port", type=int, default=47126, help="Port to run the server on, defaults to 47126")
    parser.add_argument(
        "--production", action="store_true", help="Run the server in production mode on 0.0.0.0 instead of localhost"
    )
    args = parser.parse_args()

    app = create_app(auth_password=args.password)

    initialize_datasets()
    with app.app_context():
        initialize_database(db)

    if args.production:
        serve(app, host="0.0.0.0", port=args.port)
    else:
        app.run(debug=True, port=args.port)


if __name__ == "__main__":
    run()
