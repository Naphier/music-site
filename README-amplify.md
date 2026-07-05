# CloudFront + S3 Terraform Deployment

This repo deploys a small static music website to an existing S3 bucket and serves it through CloudFront. The first deployment uses the AWS-generated CloudFront HTTPS hostname. The custom domain `music.naplandgames.com` is staged behind feature flags because JaguarPC DNS is an external dependency.

> Note: this file replaced the earlier Amplify plan. The filename is retained for PR continuity, but the implementation is now CloudFront + ACM + existing S3.

## Initial deployment: AWS-generated CloudFront HTTPS hostname

Start with custom-domain settings disabled:

```hcl
create_custom_domain_certificate = false
enable_custom_domain             = false
custom_domain_name                = "music.naplandgames.com"
```

After Terraform applies, use this output for testing:

```text
cloudfront_default_url
```

It will look similar to:

```text
https://d123example.cloudfront.net
```

That CloudFront hostname has HTTPS immediately through CloudFront's default certificate, so no JaguarPC DNS change is needed for the first test deployment.

## GitHub Actions setup

The repo includes two workflows:

```text
.github/workflows/terraform-check.yml
.github/workflows/terraform-deploy.yml
```

`terraform-check.yml` runs formatting and validation checks on pull requests, manual dispatch, and pushes to `main`.

`terraform-deploy.yml` can be triggered manually and also runs after this PR is merged to `main` when Terraform or static-site files change. A push to `main` applies Terraform, syncs the generated static artifact to S3, and invalidates CloudFront. A manual run defaults to `plan`; choose `apply` only when you want to deploy changes.

The deploy workflow uses GitHub Actions OIDC to assume an AWS role instead of storing long-lived AWS API keys in GitHub. Configure these repository-level secrets:

| Secret | Purpose |
| --- | --- |
| `AWS_GITHUB_ACTIONS_ROLE_ARN` | IAM role ARN that GitHub Actions is allowed to assume through OIDC. |
| `TF_STATE_BUCKET` | Existing S3 bucket used for Terraform remote state. |

Required repository variables:

| Variable | Example | Purpose |
| --- | --- | --- |
| `SITE_BUCKET_NAME` | `my-existing-site-bucket` | Existing S3 bucket that receives `index.html`, `styles.css`, and processed `app.js`. |

Recommended repository variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `AWS_REGION` | `us-east-1` | AWS provider and Terraform state region. |
| `TRACK_BUCKET_NAME` | empty | Public S3 bucket that stores audio tracks. Leave empty for mock mode. |
| `TRACK_BUCKET_REGION` | `us-east-1` | Region for the audio-track S3 bucket. |
| `TRACK_PREFIX` | empty | Optional S3 prefix for tracks, such as `tracks/`. |
| `ENABLE_MOCK_MODE` | `true` | Shows mock tracks when no track bucket is configured. |
| `CREATE_CUSTOM_DOMAIN_CERTIFICATE` | `false` | Requests an ACM certificate and outputs JaguarPC DNS validation records. |
| `ENABLE_CUSTOM_DOMAIN` | `false` | Adds `music.naplandgames.com` as a CloudFront alternate domain name after the certificate is issued. |
| `CUSTOM_DOMAIN_NAME` | `music.naplandgames.com` | Custom hostname to use later. |
| `CUSTOM_DOMAIN_CERTIFICATE_ARN` | empty | Optional existing us-east-1 ACM certificate ARN. |

The S3 bucket named by `TF_STATE_BUCKET` must exist before the first workflow run. This keeps Terraform state persistent across deploys.

## Required AWS permissions

The AWS role assumed by GitHub Actions needs permissions for:

- CloudFront distribution management
- ACM certificate management in `us-east-1`
- S3 access to the Terraform state bucket
- S3 write access to the existing site bucket
- CloudFront cache invalidation
- Any related IAM read/list actions required by the AWS provider

A narrow policy is preferable, but for first testing you can start with a scoped administrative role and reduce it after the resource set stabilizes.

## Enabling `music.naplandgames.com` later

After the AWS-generated CloudFront URL is tested successfully:

1. Run the GitHub Actions deploy workflow manually.
2. Set `create_custom_domain_certificate` to `true`.
3. Keep `enable_custom_domain` as `false` for this apply.
4. Apply Terraform.
5. Read the Terraform output:
   - `custom_domain_certificate_validation_records`
6. Log in to JaguarPC DNS for `naplandgames.com`.
7. Add the ACM certificate validation records exactly as shown.
8. Wait for ACM to report the certificate as issued.
9. Set the repository variable `CREATE_CUSTOM_DOMAIN_CERTIFICATE` to `true` so future deploys keep the certificate managed.
10. Run the deploy workflow manually again with `enable_custom_domain=true`.
11. Read the Terraform output:
    - `custom_domain_cname_record`
12. Add the CNAME record in JaguarPC DNS so `music.naplandgames.com` points to the CloudFront distribution.
13. Set the repository variable `ENABLE_CUSTOM_DOMAIN` to `true` so future merges to `main` preserve the CloudFront alias.
14. Test:

```text
https://music.naplandgames.com
```

## JaguarPC DNS notes

For this CloudFront setup, JaguarPC will need:

- ACM DNS validation records from `custom_domain_certificate_validation_records`; and
- a CNAME record from `custom_domain_cname_record` after the certificate is issued and the CloudFront alias is enabled.

Do not create records for the apex domain unless you also want to move `naplandgames.com` itself to CloudFront.

## Cleanup from the abandoned Amplify plan

You no longer need:

- `AMPLIFY_GITHUB_ACCESS_TOKEN` in GitHub secrets.
- Any GitHub personal access token created only for Amplify.
- Any Amplify app created while testing the prior approach.
- Any IAM permissions that only exist for Amplify management.

You still need:

- The GitHub OIDC IAM role.
- The Terraform state bucket.
- The GitHub secret `AWS_GITHUB_ACTIONS_ROLE_ARN`.
- The GitHub secret `TF_STATE_BUCKET`.
