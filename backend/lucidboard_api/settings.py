import os
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "dev-only-change-me")
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")

FIRESTORE_PROJECT_ID = os.environ.get("FIRESTORE_PROJECT_ID", "demo-lucidboard")
# google-cloud-firestore reads FIRESTORE_EMULATOR_HOST directly from the
# environment; re-export it here only so `.env` is the single source of
# truth even though load_dotenv already populated os.environ.
FIRESTORE_EMULATOR_HOST = os.environ.get("FIRESTORE_EMULATOR_HOST", "")
if FIRESTORE_EMULATOR_HOST:
    os.environ.setdefault("FIRESTORE_EMULATOR_HOST", FIRESTORE_EMULATOR_HOST)

# Google Cloud Identity Platform. ID tokens are verified against this
# project's `aud`/`iss` claims; defaults to the Firestore project since both
# live in the same GCP project.
IDENTITY_PLATFORM_PROJECT_ID = os.environ.get(
    "IDENTITY_PLATFORM_PROJECT_ID", FIRESTORE_PROJECT_ID
)
# firebase-admin reads FIREBASE_AUTH_EMULATOR_HOST from the environment. When
# set, it SKIPS signature and expiry verification on ID tokens, so it must
# never be set against a real project — only Firebase `demo-*` project ids,
# which cannot exist in production, are allowed alongside it.
FIREBASE_AUTH_EMULATOR_HOST = os.environ.get("FIREBASE_AUTH_EMULATOR_HOST", "")
if FIREBASE_AUTH_EMULATOR_HOST:
    if not IDENTITY_PLATFORM_PROJECT_ID.startswith("demo-"):
        from django.core.exceptions import ImproperlyConfigured

        raise ImproperlyConfigured(
            "FIREBASE_AUTH_EMULATOR_HOST is set but IDENTITY_PLATFORM_PROJECT_ID "
            f"({IDENTITY_PLATFORM_PROJECT_ID!r}) is not a demo-* project; refusing to "
            "accept unsigned emulator tokens against a real project."
        )
    os.environ.setdefault("FIREBASE_AUTH_EMULATOR_HOST", FIREBASE_AUTH_EMULATOR_HOST)

DEBUG = True
ALLOWED_HOSTS = ["*"]

INSTALLED_APPS = [
    "core",
]

MIDDLEWARE = [
    "django.middleware.common.CommonMiddleware",
]

ROOT_URLCONF = "lucidboard_api.urls"
WSGI_APPLICATION = "lucidboard_api.wsgi.application"
ASGI_APPLICATION = "lucidboard_api.asgi.application"

USE_TZ = True
TIME_ZONE = "UTC"
