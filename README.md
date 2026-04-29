# gcp-startup-stack

> **One command. Eight components. Production-ready GCP infrastructure for startups.**

Deploy a complete Google Cloud stack with a single `terraform apply` — Cloud Run, Cloud SQL, Secret Manager, Workload Identity Federation, VPC, IAM, and more, all wired together out of the box. CI/CD via GitHub Actions.

[![Terraform](https://img.shields.io/badge/Terraform-≥1.5.0-7B42BC?logo=terraform)](https://developer.hashicorp.com/terraform/install)
[![GCP](https://img.shields.io/badge/Google_Cloud-Ready-4285F4?logo=google-cloud)](https://cloud.google.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## What gets deployed

| Component | Details |
|---|---|
| **VPC** | Private subnet, Cloud NAT, Cloud Router, VPC connector for Cloud Run |
| **Cloud Run** | Publicly accessible, auto-scales 0 → 10 instances |
| **Cloud SQL (PostgreSQL 15)** | Private IP only — no public endpoint, automated backups, PITR |
| **Artifact Registry** | Docker image repo with auto-cleanup policies |
| **Secret Manager** | DB password + API key — injected into Cloud Run at startup, zero `.env` files |
| **IAM** | 3 least-privilege service accounts: `app`, `deployer`, `terraform` |
| **Workload Identity Federation** | GitHub Actions authenticates to GCP — zero stored JSON keys |
| **Budget alerts** | Email notifications at 50%, 80%, 100% of monthly spend |

**Deploy time: ~12 minutes** (Cloud SQL takes ~8 min to provision)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  GitHub                                                      │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  GitHub Actions                                      │   │
│  │  .github/workflows/deploy.yml                        │   │
│  │                                                      │   │
│  │  on: push to main                                    │   │
│  │    1. Authenticate via WIF (no stored keys)          │   │
│  │                                                      │
│  │    2. deploy → using Terraform                             │
│  └──────────────┬───────────────────────────────────────┘   │
│                 │ Workload Identity Federation               │
└─────────────────┼───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│  GCP Project                                                │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  module: iam                                          │  │
│  │  • app SA  • deployer SA  • WIF pool + provider       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  module: compute                                      │  │
│  │  • Artifact Registry   • Cloud Run (public HTTPS)     │  │
│  └────────────────────┬─────────────────────────────────┘  │
│                       │ private VPC                         │
│  ┌────────────────────▼─────────────────────────────────┐  │
│  │  module: foundation                                   │  │
│  │  • VPC  • Private subnet  • Cloud NAT  • Cloud Router │  │
│  │  • VPC connector (Cloud Run ↔ Cloud SQL)              │  │
│  └────────────────────┬─────────────────────────────────┘  │
│                       │                                     │
│  ┌────────────────────▼─────────────────────────────────┐  │
│  │  module: data                                         │  │
│  │  • Cloud SQL PostgreSQL 15  (private IP only)         │  │
│  │  • Secret Manager  (DB password, DB URL, API key)     │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  Budget alerts: 50% / 80% / 100%                           │
└─────────────────────────────────────────────────────────────┘
```

---

## Quick start

```bash
git clone https://github.com/shobhitsystems/gcp-startup-stack
cd gcp-startup-stack

cp terraform.tfvars.example terraform.tfvars
# fill in: project_id, github_org, github_repo

terraform init \
  -backend-config="bucket=YOUR_TF_STATE_BUCKET" \
  -backend-config="prefix=gcp-startup-stack"

terraform apply   # ~12 minutes
```

After deploy:

```bash
terraform output app_url     # live Cloud Run URL
terraform output summary     # full summary + GitHub secrets to add
```

---

## Prerequisites

- **Terraform >= 1.5.0** — [install](https://developer.hashicorp.com/terraform/install)
- **gcloud CLI** authenticated:
  ```bash
  gcloud auth application-default login
  ```
- A **GCP project** with billing enabled
- A **GCS bucket** for Terraform remote state
- A **GitHub repository** (for Workload Identity + GitHub Actions)

**Enable APIs** (one-time, ~60 seconds):

```bash
gcloud services enable \
  compute.googleapis.com run.googleapis.com \
  artifactregistry.googleapis.com sqladmin.googleapis.com \
  secretmanager.googleapis.com servicenetworking.googleapis.com \
  iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com \
  monitoring.googleapis.com billingbudgets.googleapis.com \
  --project=YOUR_PROJECT_ID
```

**Create Terraform state bucket** (one-time):

```bash
gcloud storage buckets create gs://YOUR_TF_STATE_BUCKET \
  --project=YOUR_PROJECT_ID \
  --location=asia-south1 \
  --uniform-bucket-level-access
```

---

## Deploy step by step

### 1. Configure

```bash
cp terraform.tfvars.example terraform.tfvars
```

```hcl
project_id  = "your-gcp-project-id"
region      = "asia-south1"
env         = "demo"
github_org  = "your-github-username"
github_repo = "your-repo-name"
```

### 2. Configure GitHub Actions

Run `terraform output summary` and add these to **GitHub → Settings → Secrets → Actions**:

| Secret | Value |
|---|---|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | from `terraform output workload_identity_provider` |
| `GCP_SERVICE_ACCOUNT` | from `terraform output deployer_sa_email` |
| `GCP_PROJECT_ID` | your project ID |
| `GCP_REGION` | `asia-south1` |
| `TF_STATE_BUCKET` | your GCS bucket name |


### 3. Trigger your first deploy

Push any change to `main` — GitHub Actions will authenticate via Workload Identity Federation, build and push the Docker image to Artifact Registry, and deploy to Cloud Run automatically.

Watch the run at:
```
https://github.com/YOUR_ORG/YOUR_REPO/actions
```

---

## Repository structure

```
gcp-startup-stack/
├── main.tf                        # wires all modules, enables APIs, budget alert
├── variables.tf                   # input variables
├── outputs.tf                     # app_url, WIF values, deploy summary
├── terraform.tfvars.example       # copy → terraform.tfvars and fill in
│
├── .github/
│   └── workflows/
│       └── deploy.yml             # GitHub Actions: WIF auth → build → push → deploy
│
└── modules/
    ├── foundation/                # VPC, subnet, Cloud NAT, Cloud Router, VPC connector
    ├── iam/                       # 3 service accounts, IAM bindings, WIF pool + provider
    ├── data/                      # Cloud SQL PostgreSQL + Secret Manager secrets
    └── compute/                   # Artifact Registry + Cloud Run service
```

---

## Variable reference

| Variable | Required | Default | Description |
|---|---|---|---|
| `project_id` | yes | — | GCP project ID (must already exist) |
| `region` | no | `asia-south1` | GCP region for all resources |
| `env` | no | `demo` | Label prefix applied to all resources |
| `github_org` | yes | — | GitHub org name or username |
| `github_repo` | yes | — | GitHub repository name |
| `billing_account_id` | no | `""` | Billing account for budget alerts (leave blank to skip) |
| `monthly_budget_usd` | no | `100` | Monthly budget threshold in USD |

---

## Estimated monthly cost

| Resource | ~Cost/month |
|---|---|
| Cloud Run (minimal traffic) | $0–2 |
| Cloud SQL `db-f1-micro` | ~$7 |
| Artifact Registry (< 1 GB) | ~$0.10 |
| Cloud NAT | ~$1 |
| Secret Manager | ~$0.06 |
| **Total** | **~$10–12/month** |

---

## Troubleshooting

**`Error 403` on API calls**
→ Run the `gcloud services enable ...` command in prerequisites.

**Cloud SQL times out during apply**
→ Re-run `terraform apply` — it's idempotent. Cloud SQL can take up to 10 minutes.

**Cloud Run returns 403**
→ Make the service public:
```bash
gcloud run services add-iam-policy-binding demo-app \
  --region=asia-south1 --member=allUsers --role=roles/run.invoker
```

**GitHub Actions: `Error: google-github-actions/auth failed`**
→ Check that `GCP_WORKLOAD_IDENTITY_PROVIDER` and `GCP_SERVICE_ACCOUNT` match exactly what `terraform output` printed. A trailing space will break it.

---

## Teardown

```bash
terraform destroy   # removes all resources — type "yes" (~5 minutes)
```

---

> Built by [Shobhit Systems](https://shobhitsystems.com) — GCP consulting for startups.
> Book a free 30-min GCP audit: **[hello@shobhitsystems.com](mailto:hello@shobhitsystems.com)**
