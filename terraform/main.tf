locals {
  has_requested_certificate = var.create_custom_domain_certificate
  has_custom_domain         = var.enable_custom_domain && trimspace(var.custom_domain_name) != ""
  created_certificate_arn   = local.has_requested_certificate ? aws_acm_certificate.custom_domain[0].arn : ""
  viewer_certificate_arn    = trimspace(var.custom_domain_certificate_arn) != "" ? var.custom_domain_certificate_arn : local.created_certificate_arn
}

data "aws_s3_bucket" "site" {
  bucket = var.site_bucket_name
}

resource "aws_acm_certificate" "custom_domain" {
  count = local.has_requested_certificate ? 1 : 0

  provider          = aws.use1
  domain_name       = var.custom_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "music-site static website"
  default_root_object = "index.html"
  price_class         = var.price_class
  aliases             = local.has_custom_domain ? [var.custom_domain_name] : []

  origin {
    origin_id   = "site-s3-origin"
    domain_name = data.aws_s3_bucket.site.bucket_regional_domain_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "site-s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = !local.has_custom_domain
    acm_certificate_arn            = local.has_custom_domain ? local.viewer_certificate_arn : null
    ssl_support_method             = local.has_custom_domain ? "sni-only" : null
    minimum_protocol_version       = local.has_custom_domain ? "TLSv1.2_2021" : null
  }

  lifecycle {
    precondition {
      condition     = !local.has_custom_domain || trimspace(local.viewer_certificate_arn) != ""
      error_message = "enable_custom_domain requires either create_custom_domain_certificate=true or custom_domain_certificate_arn to be set."
    }
  }
}
