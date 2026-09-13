import os
import subprocess
import sys

import jwt
import pytest
from firebase_admin import auth as firebase_auth

from api.conftest import sign_up_anonymous
from core.auth import verify_id_token
from core.repository import get_user


def _resign(token: str, **claim_overrides) -> str:
    """Re-encode an emulator ID token with some claims replaced.

    Emulator tokens are unsigned (alg "none"), so this produces a token the
    emulator-mode verifier would accept if it didn't check the claim itself.
    """
    payload = jwt.decode(token, options={"verify_signature": False})
    payload.update(claim_overrides)
    return jwt.encode(payload, key=None, algorithm="none")


def test_verify_id_token_creates_user_on_first_sight():
    token = sign_up_anonymous()
    uid = jwt.decode(token, options={"verify_signature": False})["sub"]
    assert get_user(uid) is None

    user = verify_id_token(token)

    assert user.id == uid
    assert user.is_anonymous_user is True
    assert get_user(uid) is not None


def test_verify_id_token_returns_existing_user_on_repeat():
    token = sign_up_anonymous()
    first = verify_id_token(token)
    second = verify_id_token(token)
    assert second.id == first.id
    assert second.created_at == first.created_at


def test_verify_id_token_rejects_token_for_other_project():
    token = _resign(
        sign_up_anonymous(),
        aud="some-other-project",
        iss="https://securetoken.google.com/some-other-project",
    )
    with pytest.raises(firebase_auth.InvalidIdTokenError):
        verify_id_token(token)


def test_verify_id_token_rejects_wrong_issuer():
    token = _resign(sign_up_anonymous(), iss="https://evil.example.com/demo-lucidboard")
    with pytest.raises(firebase_auth.InvalidIdTokenError):
        verify_id_token(token)


def test_verify_id_token_rejects_garbage():
    with pytest.raises(firebase_auth.InvalidIdTokenError):
        verify_id_token("not.a.jwt")


def test_verify_id_token_rejects_empty_token():
    with pytest.raises(ValueError):
        verify_id_token("")


def test_settings_refuse_auth_emulator_with_real_project():
    env = {
        **os.environ,
        "FIREBASE_AUTH_EMULATOR_HOST": "127.0.0.1:9099",
        "IDENTITY_PLATFORM_PROJECT_ID": "lucidboard-prod",
    }
    result = subprocess.run(
        [sys.executable, "-c", "import lucidboard_api.settings"],
        env=env,
        capture_output=True,
        text=True,
    )
    assert result.returncode != 0
    assert "ImproperlyConfigured" in result.stderr
