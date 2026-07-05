# AGENTS.md

Guidance for AI agents and contributors working in this repository.

## Project overview

This is a small static music website deployed through AWS Amplify Hosting. The site source is plain HTML, CSS, and JavaScript at the repository root.

Primary site files:

- `index.html`
- `styles.css`
- `app.js`

Infrastructure files live under:

- `terraform/`

GitHub Actions workflows live under:

- `.github/workflows/`

## Required checks before committing

Before committing Terraform changes, validate them locally or in an equivalent CI environment:

```bash
cd terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

Do not commit Terraform changes that fail any of those commands.

Before committing static-site changes, manually verify that the site still loads with the existing plain static-file structure. Do not introduce a frontend framework or build system unless the project is intentionally migrated.

## Terraform conventions

- Keep Terraform code under `terraform/`.
- Keep the custom domain disabled by default with `enable_custom_domain = false`.
- Treat `music.naplandgames.com` as an external DNS dependency managed in JaguarPC.
- Do not make Terraform wait for domain verification by default; keep `wait_for_domain_verification = false` unless DNS records are already in place.
- Use repository variables for non-secret deployment settings.
- Use repository secrets only for sensitive values.
- Do not commit local Terraform state, plans, `.terraform/`, or real `.tfvars` files.
- Use Terraform expressions that work with provider set types. Do not index nested set blocks directly; use splats, `one(...)`, or `for` expressions instead.

## Amplify deployment conventions

- The initial deployment should be testable at the AWS-generated Amplify HTTPS hostname.
- Publish only the built/static site artifact directory, not the whole repository.
- Keep infrastructure, docs, and workflow files out of the deployed website artifact.
- Preserve the custom-domain feature flag on push-to-main deploys so later merges do not accidentally remove `music.naplandgames.com`.

## GitHub Actions conventions

- Workflows that deploy infrastructure must support manual `workflow_dispatch`.
- Terraform deployment should also run after changes are merged to `main`.
- Prefer GitHub Actions OIDC role assumption for AWS access instead of long-lived AWS access keys.
- Keep validation workflows safe for pull requests and avoid exposing secrets to untrusted PR contexts.

## Documentation conventions

- Keep setup instructions in `README-amplify.md` current with Terraform and workflow behavior.
- Document JaguarPC DNS steps in terms of the exact Terraform outputs or Amplify console records the user should copy.
- Do not imply that apex-domain DNS for `naplandgames.com` is required when only `music.naplandgames.com` is being configured.
