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
  description = "GitHub organisation name or username (for Workload Identity Federation)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (for Workload Identity Federation)"
  type        = string
}

variable "billing_account_id" {
  description = "GCP Billing Account ID for budget alerts (format: XXXXXX-XXXXXX-XXXXXX). Leave blank to skip budget alerts."
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Monthly budget in USD — alerts at 50%, 80%, 100%"
  type        = number
  default     = 100
}
