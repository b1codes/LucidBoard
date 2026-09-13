output "identity_platform_project_id" {
  description = "Set as IDENTITY_PLATFORM_PROJECT_ID on the backend (tokens' aud/iss claims must match it)."
  value       = google_identity_platform_config.default.project
}

output "ios_api_key" {
  description = "Set as IDENTITY_PLATFORM_API_KEY in the iOS app's Config.xcconfig."
  value       = google_apikeys_key.ios.key_string
  sensitive   = true
}

output "backend_service_account_email" {
  description = "Service account the backend should run as."
  value       = google_service_account.backend.email
}
