output "arn" {
  description = "ARN de la CloudFront Function"
  value       = aws_cloudfront_function.this.arn
}

output "name" {
  description = "Nombre de la CloudFront Function"
  value       = aws_cloudfront_function.this.name
}

output "etag" {
  description = "ETag de la CloudFront Function"
  value       = aws_cloudfront_function.this.etag
}
