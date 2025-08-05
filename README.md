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
| description                                 | string                 | Descripción de la distribución                                                                                            | Si        |
| primary_origin_type                         | optional(string)       | Tipo de origen primario: "s3" o "alb". Por defecto: "s3"                                                                  | No        |
| default_cache_behavior_compress             | optional(bool)         | Habilitar compresión para el comportamiento de caché predeterminado. Por defecto: false                                   | No        |
| default_cache_behavior_min_ttl              | optional(number)       | Tiempo mínimo de vida (TTL) para el comportamiento de caché predeterminado en segundos. Por defecto: 0                    | No        |
| default_cache_behavior_default_ttl          | optional(number)       | Tiempo de vida (TTL) predeterminado para el comportamiento de caché en segundos. Por defecto: 0                          | No        |
| default_cache_behavior_max_ttl              | optional(number)       | Tiempo máximo de vida (TTL) para el comportamiento de caché predeterminado en segundos. Por defecto: 0                    | No        |
| default_cache_behavior_cache_policy_id      | optional(string)       | ID de la política de caché de CloudFront. Por defecto: "658327ea-f89d-47f2-9698-9013ddb722e4" (CachingDisabled)           | No        |
| cloudfront_settings                         | optional(object)       | Configuración general de la distribución CloudFront                                                                       | No        |
| s3_origin                                   | optional(object)       | Configuración del origen S3                                                                                               | No        |
| alb_origin                                  | optional(object)       | Configuración del origen ALB                                                                                              | No        |
| [lambda_association](#lambda_association)   | optional(list(object)) | Configuración para asociar funciones lambdas a un cache behaviour                                                         | No        |
| [api_gateway_origins](#api_gateway_origins) | optional(list(object)) | Objeto que contiene los parámetros usados para asociar recursos de API Gateway como *"Cache Behavior"* de la distribución | No        |

#### cloudfront_settings

| Campo        | Tipo                | Descripción                                         | Requerido |
| ------------ | ------------------- | --------------------------------------------------- | --------- |
| enabled      | optional(bool)      | Habilitar la distribución. Por defecto: true        | No        |
| root_object  | optional(string)    | Objeto raíz. Por defecto: "index.html"              | No        |
| aliases      | optional(list(any)) | Alias para la distribución. Por defecto: []         | No        |
| price_class  | optional(string)    | Clase de precio. Por defecto: "PriceClass_200"      | No        |
| restriction  | optional(string)    | Restricción geográfica. Por defecto: "none"         | No        |
| certificate  | optional(bool)      | Usar certificado SSL/TLS. Por defecto: true         | No        |

#### s3_origin

| Campo        | Tipo              | Descripción                                    | Requerido |
| ------------ | ----------------- | ---------------------------------------------- | --------- |
| bucket_name  | string            | Nombre del bucket S3                           | Si        |
| path_pattern | optional(string)  | Patrón de ruta. Por defecto: "/static/*"       | No        |
| cache_behavior | optional(object) | Configuración del comportamiento de caché      | No        |

#### s3_origin.cache_behavior

| Campo           | Tipo                 | Descripción                                                      | Requerido |
| --------------- | -------------------- | ---------------------------------------------------------------- | --------- |
| allowed_methods | optional(list(any))  | Métodos HTTP permitidos. Por defecto: ["GET", "HEAD"]            | No        |
| cached_methods  | optional(list(any))  | Métodos HTTP para caching. Por defecto: ["GET", "HEAD"]          | No        |
| query_string    | optional(bool)       | Habilita query string. Por defecto: false                        | No        |
| cookies         | optional(string)     | Manejo de cookies. Por defecto: "none"                           | No        |
| viewer_protocol | optional(string)     | Política de protocolo del viewer. Por defecto: "redirect-to-https" | No     |

#### alb_origin

| Campo        | Tipo              | Descripción                                  | Requerido |
| ------------ | ----------------- | -------------------------------------------- | --------- |
| domain_name  | string            | Dominio del ALB                              | Si        |
| origin_id    | string            | ID del origen                                | Si        |
| origin_path  | optional(string)  | Ruta principal del origen. Por defecto: ""   | No        |
| path_pattern | optional(string)  | Patrón de ruta. Por defecto: "/api/*"        | No        |
| origin_config | optional(object) | Configuración del origen                     | No        |
| cache_behavior | optional(object) | Configuración del comportamiento de caché    | No        |

#### alb_origin.origin_config

| Campo         | Tipo                   | Descripción                                           | Requerido |
| ------------- | ---------------------- | ----------------------------------------------------- | --------- |
| http_port     | optional(number)       | Puerto HTTP. Por defecto: 80                          | No        |
| https_port    | optional(number)       | Puerto HTTPS. Por defecto: 443                        | No        |
| protocol      | optional(string)       | Protocolo de origen. Por defecto: "https-only"        | No        |
| ssl_protocols | optional(list(string)) | Protocolos SSL. Por defecto: ["TLSv1.2"]              | No        |

#### alb_origin.cache_behavior

| Campo           | Tipo                   | Descripción                                                                | Requerido |
| --------------- | ---------------------- | -------------------------------------------------------------------------- | --------- |
| allowed_methods | optional(list(string)) | Métodos HTTP permitidos. Por defecto: ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"] | No |
| cached_methods  | optional(list(string)) | Métodos HTTP para caching. Por defecto: ["GET", "HEAD"]                    | No        |
| viewer_protocol | optional(string)       | Política de protocolo del viewer. Por defecto: "https-only"                | No        |
| query_string    | optional(bool)         | Habilita query string. Por defecto: true                                   | No        |

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
| origin_id    | string       | ID del origen asociado al API Gateway                                                                        | Si        |
| origin_path  | string       | Ruta principal del origin                                                                                    | Si        |
| path_pattern | string       | Patrón para mapear peticiones de CloudFront con recurso de API Gateway                                       | Si        |
| headers      | list(string) | Lista de headers que deben llegar al recurso del API Gateway (Los que no estén en esta lista serán omitidos) | Si        |
| cookies      | list(string) | Lista de cookies que deben llegar al recurso del API Gateway (Las que no estén en esta lista serán omitidas) | Si        |
| origin_config | optional(object) | Configuración del origen                                                                               | No        |
| cache_behavior | optional(object) | Configuración del comportamiento de caché                                                             | No        |

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
  s3_origin = {
    bucket_name = "karibu-hello-world"
  }
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
  description         = "Mi distribución CloudFront"
  primary_origin_type = "alb"    # "s3" o "alb"
  
  # Configuración del comportamiento de caché predeterminado
  default_cache_behavior_compress = true
  default_cache_behavior_min_ttl = 0
  default_cache_behavior_default_ttl = 3600
  default_cache_behavior_max_ttl = 86400
  default_cache_behavior_cache_policy_id = "658327ea-f89d-47f2-9698-9013ddb722e4" # CachingDisabled
  
  cloudfront_settings = {
    enabled     = true
    root_object = "index.html"
    aliases     = ["www.midominio.com"]
    price_class = "PriceClass_200"
    restriction = "none"
    certificate = true
  }
  
  # Configuración del origen S3
  s3_origin = {
    # Propiedades básicas
    bucket_name  = "mi-bucket-origen"
    path_pattern = "/static/*"
    
    # Comportamiento de caché
    cache_behavior = {
      allowed_methods = ["GET", "HEAD"]
      cached_methods  = ["GET", "HEAD"]
      query_string    = false
      cookies         = "none"
      viewer_protocol = "redirect-to-https"
    }
  }
  
  # Configuración del origen ALB
  alb_origin = {
    # Propiedades básicas
    domain_name  = "mi-alb.us-east-1.elb.amazonaws.com"
    origin_id    = "mi-alb-origen"
    origin_path  = ""
    path_pattern = "/api/*"
    
    # Configuración de origen personalizado
    origin_config = {
      http_port     = 80
      https_port    = 443
      protocol      = "https-only"
      ssl_protocols = ["TLSv1.2"]
    }
    
    # Comportamiento de caché
    cache_behavior = {
      allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods  = ["GET", "HEAD"]
      viewer_protocol = "https-only"
      query_string    = true
    }
  }
}
```

### Caso 1: S3 como origen primario

Si deseas que S3 sea el origen predeterminado:

```hcl
distribution = {
  description         = "Mi distribución"
  primary_origin_type = "s3"
  
  # Configuración del comportamiento de caché predeterminado
  default_cache_behavior_compress = true
  default_cache_behavior_min_ttl = 0
  default_cache_behavior_default_ttl = 3600
  default_cache_behavior_max_ttl = 86400
  default_cache_behavior_cache_policy_id = "658327ea-f89d-47f2-9698-9013ddb722e4" # CachingDisabled
  
  s3_origin = {
    bucket_name = "mi-bucket-origen"
    
    # Configuración específica de S3
    cache_behavior = {
      allowed_methods = ["GET", "HEAD"]
      cached_methods  = ["GET", "HEAD"]
      viewer_protocol = "redirect-to-https"
    }
  }
  
  alb_origin = {
    domain_name  = "mi-alb.us-east-1.elb.amazonaws.com"
    origin_id    = "mi-alb-origen"
    path_pattern = "/api/*"
  }
}
```

### Caso 2: ALB como origen primario

Si deseas que el ALB sea el origen predeterminado:

```hcl
distribution = {
  description         = "Mi distribución"
  primary_origin_type = "alb"
  
  # Configuración del comportamiento de caché predeterminado
  default_cache_behavior_compress = true
  default_cache_behavior_min_ttl = 0
  default_cache_behavior_default_ttl = 3600
  default_cache_behavior_max_ttl = 86400
  default_cache_behavior_cache_policy_id = "658327ea-f89d-47f2-9698-9013ddb722e4" # CachingDisabled
  
  alb_origin = {
    domain_name = "mi-alb.us-east-1.elb.amazonaws.com"
    origin_id   = "mi-alb-origen"
    
    # Configuración específica del ALB
    cache_behavior = {
      allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods  = ["GET", "HEAD"]
      viewer_protocol = "https-only"
    }
  }
  
  s3_origin = {
    bucket_name  = "mi-bucket-origen"
    path_pattern = "/static/*"
  }
}
```
