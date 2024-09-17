resource "aws_s3_bucket" "s3_origin" {
  bucket = var.distribution.s3_origin
  tags   = var.common_tags
}

resource "aws_cloudfront_origin_access_control" "s3_origin" {
  name                              = "${var.distribution.s3_origin}-oac"
  description                       = var.distribution.description
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_public_access_block" "s3_origin" {
  bucket = aws_s3_bucket.s3_origin.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_distribution" "distribution" {

  comment             = var.distribution.description
  enabled             = var.distribution_enabled
  default_root_object = var.distribution_root_object
  aliases             = var.distribution_aliases

  origin {
    domain_name              = aws_s3_bucket.s3_origin.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.s3_origin.bucket
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_origin.id
  }

  dynamic "origin" {
    for_each = var.distribution.api_gateway_origins != null ? var.distribution.api_gateway_origins : []
    content {
      domain_name = origin.value.domain_name
      origin_id   = origin.value.origin_id
      origin_path = origin.value.origin_path
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
    target_origin_id = aws_s3_bucket.s3_origin.bucket
    forwarded_values {
      query_string = var.s3_origin_query_string
      cookies {
        forward = var.s3_origin_cookies
      }
    }
    viewer_protocol_policy = var.s3_origin_viewer_protocol
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.distribution.behavior_patterns != null ? var.distribution.behavior_patterns : []
    content {
      path_pattern     = ordered_cache_behavior.value
      allowed_methods  = var.s3_origin_allowed_methods
      cached_methods   = var.s3_origin_cached_methods
      target_origin_id = aws_s3_bucket.s3_origin.bucket
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
    for_each = var.distribution.api_gateway_origins != null ? var.distribution.api_gateway_origins : []
    content {
      path_pattern     = ordered_cache_behavior.value.path_pattern
      allowed_methods  = var.api_gateway_origin_allowed_methods
      cached_methods   = var.api_gateway_origin_cached_methods
      target_origin_id = ordered_cache_behavior.value.origin_id
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

  price_class = var.distribution_price_class

  restrictions {
    geo_restriction {
      restriction_type = var.distribution_restriction
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = var.distribution_certificate
  }
  tags = var.common_tags
}


resource "aws_s3_bucket_policy" "s3_origin" {
  bucket = aws_s3_bucket.s3_origin.id
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
          "arn:aws:s3:::${aws_s3_bucket.s3_origin.bucket}/*"
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
