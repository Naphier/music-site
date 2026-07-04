locals {
  has_custom_domain = trimspace(var.domain_name) != ""

  domain_subdomains = var.enable_www_subdomain ? [
    {
      branch_name = var.branch_name
      prefix      = ""
    },
    {
      branch_name = var.branch_name
      prefix      = "www"
    }
  ] : [
    {
      branch_name = var.branch_name
      prefix      = ""
    }
  ]
}

resource "aws_amplify_app" "this" {
  name       = var.app_name
  repository = var.repository

  # Set with TF_VAR_github_access_token rather than committing a token.
  access_token = var.github_access_token

  enable_branch_auto_build = true

  environment_variables = {
    DEPLOY_S3_BUCKET_NAME  = var.track_bucket_name
    DEPLOY_S3_REGION       = var.track_bucket_region
    DEPLOY_TRACKS_PREFIX   = var.track_prefix
    DEPLOY_ENABLE_MOCK_MODE = tostring(var.enable_mock_mode)
  }

  # This repo is a static HTML/CSS/JS site. The preBuild step replaces the
  # deployment placeholders in app.js with Amplify environment variables.
  build_spec = <<-YAML
    version: 1
    frontend:
      phases:
        preBuild:
          commands:
            - echo "Preparing static site configuration"
            - sed -i "s|__DEPLOY_S3_BUCKET_NAME__|$${DEPLOY_S3_BUCKET_NAME}|g" app.js
            - sed -i "s|__DEPLOY_S3_REGION__|$${DEPLOY_S3_REGION}|g" app.js
            - sed -i "s|__DEPLOY_TRACKS_PREFIX__|$${DEPLOY_TRACKS_PREFIX}|g" app.js
            - sed -i "s|__DEPLOY_ENABLE_MOCK_MODE__|$${DEPLOY_ENABLE_MOCK_MODE}|g" app.js
        build:
          commands:
            - echo "No build step required for static site"
      artifacts:
        baseDirectory: .
        files:
          - '**/*'
      cache:
        paths: []
  YAML

  custom_rule {
    source = "/<*>"
    target = "/index.html"
    status = "404-200"
  }
}

resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.this.id
  branch_name = var.branch_name

  display_name      = var.branch_name
  enable_auto_build = true
  framework         = "Web"
  stage             = "PRODUCTION"
}

resource "aws_amplify_domain_association" "this" {
  count = local.has_custom_domain ? 1 : 0

  app_id      = aws_amplify_app.this.id
  domain_name = var.domain_name

  # Leave verification to DNS setup after Terraform creates the association.
  # Set to true locally if your DNS records are already in place and you want
  # Terraform to wait for Amplify domain verification.
  wait_for_verification = false

  dynamic "sub_domain" {
    for_each = local.domain_subdomains

    content {
      branch_name = sub_domain.value.branch_name
      prefix      = sub_domain.value.prefix
    }
  }

  depends_on = [aws_amplify_branch.main]
}
