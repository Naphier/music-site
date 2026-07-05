# AGENTS.md

Guidance for AI agents and contributors working in this repository.

## Project overview

This is a small static music website deployed to an existing S3 bucket and served through CloudFront. The site source is plain HTML, CSS, and JavaScript at the repository root.

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

Terraform changes should pass those commands before commit.

Before committing static-site changes, manually verify that the site still loads with the existing plain static-file structure. Do not introduce a frontend framework or build system unless the project is intentionally migrated.

## Terraform conventions

- Keep Terraform code under `terraform/`.
- Keep the custom domain disabled by default with `enable_custom_domain = false`.
- Treat `music.naplandgames.com` as an external DNS dependency managed in JaguarPC.
- Request the ACM certificate separately with `create_custom_domain_certificate = true` before enabling the CloudFront alias.
- ACM certificates used by CloudFront must be in `us-east-1`.
- Use repository variables for non-secret deployment settings.
- Use repository secrets only for sensitive values.
- Avoid adding local Terraform state, saved plans, `.terraform/`, or real `.tfvars` files to commits.
- Use Terraform expressions that work with provider set types. Do not index nested set blocks directly; use splats, `one(...)`, or `for` expressions instead.

## CloudFront and S3 deployment conventions

- The initial deployment should be testable at the AWS-generated CloudFront HTTPS hostname.
- Publish only the generated static site artifact, not the whole repository.
- Keep infrastructure, docs, and workflow files out of the deployed website artifact.
- Preserve custom-domain feature flags on push-to-main deploys so later merges do not accidentally remove `music.naplandgames.com`.
- The GitHub Actions deploy workflow owns syncing `index.html`, `styles.css`, and processed `app.js` to the site S3 bucket.

## GitHub Actions conventions

- Workflows that deploy infrastructure must support manual `workflow_dispatch`.
- Terraform deployment should also run after changes are merged to `main`.
- Prefer GitHub Actions OIDC role assumption for AWS access instead of long-lived AWS access keys.
- Keep validation workflows safe for pull requests and avoid exposing secrets to untrusted PR contexts.

## Documentation conventions

- Keep setup instructions in `README-amplify.md` current with Terraform and workflow behavior until the file is renamed in a later cleanup.
- Document JaguarPC DNS steps in terms of the exact Terraform outputs the user should copy.
- Do not imply that apex-domain DNS for `naplandgames.com` is required when only `music.naplandgames.com` is being configured.
