from celery import shared_task, Task
from processing.processing import process_pipelines


@shared_task(bind=True, ignore_result=False)
def process_data_task(self: Task, dataset_ids: list[int], pipelines_json: list[dict], default_risk_score: float):
    """
    Background task for processing pipelines.

    :param self: Task instance (bound task)
    :type self: celery.Task
    :param dataset_ids: Dataset IDs
    :type dataset_ids: list[int]
    :param pipelines_json: Pipeline data
    :type pipelines_json: dict
    :param default_risk_score: Default risk score
    :type default_risk_score: float
    :return: Status and results of the processing
    :rtype: dict
    """
    try:
        self.update_state(state="PROCESSING", meta={"status": "Processing pipelines...", "progress": 0})
        results = process_pipelines(dataset_ids, pipelines_json, default_risk_score, task=self)

        results_list = [pipe.to_json() for pipe in results]

        return results_list

    except Exception as exc:
        self.update_state(state="FAILURE", meta={"status": f"Task failed: {str(exc)}", "error": str(exc)})
        raise exc
