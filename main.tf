resource "aws_s3_bucket" "s3_origin" {
  for_each = local.s3_origins_map
  bucket   = each.value.bucket_name
  tags     = var.common_tags
}

resource "aws_cloudfront_origin_access_control" "s3_origin" {
  for_each                          = local.s3_origins_map
  name                              = "${each.value.bucket_name}-oac"
  description                       = var.distribution.description
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_public_access_block" "s3_origin" {
  for_each = local.s3_origins_map
  bucket   = aws_s3_bucket.s3_origin[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_cache_policy" "custom" {
  count = var.distribution.default_cache_behavior_default_ttl != 0 || var.distribution.default_cache_behavior_max_ttl != 0 || var.distribution.default_cache_behavior_min_ttl != 0 ? 1 : 0

  name        = local.primary_s3_origin != null ? "${local.primary_s3_origin.bucket_name}-cache-policy" : "custom-cache-policy"
  default_ttl = var.distribution.default_cache_behavior_default_ttl
  max_ttl     = var.distribution.default_cache_behavior_max_ttl
  min_ttl     = var.distribution.default_cache_behavior_min_ttl

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

locals {
  # Lista unificada de todos los orígenes S3 (primary + additional)
  all_s3_origins = concat(
    var.distribution.primary_s3_origin != null ? [merge(var.distribution.primary_s3_origin, { is_primary = true, origin_id = var.distribution.primary_s3_origin.bucket_name })] : [],
    [for idx, origin in var.distribution.additional_s3_origins : merge(origin, { is_primary = false, origin_id = coalesce(origin.origin_id, origin.bucket_name) })]
  )

  # Mapa de orígenes S3 indexados por origin_id para fácil acceso
  s3_origins_map = { for origin in local.all_s3_origins : origin.origin_id => origin }

  # Referencia al origen primario
  primary_s3_origin = var.distribution.primary_s3_origin != null ? local.s3_origins_map[var.distribution.primary_s3_origin.bucket_name] : null

  default_cache_behavior_cache_policy_id = var.distribution.default_cache_behavior_cache_policy_id != "" ? var.distribution.default_cache_behavior_cache_policy_id : length(aws_cloudfront_cache_policy.custom) > 0 ? aws_cloudfront_cache_policy.custom[0].id : ""
}

resource "aws_cloudfront_distribution" "distribution" {
  comment             = var.distribution.description
  enabled             = try(var.distribution.cloudfront_settings.enabled, var.distribution_enabled)
  default_root_object = try(var.distribution.cloudfront_settings.root_object, var.distribution_root_object)
  aliases             = try(var.distribution.cloudfront_settings.aliases, var.distribution_aliases)
  web_acl_id          = try(var.distribution.cloudfront_settings.web_acl_id, "") != "" ? try(var.distribution.cloudfront_settings.web_acl_id, "") : null

  dynamic "origin" {
    for_each = local.s3_origins_map
    content {
      domain_name              = aws_s3_bucket.s3_origin[origin.key].bucket_regional_domain_name
      origin_id                = origin.value.origin_id
      origin_access_control_id = aws_cloudfront_origin_access_control.s3_origin[origin.key].id
      dynamic "custom_header" {
        for_each = var.origin_custom_headers
        content {
          name  = custom_header.value.name
          value = custom_header.value.value
        }
      }
    }
  }

  dynamic "origin" {
    for_each = var.distribution.alb_origin != null ? [var.distribution.alb_origin] : []
    content {
      domain_name = origin.value.domain_name
      origin_id   = origin.value.origin_id
      origin_path = origin.value.origin_path
      custom_origin_config {
        http_port              = try(origin.value.origin_config.http_port, var.alb_origin_http_port)
        https_port             = try(origin.value.origin_config.https_port, var.alb_origin_https_port)
        origin_protocol_policy = try(origin.value.origin_config.protocol, var.alb_origin_protocol)
        origin_ssl_protocols   = try(origin.value.origin_config.ssl_protocols, var.alb_origin_ssl_protocols)
      }
    }
  }

  dynamic "origin" {
    for_each = var.distribution.api_gateway_origins != null ? var.distribution.api_gateway_origins : []
    content {
      domain_name = origin.value.domain_name
      origin_id   = origin.value.origin_id
      origin_path = origin.value.origin_path
      custom_origin_config {
        http_port              = try(origin.value.origin_config.http_port, var.api_gateway_origin_http_port)
        https_port             = try(origin.value.origin_config.https_port, var.api_gateway_origin_https_port)
        origin_protocol_policy = try(origin.value.origin_config.protocol, var.api_gateway_origin_protocol)
        origin_ssl_protocols   = try(origin.value.origin_config.ssl_protocols, var.api_gateway_origin_ssl_protocols)
      }
    }
  }

  default_cache_behavior {
    allowed_methods  = var.distribution.primary_origin_type == "s3" ? try(var.distribution.primary_s3_origin.cache_behavior.allowed_methods, var.s3_origin_allowed_methods) : try(var.distribution.alb_origin.cache_behavior.allowed_methods, var.alb_origin_allowed_methods)
    cached_methods   = var.distribution.primary_origin_type == "s3" ? try(var.distribution.primary_s3_origin.cache_behavior.cached_methods, var.s3_origin_cached_methods) : try(var.distribution.alb_origin.cache_behavior.cached_methods, var.alb_origin_cached_methods)
    target_origin_id = var.distribution.primary_origin_type == "s3" ? local.primary_s3_origin.origin_id : var.distribution.alb_origin.origin_id

    dynamic "forwarded_values" {
      for_each = local.default_cache_behavior_cache_policy_id == "" ? [1] : []
      content {
        query_string = var.distribution.primary_origin_type == "s3" ? try(var.distribution.primary_s3_origin.cache_behavior.query_string, var.s3_origin_query_string) : try(var.distribution.alb_origin.cache_behavior.query_string, var.alb_origin_query_string)
        headers      = var.distribution.primary_origin_type == "alb" ? ["*"] : null
        cookies {
          forward = var.distribution.primary_origin_type == "s3" ? try(var.distribution.primary_s3_origin.cache_behavior.cookies, var.s3_origin_cookies) : "all"
        }
      }
    }

    compress        = var.distribution.default_cache_behavior_compress
    cache_policy_id = local.default_cache_behavior_cache_policy_id != "" ? local.default_cache_behavior_cache_policy_id : null
    min_ttl         = var.distribution.default_cache_behavior_min_ttl
    default_ttl     = var.distribution.default_cache_behavior_default_ttl
    max_ttl         = var.distribution.default_cache_behavior_max_ttl

    viewer_protocol_policy = var.distribution.primary_origin_type == "s3" ? try(var.distribution.primary_s3_origin.cache_behavior.viewer_protocol, var.s3_origin_viewer_protocol) : try(var.distribution.alb_origin.cache_behavior.viewer_protocol, var.alb_origin_viewer_protocol)

    # Asociaciones de CloudFront Functions
    dynamic "function_association" {
      for_each = var.distribution.default_cache_behavior_function_associations
      content {
        function_arn = function_association.value.function_arn
        event_type   = function_association.value.event_type
      }
    }
  }

  # Orígenes S3 adicionales
  dynamic "ordered_cache_behavior" {
    for_each = length(var.distribution.additional_s3_origins) > 0 ? var.distribution.additional_s3_origins : []
    content {
      path_pattern     = ordered_cache_behavior.value.path_pattern
      allowed_methods  = try(ordered_cache_behavior.value.cache_behavior.allowed_methods, var.s3_origin_allowed_methods)
      cached_methods   = try(ordered_cache_behavior.value.cache_behavior.cached_methods, var.s3_origin_cached_methods)
      target_origin_id = coalesce(ordered_cache_behavior.value.origin_id, ordered_cache_behavior.value.bucket_name)
      forwarded_values {
        query_string = try(ordered_cache_behavior.value.cache_behavior.query_string, var.s3_origin_query_string)
        cookies {
          forward = try(ordered_cache_behavior.value.cache_behavior.cookies, var.s3_origin_cookies)
        }
      }
      viewer_protocol_policy = try(ordered_cache_behavior.value.cache_behavior.viewer_protocol, var.s3_origin_viewer_protocol)
    }
  }

  # Primary S3 origin como ordered_cache_behavior cuando ALB es primario (si tiene path_pattern)
  dynamic "ordered_cache_behavior" {
    for_each = var.distribution.primary_origin_type == "alb" && var.distribution.primary_s3_origin != null && var.distribution.primary_s3_origin.path_pattern != "/static/*" ? [var.distribution.primary_s3_origin] : []
    content {
      path_pattern     = ordered_cache_behavior.value.path_pattern
      allowed_methods  = try(ordered_cache_behavior.value.cache_behavior.allowed_methods, var.s3_origin_allowed_methods)
      cached_methods   = try(ordered_cache_behavior.value.cache_behavior.cached_methods, var.s3_origin_cached_methods)
      target_origin_id = local.primary_s3_origin.origin_id
      forwarded_values {
        query_string = try(ordered_cache_behavior.value.cache_behavior.query_string, var.s3_origin_query_string)
        cookies {
          forward = try(ordered_cache_behavior.value.cache_behavior.cookies, var.s3_origin_cookies)
        }
      }
      viewer_protocol_policy = try(ordered_cache_behavior.value.cache_behavior.viewer_protocol, var.s3_origin_viewer_protocol)
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.distribution.primary_origin_type == "s3" && var.distribution.alb_origin != null ? [var.distribution.alb_origin] : []
    content {
      path_pattern     = ordered_cache_behavior.value.path_pattern
      allowed_methods  = try(ordered_cache_behavior.value.cache_behavior.allowed_methods, var.alb_origin_allowed_methods)
      cached_methods   = try(ordered_cache_behavior.value.cache_behavior.cached_methods, var.alb_origin_cached_methods)
      target_origin_id = ordered_cache_behavior.value.origin_id
      forwarded_values {
        query_string = try(ordered_cache_behavior.value.cache_behavior.query_string, var.alb_origin_query_string)
        headers      = ["*"]
        cookies {
          forward = "all"
        }
      }
      viewer_protocol_policy = try(ordered_cache_behavior.value.cache_behavior.viewer_protocol, var.alb_origin_viewer_protocol)
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.distribution.lambda_association != null ? var.distribution.lambda_association : []
    content {
      path_pattern     = ordered_cache_behavior.value.path_pattern
      allowed_methods  = ordered_cache_behavior.value.allowed_methods
      cached_methods   = ordered_cache_behavior.value.cached_methods
      target_origin_id = var.distribution.primary_origin_type == "s3" ? local.primary_s3_origin.origin_id : var.distribution.alb_origin.origin_id
      forwarded_values {
        query_string = ordered_cache_behavior.value.query_string
        headers      = ordered_cache_behavior.value.headers
        cookies {
          forward           = ordered_cache_behavior.value.cookies != null ? "whitelist" : "none"
          whitelisted_names = ordered_cache_behavior.value.cookies
        }
      }
      lambda_function_association {
        event_type = ordered_cache_behavior.value.event_type
        lambda_arn = "${ordered_cache_behavior.value.lambda_arn}:${ordered_cache_behavior.value.lambda_version}"
      }
      viewer_protocol_policy = ordered_cache_behavior.value.viewer_protocol_policy
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.distribution.api_gateway_origins != null ? var.distribution.api_gateway_origins : []
    content {
      path_pattern     = ordered_cache_behavior.value.path_pattern
      allowed_methods  = try(ordered_cache_behavior.value.cache_behavior.allowed_methods, var.api_gateway_origin_allowed_methods)
      cached_methods   = try(ordered_cache_behavior.value.cache_behavior.cached_methods, var.api_gateway_origin_cached_methods)
      target_origin_id = ordered_cache_behavior.value.origin_id
      forwarded_values {
        query_string = try(ordered_cache_behavior.value.cache_behavior.query_string, var.api_gateway_origin_query_string)
        headers      = ordered_cache_behavior.value.headers
        cookies {
          forward           = length(ordered_cache_behavior.value.cookies) > 0 ? "whitelist" : "none"
          whitelisted_names = ordered_cache_behavior.value.cookies
        }
      }
      viewer_protocol_policy = try(ordered_cache_behavior.value.cache_behavior.viewer_protocol, var.api_gateway_origin_viewer_protocol)
    }
  }

  price_class = try(var.distribution.cloudfront_settings.price_class, var.distribution_price_class)

  restrictions {
    geo_restriction {
      restriction_type = try(var.distribution.cloudfront_settings.restriction, var.distribution_restriction)
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = try(var.distribution.cloudfront_settings.certificate, var.distribution_certificate)
  }

  dynamic "custom_error_response" {
    for_each = var.distribution.custom_error_response != null ? var.distribution.custom_error_response : []
    content {
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
    }
  }

  tags = var.common_tags
}


resource "aws_s3_bucket_policy" "s3_origin" {
  for_each = local.s3_origins_map
  bucket   = aws_s3_bucket.s3_origin[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowCloudFrontServicePrincipalGetObject"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.s3_origin[each.key].bucket}/*"
        ],
        Condition : {
          StringEquals : {
            "aws:SourceArn" : "${aws_cloudfront_distribution.distribution.arn}"
          }
        },
      },
      {
        Sid = "AllowCloudFrontServicePrincipalListBucket"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = [
          "s3:ListBucket",
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.s3_origin[each.key].bucket}"
        ],
        Condition : {
          StringEquals : {
            "aws:SourceArn" : "${aws_cloudfront_distribution.distribution.arn}"
          }
        },
      },
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.s3_origin, aws_cloudfront_distribution.distribution]
}
