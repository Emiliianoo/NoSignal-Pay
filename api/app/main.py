from fastapi import FastAPI

from app.core.errors import register_error_handlers
from app.routers import auth, health, payments, users, wallet

API_PREFIX = "/api/v1"

app = FastAPI(title="NoSignal Pay API")

register_error_handlers(app)

app.include_router(health.router, prefix=API_PREFIX)
app.include_router(auth.router, prefix=API_PREFIX)
app.include_router(users.router, prefix=API_PREFIX)
app.include_router(wallet.router, prefix=API_PREFIX)
app.include_router(payments.router, prefix=API_PREFIX)
