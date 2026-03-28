# CloudFront Function Submódulo

Submódulo para crear una CloudFront Function en AWS.

## Uso

```hcl
module "cloudfront_function" {
  source = "./modules/cloudfront-function"

  name    = "my-viewer-request-function"
  code    = file("${path.module}/function.js")
  runtime = "cloudfront-js-2.0"  # Runtime 2.0 permite modificación de origen
  comment = "Función para seleccionar origen por dominio"
  publish = true
}
```

## Inputs

| Nombre  | Tipo   | Descripción                                              | Requerido | Default             |
|---------|--------|----------------------------------------------------------|-----------|---------------------|
| name    | string | Nombre de la CloudFront Function                         | Sí        | -                   |
| code    | string | Código JavaScript de la función                          | Sí        | -                   |
| runtime | string | Runtime de la función. Ver nota abajo sobre runtimes     | No        | cloudfront-js-1.0   |
| comment | string | Comentario opcional                                      | No        | ""                  |
| publish | bool   | Publicar la función automáticamente                      | No        | true                |

## Runtime 1.0 vs 2.0

- **`cloudfront-js-1.0`** (default): Permite modificar requests/responses básicos (headers, cookies, URL). **No permite cambiar el origen** de la petición.

- **`cloudfront-js-2.0`**: Incluye todas las capacidades del 1.0 más **modificación dinámica de origen**. Permite:
  - `cf.selectRequestOriginById(origin_id)`: Seleccionar un origen ya definido en la distribución
  - `cf.updateRequestOrigin({...})`: Actualizar propiedades del origen dinámicamente

**Usa runtime 2.0 si necesitas**:
- Enrutar tráfico a diferentes buckets/orígenes según el dominio (Host header)
- Implementar A/B testing por origen
- Cambiar el origen basado en geolocalización u otros criterios

**Ejemplo con runtime 2.0 (enrutamiento por dominio):**

```javascript
// function.js
import cf from 'cloudfront';

function handler(event) {
    var request = event.request;
    var host = request.headers.host ? request.headers.host.value : '';
    
    // Seleccionar origen según el dominio
    if (host.includes('staging')) {
        cf.selectRequestOriginById('my-staging-bucket');
    } else if (host.includes('dev')) {
        cf.selectRequestOriginById('my-dev-bucket');
    }
    // Si no coincide, usa el origen por defecto del behavior
    
    return request;
}
```

## Outputs

| Nombre | Descripción                    |
|--------|--------------------------------|
| arn    | ARN de la CloudFront Function  |
| name   | Nombre de la CloudFront Function |
| etag   | ETag de la CloudFront Function |

## Documentación de AWS

- [Helper methods for origin modification](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/helper-functions-origin-modification.html)
- [CloudFront Functions runtime 2.0](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/functions-javascript-runtime-20.html)
