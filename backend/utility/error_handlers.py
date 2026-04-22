from flask import jsonify
import traceback


def register_error_handlers(app):
    @app.errorhandler(Exception)
    def handle_exception(e):
        response = {
            "error": str(e),
            "error_type": type(e).__name__,
            "traceback": traceback.format_exception(type(e), e, e.__traceback__),
        }
        return jsonify(response), 500
