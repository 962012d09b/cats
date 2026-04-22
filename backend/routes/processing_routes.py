from flask import Blueprint, request, jsonify
from celery.result import AsyncResult
from processing.tasks import process_data_task

processing_routes_bp = Blueprint("processing_routes_bp", __name__)


class ProcessingState:
    def __init__(
        self, job_id: str, message: str, progress: float, results: list, ready: bool, successful: bool
    ) -> None:
        self.job_id = job_id
        self.message = message
        self.progress = progress
        self.ready = ready
        self.successful = successful
        self.results = results

    def to_json(self) -> dict:
        return {
            "job_id": self.job_id,
            "message": self.message,
            "progress": self.progress,
            "results": self.results,
            "ready": self.ready,
            "successful": self.successful,
        }


@processing_routes_bp.route("/api/process", methods=["POST"])
def process_data():
    assert request.json is not None, "Request does not provide JSON data"

    pipelines_json = request.json["pipelines"]
    datasets_json = request.json["datasets"]
    pipeline_defaults_json = request.json["pipeline_defaults"]
    default_risk_score = pipeline_defaults_json["default_risk_score"]

    if not (pipelines_json and datasets_json):
        return jsonify({"error": "Missing pipelines or datasets"}), 400

    result = process_data_task.delay(  # type: ignore
        datasets_json,
        pipelines_json,
        default_risk_score,
    )

    return jsonify(
        ProcessingState(
            job_id=result.id, message="Processing job started", progress=0.0, results=[], ready=False, successful=False
        ).to_json()
    )


@processing_routes_bp.route("/api/process/status/<job_id>", methods=["GET"])
def get_processing_status(job_id: str):
    try:
        current_job = AsyncResult(job_id)

        if current_job.ready():
            return jsonify(
                ProcessingState(
                    job_id=job_id,
                    message="Processing job completed" if current_job.successful else "Processing job failed",
                    progress=1.0,
                    results=current_job.result,
                    ready=True,
                    successful=current_job.successful(),
                ).to_json()
            )
        else:
            info = current_job.info or {}

            return jsonify(
                ProcessingState(
                    job_id=job_id,
                    message=info.get("status", "Job is still running..."),
                    progress=info.get("progress", 0.0),
                    results=[],
                    ready=False,
                    successful=False,
                ).to_json()
            )

    except Exception as e:
        return (
            jsonify(
                ProcessingState(
                    job_id=job_id,
                    message=f"Failed to get task status: {str(e)}",
                    progress=0.0,
                    results=[],
                    ready=True,
                    successful=False,
                ).to_json()
            ),
            500,
        )
