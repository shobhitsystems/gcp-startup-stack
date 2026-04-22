# gcp-startup-stack

> Production-ready GCP infrastructure for startups — one `terraform apply`, ~12 minutes, zero ClickOps.

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-7B42BC?logo=terraform&logoColor=white)](https://developer.hashicorp.com/terraform)
[![Google Cloud](https://img.shields.io/badge/Google_Cloud-5.x-4285F4?logo=googlecloud&logoColor=white)](https://registry.terraform.io/providers/hashicorp/google/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-00d4aa.svg)](LICENSE)

This stack deploys a complete, production-grade GCP foundation from scratch — VPC with private networking, Cloud Run, Cloud SQL with private IP, Artifact Registry, Secret Manager, Workload Identity Federation for keyless CI/CD, Cloud Build pipelines, and full observability with budget alerts. Everything is in Terraform. No manual console steps.

---

## Architecture

![GCP Startup Stack Architecture](architecture.svg)

**9 components deployed in a single apply:**

| Module | What it creates |
|---|---|
| `foundation` | Custom VPC · private subnets · Cloud NAT · Cloud Router · firewall rules |
| `iam` | App service account · CI/CD service account · Workload Identity Pool (OIDC) |
| `data` | Cloud SQL PostgreSQL (private IP, PITR) · Secret Manager secrets · PSC endpoint |
| `compute` | Artifact Registry (Docker) · Cloud Run service (autoscaling, VPC-connected) |
| `cicd` | Cloud Build trigger · build pipeline (test → Trivy scan → push → deploy → smoke test) |
| `observability` | Budget alerts (50/80/100%) · Cloud Monitoring · Cloud Logging sink · uptime checks |

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) authenticated and configured
- A GCP project with billing enabled
- A GitHub repository to connect CI/CD to

---

## Quick start

```bash
# 1. Clone
git clone https://github.com/shobhitsystems/gcp-startup-stack.git
cd gcp-startup-stack

# 2. Copy and fill in variables
cp terraform.tfvars.example terraform.tfvars

# 3. Create a GCS bucket for Terraform state (one-time)
gcloud storage buckets create gs://YOUR_PROJECT_ID-tfstate \
  --location=asia-south1 \
  --uniform-bucket-level-access

# 4. Authenticate
gcloud auth application-default login

# 5. Init, plan, apply
terraform init
terraform plan
terraform apply
```

Total time: ~12 minutes. Grab a coffee.

---

## Variables

Copy `terraform.tfvars.example` to `terraform.tfvars` and set:

```hcl
# Required
project_id          = "your-gcp-project-id"
region              = "asia-south1"           # or us-central1, europe-west2, etc.
env                 = "prod"
github_org          = "your-github-org"
github_repo         = "your-app-repo"
github_owner        = "your-github-username"
billing_account_id  = "XXXXXX-XXXXXX-XXXXXX"

# Optional
monthly_budget_usd  = 500                     # default: 500
```

**Region options:** `asia-south1` (Mumbai) · `us-central1` (Iowa) · `us-east4` (Virginia) · `europe-west2` (London) · `europe-west3` (Frankfurt) · `asia-southeast1` (Singapore)

---

## What gets deployed

### Networking — `modules/foundation`
- Custom VPC (`10.0.0.0/16`) — no default network used
- Private subnet (`10.0.1.0/24`) for application workloads
- PSA subnet (`10.0.2.0/24`) for Cloud SQL private service access
- Cloud NAT + Cloud Router for outbound egress
- Firewall rules: deny-all default, allow only necessary ingress/egress

### Identity & Access — `modules/iam`
- **app-sa** — service account for Cloud Run with least-privilege roles only (Secret Manager accessor, Cloud SQL client, Trace agent)
- **cicd-sa** — service account for Cloud Build (Artifact Registry writer, Cloud Run developer)
- **Workload Identity Federation pool** — GitHub OIDC provider configured so GitHub Actions authenticates to GCP using short-lived tokens. Zero stored JSON keys.

### Data — `modules/data`
- Cloud SQL PostgreSQL 15 — **private IP only**, no public endpoint, connected via Private Service Connect
- Point-in-time recovery (PITR) enabled
- Automated daily backups with 7-day retention
- Secret Manager secrets for `db-password` and `api-key` — IAM-controlled access, no plaintext env vars

### Compute — `modules/compute`
- Artifact Registry Docker repository (`asia-south1`)
- Cloud Run service with VPC connector (accesses Cloud SQL via private IP)
- Autoscaling from 0 to N instances
- Environment variables sourced from Secret Manager (no plaintext values in config)
- HTTPS endpoint with managed TLS certificate

### CI/CD — `modules/cicd`
- Cloud Build trigger on push to `main` branch
- Six-stage pipeline: `test → trivy-scan → docker-build → push → deploy → smoke-test`
- Auto-rollback on failed smoke test
- Trivy container image vulnerability scanning — build fails on HIGH/CRITICAL CVEs
- All authentication via Workload Identity Federation — no service account keys in GitHub Secrets

### Observability
- Billing budget with email alerts at 50%, 80%, and 100% of monthly limit
- Cloud Monitoring uptime checks on the Cloud Run endpoint
- Cloud Logging sink with configurable retention
- Cloud Trace enabled for distributed tracing

---

## Outputs

After `terraform apply` completes:

```
app_url            = "https://your-service-xxxx.run.app"
registry_host      = "asia-south1-docker.pkg.dev/your-project/app"
db_instance_name   = "your-project-prod-postgres"
wif_provider       = "projects/123/locations/global/workloadIdentityPools/..."
```

---

## CI/CD: connecting GitHub Actions

The Workload Identity Federation pool is created automatically. Add these to your GitHub Actions workflow:

```yaml
- name: Authenticate to GCP
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ secrets.WIF_PROVIDER }}   # from terraform output
    service_account: ${{ secrets.CICD_SA_EMAIL }}             # from terraform output
```

No `GOOGLE_CREDENTIALS` JSON secret needed. Keyless auth.

---

## File structure

```
gcp-startup-stack/
├── main.tf                    # Root: module wiring + API enablement + budget
├── variables.tf               # All input variables with descriptions
├── outputs.tf                 # Key outputs after apply
├── terraform.tfvars.example   # Template — copy to terraform.tfvars
├── modules/
│   ├── foundation/            # VPC, subnets, NAT, firewall
│   ├── iam/                   # Service accounts, WIF pool
│   ├── data/                  # Cloud SQL, Secret Manager
│   ├── compute/               # Artifact Registry, Cloud Run
│   └── cicd/                  # Cloud Build trigger + pipeline
├── sample-app/                # Minimal Node.js app to test the stack end-to-end
└── .github/workflows/
    └── deploy.yml             # GitHub Actions workflow using WIF
```

---

## Tear down

```bash
terraform destroy
```

Note: the GCS state bucket is not managed by Terraform — delete it manually after destroy if no longer needed.

---

## Related repos

| Repo | What it covers |
|---|---|
| [gcp-iam-baseline](https://github.com/shobhitsystems/gcp-iam-baseline) | Standalone IAM + WIF + Secret Manager — faster if you only need the security baseline |
| [gcp-artifact-registry-cicd](https://github.com/shobhitsystems/gcp-artifact-registry-cicd) | Full Cloud Build CI/CD pipeline with Trivy scanning |
| [gcp-private-gke-autopilot](https://github.com/shobhitsystems/gcp-private-gke-autopilot) | Private GKE Autopilot cluster with WIF, HPA, PDB, NetworkPolicy |
| [gcp-cloudbuild-pipelines](https://github.com/shobhitsystems/gcp-cloudbuild-pipelines) | Cloud Build-only pipelines for Node.js and Python |

---

## Need help?

Built and maintained by [Shobhit Systems](https://shobhitsystems.com) — GCP cloud infrastructure for startups.

- 🌐 [shobhitsystems.com](https://shobhitsystems.com)
- 📧 [hello@shobhitsystems.com](mailto:hello@shobhitsystems.com)
- 💬 [WhatsApp +91 70455 29476](https://wa.me/917045529476)

If this saved you hours of setup, consider starring the repo. ⭐

---

## License

MIT — use freely in commercial and personal projects.
