# music-site

Simple static website for listing and playing music files stored in a public AWS S3 bucket.

## Setup

### 1) Create and prepare the S3 bucket

1. Create an S3 bucket in your AWS account (for example `my-artist-site`).
2. Inside the bucket, create two top-level folders:
   - `tracks/` → manually managed audio clips and related images (not touched by deployment script).
   - `dev/` → static site deployment target for the dev stage.
3. Upload your audio and image media under `tracks/`.
4. Enable static hosting approach for your use case:
   - If using **S3 website endpoint**, configure Static website hosting for the bucket.
   - If using **CloudFront + S3**, keep bucket private to the public and route access through CloudFront/OAC as desired.
5. Ensure CORS is configured so the browser can load audio objects from `tracks/`.

### 2) GitHub AWS credentials (IAM access keys)

Create an IAM user specifically for CI/CD deployments and generate an **Access Key ID** and **Secret Access Key**.

Use a least-privilege policy. The example below allows deployment updates only at the bucket root and the `dev/` stage path, and explicitly denies writes/deletes in `tracks/`. Replace `YOUR_BUCKET_NAME` before using.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowListBucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME"
    },
    {
      "Sid": "AllowWriteDeleteRootObjects",
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME/*"
    },
    {
      "Sid": "AllowWriteDeleteDevObjects",
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME/dev/*"
    },
    {
      "Sid": "DenyWriteDeleteTracksObjects",
      "Effect": "Deny",
      "Action": ["s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::YOUR_BUCKET_NAME/tracks/*"
    }
  ]
}
```

Notes:
- The explicit deny on `tracks/*` overrides any broader allow and keeps media manually managed.
- If you also want to prevent reads from `tracks/*`, add `s3:GetObject` to the deny statement.

### 3) GitHub repository secrets

In GitHub: **Settings → Secrets and variables → Actions → New repository secret**.

Create these secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `S3_BUCKET_NAME`
- `S3_REGION`
- `TRACKS_PREFIX` (example: `tracks`)
- `DEPLOY_PREFIX` (recommended: `dev`)

## Deployment

This repository includes:
- Deployment script: `scripts/deploy.sh`
- GitHub Actions workflow: `.github/workflows/deploy-s3.yml`

### What deployment does

1. Loads deployment variables from environment (and `.env` when running locally).
2. Reads `headerContent.html` from the repository root.
3. Injects `headerContent.html` into the `<header class="artist-header">...</header>` section in `index.html` (in a temp build copy).
4. Writes S3 config values into `app.js` (in a temp build copy):
   - `bucketName`
   - `region`
   - `prefix` (derived from `TRACKS_PREFIX`)
   - `enableMockMode`
5. Uploads site assets to `s3://<bucket>/<DEPLOY_PREFIX>/` using AWS CLI sync and overwrite semantics.
6. Excludes `tracks/*` from deployment operations so media remains manually managed.

### Run deployment locally

1. Install AWS CLI and authenticate your local environment (for example `aws configure`, SSO, or role-based credentials).
2. Copy `.env_example` to `.env` and fill values.
3. Update `headerContent.html` as desired.
4. Run:

```bash
./scripts/deploy.sh
```

### Deploy via GitHub Actions

- Push to `main`, or run the workflow manually from **Actions → Deploy static site to S3 → Run workflow**.
- The workflow reads bucket/config values from GitHub Secrets and runs `./scripts/deploy.sh`.
- `ENABLE_MOCK_MODE` is pinned to `false` in this workflow for S3 deployments.

### Run deployment test (mocked AWS CLI)

Use the included test harness to validate deployment injection and sync argument construction without hitting AWS:

```bash
./scripts/test-deploy.sh
```

### PR code checks

Pull requests run `.github/workflows/pr-checks.yml`, which executes:

- `shellcheck scripts/*.sh`
- `./scripts/test-deploy.sh`

## Setup / Local Dev

1. Copy the sample env file:

```bash
cp .env_example .env
```

2. Edit `.env` for your local target and behavior.
3. `.env` is ignored by git via `.gitignore`.
4. Serve locally:

```bash
python -m http.server 8000
```

Then open `http://localhost:8000`.

## Notes

- GitHub Pages workflow (`.github/workflows/deploy-pages.yml`) forces `ENABLE_MOCK_MODE=true` during artifact build.
- For S3-backed deployments, set `ENABLE_MOCK_MODE=false` and provide valid S3 config.
