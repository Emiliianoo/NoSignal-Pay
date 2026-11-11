from fastapi import FastAPI

from app.routers import health

API_PREFIX = "/api/v1"

app = FastAPI(title="NoSignal Pay API")

app.include_router(health.router, prefix=API_PREFIX)
