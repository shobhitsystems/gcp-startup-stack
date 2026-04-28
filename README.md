# gcp-startup-stack

A production-ready Terraform stack for startups launching on GCP. One `terraform apply` deploys Cloud Run, Cloud SQL, Artifact Registry, Secret Manager, Workload Identity Federation, VPC, IAM, Cloud Build CI/CD, and budget alerts — all wired together and following least-privilege principles.

---

## What gets deployed

| Module | Resources |
|--------|-----------|
| `modules/foundation` | VPC, private subnet, Cloud Router, Cloud NAT, VPC connector |
| `modules/iam` | 3 service accounts (`app`, `deployer`, `terraform`), IAM bindings, Workload Identity Federation pool + provider |
| `modules/data` | Cloud SQL PostgreSQL (private IP only, no public endpoint), Secret Manager secrets (DB password, DB URL, API key) |
| `modules/compute` | Artifact Registry repository, Cloud Run service |
| `modules/cicd` | Cloud Build trigger (fires on push to `main`) |
| `main.tf` (root) | All required APIs, billing budget alerts at 50% / 80% / 100% |

---

## Prerequisites

- Terraform >= 1.5.0
- `gcloud` CLI installed and authenticated:
  ```bash
  gcloud auth application-default login
  ```
- A GCP project with billing enabled (must already exist)
- A GitHub repository (used for Workload Identity + Cloud Build trigger)

---

## Quick start

### 1. Clone and configure

```bash
git clone https://github.com/shobhitsystems/gcp-startup-stack
cd gcp-startup-stack
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
project_id         = "your-gcp-project-id"
region             = "asia-south1"        # change if needed
env                = "demo"
github_org         = "your-github-username-or-org"
github_repo        = "your-repo-name"
billing_account_id = ""                   # optional — needed for budget alerts
monthly_budget_usd = 100
```

### 2. Connect GitHub to Cloud Build (one-time, in the GCP Console)

Cloud Build needs a GitHub connection before the Terraform trigger can reference it:

```
Cloud Build → Triggers → Connect Repository → GitHub → Authorize → select your repo → Done
```

### 3. Deploy

```bash
terraform init
terraform plan    # review what will be created
terraform apply   # type "yes" — takes ~12 minutes (Cloud SQL is the slowest)
```

### 4. Read the outputs

After apply completes, run:

```bash
terraform output
```

This prints a full deployment summary including:
- Live Cloud Run URL
- Artifact Registry path
- Cloud SQL connection name
- Workload Identity provider (for GitHub Actions)
- Deployer service account email

---

## Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `project_id` | yes | — | GCP project ID (must already exist with billing enabled) |
| `region` | no | `asia-south1` | Primary GCP region for all resources |
| `env` | no | `demo` | Label prefix applied to all resource names |
| `github_org` | yes | — | GitHub organisation name or username |
| `github_repo` | yes | — | GitHub repository name |
| `billing_account_id` | no | `""` | Billing account ID for budget alerts (format: `XXXXXX-XXXXXX-XXXXXX`) |
| `monthly_budget_usd` | no | `100` | Monthly budget threshold in USD |

---

## Outputs

| Output | Description |
|--------|-------------|
| `app_url` | Live URL of the Cloud Run service |
| `registry_path` | Artifact Registry Docker path |
| `db_connection_name` | Cloud SQL connection name |
| `workload_identity_provider` | WIF provider string (use as GitHub secret) |
| `deployer_sa_email` | Deployer service account email (use as GitHub secret) |
| `app_sa_email` | App service account email (attached to Cloud Run) |
| `summary` | Full human-readable deployment summary |

---

## CI/CD pipeline (`sample-app/cloudbuild.yaml`)

The Cloud Build trigger fires on every push to `main` and runs 6 steps:

```
push to main
    │
    ▼
[1] npm test          ← unit tests (test.js)
    │
    ▼
[2] docker build      ← tagged :SHA and :latest
    │
    ▼
[3] trivy scan        ← blocks on CRITICAL CVEs
    │
    ▼
[4] docker push       ← to Artifact Registry
    │
    ▼
[5] cloud run deploy  ← new revision, 0% traffic (canary tag)
    │
    ├── smoke test passes → migrate 100% traffic ✓
    │
    └── smoke test fails  → remove canary tag, old revision stays live ✗
```

---

## Module structure

```
gcp-startup-stack/
├── main.tf                  ← wires all modules, enables APIs, budget alert
├── variables.tf             ← input variables
├── outputs.tf               ← app_url, WIF provider, summary, etc.
├── terraform.tfvars.example ← copy to terraform.tfvars and fill in
├── modules/
│   ├── foundation/          ← VPC, subnet, NAT, VPC connector
│   ├── iam/                 ← service accounts, IAM bindings, WIF
│   ├── data/                ← Cloud SQL PostgreSQL, Secret Manager
│   ├── compute/             ← Artifact Registry, Cloud Run
│   └── cicd/                ← Cloud Build trigger
└── sample-app/
    ├── server.js            ← Node.js demo app
    ├── test.js              ← unit tests (run by Cloud Build step 1)
    ├── package.json
    ├── Dockerfile
    └── cloudbuild.yaml      ← 6-step pipeline (see above)
```

---

## Estimated monthly cost

| Resource | ~Cost/month |
|----------|------------|
| Cloud Run (low traffic) | $0–2 |
| Cloud SQL `db-f1-micro` | ~$7 |
| Artifact Registry (< 1 GB) | ~$0.10 |
| Cloud NAT | ~$1 |
| Secret Manager | ~$0.06 |
| Cloud Build (120 free min/day) | $0 |
| **Total** | **~$10–12/month** |

---

## Teardown

```bash
terraform destroy   # type "yes" — takes ~5 minutes
```

> Cloud SQL deletion protection is disabled for this demo stack so `terraform destroy` completes cleanly.

---

Built by [Shobhit Systems](https://shobhitsystems.com) — GCP consulting for startups.
