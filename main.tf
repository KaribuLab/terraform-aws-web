terraform {
  backend "s3" {}
}

locals {
  default_s3_origin = var.default_s3_origin == "" ? tolist([]) : [var.default_s3_origin]
  distributions     = var.frontend_distribution
  environment_metadata = {
    development = {
      name = "Desarrollo"
      code = "dev"
    }
    production = {
      name = "Produccion"
      code = "prod"
    }

    testing = {
      name = "Testing"
      code = "test"
    }
  }
  common_tags = {
    project_name = var.tag_project_name
    customer     = var.tag_customer_name
    team         = var.tag_team_name
    environment  = var.tag_environment
  }
}

resource "aws_s3_bucket" "default_s3_origin" {
  count  = length(local.default_s3_origin)
  bucket = "${local.default_s3_origin[count.index]}-${lookup(local.environment_metadata, var.tag_environment).code}"
  tags   = local.common_tags
}

resource "aws_s3_bucket" "s3_origin" {
  count  = length(local.distributions)
  bucket = "${local.distributions[count.index].s3_origin}-${lookup(local.environment_metadata, var.tag_environment).code}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_policy" "default_s3_origin" {
  count  = length(local.default_s3_origin)
  bucket = aws_s3_bucket.default_s3_origin[count.index].id
  policy =  jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "${uuid()}"
        Principal = "*"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.default_s3_origin[count.index].bucket}/*",
          "arn:aws:s3:::${aws_s3_bucket.default_s3_origin[count.index].bucket}"
        ]
      },
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.default_s3_origin]
}

resource "aws_s3_bucket_public_access_block" "default_s3_origin" {
  count  = length(local.default_s3_origin)
  bucket = aws_s3_bucket.default_s3_origin[count.index].id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_public_access_block" "s3_origin" {
  count  = length(local.distributions)
  bucket = aws_s3_bucket.s3_origin[count.index].id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "s3_default_origin" {
  count  = length(local.default_s3_origin)
  bucket = aws_s3_bucket.default_s3_origin[count.index].id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
  depends_on = [aws_s3_bucket_public_access_block.default_s3_origin]
}

resource "aws_s3_bucket_ownership_controls" "s3_origin" {
  count  = length(local.distributions)
  bucket = aws_s3_bucket.s3_origin[count.index].id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
  depends_on = [aws_s3_bucket_public_access_block.s3_origin]
}


resource "aws_s3_bucket_policy" "s3_origin" {
  count  = length(local.distributions)
  bucket = aws_s3_bucket.s3_origin[count.index].id
  policy =  jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "${uuid()}"
        Principal = "*"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.s3_origin[count.index].bucket}/*",
          "arn:aws:s3:::${aws_s3_bucket.s3_origin[count.index].bucket}"
        ]
      },
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.s3_origin]
}

resource "aws_cloudfront_distribution" "aws_frontend" {
  count = length(local.distributions) == 0 ? 1 : length(local.distributions)

  comment             = length(local.distributions) > 0 ? (local.distributions[count.index].description == "" ? "Ambiente de ${lookup(local.environment_metadata, var.tag_environment).name} proyecto ${var.tag_project_name}" : "${local.distributions[count.index].description} - Ambiente de ${lookup(local.environment_metadata, var.tag_environment).name}") : "${var.default_s3_origin} - Ambiente de ${lookup(local.environment_metadata, var.tag_environment).name}"
  enabled             = var.distribution_enabled
  default_root_object = var.distribution_root_object
  aliases             = var.distribution_aliases

  dynamic "origin" {
    for_each = local.default_s3_origin
    content {
      domain_name = aws_s3_bucket.default_s3_origin[0].bucket_regional_domain_name
      origin_id   = aws_s3_bucket.default_s3_origin[0].bucket
    }
  }

  dynamic "origin" {
    for_each    = aws_s3_bucket.s3_origin
    content {
      domain_name = origin.value.bucket_regional_domain_name
      origin_id   = origin.value.bucket
    }
  }

  dynamic "origin" {
    for_each = length(local.distributions) > 0 ? local.distributions[count.index].api_gateway_origins : []
    content {
      domain_name = origin.value.domain_name
      origin_id   = "${origin.value.origin_id}-${lookup(local.environment_metadata, var.tag_environment).code}"
      origin_path = "/${lookup(local.environment_metadata, var.tag_environment).code}"
      custom_origin_config {
        http_port              = var.api_gateway_origin_http_port
        https_port             = var.api_gateway_origin_https_port
        origin_protocol_policy = var.api_gateway_origin_protocol
        origin_ssl_protocols   = var.api_gateway_origin_ssl_protocols
      }
    }
  }

  default_cache_behavior {
    allowed_methods  = var.s3_origin_allowed_methods
    cached_methods   = var.s3_origin_cached_methods
    target_origin_id = length(aws_s3_bucket.default_s3_origin) > 0 ? aws_s3_bucket.default_s3_origin[0].bucket : aws_s3_bucket.s3_origin[count.index].bucket
    forwarded_values {
      query_string = var.s3_origin_query_string
      cookies {
        forward = var.s3_origin_cookies
      }
    }
    viewer_protocol_policy = var.s3_origin_viewer_protocol
  }

  dynamic "ordered_cache_behavior" {
    for_each = length(local.distributions) > 0 ? local.distributions[count.index].behavior_patterns : []
    content {
      path_pattern     = ordered_cache_behavior.value
      allowed_methods  = var.s3_origin_allowed_methods
      cached_methods   = var.s3_origin_cached_methods
      target_origin_id = aws_s3_bucket.s3_origin[count.index].bucket
      forwarded_values {
        query_string = var.s3_origin_query_string
        cookies {
          forward = var.s3_origin_cookies
        }
      }
      viewer_protocol_policy = var.s3_origin_viewer_protocol
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = length(local.distributions) > 0 ? local.distributions[count.index].api_gateway_origins: []
    content {
      path_pattern     = ordered_cache_behavior.value.path_pattern
      allowed_methods  = var.api_gateway_origin_allowed_methods
      cached_methods   = var.api_gateway_origin_cached_methods
      target_origin_id = "${ordered_cache_behavior.value.origin_id}-${lookup(local.environment_metadata, var.tag_environment).code}"
      forwarded_values {
        query_string = var.api_gateway_origin_query_string
        headers      = ordered_cache_behavior.value.headers
        cookies {
          forward           = length(ordered_cache_behavior.value.cookies) > 0 ? "whitelist" : "none"
          whitelisted_names = ordered_cache_behavior.value.cookies
        }
      }
      viewer_protocol_policy = var.api_gateway_origin_viewer_protocol
    }
  }

  custom_error_response {
    error_code         = var.s3_origin_not_found_code
    response_code      = var.s3_origin_ok_code
    response_page_path = var.distribution_root_object
  }

  price_class = var.distribution_price_class

  restrictions {
    geo_restriction {
      restriction_type = var.distribution_restriction
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = var.distribution_certificate
  }
  tags = local.common_tags
}
