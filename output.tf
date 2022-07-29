output origin_id {
  value = aws_cloudfront_distribution.aws_frontend[*].id
}

output domain_name {
  value = aws_cloudfront_distribution.aws_frontend[*].domain_name
}
