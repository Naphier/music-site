variable "aws_region" {
  description = "AWS region for regional resources and the Terraform state bucket. CloudFront is global and ACM for CloudFront uses us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "site_bucket_name" {
  description = "Existing S3 bucket that stores the static website files. GitHub Actions syncs the built site files here."
  type        = string
}

variable "track_bucket_name" {
  description = "Public S3 bucket name that stores the audio files listed by the frontend. Leave empty to use mock mode."
  type        = string
  default     = ""
}

variable "track_bucket_region" {
  description = "Region of the public S3 bucket that stores the audio files."
  type        = string
  default     = "us-east-1"
}

variable "track_prefix" {
  description = "Optional S3 prefix containing tracks, for example tracks/. Leave empty for bucket root."
  type        = string
  default     = ""
}

variable "enable_mock_mode" {
  description = "Whether the frontend should show mock tracks when no track_bucket_name is configured."
  type        = bool
  default     = true
}

variable "custom_domain_name" {
  description = "Custom hostname to use later after DNS is configured in JaguarPC."
  type        = string
  default     = "music.naplandgames.com"
}

variable "create_custom_domain_certificate" {
  description = "Feature flag that requests an ACM certificate in us-east-1 and outputs DNS validation records. This can be enabled before the CloudFront alias is enabled."
  type        = bool
  default     = false
}

variable "enable_custom_domain" {
  description = "Feature flag that adds custom_domain_name as a CloudFront alternate domain name. Enable only after the ACM certificate is issued."
  type        = bool
  default     = false
}

variable "custom_domain_certificate_arn" {
  description = "Optional existing us-east-1 ACM certificate ARN for custom_domain_name. Leave empty to use the certificate created by this Terraform configuration."
  type        = string
  default     = ""
}

variable "price_class" {
  description = "CloudFront price class. PriceClass_100 is usually sufficient for a very low traffic personal/static site."
  type        = string
  default     = "PriceClass_100"
}
