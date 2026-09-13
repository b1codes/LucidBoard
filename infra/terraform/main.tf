locals {
  auth_services = [
    "identitytoolkit.googleapis.com", # Identity Platform: sign-up / sign-in
    "securetoken.googleapis.com",     # ID token refresh
    "apikeys.googleapis.com",         # managing the client API key below
  ]
}

resource "google_project_service" "auth" {
  for_each = toset(local.auth_services)

  project = var.project_id
  service = each.value

  # Other stacks in the project may rely on these APIs.
  disable_on_destroy = false
}

# Upgrades the project to Identity Platform and configures sign-in. Note this
# resource cannot really be destroyed: `terraform destroy` only drops it from
# state, and the project stays on Identity Platform.
resource "google_identity_platform_config" "default" {
  project = var.project_id

  # The app has no account-upgrade flow yet, so an anonymous UID is a user's
  # only identity — auto-deleting it after 30 days would orphan their boards.
  autodelete_anonymous_users = false

  sign_in {
    allow_duplicate_emails = false

    anonymous {
      enabled = true
    }
  }

  depends_on = [google_project_service.auth]
}

# The iOS client's API key. Identity Platform API keys identify the project
# rather than grant access, but restricting it to the app's bundle id and the
# two auth APIs keeps it from being reused for anything else.
resource "google_apikeys_key" "ios" {
  project      = var.project_id
  name         = "lucidboard-ios"
  display_name = "LucidBoard iOS (Identity Platform)"

  restrictions {
    ios_key_restrictions {
      allowed_bundle_ids = [var.ios_bundle_id]
    }

    api_targets {
      service = "identitytoolkit.googleapis.com"
    }

    api_targets {
      service = "securetoken.googleapis.com"
    }
  }

  depends_on = [google_project_service.auth]
}

# Runtime identity for the Django API (e.g. on Cloud Run). Verifying
# Identity Platform ID tokens needs no IAM role: firebase-admin checks them
# against Google's public signing certs using only the project id. Data-access
# roles (Firestore) belong with the Firestore infrastructure.
resource "google_service_account" "backend" {
  project      = var.project_id
  account_id   = "lucidboard-backend"
  display_name = "LucidBoard backend API"
  description  = "Runtime identity for the LucidBoard Django API."
}
