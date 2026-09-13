from __future__ import annotations

import os

import pytest
import requests
from django.test import Client

from core.auth import verify_id_token


def sign_up_anonymous() -> str:
    """Create an anonymous account in the Auth emulator and return its ID token.

    This is the same REST call the Swift client makes; the emulator accepts
    any API key.
    """
    host = os.environ["FIREBASE_AUTH_EMULATOR_HOST"]
    resp = requests.post(
        f"http://{host}/identitytoolkit.googleapis.com/v1/accounts:signUp",
        params={"key": "fake-api-key"},
        json={"returnSecureToken": True},
        timeout=5,
    )
    resp.raise_for_status()
    return resp.json()["idToken"]


@pytest.fixture
def client():
    return Client()


@pytest.fixture
def auth_client():
    token = sign_up_anonymous()
    c = Client(HTTP_AUTHORIZATION=f"Bearer {token}")
    c.user = verify_id_token(token)
    c.token = token
    return c


@pytest.fixture
def other_user():
    """A second, independently signed-up user for cross-user access tests."""
    return verify_id_token(sign_up_anonymous())
