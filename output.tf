output "origin_id" {
  value = aws_cloudfront_distribution.distribution.id
}

output "domain_name" {
  value = aws_cloudfront_distribution.distribution.domain_name
}

output "distribution_arn" {
  value = aws_cloudfront_distribution.distribution.arn
}

output "s3_bucket_ids" {
  description = "Mapa de origin_id a bucket_id para todos los orígenes S3 creados"
  value       = { for k, v in aws_s3_bucket.s3_origin : k => v.id }
}

output "s3_origin_ids" {
  description = "Lista de origin_ids de todos los orígenes S3 configurados en CloudFront"
  value       = keys(local.s3_origins_map)
}

output "primary_s3_origin_id" {
  description = "Origin ID del origen S3 primario (usado en default_cache_behavior)"
  value       = local.primary_s3_origin != null ? local.primary_s3_origin.origin_id : null
}
