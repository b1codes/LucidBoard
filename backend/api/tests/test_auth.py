from unittest.mock import patch

import jwt
from django.test import Client
from firebase_admin.auth import CertificateFetchError

from api.conftest import sign_up_anonymous
from core.repository import get_user


def test_valid_identity_platform_token_is_accepted_and_creates_user(client):
    token = sign_up_anonymous()
    uid = jwt.decode(token, options={"verify_signature": False})["sub"]
    res = client.get("/api/profile", HTTP_AUTHORIZATION=f"Bearer {token}")
    assert res.status_code == 200
    assert get_user(uid) is not None


def test_missing_token_returns_401(client):
    res = client.get("/api/profile")
    assert res.status_code == 401
    assert res.json()["code"] == "unauthorized"


def test_invalid_token_returns_401():
    c = Client(HTTP_AUTHORIZATION="Bearer not.a.jwt")
    res = c.get("/api/profile")
    assert res.status_code == 401
    assert res.json()["code"] == "unauthorized"


def test_cert_fetch_failure_returns_503_not_401(auth_client):
    with patch(
        "core.auth.firebase_auth.verify_id_token",
        side_effect=CertificateFetchError("certs unreachable", cause=None),
    ):
        res = auth_client.get("/api/profile")
    assert res.status_code == 503
    assert res.json()["code"] == "auth_unavailable"


def test_legacy_signup_endpoint_is_gone(client):
    res = client.post("/auth/v1/signup?anonymous=true")
    assert res.status_code == 404
