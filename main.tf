locals {
  all_s3_origins = concat(
    var.distribution.primary_s3_origin != null ? [merge(var.distribution.primary_s3_origin, {
      is_primary = true
      origin_id  = coalesce(var.distribution.primary_s3_origin.origin_id, var.distribution.primary_s3_origin.bucket_name)
    })] : [],
    [for origin in var.distribution.additional_s3_origins : merge(origin, {
      is_primary = false
      origin_id  = coalesce(origin.origin_id, origin.bucket_name)
    })]
  )

  s3_origins_map = { for origin in local.all_s3_origins : origin.origin_id => origin }

  primary_s3_origin = var.distribution.primary_s3_origin != null ? local.s3_origins_map[coalesce(var.distribution.primary_s3_origin.origin_id, var.distribution.primary_s3_origin.bucket_name)] : null

  primary_cache_behavior = var.distribution.primary_origin_type == "s3" ? var.distribution.primary_s3_origin.cache_behavior : var.distribution.alb_origin.cache_behavior
}

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
  count = try(local.primary_cache_behavior.cache_policy_id, "") == "" && (
    try(local.primary_cache_behavior.default_ttl, 0) != 0 ||
    try(local.primary_cache_behavior.max_ttl, 0) != 0 ||
    try(local.primary_cache_behavior.min_ttl, 0) != 0
  ) ? 1 : 0

  name        = local.primary_s3_origin != null ? "${local.primary_s3_origin.bucket_name}-cache-policy" : "${var.distribution.alb_origin.origin_id}-cache-policy"
  default_ttl = try(local.primary_cache_behavior.default_ttl, 0)
  max_ttl     = try(local.primary_cache_behavior.max_ttl, 0)
  min_ttl     = try(local.primary_cache_behavior.min_ttl, 0)

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = try(local.primary_cache_behavior.cache_policy_config.cookies_config.cookie_behavior, "none")
      dynamic "cookies" {
        for_each = length(try(local.primary_cache_behavior.cache_policy_config.cookies_config.cookies, [])) > 0 ? [1] : []
        content {
          items = try(local.primary_cache_behavior.cache_policy_config.cookies_config.cookies, [])
        }
      }
    }
    headers_config {
      header_behavior = try(local.primary_cache_behavior.cache_policy_config.headers_config.header_behavior, "none")
      dynamic "headers" {
        for_each = length(try(local.primary_cache_behavior.cache_policy_config.headers_config.headers, [])) > 0 ? [1] : []
        content {
          items = try(local.primary_cache_behavior.cache_policy_config.headers_config.headers, [])
        }
      }
    }
    query_strings_config {
      query_string_behavior = try(local.primary_cache_behavior.cache_policy_config.query_strings_config.query_string_behavior, "none")
      dynamic "query_strings" {
        for_each = length(try(local.primary_cache_behavior.cache_policy_config.query_strings_config.query_strings, [])) > 0 ? [1] : []
        content {
          items = try(local.primary_cache_behavior.cache_policy_config.query_strings_config.query_strings, [])
        }
      }
    }
  }
}

locals {
  default_cache_behavior_cache_policy_id = try(local.primary_cache_behavior.cache_policy_id, "") != "" ? try(local.primary_cache_behavior.cache_policy_id, "") : (
    length(aws_cloudfront_cache_policy.custom) > 0 ? aws_cloudfront_cache_policy.custom[0].id : ""
  )
}

resource "aws_cloudfront_distribution" "distribution" {
  comment             = var.distribution.description
  enabled             = try(var.distribution.cloudfront_settings.enabled, true)
  default_root_object = try(var.distribution.cloudfront_settings.root_object, "index.html")
  aliases             = try(var.distribution.cloudfront_settings.aliases, [])
  web_acl_id          = try(var.distribution.cloudfront_settings.web_acl_id, "") != "" ? try(var.distribution.cloudfront_settings.web_acl_id, "") : null

  dynamic "origin" {
    for_each = local.s3_origins_map
    content {
      domain_name              = aws_s3_bucket.s3_origin[origin.key].bucket_regional_domain_name
      origin_id                = origin.value.origin_id
      origin_access_control_id = aws_cloudfront_origin_access_control.s3_origin[origin.key].id
      dynamic "custom_header" {
        for_each = try(origin.value.custom_headers, [])
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
        http_port              = try(origin.value.origin_config.http_port, 80)
        https_port             = try(origin.value.origin_config.https_port, 443)
        origin_protocol_policy = try(origin.value.origin_config.protocol, "https-only")
        origin_ssl_protocols   = try(origin.value.origin_config.ssl_protocols, ["TLSv1.2"])
      }
    }
  }

  dynamic "origin" {
    for_each = try(var.distribution.api_gateway_origins, [])
    content {
      domain_name = origin.value.domain_name
      origin_id   = origin.value.origin_id
      origin_path = origin.value.origin_path
      custom_origin_config {
        http_port              = try(origin.value.origin_config.http_port, 80)
        https_port             = try(origin.value.origin_config.https_port, 443)
        origin_protocol_policy = try(origin.value.origin_config.protocol, "https-only")
        origin_ssl_protocols   = try(origin.value.origin_config.ssl_protocols, ["TLSv1.2"])
      }
    }
  }

  default_cache_behavior {
    allowed_methods  = try(local.primary_cache_behavior.allowed_methods, var.distribution.primary_origin_type == "s3" ? ["GET", "HEAD"] : ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"])
    cached_methods   = try(local.primary_cache_behavior.cached_methods, ["GET", "HEAD"])
    target_origin_id = var.distribution.primary_origin_type == "s3" ? local.primary_s3_origin.origin_id : var.distribution.alb_origin.origin_id

    dynamic "forwarded_values" {
      for_each = local.default_cache_behavior_cache_policy_id == "" ? [1] : []
      content {
        query_string = var.distribution.primary_origin_type == "s3" ? try(local.primary_cache_behavior.query_string, false) : try(local.primary_cache_behavior.query_string, true)
        headers      = var.distribution.primary_origin_type == "alb" ? ["*"] : null
        cookies {
          forward = var.distribution.primary_origin_type == "s3" ? try(local.primary_cache_behavior.cookies_forward, "none") : try(local.primary_cache_behavior.cookies_forward, "all")
        }
      }
    }

    compress        = try(local.primary_cache_behavior.compress, false)
    cache_policy_id = local.default_cache_behavior_cache_policy_id != "" ? local.default_cache_behavior_cache_policy_id : null
    min_ttl         = local.default_cache_behavior_cache_policy_id == "" ? try(local.primary_cache_behavior.min_ttl, 0) : 0
    default_ttl     = local.default_cache_behavior_cache_policy_id == "" ? try(local.primary_cache_behavior.default_ttl, 0) : 0
    max_ttl         = local.default_cache_behavior_cache_policy_id == "" ? try(local.primary_cache_behavior.max_ttl, 0) : 0

    viewer_protocol_policy = var.distribution.primary_origin_type == "s3" ? try(local.primary_cache_behavior.viewer_protocol, "redirect-to-https") : try(local.primary_cache_behavior.viewer_protocol, "https-only")

    dynamic "function_association" {
      for_each = try(local.primary_cache_behavior.function_associations, [])
      content {
        function_arn = function_association.value.function_arn
        event_type   = function_association.value.event_type
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.distribution.ordered_cache_behaviors
    content {
      path_pattern     = ordered_cache_behavior.value.path_pattern
      allowed_methods  = try(ordered_cache_behavior.value.allowed_methods, ["GET", "HEAD"])
      cached_methods   = try(ordered_cache_behavior.value.cached_methods, ["GET", "HEAD"])
      target_origin_id = ordered_cache_behavior.value.target_origin_id
      compress         = try(ordered_cache_behavior.value.compress, false)

      dynamic "forwarded_values" {
        for_each = try(ordered_cache_behavior.value.cache_policy_id, "") == "" ? [1] : []
        content {
          query_string = try(ordered_cache_behavior.value.forwarded_values.query_string, false)
          headers      = length(try(ordered_cache_behavior.value.forwarded_values.headers, [])) > 0 ? ordered_cache_behavior.value.forwarded_values.headers : null
          cookies {
            forward           = try(ordered_cache_behavior.value.forwarded_values.cookies, "none")
            whitelisted_names = try(ordered_cache_behavior.value.forwarded_values.whitelisted_cookies, [])
          }
        }
      }

      cache_policy_id = try(ordered_cache_behavior.value.cache_policy_id, "") != "" ? ordered_cache_behavior.value.cache_policy_id : null
      min_ttl         = try(ordered_cache_behavior.value.cache_policy_id, "") == "" ? try(ordered_cache_behavior.value.min_ttl, 0) : 0
      default_ttl     = try(ordered_cache_behavior.value.cache_policy_id, "") == "" ? try(ordered_cache_behavior.value.default_ttl, 0) : 0
      max_ttl         = try(ordered_cache_behavior.value.cache_policy_id, "") == "" ? try(ordered_cache_behavior.value.max_ttl, 0) : 0

      viewer_protocol_policy = try(ordered_cache_behavior.value.viewer_protocol, "redirect-to-https")

      dynamic "function_association" {
        for_each = try(ordered_cache_behavior.value.function_associations, [])
        content {
          function_arn = function_association.value.function_arn
          event_type   = function_association.value.event_type
        }
      }

      dynamic "lambda_function_association" {
        for_each = try(ordered_cache_behavior.value.lambda_function_associations, [])
        content {
          event_type = lambda_function_association.value.event_type
          lambda_arn = "${lambda_function_association.value.lambda_arn}:${lambda_function_association.value.lambda_version}"
        }
      }
    }
  }

  price_class = try(var.distribution.cloudfront_settings.price_class, "PriceClass_200")

  restrictions {
    geo_restriction {
      restriction_type = try(var.distribution.cloudfront_settings.restriction, "none")
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = try(var.distribution.cloudfront_settings.acm_certificate_arn, "") == ""
    acm_certificate_arn            = try(var.distribution.cloudfront_settings.acm_certificate_arn, "") != "" ? var.distribution.cloudfront_settings.acm_certificate_arn : null
    ssl_support_method             = try(var.distribution.cloudfront_settings.acm_certificate_arn, "") != "" ? "sni-only" : null
    minimum_protocol_version       = try(var.distribution.cloudfront_settings.acm_certificate_arn, "") != "" ? try(var.distribution.cloudfront_settings.minimum_protocol_version, "TLSv1.2_2021") : "TLSv1"
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
