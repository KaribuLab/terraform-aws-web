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

    # Configuración general de la distribución
    cloudfront_settings = optional(object({
      enabled     = optional(bool, true)
      root_object = optional(string, "index.html")
      aliases     = optional(list(any), [])
      price_class = optional(string, "PriceClass_200")
      restriction = optional(string, "none")
      certificate = optional(bool, true)
      acm_certificate_arn      = optional(string, "")
      minimum_protocol_version   = optional(string, "TLSv1.2_2021")
      web_acl_id  = optional(string, "")
    }), {})

    # Origen S3 primario (obligatorio cuando primary_origin_type es "s3")
    primary_s3_origin = optional(object({
      bucket_name = string
      origin_id   = optional(string, null) # Si no se especifica, se usa bucket_name

      # Custom headers enviados al origen S3
      custom_headers = optional(list(object({
        name  = string
        value = string
      })), [])

      # Configuración del default_cache_behavior (cuando S3 es primario)
      cache_behavior = optional(object({
        allowed_methods = optional(list(string), ["GET", "HEAD"])
        cached_methods  = optional(list(string), ["GET", "HEAD"])
        viewer_protocol = optional(string, "redirect-to-https")
        compress        = optional(bool, false)
        min_ttl         = optional(number, 0)
        default_ttl     = optional(number, 0)
        max_ttl         = optional(number, 0)
        cache_policy_id = optional(string, "")
        query_string    = optional(bool, false)
        cookies_forward = optional(string, "none")
        cache_policy_config = optional(object({
          cookies_config = optional(object({
            cookie_behavior = optional(string, "none")
            cookies         = optional(list(string), [])
          }), {})
          headers_config = optional(object({
            header_behavior = optional(string, "none")
            headers         = optional(list(string), [])
          }), {})
          query_strings_config = optional(object({
            query_string_behavior = optional(string, "none")
            query_strings         = optional(list(string), [])
          }), {})
        }), {})
        function_associations = optional(list(object({
          function_arn = string
          event_type   = string
        })), [])
      }), {})
    }))

    # Orígenes S3 adicionales (solo bucket; los cache behaviors van en ordered_cache_behaviors)
    additional_s3_origins = optional(list(object({
      bucket_name = string
      origin_id   = optional(string, null)
    })), [])

    # ALB (cuando primary_origin_type es "alb")
    alb_origin = optional(object({
      domain_name = string
      origin_id   = string
      origin_path = optional(string, "")

      origin_config = optional(object({
        http_port     = optional(number, 80)
        https_port    = optional(number, 443)
        protocol      = optional(string, "https-only")
        ssl_protocols = optional(list(string), ["TLSv1.2"])
      }), {})

      # Configuración del default_cache_behavior (cuando ALB es primario)
      cache_behavior = optional(object({
        allowed_methods = optional(list(string), ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"])
        cached_methods  = optional(list(string), ["GET", "HEAD"])
        viewer_protocol = optional(string, "https-only")
        compress        = optional(bool, false)
        min_ttl         = optional(number, 0)
        default_ttl     = optional(number, 0)
        max_ttl         = optional(number, 0)
        cache_policy_id = optional(string, "")
        query_string    = optional(bool, true)
        cookies_forward = optional(string, "all")
        cache_policy_config = optional(object({
          cookies_config = optional(object({
            cookie_behavior = optional(string, "none")
            cookies         = optional(list(string), [])
          }), {})
          headers_config = optional(object({
            header_behavior = optional(string, "none")
            headers         = optional(list(string), [])
          }), {})
          query_strings_config = optional(object({
            query_string_behavior = optional(string, "none")
            query_strings         = optional(list(string), [])
          }), {})
        }), {})
        function_associations = optional(list(object({
          function_arn = string
          event_type   = string
        })), [])
      }), {})
    }))

    # API Gateway como orígenes (solo definición de origen; routing en ordered_cache_behaviors)
    api_gateway_origins = optional(list(object({
      origin_path = string
      domain_name = string
      origin_id   = string
      origin_config = optional(object({
        http_port     = optional(number, 80)
        https_port    = optional(number, 443)
        protocol      = optional(string, "https-only")
        ssl_protocols = optional(list(string), ["TLSv1.2"])
      }), {})
    })), [])

    # Cache behaviors ordenados (desacoplados de orígenes)
    ordered_cache_behaviors = optional(list(object({
      path_pattern     = string
      target_origin_id = string
      allowed_methods  = optional(list(string), ["GET", "HEAD"])
      cached_methods   = optional(list(string), ["GET", "HEAD"])
      viewer_protocol  = optional(string, "redirect-to-https")
      compress         = optional(bool, false)
      min_ttl          = optional(number, 0)
      default_ttl      = optional(number, 0)
      max_ttl          = optional(number, 0)
      cache_policy_id  = optional(string, "")
      forwarded_values = optional(object({
        query_string        = optional(bool, false)
        headers             = optional(list(string), [])
        cookies             = optional(string, "none")
        whitelisted_cookies = optional(list(string), [])
      }), {})
      function_associations = optional(list(object({
        function_arn = string
        event_type   = string
      })), [])
      lambda_function_associations = optional(list(object({
        event_type     = string
        lambda_arn     = string
        lambda_version = string
      })), [])
    })), [])

    custom_error_response = optional(list(object({
      error_caching_min_ttl = optional(number, 300)
      error_code            = number
      response_code         = optional(number, null)
      response_page_path    = optional(string, null)
    })), [])
  })

  validation {
    condition = (
      (var.distribution.primary_origin_type == "s3" && var.distribution.primary_s3_origin != null) ||
      (var.distribution.primary_origin_type == "alb" && var.distribution.alb_origin != null)
    )
    error_message = "Debe proporcionar primary_s3_origin si primary_origin_type es 's3', o alb_origin si es 'alb'."
  }

  validation {
    condition = (
      length(var.distribution.additional_s3_origins) == 0 ||
      length(distinct(concat(
        var.distribution.primary_s3_origin != null ? [var.distribution.primary_s3_origin.bucket_name] : [],
        [for o in var.distribution.additional_s3_origins : o.bucket_name]
      ))) == length(var.distribution.additional_s3_origins) + (var.distribution.primary_s3_origin != null ? 1 : 0)
    )
    error_message = "Los bucket_name de primary_s3_origin y additional_s3_origins deben ser únicos."
  }

  validation {
    condition = !(
      var.distribution.primary_origin_type == "s3" && var.distribution.primary_s3_origin != null &&
      try(var.distribution.primary_s3_origin.cache_behavior.cache_policy_id, "") != "" &&
      (
        try(var.distribution.primary_s3_origin.cache_behavior.min_ttl, 0) != 0 ||
        try(var.distribution.primary_s3_origin.cache_behavior.default_ttl, 0) != 0 ||
        try(var.distribution.primary_s3_origin.cache_behavior.max_ttl, 0) != 0
      )
      ) && !(
      var.distribution.primary_origin_type == "alb" && var.distribution.alb_origin != null &&
      try(var.distribution.alb_origin.cache_behavior.cache_policy_id, "") != "" &&
      (
        try(var.distribution.alb_origin.cache_behavior.min_ttl, 0) != 0 ||
        try(var.distribution.alb_origin.cache_behavior.default_ttl, 0) != 0 ||
        try(var.distribution.alb_origin.cache_behavior.max_ttl, 0) != 0
      )
    )
    error_message = "No puede especificar cache_policy_id y TTLs (!= 0) simultáneamente en el cache_behavior del origen primario."
  }

  validation {
    condition = (
      var.distribution.primary_origin_type == "s3" && var.distribution.primary_s3_origin != null &&
      (
        try(var.distribution.primary_s3_origin.cache_behavior.cache_policy_id, "") != "" ||
        try(var.distribution.primary_s3_origin.cache_behavior.min_ttl, 0) != 0 ||
        try(var.distribution.primary_s3_origin.cache_behavior.default_ttl, 0) != 0 ||
        try(var.distribution.primary_s3_origin.cache_behavior.max_ttl, 0) != 0
      )
      ) || (
      var.distribution.primary_origin_type == "alb" && var.distribution.alb_origin != null &&
      (
        try(var.distribution.alb_origin.cache_behavior.cache_policy_id, "") != "" ||
        try(var.distribution.alb_origin.cache_behavior.min_ttl, 0) != 0 ||
        try(var.distribution.alb_origin.cache_behavior.default_ttl, 0) != 0 ||
        try(var.distribution.alb_origin.cache_behavior.max_ttl, 0) != 0
      )
    )
    error_message = "Debe definir cache_policy_id o al menos un TTL (!= 0) en el cache_behavior del origen primario."
  }

  validation {
    condition = alltrue([
      for assoc in concat(
        var.distribution.primary_s3_origin != null ? try(var.distribution.primary_s3_origin.cache_behavior.function_associations, []) : [],
        var.distribution.alb_origin != null ? try(var.distribution.alb_origin.cache_behavior.function_associations, []) : [],
        flatten([for b in var.distribution.ordered_cache_behaviors : try(b.function_associations, [])])
      ) : contains(["viewer-request", "viewer-response"], assoc.event_type)
    ])
    error_message = "Las CloudFront Functions solo permiten event_type 'viewer-request' o 'viewer-response'."
  }

  validation {
    condition = alltrue([
      for tid in [for b in var.distribution.ordered_cache_behaviors : b.target_origin_id] :
      contains(
        distinct(concat(
          var.distribution.primary_s3_origin != null ? [coalesce(var.distribution.primary_s3_origin.origin_id, var.distribution.primary_s3_origin.bucket_name)] : [],
          [for o in var.distribution.additional_s3_origins : coalesce(o.origin_id, o.bucket_name)],
          var.distribution.alb_origin != null ? [var.distribution.alb_origin.origin_id] : [],
          [for o in var.distribution.api_gateway_origins : o.origin_id]
        )),
        tid
      )
    ])
    error_message = "Cada ordered_cache_behaviors.target_origin_id debe coincidir con un origin_id existente (S3, ALB o API Gateway)."
  }

  validation {
    condition = alltrue([
      for b in var.distribution.ordered_cache_behaviors :
      !(try(b.cache_policy_id, "") != "" && (
        try(b.min_ttl, 0) != 0 || try(b.default_ttl, 0) != 0 || try(b.max_ttl, 0) != 0
      ))
    ])
    error_message = "En ordered_cache_behaviors no puede especificar cache_policy_id y TTLs (!= 0) a la vez."
  }

  validation {
    condition = alltrue([
      for b in var.distribution.ordered_cache_behaviors :
      try(b.cache_policy_id, "") != "" || (
        try(b.min_ttl, 0) != 0 || try(b.default_ttl, 0) != 0 || try(b.max_ttl, 0) != 0
      )
    ])
    error_message = "Cada ordered_cache_behaviors debe tener cache_policy_id o al menos un TTL (!= 0)."
  }

  validation {
    condition = alltrue([
      for b in var.distribution.ordered_cache_behaviors :
      try(b.viewer_protocol, "redirect-to-https") == "allow-all" ||
      try(b.viewer_protocol, "redirect-to-https") == "https-only" ||
      try(b.viewer_protocol, "redirect-to-https") == "redirect-to-https"
    ])
    error_message = "viewer_protocol en ordered_cache_behaviors debe ser allow-all, https-only o redirect-to-https."
  }

  validation {
    condition = (
      var.distribution.primary_origin_type != "s3" || var.distribution.primary_s3_origin == null ||
      contains(["allow-all", "https-only", "redirect-to-https"], try(var.distribution.primary_s3_origin.cache_behavior.viewer_protocol, "redirect-to-https"))
      ) && (
      var.distribution.primary_origin_type != "alb" || var.distribution.alb_origin == null ||
      contains(["allow-all", "https-only", "redirect-to-https"], try(var.distribution.alb_origin.cache_behavior.viewer_protocol, "https-only"))
    )
    error_message = "viewer_protocol en cache_behavior del origen primario debe ser allow-all, https-only o redirect-to-https."
  }
}
