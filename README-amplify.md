# Amplify Hosting Terraform Deployment

This repo can be deployed to AWS Amplify Hosting with Terraform. The initial deployment uses the AWS-generated Amplify hostname, which includes managed HTTPS automatically. The custom domain `music.naplandgames.com` is behind a feature flag because JaguarPC DNS is an external dependency that can be configured later.

## Initial deployment: AWS-generated HTTPS hostname

Start with the custom domain disabled:

```hcl
enable_custom_domain         = false
domain_name                  = "naplandgames.com"
subdomain_prefix             = "music"
wait_for_domain_verification = false
```

After Terraform applies, use this output for testing:

```text
amplify_branch_url
```

It will look similar to:

```text
https://main.<amplify-app-id>.amplifyapp.com
```

That AWS-generated hostname receives an Amplify-managed HTTPS certificate automatically, so no JaguarPC DNS change is needed for the first test deployment.

## GitHub Actions setup

The repo includes two workflows:

```text
.github/workflows/terraform-check.yml
.github/workflows/terraform-deploy.yml
```

`terraform-check.yml` runs formatting and validation checks on pull requests, manual dispatch, and pushes to `main`.

`terraform-deploy.yml` can be triggered manually and also runs after this PR is merged to `main` when Terraform files change. A push to `main` applies the plan automatically. A manual run defaults to `plan`; choose `apply` only when you want to deploy changes.

The deploy workflow uses GitHub Actions OIDC to assume an AWS role instead of storing long-lived AWS API keys in GitHub. Configure these repository-level secrets:

| Secret | Purpose |
| --- | --- |
| `AWS_GITHUB_ACTIONS_ROLE_ARN` | IAM role ARN that GitHub Actions is allowed to assume through OIDC. |
| `AMPLIFY_GITHUB_ACCESS_TOKEN` | GitHub token Amplify uses to connect this repository. |
| `TF_STATE_BUCKET` | Existing S3 bucket used for Terraform remote state. |

Recommended repository variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `AWS_REGION` | `us-east-1` | AWS provider and Terraform state region. |
| `TRACK_BUCKET_NAME` | empty | Public S3 bucket that stores audio tracks. Leave empty for mock mode. |
| `TRACK_BUCKET_REGION` | `us-east-1` | Region for the audio-track S3 bucket. |
| `TRACK_PREFIX` | empty | Optional S3 prefix for tracks, such as `tracks/`. |
| `ENABLE_MOCK_MODE` | `true` | Shows mock tracks when no track bucket is configured. |

The S3 bucket named by `TF_STATE_BUCKET` must exist before the first workflow run. This keeps Terraform state persistent across deploys.

## Required AWS permissions

The AWS role assumed by GitHub Actions needs permissions for:

- Amplify app, branch, and domain-association management
- S3 access to the Terraform state bucket
- Any related IAM read/list actions required by the AWS provider

A narrow policy is preferable, but for first testing you can start with a scoped administrative role and reduce it after the resource set stabilizes.

## Enabling `music.naplandgames.com` later

After the AWS-generated Amplify URL is tested successfully:

1. Run the GitHub Actions deploy workflow manually.
2. Set `enable_custom_domain` to `true`.
3. Keep `wait_for_domain_verification` as `false` for the first custom-domain apply.
4. Apply Terraform.
5. Read the Terraform outputs:
   - `custom_domain_subdomain_dns_record`
   - `custom_domain_certificate_verification_dns_record`
6. Log in to JaguarPC DNS for `naplandgames.com`.
7. Add the Amplify-provided CNAME/subdomain-routing record and certificate-verification record exactly as shown.
8. Wait for DNS propagation and Amplify certificate validation.
9. After Amplify reports the domain as available, test:

```text
https://music.naplandgames.com
```

Optionally run Terraform again with:

```hcl
enable_custom_domain         = true
wait_for_domain_verification = true
```

This makes future Terraform runs wait for Amplify domain verification.

## JaguarPC DNS notes

For an external DNS provider, Amplify normally gives you at least:

- a CNAME-style record that routes `music.naplandgames.com` to the Amplify app target; and
- one or more certificate validation records.

Use the exact record names and values shown in the Amplify console or Terraform output. Do not create records for the apex domain unless you also want to move `naplandgames.com` itself to Amplify.
