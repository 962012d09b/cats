from flask import request, jsonify, current_app


def require_auth():
    auth_password = current_app.config.get("AUTH_PASSWORD")
    if not auth_password:
        return jsonify({"error": "Authentication not configured"}), 500

    auth_header = request.headers.get("Authorization")

    if not auth_header or auth_header != f"Bearer {auth_password}":
        return jsonify({"error": "Unauthorized"}), 401
