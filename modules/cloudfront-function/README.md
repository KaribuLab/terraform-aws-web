# CloudFront Function Submódulo

Submódulo para crear una CloudFront Function en AWS.

## Uso

```hcl
module "cloudfront_function" {
  source = "./modules/cloudfront-function"

  name    = "my-viewer-request-function"
  code    = file("${path.module}/function.js")
  runtime = "cloudfront-js-1.0"
  comment = "Función para reescribir URLs"
  publish = true
}
```

## Inputs

| Nombre  | Tipo   | Descripción                                              | Requerido | Default             |
|---------|--------|----------------------------------------------------------|-----------|---------------------|
| name    | string | Nombre de la CloudFront Function                         | Sí        | -                   |
| code    | string | Código JavaScript de la función                          | Sí        | -                   |
| runtime | string | Runtime de la función                                    | No        | cloudfront-js-1.0   |
| comment | string | Comentario opcional                                      | No        | ""                  |
| publish | bool   | Publicar la función automáticamente                      | No        | true                |

## Outputs

| Nombre | Descripción                    |
|--------|--------------------------------|
| arn    | ARN de la CloudFront Function  |
| name   | Nombre de la CloudFront Function |
| etag   | ETag de la CloudFront Function |
