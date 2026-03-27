variable "name" {
  type        = string
  description = "Nombre de la CloudFront Function"
}

variable "code" {
  type        = string
  description = "Código JavaScript de la función"
}

variable "runtime" {
  type        = string
  default     = "cloudfront-js-1.0"
  description = "Runtime de la función. Por defecto: cloudfront-js-1.0"
}

variable "comment" {
  type        = string
  default     = ""
  description = "Comentario opcional para la función"
}

variable "publish" {
  type        = bool
  default     = true
  description = "Publicar la función automáticamente. Por defecto: true"
}
