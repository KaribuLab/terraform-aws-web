# ===================================================
## Variables Requeridas
## ===================================================

## Tags AWS
## ---------------------------------------------------

variable "common_tags" {
  type        = map(string)
  description = "Tags to be applied to all resources."
}

## Distribución CloudFront
## ---------------------------------------------------

variable "distribution" {
  type = object({
    s3_origin   = string
    description = string
    lambda_association = optional(list(object({
      path_pattern           = string
      allowed_methods        = list(string)
      cached_methods         = list(string)
      query_string           = bool
      headers                = list(string)
      event_type             = string
      lambda_arn             = string
      lambda_version         = string
      viewer_protocol_policy = string
      cookies                = optional(list(string))
    })))
    behavior_patterns = optional(list(string))
    api_gateway_origins = optional(list(object({
      origin_path  = string
      domain_name  = string
      origin_id    = string
      path_pattern = string
      headers      = list(string)
      cookies      = list(string)
    })))
  })
}

variable "origin_custom_headers" {
  type = list(object({
    name  = string
    value = string
  }))
  default     = []
  description = "Custom headers to be added to the origin request."

}

## ===================================================
## Variables Opcionales
## ===================================================

## Distribución CloudFront
## ---------------------------------------------------

variable "distribution_enabled" {
  type    = bool
  default = true
}

variable "distribution_root_object" {
  type    = string
  default = "index.html"
}

variable "distribution_aliases" {
  type    = list(any)
  default = []
}

variable "distribution_price_class" {
  type    = string
  default = "PriceClass_200"
}

variable "distribution_restriction" {
  type    = string
  default = "none"
}

variable "distribution_certificate" {
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

variable "s3_origin_allowed_methods" {
  type    = list(any)
  default = ["GET", "HEAD"]
}

variable "s3_origin_cached_methods" {
  type    = list(any)
  default = ["GET", "HEAD"]
}

variable "s3_origin_query_string" {
  type    = bool
  default = false
}

variable "s3_origin_cookies" {
  type    = string
  default = "none"
}

variable "s3_origin_viewer_protocol" {
  type    = string
  default = "redirect-to-https"
}
