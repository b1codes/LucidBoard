from __future__ import annotations

import firebase_admin
from django.conf import settings
from firebase_admin import auth as firebase_auth
from ninja.security import HttpBearer

from core.models import User
from core.repository import get_or_create_user

_APP_NAME = "lucidboard"


def _get_app() -> firebase_admin.App:
    """Return the process-wide firebase-admin app, initializing it on first use.

    No credential is passed: ID token verification only needs the project id
    (it fetches Google's public signing certs anonymously), and against the
    Auth Emulator no credentials are involved at all.
    """
    try:
        return firebase_admin.get_app(_APP_NAME)
    except ValueError:
        return firebase_admin.initialize_app(
            options={"projectId": settings.IDENTITY_PLATFORM_PROJECT_ID}, name=_APP_NAME
        )


def verify_id_token(token: str) -> User:
    """Verify an Identity Platform ID token and return the User it identifies.

    The first request from a new Identity Platform account creates its
    `users/{uid}` document. Raises `firebase_admin.auth.InvalidIdTokenError`
    (or its `ExpiredIdTokenError` subclass) on a bad token, `ValueError` on
    an empty one, and `firebase_admin.auth.CertificateFetchError` if Google's
    signing certs can't be fetched.
    """
    claims = firebase_auth.verify_id_token(token, app=_get_app())
    provider = claims.get("firebase", {}).get("sign_in_provider")
    return get_or_create_user(claims["uid"], is_anonymous=provider == "anonymous")


class IdentityPlatformBearer(HttpBearer):
    """Ninja auth class. Returns the User on success, None on failure."""

    def authenticate(self, request, token: str) -> User | None:
        try:
            user = verify_id_token(token)
        except (firebase_auth.InvalidIdTokenError, ValueError):
            return None
        request.user = user
        return user
