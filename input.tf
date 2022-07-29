# ===================================================
## Variables Requeridas
## ===================================================

## Tags AWS
## ---------------------------------------------------

variable "tag_project_name" {
  type        = string
  description = "Nombre del proyecto"
}

variable "tag_customer_name" {
  type        = string
  description = "Nombre del cliente"
}

variable "tag_team_name" {
  type        = string
  description = "Nombre del equipo"
}

variable "tag_environment" {
  type        = string
  description = "Nombre del ambiente"
}

## Distribución CloudFront
## ---------------------------------------------------

variable "default_s3_origin" {
  type    = string
  default = ""
}

variable "frontend_distribution" {
  type = list(object({
    s3_origin         = string
    behavior_patterns = list(string)
    description       = string
    api_gateway_origins = list(object({
      domain_name  = string
      origin_id    = string
      path_pattern = string
      headers      = list(string)
      cookies      = list(string)
    }))
  }))
  default = []
}

## ===================================================
## Variables Opcionales
## ===================================================

## Bucket S3
## ---------------------------------------------------

variable default_bucket_acl {
  type    = string
  default = "private"
}

## Distribución CloudFront
## ---------------------------------------------------

variable distribution_enabled {
  type    = bool
  default = true
}

variable distribution_root_object {
  type    = string
  default = "/index.html"
}

variable distribution_aliases {
  type    = list
  default = []
}

variable distribution_price_class {
  type    = string
  default = "PriceClass_200"
}

variable distribution_restriction {
  type    = string
  default = "none"
}

variable distribution_certificate {
  type    = bool
  default = true
}

## API Gateway Origin
## ---------------------------------------------------

variable "api_gateway_origin_http_port" {
  type    = number
  default = 80
}

variable "api_gateway_origin_https_port" {
  type    = number
  default = 443
}

variable "api_gateway_origin_protocol" {
  type    = string
  default = "https-only"
}

variable "api_gateway_origin_ssl_protocols" {
  type    = list(string)
  default = ["TLSv1.2"]
}

variable "api_gateway_origin_allowed_methods" {
  type    = list(string)
  default = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
}

variable "api_gateway_origin_cached_methods" {
  type    = list(string)
  default = ["GET", "HEAD"]
}

variable "api_gateway_origin_viewer_protocol" {
  type    = string
  default = "https-only"
}

variable "api_gateway_origin_query_string" {
  type    = bool
  default = true
}

## Cache Behavior
## ---------------------------------------------------

variable s3_origin_allowed_methods {
  type    = list
  default = ["GET", "HEAD"]
}

variable s3_origin_cached_methods {
  type    = list
  default = ["GET", "HEAD"]
}

variable s3_origin_query_string {
  type    = bool
  default = false
}

variable "s3_origin_not_found_code" {
  type    = number
  default = 404
}

variable "s3_origin_ok_code" {
  type    = number
  default = 200
}

variable s3_origin_cookies {
  type    = string
  default = "none"
}

variable s3_origin_viewer_protocol {
  type    = string
  default = "redirect-to-https"
}
