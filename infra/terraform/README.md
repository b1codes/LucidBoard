# LucidBoard Terraform — Identity Platform

Provisions Google Cloud Identity Platform for LucidBoard's anonymous auth:

| Resource | Purpose |
|---|---|
| `google_project_service.auth` | Enables `identitytoolkit`, `securetoken`, and `apikeys` APIs |
| `google_identity_platform_config.default` | Upgrades the project to Identity Platform, enables anonymous sign-in |
| `google_apikeys_key.ios` | Client API key, restricted to the iOS bundle id and the two auth APIs |
| `google_service_account.backend` | Runtime identity for the Django API (no roles needed for token verification) |

Local development doesn't use any of this. It runs against the Firebase Auth
emulator (see `backend/README.md`).

## Prerequisites

- A GCP project **with billing enabled** (Identity Platform requires it)
- `gcloud auth application-default login` as a user who can enable APIs and
  manage Identity Platform / API keys on the project

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # set project_id
terraform init
terraform plan
terraform apply
```

Then wire the outputs into the apps:

```bash
terraform output identity_platform_project_id   # backend: IDENTITY_PLATFORM_PROJECT_ID
terraform output -raw ios_api_key               # iOS: IDENTITY_PLATFORM_API_KEY in Config.xcconfig
```

The backend must **not** have `FIREBASE_AUTH_EMULATOR_HOST` set in any
deployed environment. Settings refuse to start if it's set alongside a
non-`demo-*` project id, because the Admin SDK skips signature and expiry
checks in emulator mode.

## Notes

- `terraform destroy` does not downgrade the project from Identity Platform;
  the config resource is only removed from state.
- `autodelete_anonymous_users` is deliberately off: an anonymous UID is
  currently a user's only identity.
- State is local by default; see the commented `backend "gcs"` block in
  `versions.tf` for shared state.
