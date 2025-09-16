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
    description         = string
    primary_origin_type = optional(string, "s3") # "s3" o "alb"
    default_cache_behavior_compress = optional(bool, false)
    default_cache_behavior_min_ttl = optional(number, 0)
    default_cache_behavior_default_ttl = optional(number, 0)
    default_cache_behavior_max_ttl = optional(number, 0)
    default_cache_behavior_cache_policy_id = optional(string, "")

    # Configuración general de la distribución
    cloudfront_settings = optional(object({
      enabled     = optional(bool, true)
      root_object = optional(string, "index.html")
      aliases     = optional(list(any), [])
      price_class = optional(string, "PriceClass_200")
      restriction = optional(string, "none")
      certificate = optional(bool, true)
    }), {})

    # Configuración de S3
    s3_origin = optional(object({
      bucket_name  = string
      path_pattern = optional(string, "/static/*")

      # Configuración del comportamiento de caché para S3
      cache_behavior = optional(object({
        allowed_methods = optional(list(any), ["GET", "HEAD"])
        cached_methods  = optional(list(any), ["GET", "HEAD"])
        query_string    = optional(bool, false)
        cookies         = optional(string, "none")
        viewer_protocol = optional(string, "redirect-to-https")
      }), {})
    }))

    # Configuración de ALB
    alb_origin = optional(object({
      domain_name  = string
      origin_id    = string
      origin_path  = optional(string, "")
      path_pattern = optional(string, "/api/*")

      # Configuración del origen
      origin_config = optional(object({
        http_port     = optional(number, 80)
        https_port    = optional(number, 443)
        protocol      = optional(string, "https-only")
        ssl_protocols = optional(list(string), ["TLSv1.2"])
      }), {})

      # Configuración del comportamiento de caché
      cache_behavior = optional(object({
        allowed_methods = optional(list(string), ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"])
        cached_methods  = optional(list(string), ["GET", "HEAD"])
        viewer_protocol = optional(string, "https-only")
        query_string    = optional(bool, true)
      }), {})
    }))
    # Otras configuraciones
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
    api_gateway_origins = optional(list(object({
      origin_path  = string
      domain_name  = string
      origin_id    = string
      path_pattern = string
      headers      = list(string)
      cookies      = list(string)

      # Configuración del origen
      origin_config = optional(object({
        http_port     = optional(number, 80)
        https_port    = optional(number, 443)
        protocol      = optional(string, "https-only")
        ssl_protocols = optional(list(string), ["TLSv1.2"])
      }), {})

      # Configuración del comportamiento de caché
      cache_behavior = optional(object({
        allowed_methods = optional(list(string), ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"])
        cached_methods  = optional(list(string), ["GET", "HEAD"])
        viewer_protocol = optional(string, "https-only")
        query_string    = optional(bool, true)
      }), {})
    })))
  })
  validation {
    condition = (
      (var.distribution.primary_origin_type == "s3" && var.distribution.s3_origin != null) ||
      (var.distribution.primary_origin_type == "alb" && var.distribution.alb_origin != null)
    )
    error_message = "Debe proporcionar una configuración válida para el origen primario. Si primary_origin_type es 's3', debe proporcionar s3_origin. Si primary_origin_type es 'alb', debe proporcionar alb_origin."
  }
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
## Variables Opcionales (Mantenidas para compatibilidad)
## ===================================================

variable "distribution_enabled" {
  type        = bool
  default     = true
  description = "Obsoleta. Use var.distribution.enabled"
}

variable "distribution_root_object" {
  type        = string
  default     = "index.html"
  description = "Obsoleta. Use var.distribution.root_object"
}

variable "distribution_aliases" {
  type        = list(any)
  default     = []
  description = "Obsoleta. Use var.distribution.aliases"
}

variable "distribution_price_class" {
  type        = string
  default     = "PriceClass_200"
  description = "Obsoleta. Use var.distribution.price_class"
}

variable "distribution_restriction" {
  type        = string
  default     = "none"
  description = "Obsoleta. Use var.distribution.restriction"
}

variable "distribution_certificate" {
  type        = bool
  default     = true
  description = "Obsoleta. Use var.distribution.certificate"
}

## API Gateway Origin (Mantenidas para compatibilidad)
## ---------------------------------------------------

variable "api_gateway_origin_http_port" {
  type        = number
  default     = 80
  description = "Obsoleta. Use var.distribution.api_gateway_origins[*].http_port"
}

variable "api_gateway_origin_https_port" {
  type        = number
  default     = 443
  description = "Obsoleta. Use var.distribution.api_gateway_origins[*].https_port"
}

variable "api_gateway_origin_protocol" {
  type        = string
  default     = "https-only"
  description = "Obsoleta. Use var.distribution.api_gateway_origins[*].protocol"
}

variable "api_gateway_origin_ssl_protocols" {
  type        = list(string)
  default     = ["TLSv1.2"]
  description = "Obsoleta. Use var.distribution.api_gateway_origins[*].ssl_protocols"
}

variable "api_gateway_origin_allowed_methods" {
  type        = list(string)
  default     = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
  description = "Obsoleta. Use var.distribution.api_gateway_origins[*].allowed_methods"
}

variable "api_gateway_origin_cached_methods" {
  type        = list(string)
  default     = ["GET", "HEAD"]
  description = "Obsoleta. Use var.distribution.api_gateway_origins[*].cached_methods"
}

variable "api_gateway_origin_viewer_protocol" {
  type        = string
  default     = "https-only"
  description = "Obsoleta. Use var.distribution.api_gateway_origins[*].viewer_protocol"
}

variable "api_gateway_origin_query_string" {
  type        = bool
  default     = true
  description = "Obsoleta. Use var.distribution.api_gateway_origins[*].query_string"
}

## Cache Behavior (Mantenidas para compatibilidad)
## ---------------------------------------------------

variable "s3_origin_allowed_methods" {
  type        = list(any)
  default     = ["GET", "HEAD"]
  description = "Obsoleta. Use var.distribution.s3_origin.allowed_methods"
}

variable "s3_origin_cached_methods" {
  type        = list(any)
  default     = ["GET", "HEAD"]
  description = "Obsoleta. Use var.distribution.s3_origin.cached_methods"
}

variable "s3_origin_query_string" {
  type        = bool
  default     = false
  description = "Obsoleta. Use var.distribution.s3_origin.query_string"
}

variable "s3_origin_cookies" {
  type        = string
  default     = "none"
  description = "Obsoleta. Use var.distribution.s3_origin.cookies"
}

variable "s3_origin_viewer_protocol" {
  type        = string
  default     = "redirect-to-https"
  description = "Obsoleta. Use var.distribution.s3_origin.viewer_protocol"
}

## ALB Origin (Mantenidas para compatibilidad)
## ---------------------------------------------------

variable "alb_origin_http_port" {
  type        = number
  default     = 80
  description = "Obsoleta. Use var.distribution.alb_origin.http_port"
}

variable "alb_origin_https_port" {
  type        = number
  default     = 443
  description = "Obsoleta. Use var.distribution.alb_origin.https_port"
}

variable "alb_origin_protocol" {
  type        = string
  default     = "https-only"
  description = "Obsoleta. Use var.distribution.alb_origin.protocol"
}

variable "alb_origin_ssl_protocols" {
  type        = list(string)
  default     = ["TLSv1.2"]
  description = "Obsoleta. Use var.distribution.alb_origin.ssl_protocols"
}

variable "alb_origin_allowed_methods" {
  type        = list(string)
  default     = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
  description = "Obsoleta. Use var.distribution.alb_origin.allowed_methods"
}

variable "alb_origin_cached_methods" {
  type        = list(string)
  default     = ["GET", "HEAD"]
  description = "Obsoleta. Use var.distribution.alb_origin.cached_methods"
}

variable "alb_origin_viewer_protocol" {
  type        = string
  default     = "https-only"
  description = "Obsoleta. Use var.distribution.alb_origin.viewer_protocol"
}

variable "alb_origin_query_string" {
  type        = bool
  default     = true
  description = "Obsoleta. Use var.distribution.alb_origin.query_string"
}
