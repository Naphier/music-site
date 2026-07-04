variable "aws_region" {
  description = "AWS region used by the AWS provider. Amplify Hosting is managed globally, but the API is called through a region."
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Amplify app name."
  type        = string
  default     = "music-site"
}

variable "repository" {
  description = "GitHub repository URL for the site."
  type        = string
  default     = "https://github.com/Naphier/music-site"
}

variable "branch_name" {
  description = "Git branch Amplify should deploy."
  type        = string
  default     = "main"
}

variable "github_access_token" {
  description = "GitHub personal access token used by Amplify to connect to the repository. Prefer setting this with TF_VAR_github_access_token."
  type        = string
  sensitive   = true
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

variable "enable_custom_domain" {
  description = "Feature flag for the external DNS dependency. Keep false until music.naplandgames.com is ready to be configured in JaguarPC DNS."
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Parent domain to associate with Amplify when enable_custom_domain is true. For music.naplandgames.com, use naplandgames.com."
  type        = string
  default     = "naplandgames.com"
}

variable "subdomain_prefix" {
  description = "Subdomain prefix to associate with the Amplify branch when enable_custom_domain is true. For music.naplandgames.com, use music."
  type        = string
  default     = "music"
}

variable "wait_for_domain_verification" {
  description = "Whether Terraform should wait for Amplify custom-domain DNS verification. Keep false until JaguarPC DNS records have been created."
  type        = bool
  default     = false
}
