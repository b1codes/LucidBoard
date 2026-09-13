from __future__ import annotations

import os

import pytest
import requests

from core.firestore_client import get_client, reset_client_for_tests

_START_HINT = (
    "Start the emulators with: "
    "firebase emulators:start --only firestore,auth --project demo-lucidboard"
)


def _require_env(var: str) -> str:
    value = os.environ.get(var)
    if not value:
        pytest.exit(f"{var} is not set — {_START_HINT}", returncode=1)
    return value


def _wipe(url: str, emulator: str) -> None:
    try:
        resp = requests.delete(url, timeout=5)
    except requests.exceptions.RequestException as exc:
        pytest.exit(
            f"Could not reach the {emulator} emulator at {url} — is it running?\n"
            f"{_START_HINT}\n({exc})",
            returncode=1,
        )
    resp.raise_for_status()


@pytest.fixture(autouse=True)
def clear_emulators():
    """Wipe every Firestore document and Auth account before (and after) each test."""
    firestore_host = _require_env("FIRESTORE_EMULATOR_HOST")
    auth_host = _require_env("FIREBASE_AUTH_EMULATOR_HOST")
    project_id = os.environ.get("FIRESTORE_PROJECT_ID", "demo-lucidboard")
    reset_client_for_tests()
    urls = {
        "Firestore": (
            f"http://{firestore_host}/emulator/v1/projects/{project_id}"
            "/databases/(default)/documents"
        ),
        "Auth": f"http://{auth_host}/emulator/v1/projects/{project_id}/accounts",
    }
    for emulator, url in urls.items():
        _wipe(url, emulator)
    yield
    for url in urls.values():
        requests.delete(url, timeout=5).raise_for_status()


@pytest.fixture
def firestore_client():
    return get_client()
