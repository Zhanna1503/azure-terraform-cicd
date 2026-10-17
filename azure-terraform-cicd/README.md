# Azure Terraform CI/CD – Portfolio Project

A small but production-style CI/CD setup: **Terraform** provisions an Azure static website, and a
**multi-stage Azure Pipelines YAML pipeline** validates, plans and deploys it to `dev` and `prod`,
with a **manual approval gate** before production.

```
 PR to main ──► Validate ──► Plan dev                     (preview only, nothing deployed)

 Push to main ─► Validate ──► Plan dev ──► Deploy dev ──► Plan prod ──► [Approval] ──► Deploy prod
```

## What this project demonstrates

| Practice | Where |
|---|---|
| Pipeline as code (multi-stage YAML) | `pipelines/azure-pipelines.yml` |
| Reusable stage & step templates (one definition for all environments) | `pipelines/templates/` |
| Infrastructure as Code with remote state | `infra/`, `scripts/bootstrap-state.sh` |
| Secretless auth via workload identity federation (OIDC) | `scripts/tf.sh`, `infra/providers.tf` |
| Plan on PR, apply the *saved* plan after review | `environment-stages.yml` |
| Approval gate on production | Azure DevOps environment `prod` |
| Quality & security gates: `fmt`, `validate`, Checkov scan with test results | `terraform-validate.yml` |
| Skip apply when nothing changed (`-detailed-exitcode`) | `scripts/tf.sh` |
| Environment-specific config | `infra/env/*.tfvars` |

## Repository layout

```
infra/                 Terraform: resource group + storage account with static website
  env/dev.tfvars       per-environment values
  env/prod.tfvars
pipelines/
  azure-pipelines.yml  entry point
  templates/
    terraform-validate.yml   fmt, validate, Checkov
    environment-stages.yml   Plan + Deploy stages, reused for dev and prod
    deploy-website.yml       uploads website/ to the storage account
scripts/
  tf.sh                same Terraform commands locally and in the pipeline
  bootstrap-state.sh   one-time creation of the state storage account
website/index.html     the deployed page (shows environment, build, commit)
```

## Setup (about 30–45 minutes)

### 1. Free accounts
- **Azure free account:** https://azure.microsoft.com/free (credit card needed for verification)
- **Azure DevOps organization:** https://dev.azure.com (free for up to 5 users)
- **Free pipeline minutes for a new org:** Microsoft-hosted agents must be requested once via
  https://aka.ms/azpipelines-parallelism-request. Approval can take a few business days, so do this first.

### 2. Create the Terraform state storage
```bash
az login
./scripts/bootstrap-state.sh st<yourname>tfstate     # must be globally unique
```
Put the printed values into the `variables:` block of `pipelines/azure-pipelines.yml`.

### 3. Service connection (no secrets)
Azure DevOps → **Project settings → Service connections → New → Azure Resource Manager →
Workload identity federation (automatic)**, scope: your subscription.
Name it `sc-azure-portfolio` (or change `serviceConnection` in the pipeline).

The connection gets *Contributor* automatically. Also give its identity **Storage Blob Data Contributor**
on the subscription (needed for state access and website upload with Entra ID instead of keys):

Azure Portal → Subscription → Access control (IAM) → Add role assignment →
*Storage Blob Data Contributor* → select the service connection's app (named after your DevOps org/project).

### 4. Environments & approval
Azure DevOps → **Pipelines → Environments**: create `dev` and `prod`.
On `prod`: **⋯ → Approvals and checks → Approvals** → add yourself.

### 5. Push code & create the pipeline
```bash
git init && git add . && git commit -m "Initial CI/CD setup"
git remote add origin https://dev.azure.com/<org>/<project>/_git/<repo>
git push -u origin main
```
**Pipelines → New pipeline → Azure Repos Git → your repo → Existing YAML file →
`/pipelines/azure-pipelines.yml`** → Run.

### 6. Protect `main` (shows the PR flow)
**Repos → Branches → main → Branch policies:** require 1 reviewer (allow self-approval for a solo
project) and add **Build validation** with this pipeline. Now every PR shows the Terraform plan before merge.

## Try it out
1. Create a branch, change something in `website/index.html` or `infra/` (e.g. add a tag).
2. Open a pull request → pipeline runs Validate + Plan dev. Check the plan output.
3. Merge → dev is deployed automatically, prod waits for your approval.
4. Open the URL printed in the "Upload website" step.

## Costs & cleanup
A storage-account static website costs a few cents per month. To remove everything:
```bash
az group delete -n rg-cicddemo-dev --yes
az group delete -n rg-cicddemo-prod --yes
az group delete -n rg-tfstate --yes
```

## Ideas to extend
- Add `tflint` and fix Checkov findings, then make the scan blocking
- Add a Function App or Azure SQL and a smoke test after deployment
- Port the same pipeline to GitHub Actions and compare
- Add drift detection: a scheduled pipeline running `terraform plan` nightly
