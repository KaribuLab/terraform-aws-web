output "origin_id" {
  value = aws_cloudfront_distribution.distribution.id
}

output "domain_name" {
  value = aws_cloudfront_distribution.distribution.domain_name
}

output "distribution_arn" {
  value = aws_cloudfront_distribution.distribution.arn
}
