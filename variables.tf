variable "project_id" {
  description = "GCP project ID — must already exist with billing enabled"
  type        = string
}

variable "region" {
  description = "Primary GCP region"
  type        = string
  default     = "asia-south1"
}

variable "env" {
  description = "Environment label applied to all resources"
  type        = string
  default     = "demo"
}

variable "github_org" {
  description = "GitHub organisation name for Workload Identity + Cloud Build trigger"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "billing_account_id" {
  description = "GCP Billing Account ID for budget alerts (format: XXXXXX-XXXXXX-XXXXXX)"
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Monthly budget in USD — alerts at 50%, 80%, 100%"
  type        = number
  default     = 100
}
