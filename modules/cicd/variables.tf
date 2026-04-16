variable "project_id"        { type = string }
variable "region"            { type = string }
variable "env"               { type = string }
variable "registry_host"     { type = string }
variable "cloud_run_service" { type = string }
variable "github_owner"      { type = string; default = "" }
variable "github_repo"       { type = string; default = "" }
