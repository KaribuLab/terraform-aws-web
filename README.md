# Terraform - AWS Web Module

## Uso

### Input

| Parámetro    | Tipo        | Descripción              | Requerido |
| ------------ | ----------- | ------------------------ | --------- |
| common_tags  | map(string) | Tags de los recursos     | Si        |
| distribution | object      | Datos de la distribución | Si        |

#### distribution

| Campo                                       | Tipo                   | Descripción                                                                                                               | Requirido |
| ------------------------------------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------- | --------- |
| s3_orign                                    | string                 | Origen usado como CDN u Origen por defecto de la distribución                                                             | Si        |
| description                                 | string                 | Descripción de la distribución                                                                                            | Si        |
| behavior_patterns                           | optional(list(string)) | Patrones usados en el caso de que se use `s3_origin` como CDN                                                             | No        |
| [lambda_association](#lambda_association)   | optional(list(object)) | Configuración para asociar funciones lambdas a un cache behaviour                                                         | No        |
| [api_gateway_origins](#api_gateway_origins) | optional(list(object)) | Objeto que contiene los parámetros usados para asociar recursos de API Gateway como *"Cache Behavior"* de la distribución | No        |

#### lambda_association

| Campo                  | Tipo                   | Descripción                                                                               | Requerido |
| ---------------------- | ---------------------- | ----------------------------------------------------------------------------------------- | --------- |
| path_pattern           | string                 | Path pattern asociado al cache behaviour                                                  | Si        |
| allowed_methods        | list(string)           | Métodos HTTP permitidos                                                                   | Si        |
| cached_methods         | list(string)           | Métodos HTTP para caching                                                                 | Si        |
| query_string           | bool                   | Habilita query string                                                                     | Si        |
| headers                | list(string)           | Headers soportados que serán propagados                                                   | Si        |
| event_type             | string                 | Tipo de evento (`viewer-request`, `viewer-reponse`, `origin-request` y `origin-response`) | Si        |
| lambda_arn             | string                 | ARN de la función lambda                                                                  | Si        |
| lambda_version         | string                 | Versión de la función lambda                                                              | Si        |
| viewer_protocol_policy | string                 | Pólitica de las peticiones que llegan al viewer (`redirect-to-https`)                     | Si        |
| cookies                | optional(list(string)) | Lista de cookies que se propagarán                                                        | No        |

#### api_gateway_origins

| Campo        | Tipo         | Descripción                                                                                                  | Requirido |
| ------------ | ------------ | ------------------------------------------------------------------------------------------------------------ | --------- |
| domain_name  | string       | Dominio autogenerado para API Gateway                                                                        | Si        |
| path_pattern | string       | Patrón para mapear peticiones de CloudFront con recurso de API Gateway                                       | Si        |
| origin_id    | string       | ID del origen asociado al API Gateway                                                                        | Si        |
| origin_path  | string       | Ruta principal del origin                                                                                    | Si        |
| headers      | list(string) | Lista de headers que deben llegar al recurso del API Gateway (Los que no estén en esta lista serán omitidos) | Si        |
| cookies      | list(string) | Lista de cookies que deben llegar al recurso del API Gateway (Las que no estén en esta lista serán omitidas) | Si        |

### Output

| Nombre | Descripción |
|--------|-------------|
| origin_id | ID de la distribución CloudFront |
| domain_name | Nombre de dominio de la distribución CloudFront |
| distribution_arn | ARN (Amazon Resource Name) de la distribución CloudFront |

## Desarrollo

### Requisitos

- Terraform versión 0.12 o superior
- AWS CLI 1.2 o superior
- Credenciales de AWS CLI

### Pruebas

Para probar el módulo de forma local, se deben crear 2 archivos:

`terraform.tfvars` y `.env` como se muestra a continuación:

```terraform
# Archivo terraform.tfvars
common_tags = {
  "project" = "Hello World"
}

distribution = {
  description = "Hello World"
  s3_origin = "karibu-hello-world"
}
```

```shell
# Archivo .env
export AWS_SECRET_ACCESS_KEY=C9xhhXCcY4g7LJYUyXvztdVTE7tjvtXL6JsenjTb
export AWS_ACCESS_KEY_ID=LSDRWKXCQPHQJFDMXGYK
export AWS_DEFAULT_REGION=us-east-1
```

Luego para ejecutar el modulo deberá cargar las variables de ambiente de AWS usando el siguiente comando:

```shell
. .env
```

Posteriormente deberá inicializar el módulo, cargar el plan de ejecución y aplicar las instrucciones del módulo:

```shell
terraform init
terraform plan
terraform apply
```

> En el último paso deberá confirmar si desea aplicar los cambios

Para destruir la infraestructura creada ejecute el comando `terraform destroy` y por último apruebe la ejecución.

## Configuración de orígenes

Este módulo permite configurar varios tipos de orígenes para tu distribución CloudFront con toda la configuración concentrada en un solo objeto:

### Estructura de configuración mejorada

La nueva estructura concentra toda la configuración en el objeto `distribution`:

```hcl
distribution = {
  # Configuración general
  description        = "Mi distribución CloudFront"
  primary_origin_type = "alb"    # "s3" o "alb"
  enabled            = true
  root_object        = "index.html"
  aliases            = ["www.midominio.com"]
  price_class        = "PriceClass_200"
  restriction        = "none"
  certificate        = true
  
  # Configuración del origen S3
  s3_origin = {
    # Propiedades básicas
    bucket_name  = "mi-bucket-origen"
    path_pattern = "/static/*"
    enabled      = true
    
    # Comportamiento de caché
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]
    query_string    = false
    cookies         = "none"
    viewer_protocol = "redirect-to-https"
  }
  
  # Configuración del origen ALB
  alb_origin = {
    # Propiedades básicas
    domain_name = "mi-alb.us-east-1.elb.amazonaws.com"
    origin_id   = "mi-alb-origen"
    origin_path = ""
    path_pattern = "/api/*"
    enabled     = true
    
    # Configuración de origen personalizado
    http_port     = 80
    https_port    = 443
    protocol      = "https-only"
    ssl_protocols = ["TLSv1.2"]
    
    # Comportamiento de caché
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]
    viewer_protocol = "https-only"
    query_string    = true
  }
}
```

### Caso 1: S3 como origen primario

Si deseas que S3 sea el origen predeterminado:

```hcl
distribution = {
  description        = "Mi distribución"
  primary_origin_type = "s3"
  
  s3_origin = {
    bucket_name = "mi-bucket-origen"
    enabled     = true
    
    # Configuración específica de S3
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]
    viewer_protocol = "redirect-to-https"
  }
  
  alb_origin = {
    domain_name  = "mi-alb.us-east-1.elb.amazonaws.com"
    origin_id    = "mi-alb-origen"
    path_pattern = "/api/*"
    enabled      = true
  }
}
```

### Caso 2: ALB como origen primario

Si deseas que el ALB sea el origen predeterminado:

```hcl
distribution = {
  description        = "Mi distribución"
  primary_origin_type = "alb"
  
  alb_origin = {
    domain_name = "mi-alb.us-east-1.elb.amazonaws.com"
    origin_id   = "mi-alb-origen"
    enabled     = true
    
    # Configuración específica del ALB
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]
    viewer_protocol = "https-only"
  }
  
  s3_origin = {
    bucket_name  = "mi-bucket-origen"
    path_pattern = "/static/*"
    enabled      = true
  }
}
