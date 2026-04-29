# gcp-startup-stack

> **Demo repo by [Shobhit Systems](https://shobhitsystems.com)** — a complete, production-ready GCP stack deployed with a single `terraform apply`.

This is the showpiece demo. One command deploys everything a funded startup needs to run on Google Cloud — securely, with full CI/CD, ready to scale.

**What this deploys (9 components):**

| Component | What it is |
|---|---|
| VPC | Private subnet, Cloud NAT, Cloud Router, VPC connector for Cloud Run |
| Cloud Run | The sample app — publicly accessible, auto-scales 0→10 instances |
| Cloud SQL PostgreSQL 15 | Private IP only (no public endpoint), automated backups, PITR |
| Artifact Registry | Docker image repository with auto-cleanup policies |
| Secret Manager | DB password + API key — injected into Cloud Run at startup, no `.env` files |
| IAM | 3 least-privilege service accounts: `app`, `deployer`, `terraform` |
| Workload Identity Federation | GitHub Actions authenticates to GCP with zero stored keys |
| Budget alerts | Email notifications at 50%, 80%, 100% of monthly spend |

**Time to deploy: ~12 minutes**
(Cloud SQL takes the longest — ~8 min to provision)

---

## The demo in 60 seconds

```bash
git clone https://github.com/shobhit-systems/gcp-startup-stack
cd gcp-startup-stack
cp terraform.tfvars.example terraform.tfvars
# fill in project_id, github_org, github_repo
terraform init && terraform apply
# → opens a live URL showing all 9 components active
# → prints GitHub secrets to add for CI/CD
```

---

## Prerequisites

- Terraform >= 1.5.0 (`brew install terraform` or https://developer.hashicorp.com/terraform/install)
- `gcloud` CLI installed and authenticated:
  ```bash
  gcloud auth application-default login
  ```
- A GCP project with billing enabled
- A GitHub repository (for Workload Identity + Cloud Build trigger)

Enable APIs (one-time, ~60 seconds):
```bash
gcloud services enable \
  compute.googleapis.com container.googleapis.com run.googleapis.com \
  cloudbuild.googleapis.com artifactregistry.googleapis.com sqladmin.googleapis.com \
  secretmanager.googleapis.com servicenetworking.googleapis.com \
  iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com \
  monitoring.googleapis.com logging.googleapis.com billingbudgets.googleapis.com \
  --project=YOUR_PROJECT_ID
```

---

## Deploy step by step

### Step 1 — Configure

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
project_id  = "your-gcp-project-id"    # must already exist
region      = "asia-south1"             # Mumbai — change if needed
env         = "demo"
github_org  = "your-github-username"   # or org name
github_repo = "your-repo-name"
```

### Step 2 — Deploy

```bash
terraform init
terraform plan   # review what will be created
terraform apply  # type "yes" — takes ~12 minutes
```

**Resources created in order:**
1. All required APIs enabled (60s)
2. VPC, subnet, Cloud Router, Cloud NAT, VPC connector
3. VPC peering for Cloud SQL private IP
4. 3 service accounts + IAM bindings + Workload Identity pool
5. Cloud SQL PostgreSQL (takes ~8 min)
6. 3 secrets in Secret Manager (DB password, DB URL, API key)
7. Artifact Registry repository
8. Cloud Run service (starts with placeholder image)

### Step 3 — View the live app

```bash
terraform output app_url
# Opens something like: https://demo-app-abc123-uc.a.run.app
```

Visit that URL — you'll see a dashboard showing all 9 deployed components with live data (environment, revision, masked secrets loaded from Secret Manager).

### Step 4 — Set up CI/CD

```bash
terraform output
```

Add these to GitHub → **Settings → Secrets and variables → Actions**:

| Secret | Value from `terraform output` |
|---|---|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `workload_identity_provider` |
| `GCP_SERVICE_ACCOUNT` | `deployer_sa_email` |
| `GCP_PROJECT_ID` | your project ID |
| `GCP_REGION` | `asia-south1` |

### Step 5 — Trigger your first automated deploy

```bash
# Make a visible change so you can confirm it went live
sed -i 's/live demo/v2 — deployed by Cloud Build/' sample-app/server.js
git add -A && git commit -m "feat: trigger first automated deploy"
git push origin main
```

Watch it build:
```
https://console.cloud.google.com/cloud-build/builds?project=YOUR_PROJECT_ID
```

---

## Module reference

```
gcp-startup-stack/
├── main.tf                        ← wires all modules, enables APIs, budget alert
├── variables.tf                   ← project_id, region, env, github_org, github_repo
├── outputs.tf                     ← app_url, workload_identity_provider, summary
├── modules/
    ├── foundation/                ← VPC, subnet, NAT, VPC peering, VPC connector
    ├── iam/                       ← 3 SAs, IAM bindings, WIF pool + provider
    ├── data/                      ← Cloud SQL PostgreSQL + 3 Secret Manager secrets
    ├── compute/                   ← Artifact Registry + Cloud Run service
    └── cicd/                      ← Cloud Build trigger


```

---

## Variable reference

| Variable | Required | Default | Description |
|---|---|---|---|
| `project_id` | yes | — | GCP project ID (must already exist) |
| `region` | no | `asia-south1` | GCP region for all resources |
| `env` | no | `demo` | Label prefix on all resources |
| `github_org` | yes | — | GitHub org or username |
| `github_repo` | yes | — | GitHub repo name |
| `billing_account_id` | no | `""` | Billing account for budget alerts (skip if not available) |
| `monthly_budget_usd` | no | `100` | Monthly budget threshold in USD |

---

## What we will show on a demo call 

**Script (15 minutes):**

1. **(2 min)** Show `terraform plan` output — walk through the 9 components being created side by side with the existing setup (probably: nothing, or a manually-configured mess)

2. **(8 min)** Run `terraform apply` — walk though each resource does while it's creating. The Cloud SQL provisioning with explaination why private IP matters, why Secret Manager beats `.env` files, why Workload Identity is better than JSON keys.

3. **(2 min)** The live URL — dashboard with real env, revision, and masked secrets loaded live from Secret Manager. *"This is running right now on Google Cloud account."*

4. **(2 min)** With a 1-line code change, `git push`, the Cloud Build pipeline firing automatically. *"Every future deploy looks like this — tested, scanned, rolled back automatically if something breaks."*

5. **(1 min)** `terraform destroy` — everything gone in 3 minutes.*"And this is fully reproducible. Any environment, any time."*
   
---

## Estimated monthly cost (demo usage)

| Resource | ~Cost/month |
|---|---|
| Cloud Run (minimal traffic) | $0–2 |
| Cloud SQL `db-f1-micro` | ~$7 |
| Artifact Registry (< 1 GB) | ~$0.10 |
| Cloud NAT | ~$1 |
| Secret Manager | ~$0.06 |
| **Total** | **~$10–12/month** |

For a real client environment: Cloud SQL tier upgrade + multiple Cloud Run services = $50–200/month depending on traffic.

---
## Teardown

```bash
terraform destroy   # removes all resources — type "yes"
# takes ~5 minutes
# Cloud SQL deletion takes longest — protection is disabled for demo
```

---

> Built by [Shobhit Systems](https://shobhitsystems.com) — GCP consulting for startups and small companies.
> Book a free 30-min GCP audit: **hello@shobhitsystems.com**
