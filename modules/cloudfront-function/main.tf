resource "aws_cloudfront_function" "this" {
  name    = var.name
  code    = var.code
  runtime = var.runtime
  comment = var.comment
  publish = var.publish
}
