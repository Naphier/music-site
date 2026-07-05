output "amplify_app_id" {
  description = "Amplify app ID."
  value       = aws_amplify_app.this.id
}

output "amplify_default_domain" {
  description = "AWS-generated Amplify default domain. This host receives an Amplify-managed HTTPS certificate automatically."
  value       = aws_amplify_app.this.default_domain
}

output "amplify_branch_url" {
  description = "AWS-generated HTTPS URL for the deployed branch. Use this for initial testing before enabling the custom-domain feature flag."
  value       = "https://${aws_amplify_branch.main.branch_name}.${aws_amplify_app.this.default_domain}"
}

output "custom_domain_enabled" {
  description = "Whether the custom-domain association is enabled."
  value       = local.has_custom_domain
}

output "custom_domain_hostname" {
  description = "Requested custom domain hostname when the feature flag is enabled."
  value       = local.has_custom_domain ? "${var.subdomain_prefix}.${var.domain_name}" : null
}

output "custom_domain_certificate_verification_dns_record" {
  description = "Certificate validation DNS record returned by Amplify. Add this at JaguarPC after enabling the custom-domain feature flag."
  value       = local.has_custom_domain ? aws_amplify_domain_association.music[0].certificate_verification_dns_record : null
}

output "custom_domain_subdomain_dns_record" {
  description = "Subdomain routing DNS record returned by Amplify for music.naplandgames.com. Add this at JaguarPC after enabling the custom-domain feature flag."
  value       = local.has_custom_domain ? one(aws_amplify_domain_association.music[0].sub_domain[*].dns_record) : null
}
