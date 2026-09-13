# LucidBoard Local Backend

Lightweight Django Ninja API that replaces Supabase for local development,
backed by the Firestore Local Emulator instead of a local database of
its own.
Production still uses Supabase — this exists so a developer can hack on
the Swift app without depending on a remote Supabase project or running
the full Supabase Docker stack.

## Bootstrap

```bash
cp .env.example .env
# Optional: set GEMINI_API_KEY in .env (without it, embeddings are null)
npm install -g firebase-tools     # one-time, if not already installed
# Firestore on :8080, Identity Platform (Auth) on :9099, UI on :4000
firebase emulators:start --only firestore,auth --project demo-lucidboard
uv sync
uv run manage.py runserver        # http://127.0.0.1:8000
```

In Xcode, set `BACKEND_KIND = local` in `Config.xcconfig` and build/run.

## Testing

```bash
uv run pytest -v
./scripts/smoke.sh   # against a running server
```

`uv run pytest -v` loads `.env` automatically (via Django settings), so `FIRESTORE_EMULATOR_HOST`
/ `FIRESTORE_PROJECT_ID` / `FIREBASE_AUTH_EMULATOR_HOST` don't need to be exported for it. Both
emulators must be running; every test starts with an empty Firestore and no Auth accounts.
`./scripts/smoke.sh`'s board-seed
step is a bare Python process (not going through Django settings), so the shell running it
needs `FIRESTORE_EMULATOR_HOST` and `FIRESTORE_PROJECT_ID` exported — matching `.env`'s
values, e.g. `export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIRESTORE_PROJECT_ID=demo-lucidboard`.
`./scripts/smoke.sh` must also be run from the `backend/` directory (or with `PY` pointed at
an interpreter that has `google-cloud-firestore` installed), since it uses `uv run python` by
default to reach the project's `.venv`.

## Authentication

Auth is Google Cloud Identity Platform. Clients sign up and refresh tokens
**directly** against Identity Platform's REST API (`accounts:signUp`,
`securetoken.googleapis.com/v1/token`). This API only verifies the resulting
ID tokens (`core/auth.py`, via `firebase-admin`) and sends them as `Bearer`
tokens. A user's `users/{uid}` document is created on their first
authenticated request. `user_id` fields are Identity Platform UIDs (strings,
not UUIDs).

Locally, `FIREBASE_AUTH_EMULATOR_HOST` points both the Admin SDK and the
Swift app at the Auth emulator. In that mode the Admin SDK does **not** check
token signatures or expiry, so settings refuse to start if it's set with a
non-`demo-*` project id. Production provisioning lives in `infra/terraform/`.

## API surface

| Method | Path | Auth |
|---|---|---|
| `GET` | `/api/health` | none |
| `GET` | `/api/boards` | bearer |
| `PATCH` | `/api/boards/{id}` | bearer |
| `GET` | `/api/boards/{id}/notes` | bearer |
| `PUT` | `/api/notes/{id}` | bearer |
| `DELETE` | `/api/notes/{id}` | bearer |
| `GET` | `/api/profile` | bearer |
| `PUT` | `/api/profile` | bearer |
| `POST` | `/api/rpc/match_notes` | bearer |

## Limitations (Phase 1)

- Anonymous-only auth (no email/password, no OAuth). Identity Platform
  supports account linking, so these can be added later without new UIDs.
- No realtime/WebSocket sync (LocalAPIRepository returns inert subscription)
- Local dev only — this backend and its Firestore Emulator are not deployed anywhere;
  production still runs Supabase until the prod cutover task lands
- `firestore.indexes.json` is empty — the emulator doesn't enforce composite-index
  requirements, but real Firestore will; add the `boards` (user_id ==, updated_at desc)
  and `notes` (board_id ==, z_index asc) composite indexes here before pointing this
  backend at production Firestore (the latter is used by `list_notes_for_board` in
  `core/repository.py`)
- `notes.embedding` is a 768-element float array; Firestore indexes array elements
  individually by default, which would cost 768 index entries per note write — add a
  `fieldOverrides` single-field exemption for `notes.embedding` in
  `firestore.indexes.json` before the prod cutover
- `match_notes` clustering is pairwise nearest-neighbor (ported as-is from the retired
  Postgres function), not a transitive/global clustering algorithm; unlike the retired
  SQL, this port always returns a position for every note, including a single isolated
  embedded note with no peer on the board (the SQL's inner join silently dropped that
  note — see `core/matching.py`'s `match_notes()` docstring)
- No data migration from Supabase (starts empty)
