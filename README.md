# music-site

Simple static website for listing and playing music files stored in a public AWS S3 bucket.

## Configure

Open `app.js` and set the `CONFIG` values:

- `bucketName`: your public S3 bucket name
- `region`: bucket region (for example `us-east-1`)
- `prefix`: optional folder path for tracks (for example `tracks/`)
- `enableMockMode`: if `true`, loads sample tracks when no bucket is configured

## Test stage (mock mode)

By default, `enableMockMode` is `true`, so the app loads three sample tracks and thumbnails.
This allows you to publish a test stage on GitHub Pages immediately, even before your S3 bucket is wired up.

When you are ready to use your real bucket:

1. Set `bucketName` (and optionally `region` / `prefix`).
2. Keep `enableMockMode` enabled as fallback, or set it to `false` to require bucket config.

## Deploy to GitHub Pages

This repo now includes `.github/workflows/deploy-pages.yml`.

1. Push to `main`.
2. In GitHub, go to **Settings → Pages** and set **Source** to **GitHub Actions**.
3. The workflow will publish the static site.

## Run locally

Since this is a static site, serve it with any local web server from the repository root.

Example:

```bash
python -m http.server 8000
```

Then open `http://localhost:8000`.
