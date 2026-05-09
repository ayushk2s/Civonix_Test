from app.config import settings

try:
    from celery import Celery
    from celery.schedules import crontab

    celery = Celery(
        "civonix",
        broker=settings.CELERY_BROKER_URL,
        backend=settings.CELERY_RESULT_BACKEND,
        include=[
            "app.workers.tasks.trade_sync",
            "app.workers.tasks.metrics_calculation",
        ],
    )
    celery.conf.update(
        task_serializer="json",
        result_serializer="json",
        accept_content=["json"],
        timezone="UTC",
        enable_utc=True,
        task_track_started=True,
        task_acks_late=True,
        worker_prefetch_multiplier=1,
        broker_connection_retry_on_startup=False,
        beat_schedule={
            "sync-all-exchanges": {
                "task": "app.workers.tasks.trade_sync.sync_all_active_exchanges",
                "schedule": crontab(minute=0),
            },
            "recalc-all-metrics": {
                "task": "app.workers.tasks.metrics_calculation.recalculate_all_metrics",
                "schedule": crontab(minute=30),
            },
            "daily-snapshot": {
                "task": "app.workers.tasks.metrics_calculation.take_daily_snapshots",
                "schedule": crontab(hour=0, minute=5),
            },
            "resolve-predictions": {
                "task": "app.workers.tasks.metrics_calculation.resolve_daily_predictions",
                "schedule": crontab(hour=0, minute=15),
            },
        },
    )

except Exception:
    import structlog
    structlog.get_logger().warning(
        "Celery/Redis unavailable — background tasks will run inline via FastAPI BackgroundTasks"
    )

    class _NoOpTask:
        def delay(self, *a, **k): pass
        def apply_async(self, *a, **k): pass

    class _NoOpCelery:
        def task(self, *args, **kwargs):
            def decorator(fn):
                fn.delay = lambda *a, **k: None
                fn.apply_async = lambda *a, **k: None
                return fn
            if args and callable(args[0]):
                return decorator(args[0])
            return decorator

    celery = _NoOpCelery()
