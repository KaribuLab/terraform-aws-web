resource "aws_s3_bucket" "s3_origin" {
  count = var.distribution.s3_origin != null ? 1 : 0
  bucket = var.distribution.s3_origin[count.index].bucket_name
  tags   = var.common_tags
}

resource "aws_cloudfront_origin_access_control" "s3_origin" {
  count = var.distribution.s3_origin != null ? 1 : 0
  name                              = "${var.distribution.s3_origin[count.index].bucket_name}-oac"
  description                       = var.distribution.description
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_public_access_block" "s3_origin" {
  count = var.distribution.s3_origin != null ? 1 : 0
  bucket = aws_s3_bucket.s3_origin[count.index].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_distribution" "distribution" {
  comment             = var.distribution.description
  enabled             = try(var.distribution.cloudfront_settings.enabled, var.distribution_enabled)
  default_root_object = try(var.distribution.cloudfront_settings.root_object, var.distribution_root_object)
  aliases             = try(var.distribution.cloudfront_settings.aliases, var.distribution_aliases)

  dynamic "origin" {
    for_each = var.distribution.s3_origin != null ? [1] : []
    content {
      domain_name              = aws_s3_bucket.s3_origin[0].bucket_regional_domain_name
      origin_id                = aws_s3_bucket.s3_origin[0].bucket
      origin_access_control_id = aws_cloudfront_origin_access_control.s3_origin[0].id
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
    allowed_methods  = var.distribution.primary_origin_type == "s3" ? try(var.distribution.s3_origin.cache_behavior.allowed_methods, var.s3_origin_allowed_methods) : try(var.distribution.alb_origin.cache_behavior.allowed_methods, var.alb_origin_allowed_methods)
    cached_methods   = var.distribution.primary_origin_type == "s3" ? try(var.distribution.s3_origin.cache_behavior.cached_methods, var.s3_origin_cached_methods) : try(var.distribution.alb_origin.cache_behavior.cached_methods, var.alb_origin_cached_methods)
    target_origin_id = var.distribution.primary_origin_type == "s3" ? aws_s3_bucket.s3_origin[0].bucket : var.distribution.alb_origin.origin_id
    
    forwarded_values {
      query_string = var.distribution.primary_origin_type == "s3" ? try(var.distribution.s3_origin.cache_behavior.query_string, var.s3_origin_query_string) : try(var.distribution.alb_origin.cache_behavior.query_string, var.alb_origin_query_string)
      headers      = var.distribution.primary_origin_type == "alb" ? ["*"] : null
      
      cookies {
        forward = var.distribution.primary_origin_type == "s3" ? try(var.distribution.s3_origin.cache_behavior.cookies, var.s3_origin_cookies) : "all"
      }
    }

    compress = var.distribution.default_cache_behavior_compress
    
    viewer_protocol_policy = var.distribution.primary_origin_type == "s3" ? try(var.distribution.s3_origin.cache_behavior.viewer_protocol, var.s3_origin_viewer_protocol) : try(var.distribution.alb_origin.cache_behavior.viewer_protocol, var.alb_origin_viewer_protocol)
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.distribution.primary_origin_type == "alb" && var.distribution.s3_origin != null ? [var.distribution.s3_origin] : []
    content {
      path_pattern     = ordered_cache_behavior.value.path_pattern
      allowed_methods  = try(ordered_cache_behavior.value.cache_behavior.allowed_methods, var.s3_origin_allowed_methods)
      cached_methods   = try(ordered_cache_behavior.value.cache_behavior.cached_methods, var.s3_origin_cached_methods)
      target_origin_id = aws_s3_bucket.s3_origin[0].bucket
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
      target_origin_id = aws_s3_bucket.s3_origin[0].bucket
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
  
  tags = var.common_tags
}


resource "aws_s3_bucket_policy" "s3_origin" {
  count = var.distribution.s3_origin != null ? 1 : 0
  bucket = aws_s3_bucket.s3_origin[count.index].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "${uuid()}"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.s3_origin[count.index].bucket}/*"
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
