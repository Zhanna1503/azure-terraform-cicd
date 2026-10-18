# Azure Terraform CI/CD – Portfolio Project

[![CI/CD](https://github.com/Zhanna1503/azure-terraform-cicd/actions/workflows/pipeline.yml/badge.svg)](https://github.com/Zhanna1503/azure-terraform-cicd/actions/workflows/pipeline.yml)

A small but production-style CI/CD setup: **Terraform** builds a static website on Azure, and a
**GitHub Actions** pipeline checks, previews and deploys it to `dev` and `prod`, with a
**manual approval** before production. Runs at **€0**.

## How it works

```
Pull request to main ─► Check code ─► Preview dev                          (nothing changes in Azure)

Push to main ────────► Check code ─► Deploy dev ─► [your approval] ─► Deploy prod
```

- **Check code:** `terraform fmt` (formatting), `terraform validate` (syntax), Checkov (security scan)
- **Plan:** Terraform compares the code with what exists in Azure and shows what it would change.
  You find the plan on the run's summary page.
- **Apply:** Terraform creates or updates the resources, then the website is uploaded.
- **Approval:** the GitHub environment `prod` requires a reviewer, so the run pauses until you approve.

## What this project demonstrates

| Practice | Where |
|---|---|
| Pipeline as code (YAML) | `.github/workflows/pipeline.yml` |
| Reusable template, one definition for all environments | `.github/workflows/deploy-environment.yml` |
| Infrastructure as Code with remote state | `infra/` |
| Passwordless login to Azure (OIDC / workload identity federation) | `azure/login` + `ARM_USE_OIDC` |
| Plan before apply, preview on pull requests | `deploy-environment.yml` |
| Approval gate on production | GitHub environment `prod` |
| Quality and security checks | `terraform fmt`, `terraform validate`, Checkov |
| Environment-specific settings | `infra/env/*.tfvars` |

## Repository layout

```
.github/workflows/
  pipeline.yml             entry point: when the pipeline runs and in which order
  deploy-environment.yml   template: plan + deploy for one environment
infra/                     Terraform: resource group + storage account with static website
  env/dev.tfvars           settings per environment
  env/prod.tfvars
website/index.html         the deployed page (shows environment, build number and commit)
```

## Costs: €0

- GitHub Actions is free for public repositories.
- The Azure resources (tiny storage accounts) cost a few cents per month. That is covered by the
  credit of a Visual Studio subscription or the Azure free trial, and nothing is charged unless
  you upgrade to pay-as-you-go.

## Setup (about 30 minutes)

### 1. Pick an Azure subscription

Either one works, the pipeline doesn't care:

- a **Visual Studio subscription** with monthly Azure credit, or
- the **Azure free trial**: https://azure.microsoft.com/free (credit card only for identity
  verification; nothing is charged unless you upgrade).

In the Azure Portal, open **Subscriptions** and copy the **Subscription ID**.

### 2. Create a login for GitHub (app registration)

1. Azure Portal → **Microsoft Entra ID** → **App registrations** → **New registration**
2. Name: `github-azure-terraform-cicd` → **Register**
3. On the overview page, copy the **Application (client) ID** and the **Directory (tenant) ID**.

> If you get "You do not have permission", your organization blocks app registrations.
> Use the Azure free trial instead.

### 3. Let GitHub use this login without a password (federated credentials)

In the app registration → **Certificates & secrets** → **Federated credentials** → **Add credential**:

| Field | Value |
|---|---|
| Federated credential scenario | GitHub Actions deploying Azure resources |
| Organization | `Zhanna1503` |
| Repository | `azure-terraform-cicd` |
| Entity type | Environment |
| GitHub environment name | `dev` |
| Name | `github-dev` |

Click **Add**, then add a second one with environment name `prod` and name `github-prod`.
Azure now trusts short-lived tokens that GitHub issues for exactly this repository and environment.

### 4. Give the login permission on the subscription

**Subscriptions** → your subscription → **Access control (IAM)** → **Add** → **Add role assignment**
→ tab **Privileged administrator roles** → **Contributor** → **Next** → **Select members** →
search `github-azure-terraform-cicd` → **Select** → **Review + assign**.

### 5. Store the IDs in GitHub

Repository → **Settings** → **Secrets and variables** → **Actions**

Tab **Secrets** → **New repository secret** (three times):

| Name | Value |
|---|---|
| `AZURE_CLIENT_ID` | Application (client) ID from step 2 |
| `AZURE_TENANT_ID` | Directory (tenant) ID from step 2 |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID from step 1 |

Tab **Variables** → **New repository variable**:

| Name | Value |
|---|---|
| `TFSTATE_STORAGE_ACCOUNT` | a globally unique name, 3–24 lowercase letters and digits, e.g. `sttfstatezhanna4821` |

### 6. Create the environments

Repository → **Settings** → **Environments** → **New environment**:

- `dev` → **Configure environment** → nothing to set
- `prod` → tick **Required reviewers** → add yourself → **Save protection rules**

### 7. Run it

**Actions** tab → **CI/CD** → **Run workflow** (or push any change to `main`).

Watch the jobs turn green. When the run reaches **Prod**, click **Review deployments** → tick
`prod` → **Approve and deploy**. The website URL is on the run's summary page.

## Try it out

1. Create a branch, change the heading in `website/index.html` and open a pull request.
   The pipeline checks the code and shows a preview for dev.
2. Merge the pull request: dev is deployed, prod waits for your approval.
3. Open the website URL and check the environment, build number and commit.

## Troubleshooting

| Error | Fix |
|---|---|
| `Secret AZURE_... is missing` | Setup step 5 |
| `No matching federated identity record found` | Setup step 3: organization, repository and environment names must match exactly |
| `AuthorizationFailed` | Setup step 4 is missing, or wait about 5 minutes after assigning the role |
| `The storage account named ... is already taken` | Pick another `TFSTATE_STORAGE_ACCOUNT` |

## Clean up

- Delete the resource groups `rg-cicddemo-dev`, `rg-cicddemo-prod` and `rg-tfstate`,
  and the app registration `github-azure-terraform-cicd`.
- Using a subscription you will lose access to? Clean up before the access ends.
- The Azure free trial simply stops after 30 days; nothing is charged.
- The code stays here, so everything can be rebuilt in any subscription in minutes.

## Ideas to extend

- Port the same pipeline to Azure DevOps (Azure Pipelines) and compare
- Fix the Checkov findings, then make the scan blocking
- Switch storage access from account keys to Microsoft Entra ID only
- Add a smoke test that checks the website after each deployment
- Nightly drift detection: a scheduled run of `terraform plan`
