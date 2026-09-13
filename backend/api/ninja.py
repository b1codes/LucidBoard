from __future__ import annotations

from django.http import HttpRequest
from firebase_admin.auth import CertificateFetchError
from ninja import NinjaAPI
from ninja.errors import AuthenticationError, ValidationError

from api.routers.boards import router as boards_router
from api.routers.notes import router as notes_router
from api.routers.profiles import router as profiles_router
from api.routers.rpc import router as rpc_router

api = NinjaAPI(title="LucidBoard Local API", version="0.1.0", urls_namespace="api")

# Sign-up/sign-in happen directly against Identity Platform; this API only
# verifies the resulting ID tokens, so there are no /auth routes here.
api.add_router("/api", boards_router)
api.add_router("/api", notes_router)
api.add_router("/api", profiles_router)
api.add_router("/api", rpc_router)


@api.get("/api/health")
def health(request: HttpRequest):
    return {"status": "ok"}


@api.exception_handler(AuthenticationError)
def on_auth_error(request, exc):
    return api.create_response(
        request, {"detail": "Unauthorized", "code": "unauthorized"}, status=401
    )


@api.exception_handler(CertificateFetchError)
def on_cert_fetch_error(request, exc):
    # Not a 401: the token may be fine, and a 401 would make the client throw
    # away its session and re-authenticate for what is a server-side outage.
    return api.create_response(
        request,
        {"detail": "Token verification unavailable", "code": "auth_unavailable"},
        status=503,
    )


@api.exception_handler(ValidationError)
def on_validation(request, exc):
    return api.create_response(
        request,
        {"detail": "Validation failed", "code": "validation_error", "errors": exc.errors},
        status=422,
    )
