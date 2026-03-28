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
| [primary_s3_origin](#primary_s3_origin)     | optional(object)       | Configuración del origen S3 primario (requerido cuando primary_origin_type es "s3")                                       | No        |
| [additional_s3_origins](#additional_s3_origins) | optional(list(object)) | Lista de orígenes S3 adicionales                                                                                          | No        |
| alb_origin                                  | optional(object)       | Configuración del origen ALB                                                                                              | No        |
| [lambda_association](#lambda_association)   | optional(list(object)) | Configuración para asociar funciones lambdas a un cache behaviour                                                         | No        |
| [custom_error_response](#custom_error_response) | optional(list(object)) | Configuración de respuestas personalizadas de error en CloudFront                                                         | No        |
| [api_gateway_origins](#api_gateway_origins) | optional(list(object)) | Objeto que contiene los parámetros usados para asociar recursos de API Gateway como *"Cache Behavior"* de la distribución | No        |
| default_cache_behavior_function_associations | optional(list(object)) | Lista de asociaciones de CloudFront Functions al default_cache_behavior. Cada elemento: `function_arn` (string), `event_type` (string: "viewer-request" o "viewer-response") | No        |

#### cloudfront_settings

| Campo        | Tipo                | Descripción                                         | Requerido |
| ------------ | ------------------- | --------------------------------------------------- | --------- |
| enabled      | optional(bool)      | Habilitar la distribución. Por defecto: true        | No        |
| root_object  | optional(string)    | Objeto raíz. Por defecto: "index.html"              | No        |
| aliases      | optional(list(any)) | Alias para la distribución. Por defecto: []         | No        |
| price_class  | optional(string)    | Clase de precio. Por defecto: "PriceClass_200"      | No        |
| restriction  | optional(string)    | Restricción geográfica. Por defecto: "none"         | No        |
| certificate  | optional(bool)      | Usar certificado SSL/TLS. Por defecto: true         | No        |
| web_acl_id   | optional(string)    | ARN/ID del Web ACL de AWS WAF para asociar a CloudFront. Por defecto: "" (se usa `null`) | No        |

#### primary_s3_origin

| Campo        | Tipo              | Descripción                                                            | Requerido |
| ------------ | ----------------- | ---------------------------------------------------------------------- | --------- |
| bucket_name  | string            | Nombre del bucket S3                                                   | Si        |
| path_pattern | optional(string)  | Patrón de ruta. Ver nota abajo sobre su uso                              | No        |
| cache_behavior | optional(object) | Configuración del comportamiento de caché                              | No        |

**Nota importante sobre `path_pattern` en `primary_s3_origin`:**

- Cuando **`primary_origin_type = "s3"`**: El `path_pattern` **no se utiliza**. El tráfico "por defecto" (catch-all) va al bucket primario a través del `default_cache_behavior`, que no requiere path_pattern. Puedes omitir este campo o dejarlo en `null`.

- Cuando **`primary_origin_type = "alb"`**: El `path_pattern` **sí se usa** para crear un `ordered_cache_behavior` que enruta tráfico específico (por ejemplo `/static/*` o `/app/*`) al bucket S3 primario, mientras que el resto va al ALB.

#### primary_s3_origin.cache_behavior

| Campo           | Tipo                 | Descripción                                                      | Requerido |
| --------------- | -------------------- | ---------------------------------------------------------------- | --------- |
| allowed_methods | optional(list(any))  | Métodos HTTP permitidos. Por defecto: ["GET", "HEAD"]            | No        |
| cached_methods  | optional(list(any))  | Métodos HTTP para caching. Por defecto: ["GET", "HEAD"]          | No        |
| query_string    | optional(bool)       | Habilita query string. Por defecto: false                        | No        |
| cookies         | optional(string)     | Manejo de cookies. Por defecto: "none"                           | No        |
| viewer_protocol | optional(string)     | Política de protocolo del viewer. Por defecto: "redirect-to-https" | No        |

#### additional_s3_origins

Lista de orígenes S3 adicionales. Cada bucket se registra como un **origen** en CloudFront, con comportamiento de caché según el caso:

| Campo        | Tipo              | Descripción                                                                                 | Requerido |
| ------------ | ----------------- | ------------------------------------------------------------------------------------------- | --------- |
| bucket_name  | string            | Nombre del bucket S3                                                                        | Si        |
| path_pattern | optional(string)  | Patrón de ruta. Solo se usa cuando ALB es primario (ver nota abajo)                        | No        |
| origin_id    | optional(string)  | ID único del origen para CloudFront. Si no se especifica, se usa el `bucket_name`           | No        |
| cache_behavior | optional(object) | Configuración del comportamiento de caché                                                   | No        |

**Nota importante sobre el uso de `path_pattern` y `additional_s3_origins`:**

- Cuando **`primary_origin_type = "alb"`**: Cada origen adicional se crea como `ordered_cache_behavior` con su `path_pattern` (ej: `/assets/*`, `/images/*`). El tráfico que coincida con ese patrón va al bucket correspondiente.

- Cuando **`primary_origin_type = "s3"`**: Los orígenes adicionales se **registran como orígenes** en CloudFront, pero **no se crean comportamientos ordenados automáticamente**. Esto permite usar **CloudFront Functions (runtime 2.0)** para enrutamiento dinámico. Por ejemplo, puedes usar `cf.selectRequestOriginById()` en una función viewer-request para enrutar según el header `Host` (ej: `staging.dominio.com` vs `dev.dominio.com`) a diferentes buckets.

**Ejemplo de enrutamiento por dominio con CloudFront Function:**

```javascript
// CloudFront Function (runtime 2.0)
import cf from 'cloudfront';

function handler(event) {
    var request = event.request;
    var host = request.headers.host ? request.headers.host.value : '';
    
    // Enrutar según el dominio
    if (host.includes('staging')) {
        cf.selectRequestOriginById('bucket-staging');
    } else {
        cf.selectRequestOriginById('bucket-dev');
    }
    
    return request;
}
```

En este caso, el `path_pattern` de los orígenes adicionales **no se usa**; el enrutamiento lo controla la función.

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

#### custom_error_response

| Campo                 | Tipo             | Descripción                                                                 | Requerido |
| --------------------- | ---------------- | --------------------------------------------------------------------------- | --------- |
| error_code            | number           | Código de error HTTP que CloudFront debe interceptar                        | Si        |
| error_caching_min_ttl | optional(number) | TTL en segundos para cachear la respuesta de error. Por defecto: 300        | No        |
| response_code         | optional(number) | Código HTTP que CloudFront devolverá al cliente                             | No        |
| response_page_path    | optional(string) | Ruta del objeto (por ejemplo `/404.html`) para la respuesta personalizada   | No        |

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

#### default_cache_behavior_function_associations

Lista de asociaciones de CloudFront Functions al comportamiento de caché predeterminado. **Las CloudFront Functions deben crearse previamente usando el submódulo** `modules/cloudfront-function`.

| Campo        | Tipo   | Descripción                                                                                        | Requerido |
| ------------ | ------ | -------------------------------------------------------------------------------------------------- | --------- |
| function_arn | string | ARN de la CloudFront Function (output del submódulo)                                               | Sí        |
| event_type   | string | Tipo de evento. Valores permitidos: `viewer-request`, `viewer-response`                           | Sí        |

**Nota:** Los eventos `origin-request` y `origin-response` son exclusivos de Lambda@Edge y no se pueden usar con CloudFront Functions.

### Output

| Nombre | Descripción |
|--------|-------------|
| origin_id | ID de la distribución CloudFront |
| domain_name | Nombre de dominio de la distribución CloudFront |
| distribution_arn | ARN (Amazon Resource Name) de la distribución CloudFront |
| s3_bucket_ids | Mapa de origin_id a bucket_id para todos los orígenes S3 creados |
| s3_origin_ids | Lista de origin_ids de todos los orígenes S3 configurados |
| primary_s3_origin_id | Origin ID del origen S3 primario (usado en default_cache_behavior) |

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
  primary_s3_origin = {
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
    web_acl_id  = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/mi-web-acl/11111111-2222-3333-4444-555555555555"
  }
  
  # Configuración del origen S3 primario
  primary_s3_origin = {
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

  custom_error_response = [
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    }
  ]
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
  
  primary_s3_origin = {
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

  custom_error_response = [
    {
      error_code         = 404
      response_code      = 200
      response_page_path = "/index.html"
    }
  ]
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
  
  primary_s3_origin = {
    bucket_name  = "mi-bucket-origen"
    path_pattern = "/static/*"
  }

  custom_error_response = [
    {
      error_code         = 404
      response_code      = 200
      response_page_path = "/index.html"
    }
  ]
}
```

### Caso 3: Múltiples orígenes S3

Si necesitas servir contenido desde múltiples buckets S3 (por ejemplo, uno para el sitio principal y otro para assets):

```hcl
distribution = {
  description         = "Mi distribución multi-bucket"
  primary_origin_type = "s3"
  
  # Configuración del comportamiento de caché predeterminado
  default_cache_behavior_compress = true
  default_cache_behavior_min_ttl = 0
  default_cache_behavior_default_ttl = 3600
  default_cache_behavior_max_ttl = 86400
  default_cache_behavior_cache_policy_id = "658327ea-f89d-47f2-9698-9013ddb722e4" # CachingDisabled
  
  # Origen S3 primario - sirve el sitio principal en /
  primary_s3_origin = {
    bucket_name = "mi-bucket-principal"
    
    cache_behavior = {
      allowed_methods = ["GET", "HEAD"]
      cached_methods  = ["GET", "HEAD"]
      viewer_protocol = "redirect-to-https"
    }
  }
  
  # Orígenes S3 adicionales - sirven assets en /assets/*
  additional_s3_origins = [
    {
      bucket_name  = "mi-bucket-assets"
      path_pattern = "/assets/*"
      origin_id    = "assets-origin"  # Opcional: si no se especifica, usa bucket_name
      
      cache_behavior = {
        allowed_methods = ["GET", "HEAD"]
        cached_methods  = ["GET", "HEAD"]
        viewer_protocol = "redirect-to-https"
      }
    },
    {
      bucket_name  = "mi-bucket-imagenes"
      path_pattern = "/images/*"
      
      cache_behavior = {
        allowed_methods = ["GET", "HEAD"]
        cached_methods  = ["GET", "HEAD"]
        viewer_protocol = "redirect-to-https"
      }
    }
  ]

  custom_error_response = [
    {
      error_code         = 404
      response_code      = 200
      response_page_path = "/index.html"
    }
  ]
}
```

### Caso 4: ALB primario con múltiples orígenes S3 secundarios

Si tu backend está en ALB pero necesitas servir archivos estáticos desde diferentes buckets:

```hcl
distribution = {
  description         = "Mi distribución ALB + S3"
  primary_origin_type = "alb"
  
  # Configuración del comportamiento de caché predeterminado
  default_cache_behavior_compress = true
  default_cache_behavior_min_ttl = 0
  default_cache_behavior_default_ttl = 3600
  default_cache_behavior_max_ttl = 86400
  default_cache_behavior_cache_policy_id = "658327ea-f89d-47f2-9698-9013ddb722e4" # CachingDisabled
  
  alb_origin = {
    domain_name = "mi-alb.us-east-1.elb.amazonaws.com"
    origin_id   = "api-backend"
    
    cache_behavior = {
      allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods  = ["GET", "HEAD"]
      viewer_protocol = "https-only"
    }
  }
  
  # Origen S3 primario (puede tener un path_pattern específico o ser default fallback)
  primary_s3_origin = {
    bucket_name  = "mi-bucket-spa"
    path_pattern = "/app/*"
  }
  
  # Orígenes S3 adicionales para diferentes tipos de contenido
  additional_s3_origins = [
    {
      bucket_name  = "mi-bucket-media"
      path_pattern = "/media/*"
    },
    {
      bucket_name  = "mi-bucket-docs"
      path_pattern = "/docs/*"
    }
  ]
}
```

### Caso 5: Con CloudFront Function

Para asociar una CloudFront Function a la distribución, primero debes crearla usando el submódulo y luego pasar su ARN:

```hcl
# Primero crear la función usando el submódulo (en otra unidad Terragrunt o módulo)
module "viewer_request_function" {
  source = "./modules/cloudfront-function"

  name    = "my-viewer-request-function"
  code    = file("${path.module}/viewer-request.js")
  runtime = "cloudfront-js-1.0"
  comment = "Función para reescribir URLs"
  publish = true
}

# Luego usar el módulo raíz pasando el ARN
distribution = {
  description         = "Mi distribución con CloudFront Function"
  primary_origin_type = "s3"
  
  # ... configuración de origenes y caché ...
  
  primary_s3_origin = {
    bucket_name = "mi-bucket-principal"
  }
  
  # Asociar la función al default_cache_behavior
  default_cache_behavior_function_associations = [
    {
      function_arn = module.viewer_request_function.arn  # ARN desde el submódulo
      event_type   = "viewer-request"                    # Solo viewer-request o viewer-response
    }
  ]
}
```

**Nota importante:** Los eventos permitidos para CloudFront Functions son `viewer-request` y `viewer-response`. Los eventos `origin-request` y `origin-response` son exclusivos de Lambda@Edge.

### Caso 6: Enrutamiento por dominio con CloudFront Function (Runtime 2.0)

Si tienes múltiples entornos (dev, staging) con diferentes buckets y quieres usar un solo dominio con subdominios para enrutar a cada uno:

```hcl
# Código de la CloudFront Function (viewer-request.js)
# Usa runtime 2.0 para poder cambiar el origen dinámicamente
/*
import cf from 'cloudfront';

function handler(event) {
    var request = event.request;
    var host = request.headers.host ? request.headers.host.value : '';
    
    // Enrutar según el subdominio
    if (host.includes('staging')) {
        cf.selectRequestOriginById('bucket-staging-assets');
    } else if (host.includes('dev')) {
        cf.selectRequestOriginById('bucket-dev-assets');
    }
    // Si no coincide, usa el origen por defecto del behavior
    
    return request;
}
*/

# Primero crear la función con runtime 2.0
module "domain_routing_function" {
  source = "./modules/cloudfront-function"

  name    = "domain-routing-function"
  code    = file("${path.module}/viewer-request.js")
  runtime = "cloudfront-js-2.0"  # Runtime 2.0 permite cambiar origen
  comment = "Enruta según subdominio (staging/dev)"
  publish = true
}

# Luego usar el módulo raíz con múltiples buckets
distribution = {
  description         = "CDN multi-entorno"
  primary_origin_type = "s3"
  
  # Bucket por defecto (dev)
  primary_s3_origin = {
    bucket_name = "bucket-dev-assets"
  }
  
  # Bucket adicional para staging (se registra como origen, no como ordered behavior)
  additional_s3_origins = [
    {
      bucket_name = "bucket-staging-assets"
      # origin_id se usará en la función: cf.selectRequestOriginById('bucket-staging-assets')
    }
  ]
  
  # La función enrutará según el header Host
  default_cache_behavior_function_associations = [
    {
      function_arn = module.domain_routing_function.arn
      event_type   = "viewer-request"
    }
  ]
  
  cloudfront_settings = {
    aliases = ["dev.dominio.com", "staging.dominio.com"]
  }
}
```

**Puntos clave de este caso:**
- Usa **runtime 2.0** (`cloudfront-js-2.0`) que permite modificar el origen
- Los buckets adicionales se registran como **orígenes** pero no crean `ordered_cache_behavior` porque S3 es el primario
- La función usa `cf.selectRequestOriginById()` para cambiar el origen según el dominio
- **No se usa** `path_pattern` para el enrutamiento; eso es para `ordered_cache_behavior` con ALB primario

## CloudFront Functions y Terragrunt

Este módulo incluye un submódulo separado para crear CloudFront Functions: `modules/cloudfront-function`.

### Flujo recomendado con Terragrunt

1. **Aplicar la unidad del submódulo** `cloudfront-function` primero:
   - Inputs: `name`, `code`, `runtime`, `comment`, `publish`
   - Output: `arn` (necesario para el paso 2)

2. **Aplicar la unidad del módulo raíz** pasando el ARN de la función:
   - Usar `dependency` para referenciar la unidad de la función
   - Input: `default_cache_behavior_function_associations` con el ARN

### Ejemplo de estructura Terragrunt

```
terragrunt/
├── cloudfront-function/
│   └── terragrunt.hcl
└── web-distribution/
    └── terragrunt.hcl
```

**cloudfront-function/terragrunt.hcl:**
```hcl
terraform {
  source = "../../terraform-aws-web//modules/cloudfront-function"
}

inputs = {
  name    = "my-viewer-request-function"
  code    = file("${get_terragrunt_dir()}/viewer-request.js")
  runtime = "cloudfront-js-1.0"
  comment = "Reescribe URLs para SPA"
  publish = true
}
```

**web-distribution/terragrunt.hcl:**
```hcl
dependency "cloudfront_function" {
  config_path = "../cloudfront-function"
}

terraform {
  source = "../../terraform-aws-web"
}

inputs = {
  common_tags = {
    project = "my-project"
  }
  
  distribution = {
    description         = "Mi distribución"
    primary_origin_type = "s3"
    
    primary_s3_origin = {
      bucket_name = "my-bucket"
    }
    
    # Asociar la función pasando el ARN desde el submódulo
    default_cache_behavior_function_associations = [
      {
        function_arn = dependency.cloudfront_function.outputs.arn
        event_type   = "viewer-request"
      }
    ]
  }
}
```

### Outputs para Terragrunt

El módulo raíz expone `terragrunt_cloudfront_function_context` con metadatos de la distribución que pueden ser útiles para nombrar/documentar funciones:

| Output | Descripción |
|--------|-------------|
| `terragrunt_cloudfront_function_context` | Objeto con `distribution_id`, `distribution_arn`, `domain_name`, `description`, `common_tags` |
| `suggested_cloudfront_function_name` | Nombre sugerido basado en la distribución (convención, opcional) |
| `distribution_id` | ID de la distribución CloudFront (alias de `origin_id`) |

**Nota:** El ARN de la CloudFront Function **no** sale del módulo raíz, sino del **output del submódulo** `modules/cloudfront-function`.
