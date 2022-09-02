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

resource "aws_s3_bucket_acl" "default_s3_origin" {
  acl    = var.default_bucket_acl
  bucket = aws_s3_bucket.default_s3_origin.bucket
}

resource "aws_s3_bucket" "s3_origin" {
  count  = length(local.distributions)
  bucket = "${local.distributions[count.index].s3_origin}-${lookup(local.environment_metadata, var.tag_environment).code}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_acl" "s3_origin" {
  acl    = var.default_bucket_acl
  bucket = aws_s3_bucket.s3_origin.bucket
}

resource "aws_s3_bucket_policy" "default_s3_origin" {
  count  = length(local.default_s3_origin)
  bucket = aws_s3_bucket.default_s3_origin[count.index].id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Id": "s3-${local.default_s3_origin[count.index]}-policy-${lookup(local.environment_metadata, var.tag_environment).code}",
  "Statement": [
    {
      "Sid": "CloudFrontAllow",
      "Effect": "Allow",
      "Principal": {"AWS":"*"},
      "Action": [
        "s3:ListBucket",
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.default_s3_origin[count.index].bucket}/*",
        "arn:aws:s3:::${aws_s3_bucket.default_s3_origin[count.index].bucket}"
      ]
    }
  ]
}
EOF
}

resource "aws_s3_bucket_policy" "s3_origin" {
  count  = length(local.distributions)
  bucket = aws_s3_bucket.s3_origin[count.index].id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Id": "s3-${local.distributions[count.index].s3_origin}-policy-${lookup(local.environment_metadata, var.tag_environment).code}",
  "Statement": [
    {
      "Sid": "CloudFrontAllow",
      "Effect": "Allow",
      "Principal": {"AWS":"*"},
      "Action": [
        "s3:ListBucket",
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.s3_origin[count.index].bucket}/*",
        "arn:aws:s3:::${aws_s3_bucket.s3_origin[count.index].bucket}"
      ]
    }
  ]
}
EOF
}

resource "aws_cloudfront_distribution" "aws_frontend" {
  count = length(local.distributions)

  comment             = local.distributions[count.index].description == "" ? "Ambiente de ${lookup(local.environment_metadata, var.tag_environment).name} proyecto ${var.tag_project_name}" : "${local.distributions[count.index].description} - Ambiente de ${lookup(local.environment_metadata, var.tag_environment).name}"
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

  origin {
    domain_name = aws_s3_bucket.s3_origin[count.index].bucket_regional_domain_name
    origin_id   = aws_s3_bucket.s3_origin[count.index].bucket
  }

  dynamic "origin" {
    for_each = local.distributions[count.index].api_gateway_origins
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
    for_each = local.distributions[count.index].behavior_patterns
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
    for_each = local.distributions[count.index].api_gateway_origins
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
