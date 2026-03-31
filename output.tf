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

output "distribution_id" {
  description = "ID de la distribución CloudFront (el output 'origin_id' es un alias histórico)"
  value       = aws_cloudfront_distribution.distribution.id
}

output "terragrunt_cloudfront_function_context" {
  description = "Contexto para uso en Terragrunt al crear CloudFront Functions asociadas"
  value = {
    distribution_id  = aws_cloudfront_distribution.distribution.id
    distribution_arn = aws_cloudfront_distribution.distribution.arn
    domain_name      = aws_cloudfront_distribution.distribution.domain_name
    description      = var.distribution.description
    common_tags      = var.common_tags
  }
}

output "suggested_cloudfront_function_name" {
  description = "Nombre sugerido para una CloudFront Function basado en la distribución (convención, puede ignorarse)"
  value       = "cf-function-${aws_cloudfront_distribution.distribution.id}"
}
