output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID used for cache invalidations."
  value       = aws_cloudfront_distribution.site.id
}

output "cloudfront_distribution_domain_name" {
  description = "AWS-generated CloudFront domain name. Use this for initial HTTPS testing before enabling the custom domain."
  value       = aws_cloudfront_distribution.site.domain_name
}

output "cloudfront_default_url" {
  description = "AWS-generated HTTPS URL for the CloudFront distribution."
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "custom_domain_enabled" {
  description = "Whether the custom domain alias is enabled on CloudFront."
  value       = local.has_custom_domain
}

output "custom_domain_hostname" {
  description = "Requested custom domain hostname when the feature flag is enabled."
  value       = local.has_custom_domain ? var.custom_domain_name : null
}

output "custom_domain_certificate_arn" {
  description = "ACM certificate ARN created for the custom domain, if create_custom_domain_certificate is enabled."
  value       = local.has_requested_certificate ? aws_acm_certificate.custom_domain[0].arn : null
}

output "custom_domain_certificate_validation_records" {
  description = "DNS validation records for the ACM certificate. Add these in JaguarPC when create_custom_domain_certificate is enabled."
  value = local.has_requested_certificate ? [
    for record in aws_acm_certificate.custom_domain[0].domain_validation_options : {
      name  = record.resource_record_name
      type  = record.resource_record_type
      value = record.resource_record_value
    }
  ] : []
}

output "custom_domain_cname_record" {
  description = "CNAME record to add in JaguarPC after the CloudFront custom domain is enabled."
  value = local.has_custom_domain ? {
    name  = var.custom_domain_name
    type  = "CNAME"
    value = aws_cloudfront_distribution.site.domain_name
  } : null
}
