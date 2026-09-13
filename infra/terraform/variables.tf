variable "project_id" {
  description = "GCP project that hosts LucidBoard's Identity Platform tenant (and Firestore). Billing must be enabled — Identity Platform requires it."
  type        = string
}

variable "ios_bundle_id" {
  description = "Bundle identifier of the iOS app; the API key only accepts requests carrying it."
  type        = string
  default     = "blc.LucidBoard"
}
