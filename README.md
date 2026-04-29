# gcp-startup-stack

> **One command. Eight components. Production-ready GCP infrastructure for startups.**

Deploy a complete, battle-hardened Google Cloud stack with a single `terraform apply` — Cloud Run, Cloud SQL, Secret Manager, Workload Identity Federation, VPC, IAM, and more, all wired up out of the box.

[![Terraform](https://img.shields.io/badge/Terraform-≥1.5.0-7B42BC?logo=terraform)](https://developer.hashicorp.com/terraform/install)
[![GCP](https://img.shields.io/badge/Google_Cloud-Ready-4285F4?logo=google-cloud)](https://cloud.google.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## What gets deployed

| Component | Details |
|---|---|
| **VPC** | Private subnet, Cloud NAT, Cloud Router, VPC connector for Cloud Run |
| **Cloud Run** | Sample app — publicly accessible, auto-scales 0 → 10 instances |
| **Cloud SQL (PostgreSQL 15)** | Private IP only (no public endpoint), automated backups, PITR enabled |
| **Artifact Registry** | Docker image repo with auto-cleanup policies |
| **Secret Manager** | DB password + API key — injected into Cloud Run at startup, zero `.env` files |
| **IAM** | 3 least-privilege service accounts: `app`, `deployer`, `terraform` |
| **Workload Identity Federation** | GitHub Actions authenticates to GCP with zero stored keys |
| **Budget alerts** | Email at 50%, 80%, 100% of monthly spend |

**Deploy time: ~12 minutes** (Cloud SQL provisioning takes ~8 min)

> **CI/CD note:** Cloud Build trigger is intentionally excluded for now — deploy your app manually after `terraform apply` using the commands printed in `terraform output summary`. Cloud Build can be wired in as a next step once the base infrastructure is confirmed stable.

---

## Architecture

```
GitHub Actions
     │  (WIF — no stored keys)
     ▼
  gcloud / docker CLI
     │
     ├──► Artifact Registry  (docker push)
     │
     └──► Cloud Run  ◄── Public HTTPS
               │
        ┌──────┴──────┐
        ▼             ▼
    Cloud SQL    Secret Manager
   (private IP)  (DB pwd, API key)

All compute resources sit inside a private VPC.
```

---

## Quick start

```bash
git clone https://github.com/shobhitsystems/gcp-startup-stack
cd gcp-startup-stack

cp terraform.tfvars.example terraform.tfvars
# edit: project_id, github_org, github_repo

terraform init
terraform apply   # ~12 minutes — type "yes" when prompted
```

After deploy:

```bash
terraform output app_url      # live URL of the Cloud Run service
terraform output summary      # full deploy summary + manual deploy commands
```

---

## Prerequisites

- **Terraform >= 1.5.0** — [install](https://developer.hashicorp.com/terraform/install)
- **gcloud CLI** authenticated:
  ```bash
  gcloud auth application-default login
  ```
- A **GCP project** with billing enabled
- A **GitHub account** (for Workload Identity)

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

---

## Step-by-step deploy

### 1. Configure

```bash
cp terraform.tfvars.example terraform.tfvars
```

```hcl
project_id  = "your-gcp-project-id"
region      = "asia-south1"    # Mumbai — change if needed
env         = "demo"
github_org  = "your-github-username"
github_repo = "your-repo-name"
```

### 2. Deploy infrastructure

```bash
terraform init
terraform plan    # review what will be created
terraform apply   # type "yes" — takes ~12 minutes
```

Resources are created in this order:
1. VPC, subnet, Cloud NAT, Cloud Router, VPC connector
2. VPC peering for Cloud SQL private IP
3. 3 service accounts + IAM bindings + Workload Identity pool
4. Cloud SQL PostgreSQL (~8 min)
5. Secrets in Secret Manager (DB password, DB URL, API key)
6. Artifact Registry repository
7. Cloud Run service

### 3. Deploy the sample app

Run the commands printed by `terraform output summary`:

```bash
# Authenticate Docker to Artifact Registry
gcloud auth configure-docker asia-south1-docker.pkg.dev

# Build and push
docker build -t asia-south1-docker.pkg.dev/YOUR_PROJECT/demo-images/app:latest ./sample-app
docker push asia-south1-docker.pkg.dev/YOUR_PROJECT/demo-images/app:latest

# Deploy to Cloud Run
gcloud run deploy demo-app \
  --image=asia-south1-docker.pkg.dev/YOUR_PROJECT/demo-images/app:latest \
  --region=asia-south1
```

### 4. Visit the live app

```bash
terraform output app_url
```

The URL opens a dashboard showing the environment, Cloud Run revision, and secrets loaded live from Secret Manager (masked).

---

## Repository structure

```
gcp-startup-stack/
├── main.tf                        # wires all modules, enables APIs, budget alert
├── variables.tf                   # project_id, region, env, github_org, github_repo
├── outputs.tf                     # app_url, deploy summary, WIF outputs
├── terraform.tfvars.example       # copy to terraform.tfvars and fill in
│
├── modules/
│   ├── foundation/                # VPC, subnet, NAT, VPC peering, VPC connector
│   ├── iam/                       # 3 service accounts, IAM bindings, WIF pool + provider
│   ├── data/                      # Cloud SQL PostgreSQL + 3 Secret Manager secrets
│   └── compute/                   # Artifact Registry + Cloud Run service
│
└── sample-app/
    ├── server.js                  # Node.js app — reads secrets, shows stack info
    ├── test.js                    # unit tests
    ├── package.json
    └── Dockerfile
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
→ Re-run `terraform apply` — it's idempotent. Cloud SQL can take up to 10 minutes to provision.

**Cloud Run returns 403 after deploy**
→ Make the service public:
```bash
gcloud run services add-iam-policy-binding demo-app \
  --region=asia-south1 --member=allUsers --role=roles/run.invoker
```

**`docker push` returns 403**
→ Run `gcloud auth configure-docker asia-south1-docker.pkg.dev` first.

---

## Teardown

```bash
terraform destroy   # removes all resources — type "yes"
# takes ~5 minutes
```

---

> Built by [Shobhit Systems](https://shobhitsystems.com) — GCP consulting for startups.
> Book a free 30-min GCP audit: **[hello@shobhitsystems.com](mailto:hello@shobhitsystems.com)**
